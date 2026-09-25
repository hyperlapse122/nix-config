# Repository Guidelines

## Project structure

This flake configures two machines: a ThinkPad X1 Carbon Gen 11 laptop and an MS-7D91 desktop workstation. Preserve the default Plasma desktop. Other operating systems, desktop customization, and coding-agent settings are outside the migration.

- `flake.nix`: production and bootstrap hosts, checks, and development tools.
- `hosts/ThinkPad-X1-Carbon-Gen-11/`: hardware and disk configuration for ThinkPad laptop.
- `hosts/MS-7D91/`: hardware, NVIDIA, secondary storage, and disk configuration for desktop.
- `modules/nixos/`: system modules by subsystem -- `hardware/` (udev, keyd, fingerprint, YubiKey), `system/` (base, boot, sysctl/cleanup, nix-ld, secrets), `desktop/` (Plasma/SDDM, fonts), `services/` (Podman, Tailscale, repository clones). No domain-level `default.nix`: each host's `hosts/*/default.nix` cherry-picks the exact modules it imports.
- `home/h82/`: Home Manager modules by domain, each with its own `default.nix` that `home/h82/default.nix` imports -- `agents/` (Claude Code, Gemini CLI, agent plugins), `desktop/` (Fcitx5, terminal, `kde/`), `dev/` (Git, containers), `security/` (GPG, SSH), `shell/` (Zsh/shell config).
- `scripts/`: authentication and rebuild helpers; `packages/`: Nix packaging for those helpers.
- `tests/`: Python, shell, and NixOS VM checks.
- `docs/`: installation, provisioning, recovery, and verification. `secrets/README.md` defines secret conventions.

The [implementation plan](.compound-engineering/artifacts/plans/2026-09-21-0149-feat-thinkpad-nixos-declarative-environment-plan.md) and [desktop plan](.compound-engineering/artifacts/plans/2026-09-22-1646-feat-ms-7d91-desktop-nixos-plan.md) record migration scope.

## Build and development commands

- `nix develop`: enter the development shell.
- `nix fmt`: format Nix files with `nixfmt-tree`.
- `nix fmt -- --ci`: check formatting without edits.
- `nix flake check`: run declared checks.

Before shipping, run `nix flake check` and all host builds:

```sh
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel
```

## Coding style and naming

Write all repository documentation in English, including READMEs, guides, plans, and captured learnings. Preserve exact commands, identifiers, and link targets.

Use two-space Nix indentation and let `nix fmt` control layout. Keep each module focused on one concern. Follow existing lowercase hyphenated module and helper names. Remove redundant comments, but keep comments that explain non-obvious constraints. Keep nixpkgs on unstable and change `flake.lock` intentionally.

## Testing guidelines

Add regression checks beside related tests and register new checks in `flake.nix`. Use fake tokens, PINs, and test keys. VM checks require Linux with `/dev/kvm` access and disposable disks. Report hardware verification separately from VM evidence; follow `docs/verification.md`.

## Commit and pull request guidelines

Use lowercase Conventional Commit subjects, matching the history's `feat(nixos):` and `chore:` prefixes. Write imperative, specific subjects, preferably under 50 characters and never over 72. PRs should describe behavior changes, link relevant issues, and report check and build results.

Always apply all review findings. When code review or adversarial analysis identifies failure modes, regressions, or architectural edge cases with concrete fixes, implement and verify them on the branch rather than deferring them as unapplied residuals.

When watching a pull request from a local session, judge readiness on check evidence rather than on a quiet period. Every reviewer here reports as a check, so arm the babysit watch with `--settle-seconds 0`; this supersedes that skill's instruction not to pass `--settle-seconds` on the ordinary arm. Evidence counts only when every workflow that runs on pull requests has a run registered against the current head, every such run is terminal, and no review check merely skipped; a skipped review is absent evidence, not a clean review. Nothing else relaxes: outstanding threads, comments, `needs-human`, and the base and branch-currency blockers keep their current force. While evidence is incomplete, do not declare readiness and do not re-arm at a shorter window. When a review check skipped, report the missing review evidence and hand back rather than withholding readiness with no report.

After an agent pushes to a pull request branch from CI, the push re-triggers the checks; wait for them and report what they said, never a result you did not see. Hand a failure you cannot reproduce with the fast Nix commands to `check.yml` rather than guessing at it. On reaching the wait ceiling, report the commit pushed, the runs still in flight, and where to watch them.

## Security and lifecycle constraints

Never evaluate or build with real plaintext credentials. Ordinary rebuilds use the local LUKS-protected age identity. YubiKey use is for initial recovery and Git signing; three cards carry the same key, each with its own PIN. Publish gh/glab files only after successful decryption and keep them writable by their user. Report failures without printing tokens.

Do not partition or format the developer's host, enroll firmware or TPM keys, or run `nixos-rebuild switch` as validation. Hardware installation requires an explicit instruction.

Before authentication or boot changes, read relevant entries under `.compound-engineering/artifacts/solutions/`, including [SOPS permissions](.compound-engineering/artifacts/solutions/integration-issues/sops-service-umask-blocks-user-secrets.md), [ThinkPad EFI variables immutability](.compound-engineering/artifacts/solutions/boot-issues/thinkpad-efivars-immutable-blocks-sbctl-enroll.md), [Ghostty CJK font fallback](.compound-engineering/artifacts/solutions/integration-issues/ghostty-cjk-fallback-and-d2coding-nerd-font-naming.md), and [tmpfs GNUPGHOME card provisioning](.compound-engineering/artifacts/solutions/integration-issues/tmpfs-gnupghome-card-provisioning-traps.md). Read that solution before SOPS permission, boot, or activation-test changes. Before adding a repository check, or before trusting one as a guard, read [mutation testing for check assertions](.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md), [mutations that only break evaluation](.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md), [checks that read an option value instead of the materialized output](.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md), [fixture state that cannot distinguish a bug from its fix](.compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md), [assertions on an unconditionally set option](.compound-engineering/artifacts/solutions/best-practices/nix-check-assertion-on-unconditional-option-folds-to-a-constant.md), [nullable options that reach a shell comparison as an empty word](.compound-engineering/artifacts/solutions/best-practices/nullable-option-empty-operand-passes-a-shell-comparison.md), [a bare repo's HEAD symref left dangling by an unset init.defaultBranch under a sandboxed HOME](.compound-engineering/artifacts/solutions/best-practices/unset-defaultbranch-leaves-bare-repo-head-dangling-for-second-clone.md), and [a tool vendoring libgit2 that ignores GIT_CONFIG_GLOBAL](.compound-engineering/artifacts/solutions/best-practices/vendored-libgit2-ignores-git-config-global.md). Before writing that a `home.activation` entry reasserts anything on every rebuild, read [activation does not re-run when the generation is unchanged](.compound-engineering/artifacts/solutions/best-practices/home-manager-activation-does-not-run-on-every-rebuild.md). Before ordering a new systemd unit `Before=`/`After=` an existing `Type=notify` unit that can retry, read [a Type=notify unit's TimeoutStartSec failure still satisfies ordering](.compound-engineering/artifacts/solutions/best-practices/systemd-notify-unit-timeout-still-satisfies-ordering.md). Use `ce-compound` to record verified, non-obvious failures not explained by code or tests, and link new solutions here.
