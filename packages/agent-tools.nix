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

  # The same shape for a helper that needs libraries: patchShebangs resolves
  # the interpreter to the one wrapped with the helper's packages.
  helperWith =
    name: src: interpreter:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      version = "1";
      dontUnpack = true;
      nativeBuildInputs = [ interpreter ];
      installPhase = ''
        install -Dm755 ${src} $out/bin/${name}
        patchShebangs $out/bin/${name}
      '';
      meta.mainProgram = name;
    };

  # tomlkit is what lets the TOML mode rewrite a file such as Codex's
  # config.toml without dropping the comments and tables it does not own. The
  # flake check runs the source copy of the tests under this same interpreter.
  agentSettingsPython = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  agentSettings = helperWith "agent-settings" ../scripts/agent-settings agentSettingsPython;

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

  # Resolves the latest ChatGPT desktop release from OpenAI's APT repository.
  # Its network call goes through an overridable command so the sandboxed
  # repository check can drive it with fixtures.
  chatgptRelease = pythonHelper "chatgpt-release" ../scripts/chatgpt-release;

  # Resolves the latest claude-code release manifest from Anthropic's own
  # release endpoints. Its network calls go through an overridable command so
  # the sandboxed repository check can drive it with fixtures.
  claudeCodeRelease = pythonHelper "claude-code-release" ../scripts/claude-code-release;

  # Resolves the latest mise release from the SHASUMS256.txt asset of its
  # latest GitHub release. Its network call goes through an overridable
  # command so the sandboxed repository check can drive it with fixtures.
  miseRelease = pythonHelper "mise-release" ../scripts/mise-release;

  # Resolves the latest Codex release and its musl asset digest from the
  # GitHub releases API. Its network call goes through an overridable command
  # so the sandboxed repository check can drive it with fixtures.
  codexRelease = pythonHelper "codex-release" ../scripts/codex-release;

  # Resolves the newest T3 Code nightly and its asset digests from the GitHub
  # releases API. Its network call goes through an overridable command so the
  # sandboxed repository check can drive it with fixtures.
  t3codeRelease = pythonHelper "t3code-release" ../scripts/t3code-release;

  # Runs from home activation and links the pinned Antigravity runtime into
  # T3 Code's managed runtime directory, which T3 Code checks on disk.
  t3codeAntigravityInstall = pythonHelper "t3code-antigravity-install" ../scripts/t3code-antigravity-install;

  # Pins the Android SDK packages from Google's repository XML. Its network
  # call goes through an overridable command for the same reason. It is Ruby
  # because it vendors nixpkgs' androidenv update.rb, which parses with
  # nokogiri.
  androidSdkRelease = helperWith "android-sdk-release" ../scripts/android-sdk-release (
    pkgs.ruby.withPackages (ps: [ ps.nokogiri ])
  );
in
{
  inherit
    agentSettings
    agentSettingsPython
    agentPluginSync
    agentPluginRelease
    claudeDesktopRelease
    chatgptRelease
    claudeCodeRelease
    miseRelease
    codexRelease
    t3codeRelease
    t3codeAntigravityInstall
    androidSdkRelease
    ;
}
