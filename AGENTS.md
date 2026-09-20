# Working in this repository

This repository configures one NixOS ThinkPad X1 Carbon Gen 11. The implementation plan is in `.compound-engineering/artifacts/plans/2026-09-21-0149-feat-thinkpad-nixos-declarative-environment-plan.md`.

- Keep nixpkgs on unstable and commit `flake.lock` changes intentionally.
- Preserve the default Plasma desktop. macOS, other Linux distributions, desktop customization, and coding-agent settings are outside the first migration.
- Never evaluate or build with real plaintext credentials. YubiKey use belongs to initial secret recovery and Git signing; ordinary rebuilds use the local LUKS-protected age identity.
- Do not run partitioning, formatting, firmware enrollment, TPM enrollment, or `nixos-rebuild switch` on the developer's host as validation. Use disposable VM disks. Hardware installation requires an explicit instruction to install.
- Keep regular gh/glab files writable by their user. Publish them only after successful decryption and report failures without printing tokens.
- Run `nix flake check` and both host toplevel builds before shipping. Report actual hardware checks separately from VM evidence.
- Read relevant entries under `.compound-engineering/artifacts/solutions/` before changing authentication or boot lifecycle code. When verified work uncovers a non-obvious failure not explained by the code or tests, use `ce-compound` to add a solution there and link it below.

## Solutions

- [SOPS service umask and user secret traversal](.compound-engineering/artifacts/solutions/integration-issues/sops-service-umask-blocks-user-secrets.md): read before changing SOPS service permissions or activation tests.
