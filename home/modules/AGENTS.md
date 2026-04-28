# home/modules — Home Manager modules

Reusable user-level modules under the `my.*` option namespace.
Bundled via `./default.nix`, opted-in per-feature in `home/h82.nix`.

## STRUCTURE

```plain
modules/
├── default.nix          # Aggregator: imports shell, git, editors, desktop/plasma, i18n
├── shell.nix            # my.shell.enable           — zsh + direnv + mise + CLI utilities (rebuild aliases live here)
├── git.nix              # my.git.enable             — git config + git-credential-manager
├── desktop/plasma.nix   # my.desktop.plasma.enable  — plasma-manager (KDE Plasma 6)
├── editors/             # my.editors.{vscode,zed}.enable — see editors/AGENTS.md
└── i18n/fcitx5.nix      # my.i18n.fcitx5.enable     — fcitx5 + fcitx5-hangul (Wayland frontend)
```

## ADDING A NEW MODULE

1. Create `home/modules/<group>/<name>.nix` (or directly under `modules/` for top-level features).
2. Use this skeleton — no exceptions:

    ```nix
    { config, lib, pkgs, ... }:
    let
      cfg = config.my.<group>.<name>;
    in {
      options.my.<group>.<name> = {
        enable = lib.mkEnableOption "<one-line human description>";
        # Add more options ONLY if user-tunable. Default to enable-only.
      };

      config = lib.mkIf cfg.enable {
        # programs.X / home.packages / etc.
      };
    }
    ```

3. Add the path to the nearest `default.nix` (`modules/default.nix` or `modules/<group>/default.nix`).
4. Flip the toggle in `home/h82.nix`: `my.<group>.<name>.enable = true;`.

## CONVENTIONS

- **`{ config, lib, pkgs, ... }:`** function header, even when `config` or `lib` is unused. Consistency over micro-optimization.
- **`let cfg = config.my.<path>; in { options = ...; config = lib.mkIf cfg.enable ...; }`** — never inline `config.my.X.enable` in multiple places.
- **Enable-only options.** Only `vscode.nix` adds a non-`enable` option (`package`, for VSCode/VSCodium/Insiders swap). Stay minimal otherwise.
- **Korean comments** (e.g. `# 셸 유틸리티`, `# 모듈 활성화`, `# 한국어 입력`) explain intent. Preserve them when editing.
- **Shell hooks** (e.g. `programs.zsh.initContent` in `shell.nix`) are the right place for thin wrappers like the `rebuild*` aliases.

## ANTI-PATTERNS

- ❌ **No `my.<X>.enable` gate.** A module that runs unconditionally cannot be turned off without deleting the import — defeats the entire pattern.
- ❌ **Imported but not enabled in `home/h82.nix`.** Imports without enables are dead weight; either enable it or remove the import.
- ❌ **Hard-coded `/home/h82/...` paths inside modules.** Use `config.home.homeDirectory`. Modules should be user-agnostic in case a second user appears.
- ❌ **Host-specific code inside modules.** No `if config.networking.hostName == "jpi-vmware" then ...` conditionals, no host-scoped paths, no hardware references. Modules under `home/modules/` are imported by EVERY host and must work on all of them. Host divergence lives in `hosts/<hostname>/default.nix` — see the **PER-HOST QUIRKS** section in the root `AGENTS.md`.
- ❌ **NixOS (system-level) options here.** `users.users.*`, `services.*`, `boot.*`, `networking.*`, `security.*`, `nixpkgs.overlays`, `nixpkgs.config.allowUnfree` belong in `hosts/<hostname>/default.nix`. Putting them here will fail evaluation.
- ❌ **Tightly coupling two modules.** If `my.editors.vscode` reads `config.my.shell.enable`, you've created an undocumented dependency. Keep modules independent.
