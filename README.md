# Nix Config

A NixOS flake for the ThinkPad X1 Carbon Gen 11. It pins nixos-unstable with a lock file and uses the default Plasma desktop.

```sh
sudo nixos-rebuild switch --flake .#ThinkPad-X1-Carbon-Gen-11
```

After initial installation and key recovery, this command applies the system, Home Manager configuration, and gh/glab authentication files together. The YubiKey handles Git signing and initial secret recovery. Ordinary rebuilds use the local age identity inside LUKS. Sign in to 1Password manually; the SSH agent configuration is declarative.

## Included tools

zsh, Git, Ghostty, Claude Code, omp, gh, glab, 1Password GUI, and Google Chrome. Claude Code's default model and effort level are managed declaratively; its remaining settings, logins, and plugins are not migrated. macOS and Linux distributions other than NixOS are future work.

## Installation and operation

- [Fresh installation](docs/install.md): initialize the internal NVMe disk, bootstrap, and enroll Secure Boot and TPM2 keys.
- [Authentication preparation and recovery](docs/provisioning.md): prepare encrypted repository files and recover secrets with the YubiKey for the first time.
- [Updates and recovery](docs/recovery.md): retry failures, roll back, and recover TPM, card, and signing-key access.
- [Verification](docs/verification.md): automated checks and hardware checks.
- [Secret file conventions](secrets/README.md)

The `ThinkPad-X1-Carbon-Gen-11-bootstrap` output can be installed without private keys or tokens. The final output can also be evaluated and built without plaintext secrets. Applying it requires the local age identity, encrypted tokens, and a Secure Boot signing bundle. Authentication recovery is not complete until the repository contains the real tokens in encrypted form and the bootstrap ciphertext.

## Development checks

```sh
nix flake check
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
nix fmt
```

Installation and enrollment are explicit, one-time operations. Do not run disko or rebuild switch on the current host for validation.
