{ pkgs }:

let
  # patchShebangs resolves the interpreter from the build PATH, so python3
  # has to be here for the `#!/usr/bin/env python3` line to be rewritten
  # into a store path rather than left dangling.
  # The source is passed per helper rather than derived from a directory, so a
  # change to one script does not rebuild the others.
  pythonHelper =
    name: src:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      version = "1";
      dontUnpack = true;
      nativeBuildInputs = [ pkgs.python3 ];
      installPhase = ''
        install -Dm755 ${src} $out/bin/${name}
        patchShebangs $out/bin/${name}
      '';
      meta.mainProgram = name;
    };

  agentSettings = pythonHelper "agent-settings" ../scripts/agent-settings;

  # Runs from home activation, where PATH carries neither home.packages nor
  # the login shell's session variables, so the module hands it the agent CLI
  # by store path and exports the declared environment tier around it.
  agentPluginSync = pythonHelper "agent-plugin-sync" ../scripts/agent-plugin-sync;

  # Runs in continuous integration rather than at activation. Its network call
  # goes through an overridable command so the repository check can drive it
  # with fixtures; a sandboxed check has no network.
  agentPluginRelease = pythonHelper "agent-plugin-release" ../scripts/agent-plugin-release;

  # Resolves the latest release of Claude Desktop from the Debian APT repository.
  claudeDesktopRelease = pythonHelper "claude-desktop-release" ../scripts/claude-desktop-release;

  # Resolves the latest claude-code release manifest from Anthropic's own
  # release endpoints. Its network calls go through an overridable command so
  # the sandboxed repository check can drive it with fixtures.
  claudeCodeRelease = pythonHelper "claude-code-release" ../scripts/claude-code-release;
in
{
  inherit
    agentSettings
    agentPluginSync
    agentPluginRelease
    claudeDesktopRelease
    claudeCodeRelease
    ;
}
