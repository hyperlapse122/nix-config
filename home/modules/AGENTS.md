# home/modules - Home Manager Modules

Reusable user-level modules under the `my.*` namespace. Imported through `home/h82.nix` and enabled per feature there.

## STRUCTURE

```plain
home/modules/
+-- default.nix              # imports every shared home module group
+-- _1password.nix           # my._1password.enable
+-- shell.nix                # my.shell.enable; zsh, direnv, mise, rebuild wrappers
+-- git.nix                  # my.git.enable; git + credential manager
+-- gpg.nix                  # my.gpg.enable
+-- ssh.nix                  # my.ssh.enable; OpenSSH client + 1Password SSH agent
+-- env.nix                  # my.env.enable; session variables
+-- chrome.nix               # my.chrome.enable
+-- obsidian/               # my.obsidian.enable; default vault and plugins
+-- desktop/plasma.nix       # my.desktop.plasma.enable; user Plasma settings
+-- editors/                 # VS Code and Zed; see editors/AGENTS.md
+-- i18n/fcitx5.nix          # my.i18n.fcitx5.enable
+-- dev/                     # developer tools; see dev/AGENTS.md
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add a home module | `home/modules/<group>/<name>.nix` | Use the standard `my.*.enable` shape. |
| Import a module | nearest `default.nix` | Imports are explicit; no auto-discovery. |
| Enable a module | `home/h82.nix` | Imports without enables are dead weight. |
| Add shell wrapper | `shell.nix` | Thin aliases/functions belong in zsh init content. |
| Add editor config | `editors/` | Keep editor-specific caveats in `editors/AGENTS.md`. |
| Add dev tooling | `dev/` | Keep opencode/agents/Playwright/Docker details in `dev/AGENTS.md`. |

## ADDING A MODULE

Use this skeleton unless a documented local exception exists:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.my.<group>.<name>;
in
{
  options.my.<group>.<name> = {
    enable = lib.mkEnableOption "<one-line human description>";
  };

  config = lib.mkIf cfg.enable {
    # programs.X / home.packages / home.file / xdg.configFile / etc.
  };
}
```

Then import it from the nearest `default.nix` and enable it in `home/h82.nix`.

## CONVENTIONS

- Keep the function header `{ config, lib, pkgs, ... }:` even when one argument is unused.
- Bind `cfg = config.my.<path>` once; do not repeat `config.my.X.enable` inline.
- Default to enable-only options. Current notable exceptions are `my.editors.vscode.package` and user Plasma toggles for per-host overrides.
- Use `config.home.homeDirectory` instead of hard-coded `/home/h82` inside reusable modules.
- English-only comments, option descriptions, and human-readable strings.
- If a module writes runtime-mutable files, do not point them at the Nix store. See `dev/agents.nix` for the out-of-store symlink case.

## ANTI-PATTERNS

- No `my.<path>.enable` gate.
- Imported but not enabled in `home/h82.nix`.
- Host-specific checks such as `config.networking.hostName` inside `home/modules/`.
- System-level NixOS options here: `users.users.*`, `services.*`, `boot.*`, `networking.*`, `security.*`, `nixpkgs.overlays`, and `nixpkgs.config.allowUnfree` belong in host/system modules.
- Tight hidden coupling between modules. If `my.editors.vscode` reads `config.my.shell.enable`, the dependency is undocumented.
