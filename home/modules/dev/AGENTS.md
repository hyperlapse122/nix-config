# home/modules/dev - Developer Tooling

Developer-focused Home Manager modules. This subtree has several non-standard modules: mutable agent skills, OpenCode and Codex wrappers, Playwright browser wiring, Docker credential helpers, and `mise` wrappers.

## STRUCTURE

```plain
home/modules/dev/
+-- default.nix              # imports all dev modules
+-- agents.nix               # my.dev.agents.enable; ~/.agents live symlink
+-- codex.nix                # my.dev.codex.enable; Codex CLI mise wrapper
+-- docker.nix               # my.dev.docker.enable; Docker credential helpers
+-- native-build.nix         # my.dev.native-build.enable; gcc/make/pkg-config/autotools
+-- nodejs.nix               # my.dev.nodejs.enable; Node.js LTS + yarn
+-- opencode/                # my.dev.opencode.enable; self-contained OpenCode config
+-- playwright.nix           # my.dev.playwright.enable; flake-provided Playwright stack
+-- python.nix               # my.dev.python.enable; Python 3
+-- tokscale.nix             # my.dev.tokscale.enable; mise wrapper
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add small dev package bundle | `nodejs.nix` / `python.nix` / `native-build.nix` pattern | Enable-only module with `home.packages`. |
| Add `mise` CLI wrapper | `codex.nix`, `opencode/default.nix`, or `tokscale.nix` pattern | Use `pkgs.writeShellApplication` and include `pkgs.mise`. |
| Change OpenCode settings | `opencode/opencode.json` | Parsed with `builtins.fromJSON`; `$schema` is stripped before HM settings. |
| Change OpenCode global context | `opencode/context.md` | Installed by HM as `~/.config/opencode/AGENTS.md`; not named `AGENTS.md` in-tree to avoid scoped-context collisions. |
| Add OpenCode command | `opencode/commands/*.md` | HM wires the whole directory through `programs.opencode.commands`. |
| Change OpenCode plugin config | `opencode/oh-my-openagent.jsonc` | Installed separately with `xdg.configFile`. |
| Change Docker registry auth | `docker.nix` | Add helper binary and matching `credHelpers` key. |
| Change Playwright versioning | `flake.nix` + `playwright.nix` | Keep npm `@playwright/test` and flake tag in sync. |

## OPENCODE

- `opencode/default.nix` passes a `mise exec -q opencode@latest -- opencode` wrapper as `programs.opencode.package`.
- Do not set `programs.opencode.package = null`; Home Manager master currently evaluates warnings through `lib.versionAtLeast null ...` and fails.
- `opencode.json` stays schema-bearing JSON for editor validation, but the Nix module removes `$schema` before passing settings to Home Manager.
- `context.md` is the source for global OpenCode behavior and is installed as `~/.config/opencode/AGENTS.md`.

## CODEX

- `codex.nix` installs a `codex` wrapper that runs `mise exec -q npm:@openai/codex@latest -- codex`.
- `pkgs.mise` is added alongside the wrapper because the wrapper depends on it at runtime.

## AGENTS SYMLINK

`agents.nix` uses `config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/agents"` because OpenCode writes to `skills/` and `.skill-lock.json` at runtime. A Nix store symlink would fail with EROFS and hide live skill updates until rebuild.

The trade-off is deliberate: this module assumes the repo exists at `~/nix-config`, matching the rebuild wrapper convention.

## DOCKER

- `docker-credential-glab` delegates to `glab auth docker-helper`.
- `docker-credential-gh` implements the Docker credential helper protocol for `ghcr.io` and legacy `docker.pkg.github.com`.
- `~/.docker/config.json` is declarative and read-only. `docker login` for unlisted registries will fail with EROFS; add another helper or mapping here.

## PLAYWRIGHT

- Playwright packages come from `inputs.playwright.packages.${pkgs.stdenv.hostPlatform.system}`, not plain nixpkgs.
- `PLAYWRIGHT_BROWSERS_PATH` points at prebuilt browsers and skips `playwright install`.
- `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS` is true because wrapped libraries are store-pathed.
- `PLAYWRIGHT_HOST_PLATFORM_OVERRIDE = "ubuntu-24.04"` short-circuits distro detection.
- If npm `@playwright/test` is present in a project, keep it version-aligned with the flake input tag.

## ANTI-PATTERNS

- Do not name the in-tree OpenCode source context `AGENTS.md`.
- Do not replace the live `~/.agents` symlink with a store-backed source.
- Do not add Docker registries to `credHelpers` without a matching helper on `PATH`.
- Do not rely on `playwright install` or npm browser caches on NixOS.
- Do not duplicate the generic Home Manager module skeleton here; parent `home/modules/AGENTS.md` owns that.
