# Repository Guidelines

## Project structure

This flake configures personal NixOS machines, one per directory under `hosts/`; today those are a ThinkPad X1 Carbon Gen 11 laptop and an MS-7D91 desktop workstation. Preserve the default Plasma desktop. Other operating systems, desktop customization, and coding-agent settings are outside the migration.

- `flake.nix`: host discovery, checks, and development tools. Every directory under `hosts/` is a host named by the directory, and `mkHost` builds a production `<host>` and a `<host>-bootstrap` output for each and sets `networking.hostName` from the name.
- `hosts/<host>/`: one machine's hardware (`hardware.nix`), disk layout (`disko.nix`), and traits (`default.nix`). [Adding a host](docs/adding-a-host.md) walks through a new one.
- `modules/nixos/`: system modules by subsystem -- `hardware/` (udev, keyd, fingerprint, YubiKey, Thunderbolt, laptop lid policy), `system/` (base, boot, sysctl/cleanup, nix-ld, agent-browser runtime deps, secrets), `desktop/` (Plasma/SDDM, fonts), `services/` (Podman, Tailscale, Proton VPN). Every host gets the one shared profile, `modules/nixos/profile.nix`, which `mkHost` imports: it imports every NixOS module, declares `my.bootstrap`, and sets shared defaults with `lib.mkDefault`. There is no domain-level `default.nix` and no per-host import list. Hosts differ only through traits, the `my.*.enable` options that default to `false` (`my.keyd`, `my.fingerprint`, `my.thunderbolt`, `my.nuphyGem80`, `my.laptop`), and through per-host values the host file sets. Hardware-specific modules stay inert until a host enables their trait. Modules, Home Manager (through `osConfig`), and checks branch on traits and `my.bootstrap`, never on a host name; the `host-name-guard` check fails when a host directory name appears in `flake.nix`, `modules/`, `home/`, `tests/`, `scripts/`, `packages/`, or `.github/workflows/`.
- `home/h82/`: Home Manager modules by domain, each with its own `default.nix` that `home/h82/default.nix` imports -- `agents/` (Claude Code, Gemini CLI, agent plugins, shared agent instructions), `desktop/` (Fcitx5, terminal, `kde/`), `dev/` (Git, containers, Android SDK), `security/` (GPG, SSH), `shell/` (Zsh/shell config).
- `scripts/`: authentication and rebuild helpers; `packages/`: Nix packaging for those helpers.
- `tests/`: Python, shell, and NixOS VM checks.
- `docs/`: installation, provisioning, recovery, verification, and adding a host. `secrets/README.md` defines secret conventions.

The [implementation plan](.compound-engineering/artifacts/plans/2026-09-21-0149-feat-thinkpad-nixos-declarative-environment-plan.md) and [desktop plan](.compound-engineering/artifacts/plans/2026-09-22-1646-feat-ms-7d91-desktop-nixos-plan.md) record migration scope. The [host-generic composition plan](.compound-engineering/artifacts/plans/2026-09-28-0203-refactor-host-generic-composition-plan.md) records the shared profile, traits, and host discovery.

## Build and development commands

- `nix develop`: enter the development shell.
- `nix fmt`: format Nix files with `nixfmt-tree`.
- `nix fmt -- --ci`: check formatting without edits.
- `nix flake check`: run declared checks.

Before shipping, run `nix flake check` and build every output under `nixosConfigurations`, production and bootstrap. List them, then build each:

```sh
nix eval .#nixosConfigurations --apply builtins.attrNames
for host in $(nix eval --raw .#nixosConfigurations --apply 'c: toString (builtins.attrNames c)'); do
  nix build --no-link ".#nixosConfigurations.$host.config.system.build.toplevel"
done
```

## Coding style and naming

Write all repository documentation in English, including READMEs, guides, plans, and captured learnings. Preserve exact commands, identifiers, and link targets.

Use two-space Nix indentation and let `nix fmt` control layout. Keep each module focused on one concern. Follow existing lowercase hyphenated module and helper names. Remove redundant comments, but keep comments that explain non-obvious constraints. Keep nixpkgs on unstable and change `flake.lock` intentionally.

## Testing guidelines

Add regression checks beside related tests and register new checks in `flake.nix`. Use fake tokens, PINs, and test keys. VM checks require Linux with `/dev/kvm` access and disposable disks. Report hardware verification separately from VM evidence; follow `docs/verification.md`.

## Commit and pull request guidelines

Use lowercase Conventional Commit subjects, matching the history's `feat(nixos):` and `chore:` prefixes. Write imperative, specific subjects, preferably under 50 characters and never over 72. PRs should describe behavior changes, link relevant issues, and report check and build results.

Always apply all review findings. When code review or adversarial analysis identifies failure modes, regressions, or architectural edge cases with concrete fixes, implement and verify them on the branch rather than deferring them as unapplied residuals. This covers every finding from `ce-code-review` and `ce-simplify-code`, whether you invoke them directly or through a workflow such as `lfg`, and it supersedes those skills' defaults:

- Apply every severity, P0 through P3 and anything lower. Severity sets the order of work, not whether it happens; the rubric's "Fix if straightforward" for P2 and "User's discretion" for P3 do not apply here.
- Apply every `autofix_class`. Apply `gated_auto` fixes, resolve `manual` findings by choosing a defensible fix and implementing it, and apply `advisory` findings and `testing_gaps` or `residual_risks` entries that name a concrete change, such as a missing test or check. A fix that changes a contract or user-visible behavior is applied like any other; a permission change is applied only when it does not weaken security.
- Apply the `ce-simplify-code` findings that the skill would record as low-value, as long as the change keeps behavior.
- A bare or `mode:agent` `ce-code-review` run is report-only, so apply its findings yourself after it returns.
- In `lfg`, apply the findings that step 5's eligibility bar would exclude, whatever their `suggested_fix`, confidence, or mechanical shape. Do not move a finding into the step-6 residual handoff because it is hard or low-priority.

Leave a finding unapplied only when:

- it is a false positive you verified against the code;
- its fix would edit outside the scope the run was given, such as files outside `changed_files` on `lfg`'s defect route, or it is a `pre_existing` finding in code the change does not touch;
- a `ce-simplify-code` fix would change behavior, remove a safety check the skill must keep, or cannot be shown to preserve outputs, errors, side effects, and ordering;
- its fix would weaken a security stance, such as authentication, authorization, secret permissions, firewall rules, or sandboxing, and the user has not approved that change;
- it conflicts with a user-settled decision or with the security and lifecycle constraints below; or
- it needs an irreversible action the user did not grant.

Report each unapplied finding, and each `advisory` finding or `testing_gaps` or `residual_risks` entry that names no change, with its exception or reason and the evidence. An unapplied finding with no named exception is a defect in the run. In `lfg`, these reports go in step 6's `## Unapplied review findings` PR-body section, or in tickets and the DONE report when no PR exists. That section holds no applied or merely deferred findings; `lfg`'s own `settled_conflict` and `settled_decision_conflicts` entries stay in it. Verify applied fixes with the checks this file requires before shipping.

When watching a pull request from a local session, judge readiness on check evidence rather than on a quiet period. Every reviewer here reports as a check, so arm the babysit watch with `--settle-seconds 0`; this supersedes that skill's instruction not to pass `--settle-seconds` on the ordinary arm. Evidence counts only when every workflow that runs on pull requests has a run registered against the current head, every such run is terminal, and no review check merely skipped; a skipped review is absent evidence, not a clean review. Nothing else relaxes: outstanding threads, comments, `needs-human`, and the base and branch-currency blockers keep their current force. While evidence is incomplete, do not declare readiness and do not re-arm at a shorter window. When a review check skipped, report the missing review evidence and hand back rather than withholding readiness with no report.

After an agent pushes to a pull request branch from CI, the push re-triggers the checks; wait for them and report what they said, never a result you did not see. Hand a failure you cannot reproduce with the fast Nix commands to `check.yml` rather than guessing at it. On reaching the wait ceiling, report the commit pushed, the runs still in flight, and where to watch them.

## Security and lifecycle constraints

Never evaluate or build with real plaintext credentials. Ordinary rebuilds use the local LUKS-protected age identity. YubiKey use is for initial recovery and Git signing; three cards carry the same key, each with its own PIN. Publish gh/glab files only after successful decryption and keep them writable by their user. Report failures without printing tokens.

Do not partition or format the developer's host, enroll firmware or TPM keys, or run `nixos-rebuild switch` as validation. Hardware installation requires an explicit instruction.

Before authentication or boot changes, read relevant entries under `.compound-engineering/artifacts/solutions/`, including [SOPS permissions](.compound-engineering/artifacts/solutions/integration-issues/sops-service-umask-blocks-user-secrets.md), [ThinkPad EFI variables immutability](.compound-engineering/artifacts/solutions/boot-issues/thinkpad-efivars-immutable-blocks-sbctl-enroll.md), [Ghostty CJK font fallback](.compound-engineering/artifacts/solutions/integration-issues/ghostty-cjk-fallback-and-d2coding-nerd-font-naming.md), and [tmpfs GNUPGHOME card provisioning](.compound-engineering/artifacts/solutions/integration-issues/tmpfs-gnupghome-card-provisioning-traps.md). Read that solution before SOPS permission, boot, or activation-test changes. Before adding a repository check, or before trusting one as a guard, read [mutation testing for check assertions](.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md), [mutations that only break evaluation](.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md), [checks that read an option value instead of the materialized output](.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md), [fixture state that cannot distinguish a bug from its fix](.compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md), [assertions on an unconditionally set option](.compound-engineering/artifacts/solutions/best-practices/nix-check-assertion-on-unconditional-option-folds-to-a-constant.md), [unit existence tests that pass for a unit masked to /dev/null](.compound-engineering/artifacts/solutions/best-practices/nix-check-unit-existence-passes-for-masked-unit.md), [nullable options that reach a shell comparison as an empty word](.compound-engineering/artifacts/solutions/best-practices/nullable-option-empty-operand-passes-a-shell-comparison.md), [a bare repo's HEAD symref left dangling by an unset init.defaultBranch under a sandboxed HOME](.compound-engineering/artifacts/solutions/best-practices/unset-defaultbranch-leaves-bare-repo-head-dangling-for-second-clone.md), and [a tool vendoring libgit2 that ignores GIT_CONFIG_GLOBAL](.compound-engineering/artifacts/solutions/best-practices/vendored-libgit2-ignores-git-config-global.md). Before running a mutation test in a scratch copy of this checkout, read [a copied git worktree still writes the real index](.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md). Before writing that a `home.activation` entry reasserts anything on every rebuild, read [activation does not re-run when the generation is unchanged](.compound-engineering/artifacts/solutions/best-practices/home-manager-activation-does-not-run-on-every-rebuild.md). Before ordering a new systemd unit `Before=`/`After=` an existing `Type=notify` unit that can retry, read [a Type=notify unit's TimeoutStartSec failure still satisfies ordering](.compound-engineering/artifacts/solutions/best-practices/systemd-notify-unit-timeout-still-satisfies-ordering.md). Before installing files through `home.file` for a tool that inspects them on disk rather than only reading their content, read [Orca rejects skill files hardlinked by the Nix store optimiser](.compound-engineering/artifacts/solutions/integration-issues/orca-rejects-hardlinked-nix-store-skill-files.md). Before changing KDE color scheme or `kdeglobals` defaults, or applying a Plasma setting from activation, read [plasma-apply-colorscheme no-op under the kdeglobals cascade](.compound-engineering/artifacts/solutions/integration-issues/plasma-apply-colorscheme-no-op-under-xdg-kdeglobals-cascade.md). Before changing an Antigravity hook or `scripts/orca-subagent-guard`, or probing an agent CLI's undocumented hook contract, read [the Antigravity PreToolUse hook contract and how to probe it safely](.compound-engineering/artifacts/solutions/integration-issues/antigravity-pretooluse-hook-contract-and-probing.md). Before debugging a rootless Podman failure that reports host files missing, or changing Orca's sandbox wrapper, read [a pause process started inside the Orca sandbox poisons the host Podman service](.compound-engineering/artifacts/solutions/integration-issues/orca-sandbox-pause-process-poisons-host-rootless-podman.md). Use `ce-compound` to record verified, non-obvious failures not explained by code or tests, and link new solutions here.
