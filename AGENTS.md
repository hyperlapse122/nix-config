# H82's NixOS Configurations

**Generated:** 2026-04-28
**Commit:** 8925203
**Branch:** main

## OVERVIEW

Multi-host flake-based NixOS config tracking the **`nixos-unstable`** channel exclusively (rolling release, Arch-equivalent). Each host lives under `hosts/<hostname>/` and is wired into `flake.nix#nixosConfigurations`.
Shared system-level config lives in `hosts/common/`; shared user-level config lives in `home/modules/`. Per-host divergence stays inside `hosts/<hostname>/default.nix`.
Home Manager runs on **`master`** (matches unstable nixpkgs); KDE Plasma 6 is configured via `plasma-manager`.
Reusable modules use a custom `my.*` option namespace — `my.<group>.<name>.enable` for home modules (toggled in `home/h82.nix`), `my.system.<group>.<name>.enable` for shared system modules (toggled in each host's `default.nix`).

> Currently only `jpi-vmware` exists. New hosts: NixOS only (no nix-darwin / WSL planned).

## STRUCTURE

```plain
nix-config/
├── flake.nix                  # Inputs + every nixosConfiguration entry
├── flake.lock                 # Pinned revisions for nixpkgs (nixos-unstable), home-manager (master), plasma-manager, nix-vscode-extensions
├── hosts/
│   ├── common/                # Reusable, host-agnostic system modules — `my.system.*` namespace
│   │   ├── default.nix        # Aggregator
│   │   ├── base.nix           # Always-on baseline (nix flakes, allowUnfree, dbus, minimal pkgs) — no toggle
│   │   ├── users.nix          # my.system.users.h82           — h82 user account + zsh
│   │   ├── locale.nix         # my.system.locale.korean       — Asia/Seoul + ko_KR.UTF-8
│   │   ├── networking.nix     # my.system.networking.networkmanager
│   │   ├── audio.nix          # my.system.audio.pipewire      — PipeWire (ALSA + Pulse compat)
│   │   ├── ssh.nix            # my.system.ssh.server          — OpenSSH (sshd, no password / no root)
│   │   ├── boot/              # my.system.boot.{grub,systemd-boot,sbctl,tpm-luks-enroll} — bootloader, Secure Boot, TPM LUKS helpers
│   │   ├── desktop/plasma.nix # my.system.desktop.plasma      — Plasma 6 + SDDM Wayland + KWallet PAM
│   │   └── programs/          # my.system.programs.{nix-ld,_1password}
│   └── <hostname>/            # One directory per machine; name MUST match networking.hostName
│       ├── default.nix        # Imports ../common, flips `my.system.*.enable`, declares per-host bits (bootloader, hostname, hardware-specific overlays, stateVersion)
│       └── hardware-configuration.nix  # GENERATED per host — DO NOT MODIFY
└── home/
    ├── h82.nix                # User entrypoint (host-agnostic); flips my.*.enable toggles
    └── modules/               # Reusable, host-agnostic home-manager modules — see home/modules/AGENTS.md
```

> **home/modules/dev/opencode/** — opencode CLI module. Wraps `bunx opencode-ai@latest` and wires `programs.opencode.{settings,context,commands}` from `opencode.json` / `AGENTS.md` / `commands/` co-located in the same directory. Plugin config (`oh-my-openagent.jsonc`) sits next to it as a raw `xdg.configFile`. See **WHERE TO LOOK** for editing flow.

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add a system-level package or service for ONE host | `hosts/<hostname>/default.nix` |
| Add a system-level package or service for ALL hosts | `hosts/common/<name>.nix` (gated by `my.system.<group>.<name>.enable`), then flip the toggle in each host's `default.nix`. Always-on baseline lives in `hosts/common/base.nix` (no toggle). |
| Toggle Korean locale / KDE Plasma / OpenSSH / etc. on a host | Flip `my.system.locale.korean.enable` / `my.system.desktop.plasma.enable` / `my.system.ssh.server.enable` etc. in `hosts/<hostname>/default.nix` |
| Add a user package / program (all hosts) | `home/modules/<name>.nix`, then enable in `home/h82.nix` |
| Add a VS Code extension or setting | `home/modules/editors/vscode.nix` (see `home/modules/editors/AGENTS.md`) |
| Add a KDE Plasma setting | `home/modules/desktop/plasma.nix` |
| Add an input method (fcitx5) addon | `home/modules/i18n/fcitx5.nix` |
| Add Secure Boot / TPM LUKS helpers | `hosts/common/boot/{sbctl.nix,tpm-luks-enroll.nix}`, then enable per host in `hosts/<hostname>/default.nix`. TPM helper command: `enroll-luks-tpm2` |
| Modify opencode CLI config (settings / context / commands / plugin) | `home/modules/dev/opencode/{opencode.json,AGENTS.md,commands/,oh-my-openagent.jsonc}` — wired through home-manager's `programs.opencode.*` |
| Bump nixpkgs / home-manager / plasma-manager / nix-vscode-extensions | `flake.lock` via `nix flake update` |
| Install NixOS on a fresh machine using this flake | See **INSTALLING NIXOS** below |
| Add a new host (NixOS already installed) | See **ADDING A HOST** below |

## CONVENTIONS

- **`my.*` option namespace** — reusable modules expose `<path>.enable` and nothing else. Rare exceptions are reserved for genuinely required arguments with no sensible default: `vscode.package` (editor binary swap, home module), `boot.grub.device` (BIOS disk path, system module), and `boot.tpm-luks-enroll.device` (host LUKS device path). Two slices:
  - `my.<group>.<name>.enable` for **home** modules (`home/modules/`), toggled in `home/h82.nix`. See `home/modules/AGENTS.md`.
  - `my.system.<group>.<name>.enable` for **shared system** modules (`hosts/common/`), toggled in `hosts/<hostname>/default.nix`.
  - Always-on baseline in `hosts/common/base.nix` is the **only** system file without an `enable` gate (nix flakes / allowUnfree / dbus / minimal pkgs are universal across hosts).
- **Imports are explicit `imports = [ ... ]` lists**, not auto-discovered. Aggregated via `default.nix` per directory (`hosts/common`, `home/modules`, `editors`, etc.).
- **`with pkgs; [ ... ]`** style for package lists.
- **Single `nixos-unstable` channel.** `flake.nix` pins `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`; there is no separate `pkgs-unstable` instance, no overlays for fresher packages, no stable/unstable mixing. Every package — system or home — comes from one `nixpkgs` revision (locked in `flake.lock`). Coming from Arch Linux: same rolling-release model, just with atomic rollbacks.
- **No flake-parts / snowfall / devshell / devenv.** Plain `nixpkgs.lib.nixosSystem` + `home-manager.nixosModules.home-manager`.
- **English-only for every version-controlled text.** See the **LANGUAGE** section below — non-English text is forbidden in any tracked file (comments, option descriptions, strings, docs, commit messages, branch names). The only exception is when a non-English literal IS the technical value (locale codes like `ko_KR.UTF-8`, font names like `Pretendard`, key codes like `hangeul`).
- **Nix code is formatted with `nixfmt`** (RFC-style; the legacy `nixfmt-rfc-style` alias has been collapsed into `nixfmt` upstream). Zed invokes it directly. There is no `treefmt`, no `nix fmt` formatter output, no pre-commit hook, no CI.
- **Git identity is hard-coded** (`Joosung Park <iam@h82.dev>`) in `home/modules/git.nix`. Do not parameterize unless adding a second user.

## INSTALLING NIXOS

This config pins `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`, so any host built from it tracks **nixos-unstable** regardless of which installer ISO you booted. There is **no `nix-channel` setup**: flakes pin nixpkgs by revision in `flake.lock`, not by channel name. Coming from Arch Linux, this is the same rolling-release model.

### Fresh install (new machine)

1. **Boot any recent NixOS ISO.** The unstable graphical / minimal ISO is recommended (matches the runtime channel) but a stable 25.11 ISO works too — flakes are enabled in modern installers, and nothing about the installer ISO leaks into the installed system.
2. **Partition + mount `/mnt`** per the [official NixOS install guide](https://nixos.org/manual/nixos/unstable/index.html#sec-installation).
3. **Generate the hardware config**:
   ```bash
   sudo nixos-generate-config --root /mnt
   ```
4. **Bring this repo onto the target**:
   ```bash
   sudo nix-shell -p git --run "git clone https://github.com/<user>/nix-config /mnt/etc/nix-config"
   sudo mkdir -p /mnt/etc/nix-config/hosts/<new-hostname>
   sudo mv /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nix-config/hosts/<new-hostname>/
   ```
5. **Wire up the new host** — follow **ADDING A HOST** below (steps 2–8). Skip step 1 there since `nixos-generate-config` already produced the hardware file.
6. **Install with the flake** (the `#<hostname>` MUST match `networking.hostName`, which MUST match the directory under `hosts/`):
   ```bash
   sudo nixos-install --flake /mnt/etc/nix-config#<new-hostname>
   ```
7. **Reboot.** The system is now on nixos-unstable; subsequent rebuilds (`rebuild` zsh wrapper from `home/modules/shell.nix`) pull from the same `flake.lock`-pinned nixpkgs revision.

### Updating after install

This config does NOT use `nix-channel` (legacy mechanism). Update inputs explicitly:

```bash
nix flake update                  # bump every input
nix flake update nixpkgs          # bump just nixpkgs
sudo nixos-rebuild switch --flake ~/nix-config
```

The lock file is the source of truth. Switching back to a stable release would require editing `flake.nix` itself (`nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"` plus matching `home-manager` URL) — there is no runtime "channel switch".

### Caveats specific to this repo

- **`system.stateVersion` / `home.stateVersion` are picked once at install time and never bumped.** They mark the data formats your system was first set up with, independent of the rolling nixpkgs channel. Set them in the new host's `default.nix` and `home/h82.nix` to whatever NixOS release was current when you installed (e.g. `"25.11"`). See **ANTI-PATTERNS**.
- **`allowUnfree = true`** is set globally in `hosts/common/base.nix`. New hosts inherit it via `imports = [ ../common ]`.
- **No standalone `home-manager`**: it's wired into each host as a NixOS module (`home-manager.nixosModules.home-manager` in `flake.nix`). Do **not** run `home-manager switch` directly.
- **Internet required during `nixos-install`** — the flake fetches nixpkgs (nixos-unstable) and other inputs from GitHub. Same as any other flake-based install.

## ADDING A HOST

1. `mkdir hosts/<new-hostname>` and run `nixos-generate-config --root /mnt --dir hosts/<new-hostname>` (or copy the file from the running machine). This produces `hardware-configuration.nix`.
2. Create `hosts/<new-hostname>/default.nix` — start by copying `hosts/jpi-vmware/default.nix`. The shared layer is pulled in via `imports = [ ./hardware-configuration.nix ../common ];`; everything else in the file should be host-specific.
3. Set `networking.hostName = "<new-hostname>";` — **must match the directory name** (the rebuild aliases rely on this).
4. Declare host-specific bits inline: hardware-specific options (e.g. `virtualisation.<flavor>.guest.enable`) and `system.stateVersion` (set to the NixOS release on which this host was first installed). Boot policy lives in shared modules — enable `my.system.boot.grub` (BIOS, requires `.device = "/dev/X"`) or `my.system.boot.systemd-boot` (UEFI, includes Plymouth splash). UEFI Secure Boot hosts may also enable `my.system.boot.sbctl`; TPM2 LUKS enrollment helpers use `my.system.boot.tpm-luks-enroll` and require a host-specific `.device`.
5. Flip the `my.system.*.enable` toggles the host needs (see `hosts/common/` modules). Skip the ones that don't apply: a headless server typically drops `my.system.desktop.plasma`, `my.system.audio.pipewire`; a non-Korean host drops `my.system.locale.korean` and sets its own `time.timeZone` / `i18n.*` directly.
6. If the host uses VS Code, add `nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];` to its `default.nix` (see `home/modules/editors/AGENTS.md` for why it must be host-level).
7. In `flake.nix`, add a new entry to `nixosConfigurations` mirroring the `jpi-vmware` block. Pass the same `inherit system; specialArgs; modules = [ ./hosts/<new-hostname> home-manager.nixosModules.home-manager { ... } ];`.
8. The user `h82` and `home/modules/*` import automatically — no per-host home config needed unless the host needs a different module set (then create `home/<user>-<hostname>.nix`).
9. Verify: `nixos-rebuild build --flake .#<new-hostname>` from the repo root.

## LANGUAGE

**Every version-controlled text in this repo MUST be written in English.** This rule is non-negotiable and applies to every tracked file under this repository.

### Scope (what is covered)

- All `.nix` source code: comments, option `description` strings, `mkEnableOption` summaries, assertion `message` strings, `lib.warn` / `lib.trace` payloads, every other string literal that is intended to be read by a human.
- All `.md`, `.mdx`, `.txt` documentation, including this `AGENTS.md`, every other `AGENTS.md`, and every file under `home/modules/dev/opencode/commands/`.
- All `.json`, `.jsonc`, `.toml`, `.yaml`, `.yml` configuration: comments, descriptions, and any human-readable string fields you author.
- Git artifacts authored from this repo: commit messages, branch names, tag names, PR / MR titles and descriptions.

### Allowed exceptions (what is NOT a violation)

- **Technical values that happen to use a non-Latin script** when the value itself is what the system requires. Examples: `i18n.defaultLocale = "ko_KR.UTF-8"`, `time.timeZone = "Asia/Seoul"`, font family `"Pretendard"`, key codes such as `hangeul`, fcitx5 `TriggerKeys` of `"Hangul"`.
- **Generated / vendored content** under `agents/skills/` and `agents/.skill-lock.json`. These are managed by OpenCode's skill system; do not hand-edit them. Their language is upstream's choice.
- **Generated `hardware-configuration.nix`** files. Regenerate via `nixos-generate-config`, never edit by hand.

### Why this rule exists

Mixed-language sources fragment review, search, code-mod, and AI-assisted refactoring. A single language across every comment, description, and doc keeps every tool — `grep`, `nixfmt`, AGENTS.md-aware agents, code review — predictable.

### Enforcement before commit

Before opening a PR, verify the diff has no non-English text. A simple guardrail:

```bash
# Must produce no output for any tracked file you authored or modified.
git diff --name-only HEAD | xargs -r grep -lP '[^\x00-\x7F]' \
  | grep -vE '^(agents/skills/|agents/\.skill-lock\.json$|hosts/.*/hardware-configuration\.nix$)' \
  || true
```

If a match shows up: translate it before committing. There is no "TODO: translate later" carve-out.

## ANTI-PATTERNS (THIS PROJECT)

- ❌ **Do not modify any host's `hardware-configuration.nix`** — regenerate via `nixos-generate-config` if hardware changes. The file's own header forbids edits.
- ❌ **Do not change `system.stateVersion` or `home.stateVersion`** (both `25.11`). The `jpi-vmware` host calls this out explicitly: `# state version — never change arbitrarily`. New hosts inherit the same rule — set `stateVersion` to the NixOS release on which they were first installed and never bump it casually.
- ❌ **Do not move `inputs.nix-vscode-extensions.overlays.default` out of the host's `default.nix`.** It must be applied to that host's `nixpkgs` so `allowUnfree` propagates to marketplace extensions. Each host that uses VS Code declares the overlay locally. Adding it inside `home-manager` produces a separate `pkgs` instance without `allowUnfree` and silently breaks Copilot, Pylance, etc.
- ❌ **Do not put host-specific config in `home/modules/`.** Modules under `home/modules/` are shared by every host. Anything that depends on hardware, hostname, or per-machine quirks belongs in `hosts/<hostname>/default.nix`.
- ❌ **Do not put host-specific config in `hosts/common/`.** Same rule, system side. No `if config.networking.hostName == "..." then ...`, no hardware-specific overlays, no per-machine paths. Host-only divergence (bootloader, virtualization flavor, `nix-vscode-extensions` overlay, `system.stateVersion`) lives in `hosts/<hostname>/default.nix`.
- ❌ **Do not duplicate shared config inline in a host's `default.nix` if `hosts/common/` already provides it.** If a feature has a `my.system.*.enable` toggle in common, **flip the toggle**; don't paste the underlying NixOS options. Inline duplication causes the host to drift from the shared baseline silently — the duplicate may merge, shadow, or conflict with the shared version. The only legitimate inline overrides are host-only quirks (bootloader, hardware, hostname, stateVersion, host-level overlays). Boot policy lives in shared modules (`my.system.boot.{grub,systemd-boot,sbctl,tpm-luks-enroll}`); required host-specific arguments are passed through module options such as `my.system.boot.grub.device` and `my.system.boot.tpm-luks-enroll.device`.
- ❌ **Do not let `networking.hostName` drift from the directory name** under `hosts/`. The rebuild aliases (`rebuild`, `rebuild-test`, `rebuild-boot`) call `nixos-rebuild --flake ~/nix-config` with no `#hostname` attribute, which resolves to `nixosConfigurations.${current hostname}`. Mismatch = silent build of the wrong host.
- ❌ **Do not introduce flake-parts / module library indirection** unless rewriting the layout deliberately. The simplicity is intentional even with N hosts — copy-paste the `nixosSystem` block, don't abstract it prematurely.
- ❌ **Do not commit `result`, `result-*`, or `.direnv/`** — already in `.gitignore`.
- ❌ **Do not introduce non-English text in any tracked file.** See the **LANGUAGE** section above. Translate before committing — no "TODO" carve-outs.

## COMMANDS

```bash
# Apply changes — zsh wrappers defined in home/modules/shell.nix.
# All wrappers default to the CURRENT machine's hostname (resolved by nixos-rebuild).
rebuild           # → sudo nixos-rebuild switch --flake ~/nix-config "$@"
rebuild-test      # → sudo nixos-rebuild test   --flake ~/nix-config "$@"
rebuild-boot      # → sudo nixos-rebuild boot   --flake ~/nix-config "$@"

# Build/switch a specific host explicitly (run from any machine)
sudo nixos-rebuild switch --flake ~/nix-config#<hostname>
sudo nixos-rebuild build  --flake ~/nix-config#<hostname>   # dry build, no activation

# Update inputs
nix flake update                  # all inputs
nix flake update home-manager     # one input

# Validate
nix flake check                   # evaluates ALL hosts; catches breakage early

# Format Nix files (no `nix fmt` configured in this flake)
nixfmt flake.nix hosts/**/*.nix home/**/*.nix
```

## PER-HOST QUIRKS

Anything in this section is specific to ONE host and should NOT leak into shared modules.

### `jpi-vmware` (VMware guest, KDE Plasma 6, Korean desktop)
- **VMware-only** (inline in host): `virtualisation.vmware.guest.enable`, GRUB BIOS device `/dev/sda` (policy via shared `my.system.boot.grub` module), `ata_piix`/`mptspi` initrd modules. Not portable.
- **`nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ]`** — declared at host level (see ANTI-PATTERNS for why it can't move to `hosts/common/` or home-manager).
- **Shared toggles enabled** (provided by `hosts/common/`): `my.system.users.h82`, `my.system.locale.korean`, `my.system.networking.networkmanager`, `my.system.audio.pipewire`, `my.system.ssh.server`, `my.system.desktop.plasma`, `my.system.programs.nix-ld`, `my.system.programs._1password`, `my.system.virtualisation.docker`, `my.system.boot.grub` (with `device = "/dev/sda"`). Hosts in other regions / without a desktop should leave the corresponding toggles off.

### `h82-t14-gen2` (ThinkPad T14 Gen 2 Intel, Secure Boot, TPM2 LUKS)
- **UEFI boot policy**: uses shared `my.system.boot.systemd-boot` plus `my.system.boot.sbctl` for Secure Boot key creation/enrollment and EFI signing during systemd-boot install.
- **TPM2 LUKS helper**: enables `my.system.boot.tpm-luks-enroll` with the host's encrypted root device. The manual command is `sudo enroll-luks-tpm2 --check`, then `sudo enroll-luks-tpm2 --recovery-key --yes` after creating a LUKS header backup.
- **TPM2 unlock**: uses systemd initrd TPM2 support plus `crypttabExtraOpts = [ "tpm2-device=auto" "tpm2-measure-pcr=yes" ];` on the enrolled LUKS mapping.

> **fcitx5 input method**: managed at the home-manager layer (`my.i18n.fcitx5`) rather than the system layer, and shared across every host. See `home/modules/i18n/fcitx5.nix`. The KDE Wayland InputMethod path is set in `home/modules/desktop/plasma.nix`'s `kwinrc` and points directly at the fcitx5-with-addons package's store path.

## NOTES

- **Three-layer config.** `hosts/common/` provides shared system-level modules (`my.system.*`). `home/modules/` provides shared user-level modules (`my.*`), imported by every host's home-manager block via `home/h82.nix`. `hosts/<hostname>/default.nix` is per-host: imports `../common`, flips `my.system.*.enable` toggles, declares hardware/bootloader/overlays inline.
- **No secret management** (`sops-nix`, `agenix`). Git auth uses `git-credential-manager` + `secretservice` (KDE Wallet via PAM); on a non-KDE host you'll need a different credential store.
- **Git identity is hard-coded** (`Joosung Park <iam@h82.dev>`) in `home/modules/git.nix`. Acceptable while there's only one user; parameterize before adding a second.
- **Home Manager is integrated into each NixOS host**, not exposed as `homeConfigurations`. Running `home-manager switch` standalone is not supported.
