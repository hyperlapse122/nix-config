// OpenCode accepts any default export with a string `id` and a `setup`
// function, so the plugin imports nothing and runs from the Nix store as is.
// A tool's context carries no model, so the model comes from the session's
// last primary model.request event, then from ctx.session.get. The effort is
// the model's configured reasoningEffort from ctx.model.list; its settings
// also hold the provider's apiKey, so only that one field is read.

const read = (value) => (typeof value === "string" && value.length > 0 ? value : null);

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

    const report = async (context) => {
      const errors = [];
      const sessionID = read(context?.sessionID);
      const result = blank(sessionID);

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
        take(requested.get(sessionID), "model.request");
        if (result.provider === null || result.model === null || result.variant === null) {
          try {
            take((await ctx.session.get({ sessionID }))?.model, "session.get");
          } catch (error) {
            errors.push(`session.get: ${error?.message ?? String(error)}`);
          }
        }
      } else {
        errors.push("the tool context carries no session ID");
      }

      if (result.provider !== null && result.model !== null) {
        try {
          const listed = await ctx.model.list();
          const entry = (Array.isArray(listed?.data) ? listed.data : []).find(
            (model) =>
              model?.providerID === result.provider && (model.id === result.model || model.modelID === result.model),
          );
          const effort = read(entry?.settings?.reasoningEffort);
          if (effort !== null) {
            result.effort = effort;
            result.sources.effort = "model.list";
          }
        } catch (error) {
          errors.push(`model.list: ${error?.message ?? String(error)}`);
        }
      }

      result.error = errors.length === 0 ? null : errors.join("; ");
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
            result = { ...blank(null), error: `session_info: ${error?.message ?? String(error)}` };
          }
          return { content: JSON.stringify(result) };
        },
      });
    });
  },
};
