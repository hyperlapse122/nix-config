// Drives the OpenCode session-info plugin against stub plugin contexts.
//
//   node --test tests/opencode-session-info.test.mjs
//
// PLUGIN names the plugin's index.js; it defaults to the repository copy.
// The stubs reproduce the shapes OpenCode 2.1.1 handed a probe plugin on a
// live run: the model.request event, the tool context, session.get, and
// model.list, whose settings carry the provider's apiKey beside the
// configured reasoningEffort.
import assert from "node:assert/strict";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

const pluginPath =
  process.env.PLUGIN ?? new URL("../packages/opencode-session-info/index.js", import.meta.url).pathname;
const plugin = (await import(pathToFileURL(pluginPath).href)).default;

const SESSION = "ses_fixture";
const API_KEY = "fake-api-key-must-not-leak";

const modelEntry = (providerID, id, reasoningEffort) => ({
  id,
  modelID: id,
  providerID,
  settings: { apiKey: API_KEY, baseURL: "http://127.0.0.1:9/v1", provider: providerID, reasoningEffort },
  variants: [{ id: "high", settings: { reasoningEffort: "high" } }],
});

// A stub plugin context. `get` and `list` replace ctx.session.get and
// ctx.model.list; the returned `fire` replays a model.request event through
// the hook the plugin registered, and `call` runs the registered tool.
async function load({ get, list } = {}) {
  const hooks = new Map();
  const tools = [];
  const ctx = {
    session: {
      hook: async (name, callback) => {
        hooks.set(name, callback);
      },
      get:
        get ??
        (async () => {
          throw new Error("session.get not stubbed");
        }),
    },
    model: {
      list:
        list ??
        (async () => ({
          location: { directory: "/tmp" },
          data: [
            modelEntry("synthetic", "hf:moonshotai/Kimi-K3", "high"),
            modelEntry("synthetic", "hf:zai-org/GLM-5.3", "max"),
          ],
        })),
    },
    tool: {
      transform: async (callback) => {
        callback({ add: (definition) => tools.push(definition) });
      },
    },
  };
  await plugin.setup(ctx);
  return {
    tools,
    fire: (event) => hooks.get("model.request")?.(event),
    call: async (sessionID = SESSION) => {
      const result = await tools[0].execute({}, { sessionID, agent: "build", messageID: "msg_1", id: "call_1" });
      return { raw: result.content, report: JSON.parse(result.content) };
    },
  };
}

test("the default export is a v2 plugin definition", () => {
  assert.equal(typeof plugin.id, "string");
  assert.ok(plugin.id.length > 0);
  assert.equal(typeof plugin.setup, "function");
});

test("setup registers one argument-free tool outside code mode", async () => {
  const { tools } = await load();
  assert.equal(tools.length, 1);
  assert.equal(tools[0].name, "session_info");
  assert.deepEqual(tools[0].input, { type: "object", properties: {}, additionalProperties: false });
  assert.equal(tools[0].options?.codemode, false);
});

test("a recorded primary request supplies provider, model, and variant", async () => {
  const session = load({
    get: async () => {
      throw new Error("session.get must not be needed");
    },
  });
  const { fire, call } = await session;
  await fire({
    sessionID: SESSION,
    agent: "build",
    kind: "primary",
    model: { providerID: "synthetic", id: "hf:zai-org/GLM-5.3", variant: "max" },
  });
  const { raw, report } = await call();
  assert.deepEqual(report, {
    provider: "synthetic",
    model: "hf:zai-org/GLM-5.3",
    variant: "max",
    effort: "max",
    sessionID: SESSION,
    sources: {
      provider: "model.request",
      model: "model.request",
      variant: "model.request",
      effort: "model.list",
      sessionID: "tool.context",
    },
    error: null,
  });
  assert.ok(!raw.includes(API_KEY), "the report must not carry the provider's apiKey");
});

test("a title request does not replace the primary model", async () => {
  const { fire, call } = await load();
  await fire({
    sessionID: SESSION,
    kind: "primary",
    model: { providerID: "synthetic", id: "hf:zai-org/GLM-5.3", variant: "default" },
  });
  await fire({
    sessionID: SESSION,
    agent: "title",
    kind: "title",
    model: { providerID: "synthetic", id: "hf:moonshotai/Kimi-K3", variant: "low" },
  });
  const { report } = await call();
  assert.equal(report.model, "hf:zai-org/GLM-5.3");
  assert.equal(report.variant, "default");
  assert.equal(report.effort, "max");
});

test("another session's request is not reported", async () => {
  let asked = null;
  const { fire, call } = await load({
    get: async ({ sessionID }) => {
      asked = sessionID;
      return { id: sessionID };
    },
  });
  await fire({
    sessionID: "ses_other",
    kind: "primary",
    model: { providerID: "synthetic", id: "hf:zai-org/GLM-5.3", variant: "max" },
  });
  const { report } = await call();
  assert.equal(asked, SESSION);
  assert.equal(report.model, null);
  assert.equal(report.sources.model, null);
});

test("with no recorded request, session.get supplies the values", async () => {
  let asked = null;
  const { call } = await load({
    get: async ({ sessionID }) => {
      asked = sessionID;
      return {
        id: sessionID,
        model: { providerID: "synthetic", id: "hf:moonshotai/Kimi-K3", variant: "default" },
      };
    },
  });
  const { raw, report } = await call();
  assert.equal(asked, SESSION);
  assert.deepEqual(report, {
    provider: "synthetic",
    model: "hf:moonshotai/Kimi-K3",
    variant: "default",
    effort: "high",
    sessionID: SESSION,
    sources: {
      provider: "session.get",
      model: "session.get",
      variant: "session.get",
      effort: "model.list",
      sessionID: "tool.context",
    },
    error: null,
  });
  assert.ok(!raw.includes(API_KEY), "the report must not carry the provider's apiKey");
});

test("a model missing from model.list leaves the effort null", async () => {
  const { call } = await load({
    get: async () => ({ model: { providerID: "synthetic", id: "hf:unknown/Model", variant: "default" } }),
  });
  const { report } = await call();
  assert.equal(report.model, "hf:unknown/Model");
  assert.equal(report.effort, null);
  assert.equal(report.sources.effort, null);
  assert.equal(report.error, null);
});

test("throwing stubs give null fields and an error note instead of a throw", async () => {
  const { call } = await load({
    get: async () => {
      throw new Error("session.get exploded");
    },
    list: async () => {
      throw new Error("model.list exploded");
    },
  });
  const { report } = await call();
  assert.equal(report.provider, null);
  assert.equal(report.model, null);
  assert.equal(report.variant, null);
  assert.equal(report.effort, null);
  assert.deepEqual(report.sources, {
    provider: null,
    model: null,
    variant: null,
    effort: null,
    sessionID: "tool.context",
  });
  assert.match(report.error, /session\.get exploded/);
});

test("a throwing model.list keeps the recorded model and notes the error", async () => {
  const { fire, call } = await load({
    list: async () => {
      throw new Error("model.list exploded");
    },
  });
  await fire({
    sessionID: SESSION,
    kind: "primary",
    model: { providerID: "synthetic", id: "hf:zai-org/GLM-5.3", variant: "max" },
  });
  const { report } = await call();
  assert.equal(report.model, "hf:zai-org/GLM-5.3");
  assert.equal(report.effort, null);
  assert.match(report.error, /model\.list exploded/);
});

test("a malformed event or a missing session ID never throws", async () => {
  const { fire, tools } = await load({ get: async () => null });
  assert.doesNotThrow(() => fire(null));
  assert.doesNotThrow(() => fire({ kind: "primary" }));
  const result = await tools[0].execute({}, undefined);
  const report = JSON.parse(result.content);
  assert.equal(report.sessionID, null);
  assert.equal(report.sources.sessionID, null);
  assert.equal(report.model, null);
});
