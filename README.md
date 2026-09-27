# Nix Config

A NixOS flake configuring personal machines on the default Plasma desktop. It pins nixos-unstable with a lock file. Every directory under `hosts/` is a host: the flake builds a production `<host>` output and a `<host>-bootstrap` output for each, from one shared profile plus the traits the host declares.

```sh
sudo nixos-rebuild switch --flake .#<host>
```

Replace `<host>` with the machine's directory name under `hosts/`, listed below. After initial installation and key recovery, this command applies the system, Home Manager configuration, and gh/glab authentication files together. Three YubiKeys carry the same signing key, each under its own PIN; any one of them handles Git signing and initial secret recovery. Ordinary rebuilds use the local age identity inside LUKS. Sign in to 1Password manually; the SSH agent configuration is declarative.

## Hosts

| Host | Machine |
| --- | --- |
| `ThinkPad-X1-Carbon-Gen-11` | Lenovo ThinkPad X1 Carbon Gen 11 laptop |
| `MS-7D91` | MSI MS-7D91 desktop workstation (Intel i7-13700F + NVIDIA RTX 3060) |

[Adding a host](docs/adding-a-host.md) covers a new machine.

## Included tools

zsh, Git, Ghostty, Claude Code, gh, glab, 1Password GUI and CLI, Kleopatra, Google Chrome, and a Tokscale wrapper that supplies its API token, device name, and Orca's Codex sessions. Claude Code's scalar settings — model, effort level, language, theme, notifications, and transcript retention — are managed declaratively and reapplied on each rebuild that produces a new Home Manager generation, while anything the repository does not declare stays yours to change. Its logins, permissions, hooks, MCP servers, and plugins are not migrated. Orca's agent skills are the one declared skill set: every coding agent finds them user-wide, at the release matching the installed Orca; other skills stay yours. macOS and Linux distributions other than NixOS are future work.

## Installation and operation

- [Fresh installation](docs/install.md): initialize the internal NVMe disk, bootstrap, and enroll Secure Boot and TPM2 keys.
- [Authentication preparation and recovery](docs/provisioning.md): prepare encrypted repository files and recover secrets with a YubiKey for the first time.
- [Updates and recovery](docs/recovery.md): retry failures, roll back, and recover TPM, card, and signing-key access.
- [Verification](docs/verification.md): automated checks and hardware checks.
- [Adding a host](docs/adding-a-host.md): create a host directory, its bootstrap age material, and its `.sops.yaml` recipient.
- [Secret file conventions](secrets/README.md)

Each `<host>-bootstrap` output can be installed without private keys or tokens. The final outputs can also be evaluated and built without plaintext secrets. Applying them requires the local age identity, encrypted tokens, and a Secure Boot signing bundle. Authentication recovery is not complete until the repository contains the real tokens in encrypted form and the bootstrap ciphertext.

## Development checks

```sh
nix flake check
nix eval .#nixosConfigurations --apply builtins.attrNames
for host in $(nix eval --raw .#nixosConfigurations --apply 'c: toString (builtins.attrNames c)'); do
  nix build --no-link ".#nixosConfigurations.$host.config.system.build.toplevel"
done
nix fmt
```

Installation and enrollment are explicit, one-time operations. Do not run disko or rebuild switch on the current host for validation.
