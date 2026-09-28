{ pkgs }:

let
  inherit (pkgs) lib;

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

  # The same shape for a Ruby helper: patchShebangs resolves `ruby` to the
  # interpreter wrapped with the helper's gems.
  rubyHelper =
    name: src: ruby:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      version = "1";
      dontUnpack = true;
      nativeBuildInputs = [ ruby ];
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

  # Resolves the latest mise release from the SHASUMS256.txt asset of its
  # latest GitHub release. Its network call goes through an overridable
  # command so the sandboxed repository check can drive it with fixtures.
  miseRelease = pythonHelper "mise-release" ../scripts/mise-release;

  # Pins the Android SDK packages from Google's repository XML. Its network
  # call goes through an overridable command for the same reason. It is Ruby
  # because it vendors nixpkgs' androidenv update.rb, which parses with
  # nokogiri.
  androidSdkRelease = rubyHelper "android-sdk-release" ../scripts/android-sdk-release (
    pkgs.ruby.withPackages (ps: [ ps.nokogiri ])
  );

  # Claude Code caps each hook's output, so the guide arrives in parts, one
  # per handler. The plugin declares this many handlers and the script appends
  # its pointer to the full guide to the last of them.
  claudeParts = 3;

  # Runs as a coding agent's session-start hook, whose PATH is whatever the
  # agent was started with, so every tool it calls is named by store path.
  orcaOrchestrationContext = pkgs.stdenvNoCC.mkDerivation {
    pname = "orca-orchestration-context";
    version = "1";
    dontUnpack = true;
    installPhase = ''
      install -Dm755 ${../scripts/orca-orchestration-context} $out/bin/orca-orchestration-context
      substituteInPlace $out/bin/orca-orchestration-context \
        --replace-fail '@ORCA_CLI@' '${(import ./orca.nix { inherit pkgs; }).cli}' \
        --replace-fail '@JQ@' '${lib.getExe pkgs.jq}' \
        --replace-fail '@TIMEOUT@' '${pkgs.coreutils}/bin/timeout' \
        --replace-fail '@CLAUDE_PARTS@' '${toString claudeParts}' \
        --replace-fail '@CLI_PATH@' '${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
          ]
        }'
      patchShebangs $out/bin/orca-orchestration-context
    '';
    passthru = { inherit claudeParts; };
    meta.mainProgram = "orca-orchestration-context";
  };
in
{
  inherit
    orcaOrchestrationContext
    agentSettings
    agentPluginSync
    agentPluginRelease
    claudeDesktopRelease
    claudeCodeRelease
    miseRelease
    androidSdkRelease
    ;
}
