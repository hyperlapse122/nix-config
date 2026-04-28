# home/modules/editors — VS Code & Zed

Editor modules. Both expose `my.editors.<name>.enable`.
`vscode.nix` is the largest module in the repo (~335 lines) and ships the bulk of editor settings.

## FILES

- `default.nix` — imports `vscode.nix` and `zed.nix`.
- `vscode.nix` — VS Code with marketplace extensions + opinionated `userSettings`. Also exposes `my.editors.vscode.package` for swapping to VSCodium / Insiders.
- `zed.nix` — Zed with AI/ACP agent servers wired up (Copilot, Gemini, Codex, Claude, OpenCode).

## VS CODE — CRITICAL CAVEAT

VS Code marketplace extensions come from the `nix-vscode-extensions` overlay (`pkgs.vscode-marketplace.<publisher>.<extension>`).
The overlay is **applied at the host level** in **each host's `default.nix`**:

```nix
# hosts/<hostname>/default.nix
nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];
```

**Why host-level, not home-manager-level**: only the host's `nixpkgs` instance has `allowUnfree = true`. Re-adding the overlay inside home-manager creates a second `pkgs` instance that does **not** inherit `allowUnfree`, and unfree extensions (Copilot, Pylance, etc.) silently fail to evaluate.

> **Multi-host rule**: every host that enables `my.editors.vscode = true` MUST declare this overlay in its own `default.nix`. There is no shared/inherited fallback. Forgetting this causes opaque "extension not found" failures at evaluation time.

→ When adding extensions, use `pkgs.vscode-marketplace.<publisher>.<extension>` (lowercased, dots → hyphens). **Never re-import the overlay here.**
→ The `package` option exists so you can swap `pkgs.vscode` → `pkgs.vscodium` / `pkgs.vscode-insiders` without touching anything else.

## ZED — AGENT SERVERS

`zed.nix` registers `OpenCode` as a custom agent server invoking `opencode acp`.
`opencode` must be on `$PATH` for the `cmd-alt-o` keybinding to work — this repo does not install it.
The other agents (Copilot, Gemini, Codex, Claude) come from Zed's own registry; nothing extra needed.

## CONVENTIONS

- **NixOS-overlay block.** Each editor's `userSettings` mirrors a dotfiles file **plus** an "NixOS overlay" section that disables auto-update and wires Nix tooling (nixd LSP, nixfmt formatter). This block is delimited by:

  ```nix
  # ─── NixOS overlay (kill-switches & Nix LSP, dotfiles에는 없음) ───
  ```

  These divider comments are searchable markers. Keep them.

- **Nix tooling paths.** `nix.serverPath = "${pkgs.nixd}/bin/nixd"`. The Nix formatter is `nixfmt` (from `pkgs.nixfmt-rfc-style`). Both packages are installed in this same module's `home.packages`, so the binaries exist at runtime.

- **Dotted setting keys must be quoted strings** in VS Code (e.g. `"editor.tabSize"`, `"github.copilot.enable"`). Already done throughout — match the pattern.

## ANTI-PATTERNS

- ❌ **Do not move the `nix-vscode-extensions` overlay into this module** or into any `home-manager.users.<user>` block. The overlay belongs in each host's `default.nix`. See critical caveat above.
- ❌ **Do not enable `extensions.autoUpdate` / `auto_update` / `update.mode = "default"`.** Nix is the source of truth; the kill-switches are intentional.
- ❌ **Do not source VS Code extensions from `pkgs.vscode-extensions.*`** (the nixpkgs set). Stick to `pkgs.vscode-marketplace.*` for consistency and version freshness.
- ❌ **Do not rename or remove the `# ─── NixOS overlay ... ───` divider comments.** They mark which settings exist only because Nix manages the editor.
- ❌ **Do not install `nixd` or `nixfmt-rfc-style` elsewhere.** They're co-located with the editor that needs them; duplicating the install is noise.
