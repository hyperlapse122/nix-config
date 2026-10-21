# Each entry:
# - `id`: the upstream model ID, without OpenCode's `synthetic/` provider prefix.
# - `family`: the family the shared instructions map the ID's org to.
# - `lineage`: an anchored regular expression, valid for both Nix
#   `builtins.match` and Python `re.fullmatch`, that matches this ID and newer
#   builds of the same product but no suffixed product such as `-Air` or
#   `-Code`. Its first capture group is the version; POSIX regular
#   expressions have no non-capturing group, so later groups only hold the
#   optional parts of that version or the build suffix.
# - `roles`: each role the model fills inside T3 Code, with the effort that
#   role runs at. These models offer no `medium` effort.
# - `opencodeEffort`: the reasoning effort OpenCode's settings pin for the
#   model, which runs outside T3 Code use as-is.
#
# The DeepSeek `id` pins one dated build and moves only when the user changes
# it after a reconcile issue reports a newer one.
{
  glm = {
    id = "hf:zai-org/GLM-5.3";
    family = "glm";
    lineage = "hf:zai-org/GLM-([0-9]+([.][0-9]+)?)";
    roles = {
      reviewer = "max";
      deep-fallback = "max";
      writing-fallback = "high";
      unspecified-high-fallback = "high";
    };
    opencodeEffort = "max";
  };

  kimi = {
    id = "hf:moonshotai/Kimi-K3";
    family = "kimi";
    lineage = "hf:moonshotai/Kimi-K([0-9]+([.][0-9]+)?)";
    roles = {
      reviewer = "max";
      visual-engineering-fallback = "max";
    };
    opencodeEffort = "max";
  };

  deepseek = {
    id = "hf:deepseek-ai/DeepSeek-V4.1-Flash-1017";
    family = "deepseek";
    lineage = "hf:deepseek-ai/DeepSeek-V([0-9]+([.][0-9]+)?)-Flash(-[0-9]{4})?";
    roles = {
      unspecified-low = "high";
      quick = "low";
      scout = "high";
      text-generation = "low";
    };
    opencodeEffort = "high";
  };

  opencodeDefault = "glm";
  small = "deepseek";
  textGeneration = "deepseek";
}
