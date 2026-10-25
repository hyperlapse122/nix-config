{ pkgs }:

let
  # patchShebangs resolves the interpreter from the build PATH, so it has to be
  # here for the `#!/usr/bin/env python3` line to be rewritten into a store
  # path rather than left dangling; a helper that needs libraries passes the
  # interpreter wrapped with them. The source is passed per helper rather than
  # derived from a directory, so a change to one script does not rebuild the
  # others.
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

  pythonHelper = name: src: helperWith name src pkgs.python3;

  # The two catalog scripts import scripts/catalog_snapshot.py from their own
  # directory, so each is installed beside it under libexec and linked into
  # bin. Their fetch goes through an overridable command so the sandboxed
  # repository check can drive it with fixtures.
  catalogHelper =
    name: src:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      version = "1";
      dontUnpack = true;
      nativeBuildInputs = [ pkgs.python3 ];
      installPhase = ''
        install -Dm755 ${src} $out/libexec/${name}/${name}
        install -Dm644 ${../scripts/catalog_snapshot.py} $out/libexec/${name}/catalog_snapshot.py
        patchShebangs $out/libexec/${name}/${name}
        mkdir -p $out/bin
        ln -s ../libexec/${name}/${name} $out/bin/${name}
      '';
      meta.mainProgram = name;
    };

  # tomlkit is what lets the TOML mode rewrite a file such as Codex's
  # config.toml without dropping the comments and tables it does not own. The
  # flake check runs the source copy of the tests under this same interpreter.
  agentSettingsPython = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  agentSettings = helperWith "agent-settings" ../scripts/agent-settings agentSettingsPython;

  ompConfigPython = pkgs.python3.withPackages (ps: [
    ps.pyyaml
    ps.xxhash
  ]);
  ompConfigReconcile =
    helperWith "omp-config-reconcile" ../scripts/omp-config-reconcile
      ompConfigPython;

  # Runs from home activation, where PATH carries neither home.packages nor
  # the login shell's session variables, so the module hands it the agent CLI
  # by store path and exports the declared environment tier around it.
  agentPluginSync = pythonHelper "agent-plugin-sync" ../scripts/agent-plugin-sync;

  # Runs in continuous integration rather than at activation. Its network call
  # goes through an overridable command so the repository check can drive it
  # with fixtures; a sandboxed check has no network.
  agentPluginRelease = pythonHelper "agent-plugin-release" ../scripts/agent-plugin-release;

  serveHtml = pythonHelper "serve-html" ../scripts/serve-html;

  chatgptRelease = pythonHelper "chatgpt-release" ../scripts/chatgpt-release;

  # Resolves the latest release of Claude Desktop from the Debian APT repository.
  claudeDesktopRelease = pythonHelper "claude-desktop-release" ../scripts/claude-desktop-release;

  # Resolves the latest WiFiman Desktop release from Ubiquiti's releases API
  # and hashes its .deb, which upstream publishes no checksum for. Its network
  # calls go through overridable commands so the sandboxed repository check
  # can drive it with fixtures.
  wifimanDesktopRelease = pythonHelper "wifiman-desktop-release" ../scripts/wifiman-desktop-release;

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
  ompRelease = pythonHelper "omp-release" ../scripts/omp-release;

  # Resolves the latest Pi release and its per-platform tarball digests from
  # the GitHub releases API and the release's SHA256SUMS. Its network calls go
  # through an overridable command so the sandboxed repository check can drive
  # it with fixtures.
  piRelease = pythonHelper "pi-release" ../scripts/pi-release;

  # Resolves the latest release of an npm package that ships no lock file,
  # such as pi-acp and acpx, and regenerates its lock file and npmDepsHash.
  # Its network call goes through an overridable command so the sandboxed
  # repository check can drive it with fixtures; npm and prefetch-npm-deps
  # come from the store so the update workflow's runner needs neither.
  npmRelease = pkgs.symlinkJoin {
    name = "npm-release";
    paths = [ (pythonHelper "npm-release" ../scripts/npm-release) ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/npm-release \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.nodejs
            pkgs.prefetch-npm-deps
          ]
        }
    '';
    meta.mainProgram = "npm-release";
  };

  # Resolves the latest Antigravity CLI release and its per-platform digests
  # from Google's release feed. Its network calls go through an overridable
  # command so the sandboxed repository check can drive it with fixtures.
  antigravityCliRelease = pythonHelper "antigravity-cli-release" ../scripts/antigravity-cli-release;

  # Resolves the newest complete Antigravity ACP runtime release by probing
  # candidate versions on Google's download host, and hashes its archives,
  # which upstream publishes no checksum for. Its network calls go through
  # overridable commands so the sandboxed repository check can drive it with
  # fixtures.
  antigravityAcpRelease = pythonHelper "antigravity-acp-release" ../scripts/antigravity-acp-release;

  # Resolves the newest T3 Code nightly and its asset digests from the GitHub
  # releases API. Its network call goes through an overridable command so the
  # sandboxed repository check can drive it with fixtures.
  t3codeRelease = pythonHelper "t3code-release" ../scripts/t3code-release;

  # Compares the Synthetic models in home/h82/agents/synthetic-models.nix with
  # Synthetic's catalog, and rewrites the committed Synthetic catalog snapshot.
  syntheticModelsWatch = catalogHelper "synthetic-models-watch" ../scripts/synthetic-models-watch;

  # Rewrites the committed OpenRouter catalog snapshot from OpenRouter's
  # /models/user endpoint.
  openrouterCatalogSnapshot = catalogHelper "openrouter-catalog-snapshot" ../scripts/openrouter-catalog-snapshot;

  # Runs from home activation and links the pinned Antigravity runtime into
  # T3 Code's managed runtime directory, which T3 Code checks on disk.
  t3codeAntigravityInstall = pythonHelper "t3code-antigravity-install" ../scripts/t3code-antigravity-install;

  # Runs from home activation and links the Antigravity CLI's plugins and
  # global instructions into each T3 Code Antigravity instance home.
  t3codeAntigravityLink = pythonHelper "t3code-antigravity-link" ../scripts/t3code-antigravity-link;

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
    ompConfigReconcile
    ompConfigPython
    agentPluginSync
    agentPluginRelease
    claudeDesktopRelease
    chatgptRelease
    wifimanDesktopRelease
    claudeCodeRelease
    miseRelease
    codexRelease
    ompRelease
    piRelease
    npmRelease
    antigravityCliRelease
    antigravityAcpRelease
    t3codeRelease
    syntheticModelsWatch
    openrouterCatalogSnapshot
    t3codeAntigravityInstall
    t3codeAntigravityLink
    androidSdkRelease
    serveHtml
    ;
}
