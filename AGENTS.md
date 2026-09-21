# Repository Guidelines

## Project structure

This flake configures one NixOS ThinkPad X1 Carbon Gen 11. Preserve the default Plasma desktop. Other operating systems, desktop customization, and coding-agent settings are outside the first migration.

- `flake.nix`: production and bootstrap hosts, checks, and development tools.
- `hosts/ThinkPad-X1-Carbon-Gen-11/`: hardware and disk configuration.
- `modules/nixos/`: system modules; `home/h82/`: Home Manager modules.
- `scripts/`: authentication helpers; `packages/`: Nix packaging for those helpers.
- `tests/`: Python, shell, and NixOS VM checks.
- `docs/`: installation, provisioning, recovery, and verification. `secrets/README.md` defines secret conventions.

The [implementation plan](.compound-engineering/artifacts/plans/2026-09-21-0149-feat-thinkpad-nixos-declarative-environment-plan.md) records migration scope.

## Build and development commands

- `nix develop`: enter the development shell.
- `nix fmt`: format Nix files with `nixfmt-tree`.
- `nix fmt -- --ci`: check formatting without edits.
- `nix flake check`: run declared checks.

Before shipping, run `nix flake check` and both builds:

```sh
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
```

## Coding style and naming

Write all repository documentation in English, including READMEs, guides, plans, and captured learnings. Preserve exact commands, identifiers, and link targets.

Use two-space Nix indentation and let `nix fmt` control layout. Keep each module focused on one concern. Follow existing lowercase hyphenated module and helper names. Remove redundant comments, but keep comments that explain non-obvious constraints. Keep nixpkgs on unstable and change `flake.lock` intentionally.

## Testing guidelines

Add regression checks beside related tests and register new checks in `flake.nix`. Use fake tokens, PINs, and test keys. VM checks require Linux with `/dev/kvm` access and disposable disks. Report hardware verification separately from VM evidence; follow `docs/verification.md`.

## Commit and pull request guidelines

Use lowercase Conventional Commit subjects, matching the history's `feat(nixos):` and `chore:` prefixes. Write imperative, specific subjects, preferably under 50 characters and never over 72. PRs should describe behavior changes, link relevant issues, and report check and build results.

## Security and lifecycle constraints

Never evaluate or build with real plaintext credentials. Ordinary rebuilds use the local LUKS-protected age identity. YubiKey use is for initial recovery and Git signing. Publish gh/glab files only after successful decryption and keep them writable by their user. Report failures without printing tokens.

Do not partition or format the developer's host, enroll firmware or TPM keys, or run `nixos-rebuild switch` as validation. Hardware installation requires an explicit instruction.

Before authentication or boot changes, read relevant entries under `.compound-engineering/artifacts/solutions/`, including [SOPS permissions](.compound-engineering/artifacts/solutions/integration-issues/sops-service-umask-blocks-user-secrets.md) and [ThinkPad EFI variables immutability](.compound-engineering/artifacts/solutions/boot-issues/thinkpad-efivars-immutable-blocks-sbctl-enroll.md). Read that solution before SOPS permission, boot, or activation-test changes. Use `ce-compound` to record verified, non-obvious failures not explained by code or tests, and link new solutions here.
