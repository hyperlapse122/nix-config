# Inline flake checks audit

Reviewed at 09e9f5aaf56f3bb549c69bc8499de9c208737e4d. No repository changes. The inline check declarations and shared package/assertion helpers in flake.nix were read, alongside the shared configuration enumerator, home package owner, GPG owner, CI routing and relevant histories. File-backed checks belong to the other lane ledgers.

## Findings

### F1: declaration-only reads miss disabled delivery

`flake.nix:842-938` (zsh-prezto and ghostty-font) and `flake.nix:970-1007` (gpg-agent-no-cache) inspect Home Manager option text/source without requiring enabled files at the consumer paths. Actual `extendModules` overrides disabling the corresponding files leave the respective check derivations byte-identical. These are not merely mutations that fail evaluation: all mutated configurations evaluate, and the same check derivation is produced. Records: `delivery-controls.json` and `gpg-delivery-control.json`, with their complete Nix expressions beside them.

The GPG control disables gpg-agent.conf on every NixOS variant. The Zsh control disables the startup chain and preztorc; the Ghostty control disables its XDG config entry. Text/source remains readable to each check while Home Manager stops delivering the file. Home Manager filters enabled file entries when constructing home-files; a source file's existence does not establish its consumer path. Retargeting is the same missing boundary.

Retain these contracts and read the materialized home-files paths, including the root .zshenv and the chained files; preserve each content/order assertion. GPG must keep both zero-TTL assertions and rejection of additional nonzero TTLs. Ghostty must keep all four font families and Twemoji exactly once, last. Keep Darwin's separate materialized GPG/Ghostty evidence. No other Linux test establishes these delivered content contracts. The declarations originated in the early configuration checks and survived host iteration (`221c7b9`); package assertion sharing in `ca7cab8` did not repair delivery. These are proof gaps, not observed bad current configuration.

### F2: Python runtime smoke uses builder packages instead of user delivery

`flake.nix:948,959-967` checks package names with an empty executable list, then runs python3 and uv supplied by nativeBuildInputs. Replacing every NixOS variant's Python package with an empty derivation with pname python3 leaves the check derivation identical. The final control uses real `extendModules` overrides, not a copied test implementation: `python-runtime-control.nix/json`. No empty package can deliver bin/python3, yet the check is unchanged.

Retain the runtime contract, resolve each user's materialized home.path and run its bin/python3 and bin/uv under a controlled environment. Builder interpreters may support the harness, but their --version cannot prove user installation. Use the shared user enumerator where the contract applies to standalone Linux users. Keep package-presence diagnostics if useful; they do not replace the executable boundary. `home/h82/default.nix:51-55` owns these packages; the change to the shared helper in `ca7cab8` retained `executables = []`. No production seam deletion follows.

## Inline declaration ledger

R retains an independent contract; F retains and repairs its proof. Grouped rows name separate declarations with the same disposition. File-backed checks are classified in their owning ledgers.

| Mark | Inline declaration(s) | Contract and credible regression |
| --- | --- | --- |
| R | pinentry-card, pinentry-card-darwin | Assuan relay/keyring and Darwin proxy transport. The file-backed security ledger separately repairs the Linux package-render claim; raw-source behavior remains useful. |
| R | podman-machine-resources, minikube-darwin-start, mobile-devices | Resource reconciliation, bounded readiness/start and declared device reconciliation through real helpers with fake external tools; see platform ledger. |
| R | restore-age-identity | Fixed-path root installer validation; user installer and VM recovery are distinct boundaries. |
| R | agent-settings | Source merger semantics plus clean-environment installed interpreter/executable delivery; process packaging is distinct from source units. |
| R | agent-plugin-sync, agent-plugin-release | Adapter sequencing/rollback and release train resolver; see agents/releases ledgers for narrow consolidation. |
| R | chatgpt-release, claude-desktop-release, wifiman-desktop-release, claude-code-release, mise-release, codex-release, pi-release, npm-release, antigravity-cli-release, antigravity-acp-release, t3code-release, android-sdk-release | Separate executable release/parser/asset/pin contracts; shared fixture shape does not make different owners duplicate. |
| R | synthetic-models-watch, openrouter-catalog-snapshot, synthetic-models-reconcile, model-catalogs-reconcile | Classifier and snapshot contracts versus issue/Git workflow delivery; see releases and desktop ledgers. |
| R | t3code-antigravity-install, t3code-antigravity-link, t3code-antigravity-pin | Runtime preinstall, provider-home layout/linking and equality of two independently consumed pins. Keep distinct malformed/preservation/security inputs. |
| R | t3code-antigravity-layout | Pinned upstream compatibility: provider-home hashing/path and profile preparation's skill linking. This source-sensitive compatibility guard is not a replacement for the helper's behavior tests or live provider verification. No stronger equivalent suite was established for removal. |
| R | android-sdk-repo-parity | Committed pin parity with dependency repository metadata; separate from local renderer examples. |
| R | tailscale-single-router | Fleet-wide maximum of one production route advertiser; per-host VM cannot prove fleet policy. |
| R | publish-cli-auth, docker-credential-sops | Secret publication and Docker credential protocol; VM consumer adds transport/lifecycle, not duplicate same-owner proof. |
| F | zsh-prezto, ghostty-font, gpg-agent-no-cache | F1: preserve startup/font/cache policy while proving materialized consumer delivery. |
| F | python3-runtime | F2: run installed user runtime rather than harness tools. |
| R | yubikey-manager-shell | Development shell delivers executable ykman; system inventory is another consumer. |
| R | kleopatra-gui, telegram-desktop, libreoffice-office, okular-pdf, discord, claude-desktop | Package executable/desktop-entry delivery for each configuration; Claude also requires KVM group/vsock. Per-variant wiring can regress independently. |
| R | chatgpt | Installed GUI wrapper and desktop launcher, packaged bwrap under empty PATH, startup of three bundled binaries; static-PIE corruption is not proven by existence. |
| R | claude-code, codex, antigravity-cli | Installed package identity versus independent pin plus wrapper policy/helper delivery. Package install checks alone do not establish selected user package. |
| R | grok-absent | Explicit retirement policy across package, unit, Home Manager, Homebrew and App Store consumers. Negative inventory has nonempty host/fixture guards. |
| R | t3code | Version/pin, SEA native PTY, static rg, resource monitor handshake, GUI sandbox environment and desktop launcher contracts; executable startup adds distinct package proof. |
| R | update-dependencies-push-order, update-dependencies-verify-status, update-dependencies-reconcile, ci-workflow-docs-skip | Publication ordering/status, schedule and workflow gating; retain and repair identified release/system assertions at their current boundaries. |
| R | nr, pi-wrapper, tokscale-wrapper, pi-acp | Source behavior plus installed wrapper transport/configuration and real adapter lifecycle; retained checks include invalid-path guards and failure controls. |
| R | lint-staged-markdown, ci-docs-only-paths, markdown-lint | Index snapshot/hook behavior, classifier and actual content lint are separate contracts. Remove only the dependency-only Git self-test identified in systems ledger. |
| R | age-identity-helpers | Real recovery/preparation pipeline uses fake crypto tools; security ledger repairs missing failure-status assertions. |

## Counts and evidence

Production LOC changed: 0. Test/support LOC changed: 0. No whole suite or production seam is proposed for deletion. Full all-systems flake evaluation and native Darwin output check passed. Identical-derivation controls establish blind spots but are not native Linux execution. Linux checks, host closures and VMs remain unexecuted; no Linux builder/KVM and Podman connection failed. No hardware claim is made.
