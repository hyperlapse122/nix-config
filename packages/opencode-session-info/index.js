// OpenCode accepts any default export with a string `id` and a `setup`
// function, so the plugin imports nothing and runs from the Nix store as is.
// A tool's context carries no model, so the model comes from the session's
// last primary model.request event, then from ctx.session.get. The effort is
// the model's configured reasoningEffort from ctx.model.list; its settings
// also hold the provider's apiKey, so only that one field is reported. An
// error message is returned only after every configured credential the
// plugin can list, and anything shaped like a bearer token, is cut from it.

const read = (value) => (typeof value === "string" && value.length > 0 ? value : null);

// A field whose name says it holds a credential, in model.list settings or
// in provider.list.
const SECRET_FIELD = /^(api[-_]?key|key|token|access[-_]?token|refresh[-_]?token|secret|password|authorization)$/i;
const BEARER = /\b(Bearer|Basic|Token)\s+[^\s"',;]+/gi;
const TOKEN_SHAPE = /\b(?:sk|syn|pk|rk|key|token)[-_][A-Za-z0-9][A-Za-z0-9_-]{15,}/gi;
const REDACTED = "[redacted]";

const collectSecrets = (value, found, depth = 0) => {
  if (depth > 8 || value === null || typeof value !== "object") return;
  for (const [field, item] of Object.entries(value)) {
    if (typeof item === "string") {
      if (item.length >= 8 && SECRET_FIELD.test(field)) found.add(item);
    } else {
      collectSecrets(item, found, depth + 1);
    }
  }
};

const redact = (message, secrets) => {
  let text = String(message);
  // Longest first, so a key that contains another is cut whole.
  for (const secret of [...secrets].sort((left, right) => right.length - left.length)) {
    text = text.split(secret).join(REDACTED);
  }
  return text.replace(BEARER, `$1 ${REDACTED}`).replace(TOKEN_SHAPE, REDACTED);
};

// Whether `current` names the provider and model `recorded` names, where
// `recorded` names them.
const sameModel = (recorded, current) =>
  ["providerID", "id"].every((key) => read(recorded?.[key]) === null || read(recorded[key]) === read(current?.[key]));

const describe = (error) => error?.message ?? String(error);

const blank = (sessionID) => ({
  provider: null,
  model: null,
  variant: null,
  effort: null,
  sessionID,
  sources: {
    provider: null,
    model: null,
    variant: null,
    effort: null,
    sessionID: sessionID === null ? null : "tool.context",
  },
  error: null,
});

const MAX_REQUESTED = 256;

export default {
  id: "nix-config.session-info",
  async setup(ctx) {
    const requested = new Map();

    // Title and compaction requests run on other models or variants.
    await ctx.session.hook("model.request", (event) => {
      try {
        if (event?.kind !== "primary" || !read(event.sessionID) || !event.model) return;
        const { providerID, id, variant } = event.model;
        const stored = requested.get(event.sessionID);
        if (stored?.providerID === providerID && stored.id === id && stored.variant === variant) return;
        requested.delete(event.sessionID);
        requested.set(event.sessionID, { providerID, id, variant });
        if (requested.size > MAX_REQUESTED) requested.delete(requested.keys().next().value);
      } catch {
        // Never disturb the request this hook observes.
      }
    });

    // Every credential the plugin's own APIs can show it. Each lookup may
    // fail; what it found still counts.
    const secrets = async (listed) => {
      const found = new Set();
      collectSecrets(listed, found);
      const sources = [() => ctx.provider.list()];
      if (listed === undefined) sources.push(() => ctx.model.list());
      for (const source of sources) {
        try {
          collectSecrets(await source(), found);
        } catch {
          // Pattern redaction below still applies.
        }
      }
      return found;
    };

    const report = async (context) => {
      const errors = [];
      const sessionID = read(context?.sessionID);
      const result = blank(sessionID);
      let listed;

      const take = (ref, source) => {
        for (const [field, key] of [
          ["provider", "providerID"],
          ["model", "id"],
          ["variant", "variant"],
        ]) {
          const value = read(ref?.[key]);
          if (result[field] === null && value !== null) {
            result[field] = value;
            result.sources[field] = source;
          }
        }
      };

      if (sessionID !== null) {
        const recorded = requested.get(sessionID);
        take(recorded, "model.request");
        const known = result.provider !== null && result.model !== null;
        // session.get fills only what the record lacks, and only from the
        // same model: the session's current model may not be the one the
        // recorded request ran.
        if (!known || result.variant === null) {
          try {
            const current = (await ctx.session.get({ sessionID }))?.model;
            if (sameModel(recorded, current)) take(current, "session.get");
          } catch (error) {
            // A record with provider and model already answers the question.
            if (!known) errors.push(`session.get: ${describe(error)}`);
          }
        }
      } else {
        errors.push("the tool context carries no session ID");
      }

      if (result.provider !== null && result.model !== null) {
        try {
          listed = await ctx.model.list();
          const entries = (Array.isArray(listed?.data) ? listed.data : []).filter(
            (model) => model?.providerID === result.provider,
          );
          // Several entries can share one upstream modelID, such as a second
          // entry at another effort, so the entry's own id wins.
          const entry =
            entries.find((model) => model.id === result.model) ??
            entries.find((model) => model.modelID === result.model);
          const effort = read(entry?.settings?.reasoningEffort);
          if (effort !== null) {
            result.effort = effort;
            result.sources.effort = "model.list";
          }
        } catch (error) {
          listed = undefined;
          errors.push(`model.list: ${describe(error)}`);
        }
      }

      result.error = errors.length === 0 ? null : redact(errors.join("; "), await secrets(listed));
      return result;
    };

    await ctx.tool.transform((editor) => {
      editor.add({
        name: "session_info",
        description:
          "Report this session's provider, model ID, variant, configured reasoning effort, and session ID, and where each value came from. Read-only; takes no arguments. A value it cannot read is null.",
        input: { type: "object", properties: {}, additionalProperties: false },
        // A code-mode tool reaches the model only through `execute`.
        options: { codemode: false },
        async execute(_input, context) {
          let result;
          try {
            result = await report(context);
          } catch (error) {
            let found = new Set();
            try {
              found = await secrets(undefined);
            } catch {
              // Pattern redaction still applies.
            }
            result = { ...blank(null), error: redact(`session_info: ${describe(error)}`, found) };
          }
          return { content: JSON.stringify(result) };
        },
      });
    });
  },
};
