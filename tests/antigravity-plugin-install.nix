/*
  Check interface:

    import ./tests/antigravity-plugin-install.nix { inherit pkgs self; }

  Drives the pinned agy through the packaged agent-plugin-sync helper, the
  same pair activation runs, against the pinned compound-engineering source
  in a throwaway HOME. The fake-CLI tests in the agent-plugin-sync check prove
  the helper's control flow; this one proves the real agy accepts what the
  helper hands it, which no fake can. agy installs a plugin offline, so the
  sandbox runs it as is.

  - The first sync installs the plugin: `agy plugin list` reports it enabled
    at the source manifest's version, and the installed skills are exactly the
    source's.
  - A second sync leaves the installed tree alone: a marker dropped into it
    survives, which an install, replacing the whole tree, would remove.
  - Retiring removes the installed plugin and the version-keyed base.
*/
{ pkgs, self }:
let
  system = pkgs.stdenv.hostPlatform.system;
  agy = "${self.packages.${system}.antigravity-cli}/bin/agy";
  sync = "${
    (import ../packages/agent-tools.nix { inherit pkgs; }).agentPluginSync
  }/bin/agent-plugin-sync";
  source = self.inputs.compound-engineering-plugin;
in
pkgs.runCommand "antigravity-plugin-install" { nativeBuildInputs = [ pkgs.jq ]; } ''
  export HOME=$PWD/home
  mkdir -p "$HOME"
  base=$HOME/.local/share/agent-plugins/compound-engineering
  installed=$HOME/.gemini/config/plugins/compound-engineering
  version=$(jq -r .version ${source}/plugin.json)

  runSync() {
    ${sync} --harness antigravity --cli ${agy} --source ${source} \
      --base "$base" --segment v-check \
      --plugin compound-engineering --marketplace compound-engineering-plugin
  }

  runSync
  if ! ${agy} plugin list | grep -qF "compound-engineering (enabled, $version)"; then
    echo "agy does not list compound-engineering enabled at $version after a sync:" >&2
    ${agy} plugin list >&2
    exit 1
  fi
  if ! diff <(ls ${source}/skills) <(ls "$installed/skills"); then
    echo "the installed skills differ from the pinned source's" >&2
    exit 1
  fi

  touch "$installed/marker"
  runSync
  if [ ! -e "$installed/marker" ]; then
    echo "a second sync on a converged home reinstalled the plugin" >&2
    exit 1
  fi

  ${sync} --retire --harness antigravity --cli ${agy} --base "$base" \
    --plugin compound-engineering --marketplace compound-engineering-plugin
  if [ -e "$installed" ] || [ -e "$base" ]; then
    echo "retiring left the installed plugin or its base behind" >&2
    exit 1
  fi

  touch $out
''
