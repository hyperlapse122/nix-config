# home/modules/editors - VS Code and Zed

Editor modules under `my.editors.*`. VS Code carries the largest user settings set; Zed wires external AI/ACP agent servers.

## FILES

- `default.nix` - imports `vscode.nix` and `zed.nix`.
- `vscode.nix` - VS Code package, marketplace extensions, settings, keybindings, and `my.editors.vscode.package`.
- `zed.nix` - Zed settings, keymaps, Nix LSP/formatter, and `OpenCode` custom ACP server.

## VS CODE CAVEAT

VS Code marketplace extensions come from `pkgs.vscode-marketplace`, provided by `inputs.nix-vscode-extensions.overlays.default`.

That overlay must be applied in each host's `default.nix`:

```nix
nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];
```

The host-level placement matters because this repo sets `allowUnfree = true` on the host `pkgs`. Re-importing the overlay inside Home Manager creates another `pkgs` instance that does not inherit that setting; unfree extensions such as Copilot and Pylance can fail to evaluate.

## ZED AGENT SERVERS

`zed.nix` registers `OpenCode` as a custom agent server:

```nix
command = "opencode";
args = [ "acp" ];
```

`opencode` must be on `$PATH`, so hosts that enable Zed should keep `my.dev.opencode.enable = true;` in `home/h82.nix`. Other agent servers use Zed's registry entries.

## CONVENTIONS

- Keep the NixOS-overlay marker comments; they identify settings that exist only because Nix manages the editor.
- VS Code dotted setting keys must be quoted strings.
- VS Code extensions use lowercased marketplace names: `pkgs.vscode-marketplace.<publisher>.<extension>`.
- Nix LSP/formatter tooling is installed next to the editor that invokes it: VS Code installs `nixd`; Zed installs `nixd` and `nixfmt`.
- Use `nixfmt`, not the deprecated `nixfmt-rfc-style` alias.

## ANTI-PATTERNS

- Do not move `nix-vscode-extensions` into this module or a `home-manager.users.<user>` block.
- Do not enable editor auto-updates: keep VS Code `update.mode = "none"` / `extensions.autoUpdate = false` and Zed `auto_update = false`.
- Do not source extensions from `pkgs.vscode-extensions.*`.
- Do not rename or remove the NixOS-overlay divider comments.
- Do not duplicate editor-invoked `nixd` / `nixfmt` installs elsewhere.
