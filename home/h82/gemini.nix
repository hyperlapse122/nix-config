{
  config,
  pkgs,
  lib,
  ...
}:
let
  merger = "${
    (import ../../packages/agent-tools.nix { inherit pkgs; }).agentSettings
  }/bin/agent-settings";

  # The Antigravity CLI owns ~/.gemini/antigravity-cli/settings.json and
  # rewrites it at runtime -- trusting a workspace replaces the whole file --
  # so a read-only store symlink cannot live there. Home Manager placed one
  # anyway until the CLI replaced it with a regular file, and the next
  # activation then refused to clobber it and failed the rebuild. Activation
  # assigns the declared keys instead and leaves everything the agent wrote,
  # trusted workspaces included, alone.
  antigravityTier = {
    disableAutoGenerateMemories = true;
  };

  # Keys this repository used to declare and has since retired. The merge only
  # assigns, so dropping a key from antigravityTier alone would leave its last
  # written value on every machine forever. Move it here instead, and delete
  # the entry once every host has rebuilt past it.
  retiredKeys = [ ];

  declared = pkgs.writeText "antigravity-declared-settings.json" (
    builtins.toJSON {
      set = antigravityTier;
      remove = retiredKeys;
    }
  );
in
{
  # Disable cross-session, implicit memory for the Gemini and Antigravity CLIs
  # to preserve declarative environment determinism.
  #
  # The Gemini CLI reads this file but does not rewrite it, so it stays a store
  # symlink; the merge is only for the file that has another writer.
  home.file.".gemini/settings.json".text = builtins.toJSON {
    experimental = {
      autoMemory = false;
    };
  };

  # Unguarded and after installPackages for the same reasons as the Claude Code
  # merge in claude.nix: the merger is a store path built from this module, so a
  # guard could only ever be true, and a refusal ordered before linkGeneration
  # would strand the rest of home activation.
  home.activation.antigravitySettings = lib.hm.dag.entryAfter [ "installPackages" ] ''
    ${merger} \
      --label 'Antigravity CLI' \
      --settings ${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json \
      --declared ${declared}
  '';
}
