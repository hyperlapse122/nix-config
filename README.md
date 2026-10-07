# Nix Config

A Nix flake configuring personal machines. NixOS hosts run the default Plasma desktop. Non-NixOS Linux hosts, on x86_64-linux or aarch64-linux, get the same shell, development tools, coding-agent configuration, Git signing, and CLI authentication, without the desktop. macOS hosts, on Apple silicon, get the same user environment through nix-darwin, plus the GUI apps through Homebrew casks. The flake pins nixos-unstable with a lock file. Every directory under `hosts/` is a host: the flake builds a production `<host>` output and a `<host>-bootstrap` output for each, from one shared profile plus the traits the host declares.

On a NixOS host:

```sh
sudo nixos-rebuild switch --flake .#<host>
```

Replace `<host>` with the machine's directory name under `hosts/`, listed below. After initial installation and key recovery, this command applies the system, Home Manager configuration, and gh/glab authentication files together. Three YubiKeys carry the same signing key, each under its own PIN; any one of them handles Git signing and initial secret recovery. Ordinary rebuilds use the local age identity inside LUKS. Sign in to 1Password manually; the SSH agent configuration is declarative.

On a non-NixOS host, run this from the clone:

```sh
nr switch
```

It applies the system layer through system-manager and `sudo`, then the standalone Home Manager configuration, which publishes the gh/glab files, the tokens, and the host's own SSH key. Routine applies use the user-owned age identity at `~/.config/nix-config/age/key.txt`. [Adding a host](docs/adding-a-host.md#non-nixos-hosts) covers the first setup.

On a macOS host, `nr switch` from the clone builds the nix-darwin system, which holds the Home Manager configuration, and activates it through `sudo`. The first apply installs Homebrew and the casks. Secrets work as on a non-NixOS Linux host, with FileVault protecting the user-owned identity. [Adding a host](docs/adding-a-host.md#macos-hosts) covers the first setup.

## Hosts

| Host | Machine |
| --- | --- |
| `ThinkPad-X1-Carbon-Gen-11` | Lenovo ThinkPad X1 Carbon Gen 11 laptop |
| `MS-7D91` | MSI MS-7D91 desktop workstation (Intel i7-13700F + NVIDIA RTX 3060) |

[Adding a host](docs/adding-a-host.md) covers a new machine.

## Included tools

zsh, Git, Ghostty, Claude Code, Claude Desktop, Codex, the ChatGPT desktop app, T3 Code (desktop app and headless `t3` server, each opt-in per host), gh, glab, 1Password GUI and CLI, Kleopatra, Google Chrome, and a Tokscale wrapper that supplies its API token, device name, Orca's Codex sessions, and the Antigravity sessions T3 Code runs. Claude Code's scalar settings — model, effort level, language, theme, notifications, and transcript retention — are managed declaratively and reapplied on each rebuild that produces a new Home Manager generation, while anything the repository does not declare stays yours to change. Its logins, permissions, hooks, MCP servers, and plugins are not migrated. Codex, the ChatGPT app, and the T3 Code nightly are pinned to upstream releases and bumped every 30 minutes; Codex's update checks and memory are kept off (reapplied on each rebuild that produces a new Home Manager generation), it gets the shared agent instructions and the Compound Engineering plugin, and its sign-in is yours. Non-NixOS hosts get the command-line tools and agent configuration, but no Ghostty, 1Password, Kleopatra, Google Chrome, Claude Desktop, ChatGPT, T3 Code desktop, or other desktop application; a headless one can opt into the `t3` server. macOS hosts get the command-line tools and agent configuration, and install Ghostty, 1Password, Google Chrome, Claude Desktop, ChatGPT, Orca, and the other GUI apps as Homebrew casks; OrbStack replaces Podman there, and VSCodium and the T3 Code desktop app come from Nix.

## Installation and operation

- [Fresh installation](docs/install.md): initialize the internal NVMe disk, bootstrap, and enroll Secure Boot and TPM2 keys.
- [Authentication preparation and recovery](docs/provisioning.md): prepare encrypted repository files and recover secrets with a YubiKey for the first time.
- [Updates and recovery](docs/recovery.md): retry failures, roll back, and recover TPM, card, and signing-key access.
- [Verification](docs/verification.md): automated checks and hardware checks.
- [Adding a host](docs/adding-a-host.md): create a host directory, its bootstrap age material, and its `.sops.yaml` recipient, for a NixOS, a non-NixOS, or a macOS host.
- [Secret file conventions](secrets/README.md)

Each `<host>-bootstrap` output can be installed without private keys or tokens. The final outputs can also be evaluated and built without plaintext secrets. Applying them requires the local age identity, encrypted tokens, and a Secure Boot signing bundle. Authentication recovery is not complete until the repository contains the real tokens in encrypted form and the bootstrap ciphertext.

## Development checks

```sh
nix flake check
nix build --no-link .#vmChecks.all  # NixOS VM tests; needs /dev/kvm
nix eval .#nixosConfigurations --apply builtins.attrNames
for host in $(nix eval --raw .#nixosConfigurations --apply 'c: toString (builtins.attrNames c)'); do
  nix build --no-link ".#nixosConfigurations.$host.config.system.build.toplevel"
done
for host in $(nix eval --raw .#homeConfigurations --apply 'c: toString (builtins.attrNames c)'); do
  nix build --no-link ".#homeConfigurations.$host.activationPackage"
done
for host in $(nix eval --raw .#systemConfigs --apply 'c: toString (builtins.attrNames c)'); do
  nix build --no-link ".#systemConfigs.$host"
done
for host in $(nix eval --raw .#darwinConfigurations --apply 'c: toString (builtins.attrNames c)'); do
  nix build --no-link ".#darwinConfigurations.$host.system"  # macOS builder only
done
nix fmt
```

`homeConfigurations` and `systemConfigs` hold the non-NixOS hosts' outputs and `darwinConfigurations` the macOS hosts'; each stays empty until `hosts/` has such a host. An aarch64 output builds only on an aarch64 builder; CI builds those on its arm runners. A macOS output builds only on a macOS builder; CI's `build-darwin` job builds those on a `macos-15` runner.

Installation and enrollment are explicit, one-time operations. Do not run disko or rebuild switch on the current host for validation.
