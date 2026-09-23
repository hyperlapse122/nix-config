---
title: Bootstrap Card PIN Keyring Registration - Plan
type: docs
date: "2026-09-22"
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Bootstrap Card PIN Keyring Registration - Plan

## Goal Capsule

- **Objective:** After completing the bootstrap installation procedure, the OpenPGP card used during that installation has its PIN already registered for automatic entry, so a later operation that needs that card (Git signing, primarily) does not prompt for the PIN again.
- **Means:** Add a guidance step to `docs/install.md`'s existing bootstrap walkthrough that points at, and reuses, the `secret-tool`-based keyring registration command already established in `docs/provisioning.md` (KTD1, KTD2). No code or `gpg-agent` configuration changes.
- **Authority hierarchy:** Product Contract Requirements below bind scope; where they are silent, follow the existing conventions in `docs/install.md` and `docs/provisioning.md`.
- **Stop conditions:** If the command block in `docs/provisioning.md`'s "Git signing and SSH" section has changed since this plan was written, re-read it and use the current wording rather than the text quoted here.
- **Execution profile:** Single-file documentation edit; no build, no runtime behavior change.
- **Who finishes and ships:** `ce-work` implements the edit; the invoking pipeline commits, opens the PR, and watches CI.

## Product Contract

### Summary

Add a short guidance step to `docs/install.md`'s bootstrap procedure that registers the OpenPGP card's PIN into the OS Secret Service keyring, reusing the command already documented in `docs/provisioning.md`. No code, `gpg-agent` configuration, or check changes.

### Problem Frame

Bootstrap already causes one PIN entry: `./scripts/recover-age-identity` (`docs/install.md:66`) unlocks the card to decrypt the age identity. Registering that PIN into the OS Secret Service keyring — which the existing `pinentry-card` proxy (`scripts/pinentry-card`) then reads on every later card prompt, per `docs/provisioning.md:73-86` — is a separate, manual step (`secret-tool store ...`) documented only under `docs/provisioning.md`'s "Git signing and SSH" section, disconnected from the bootstrap walkthrough. Since the card used during bootstrap typically stays the card in ongoing use, an operator who does not separately discover and run that command keeps re-entering the PIN for every later Git signing operation until they do.

### Requirements

- R1. `docs/install.md`'s bootstrap walkthrough includes an explicit step, positioned after `./scripts/recover-age-identity` and before `sudo sbctl create-keys` in the "Prepare local decryption and signing keys" section, that registers the OpenPGP card's PIN into the OS keyring using the command already established in `docs/provisioning.md`, so the card used during bootstrap does not prompt for its PIN on later use.
- R2. The added step is documentation only: no change to `scripts/pinentry-card`, `home/h82/gpg.nix`, or `flake.nix`'s `gpg-agent-no-cache` check.
- R3. The added step names the card-serial lookup (`gpg --card-status`) and the `nix develop` prerequisite (needed to put `secret-tool` on `PATH`), and carries forward `docs/provisioning.md:77`'s caution ("Enter the PIN at the command's prompt, not in its arguments or shell history"), so a reader can follow it safely without also opening `docs/provisioning.md`.

### Key Decisions

- **Documentation-only fix, not automated registration.** The repeated-PIN-entry problem is solved by guiding the operator through the existing manual registration step at the moment it is most useful, not by having `pinentry-card` or `recover-age-identity` auto-register a successful PIN. Governs R1, R2. (session-settled: user-directed — chosen over automatically registering the PIN in `scripts/pinentry-card` or `scripts/recover-age-identity` when a PIN is successfully verified: the user chose to keep the existing explicit opt-in registration flow and `flake.nix`'s `gpg-agent-no-cache` guard exactly as they are, rather than take on a silent-registration behavior change.)

### Scope Boundaries

- Out of scope: pre-registering the two spare cards not physically present during a given bootstrap run — `docs/recovery.md`'s lost/replaced-card procedure already covers registering those when they come into use.
- Out of scope: any change to `scripts/pinentry-card`'s auto-answer/auto-discard logic, `home/h82/gpg.nix`'s cache settings, or the `gpg-agent-no-cache` check — excluded by the session-settled decision above, not merely deferred.

## Planning Contract

### Key Technical Decisions

- KTD1. **Placement: immediately after `./scripts/recover-age-identity`, before `sudo sbctl create-keys`.** At that point in the walkthrough, Plasma login is already verified (`docs/install.md:59`), so the Secret Service keyring is unlocked, and the card is already inserted and has just had its PIN entered — the same "in h82's desktop session, with the card inserted" precondition `docs/provisioning.md:77` already assumes for registration. Placing it earlier (before login) or later (after the rebuild) would either fail (keyring locked) or separate the step from the PIN entry that motivates it.
- KTD2. **Content shape: inline the command, plus a one-line cross-reference, mirroring the paragraph's own pattern — and split the existing shared fenced block to insert it.** `docs/install.md:63` pairs the paragraph with a pointer sentence ("See provisioning for what the helper does and the boundary it preserves"); the new step follows the same shape: the exact `secret-tool store` command block from `docs/provisioning.md:79-84`, its preceding caution sentence (`docs/provisioning.md:77`), plus one sentence pointing to `docs/provisioning.md` for the full per-card, multi-serial rationale. **Correction (doc review):** `./scripts/recover-age-identity` is not its own fenced block — `docs/install.md:65-73` is a single fence holding all five commands (`recover-age-identity`, `sbctl create-keys`, both `nixos-rebuild switch` variants, `sbctl verify`) under one pointer sentence. Placing the new step "before `sudo sbctl create-keys`" (R1) requires closing that fence after `./scripts/recover-age-identity`, inserting the new prose and command block, then reopening a second fence starting at `sudo sbctl create-keys` and continuing unchanged through both `nixos-rebuild switch` lines (with their existing `# On ThinkPad:` / `# On MS-7D91:` comments) and `sudo sbctl verify`.

## Implementation Units

### U1. Add bootstrap-time PIN keyring registration guidance to docs/install.md

- **Goal:** Insert a short guidance step (one or two sentences plus a fenced command block) into `docs/install.md`'s "Prepare local decryption and signing keys" section, between the `./scripts/recover-age-identity` block and the `sudo sbctl create-keys` line, that registers the bootstrap card's PIN into the OS keyring.
- **Requirements:** R1, R2, R3 (Key Decision above; KTD1, KTD2)
- **Dependencies:** none
- **Files:**
  - `docs/install.md` (modify)
- **Approach:**
  1. In `docs/install.md`'s single fenced block spanning `./scripts/recover-age-identity` through `sudo sbctl verify` (`docs/install.md:65-73`), close the fence immediately after `./scripts/recover-age-identity` (KTD2).
  2. Between the two fences, add a sentence stating the purpose (register this card's PIN now so later Git signing does not prompt) and a sentence cross-referencing `docs/provisioning.md`'s "Git signing and SSH" section for the full per-card design (KTD2).
  3. Add a new fenced command block containing `docs/provisioning.md:77`'s caution sentence rendered as prose immediately above it, then the command reused verbatim from `docs/provisioning.md:79-84`: `nix develop`, `card_serial='<normalized serial from gpg --card-status>'`, `secret-tool store --label='OpenPGP card PIN' service gnupg-card-pin username "$card_serial"`, `unset card_serial` (R3).
  4. Reopen a second fenced block starting with `sudo sbctl create-keys` and continuing unchanged through both `nixos-rebuild switch` lines (with their existing `# On ThinkPad:` / `# On MS-7D91:` comments) and `sudo sbctl verify` (KTD2).
  5. Leave `docs/provisioning.md`, `scripts/pinentry-card`, `home/h82/gpg.nix`, and `flake.nix` untouched (R2).
  6. Leave `docs/verification.md:32`'s existing hardware checklist item ("Register each card's PIN under its own serial, and confirm signing proceeds without a prompt for each") as is — it already covers this scenario generically, regardless of when the operator performs the registration.
- **Patterns to follow:** `docs/install.md`'s existing per-step convention of an inlined command block paired with a short cross-reference sentence to the fuller explanation (see the `recover-age-identity` paragraph at `docs/install.md:63`).
- **Test scenarios:**
  - Test expectation: none — documentation-only change with no executable behavior. Correctness is verified by manual read-through (below) and, at hardware-verification time, by the existing checklist item at `docs/verification.md:32`.
- **Verification:** Reading `docs/install.md`'s "Prepare local decryption and signing keys" section end-to-end, without opening any other file, a reader can identify the new step, understand why it is there, and copy a command that matches `docs/provisioning.md`'s established command exactly (same flags, same variable name, same `secret-tool` service/username shape).

## Verification Contract

- No repository check inspects `docs/install.md` prose; `nix fmt -- --ci` and `nix flake check` do not cover this change.
- Read the edited section of `docs/install.md` end-to-end and confirm the added command is byte-identical in shape to `docs/provisioning.md:79-84` (same `secret-tool store` invocation and variable name), and that the caution sentence from `docs/provisioning.md:77` precedes it.
- Confirm the original fenced block (`docs/install.md:65-73`) is now two fences — the first ending after `./scripts/recover-age-identity`, the second starting at `sudo sbctl create-keys` — with `sudo sbctl create-keys`, both `nixos-rebuild switch` lines and their `# On ThinkPad:` / `# On MS-7D91:` comments, and `sudo sbctl verify` unchanged in the second fence.
- `docs/verification.md:32`'s existing hardware checklist item already covers confirming registration works; this plan adds no new checklist item.

## Definition of Done

- `docs/install.md` contains the new step in the position KTD1 specifies, using the command KTD2 specifies.
- No file other than `docs/install.md` is changed.
- The diff contains only the intended addition — no leftover exploratory edits.

## Appendix

### Sources / Research

- `docs/provisioning.md:71-86` — existing "Git signing and SSH" section: the per-card `secret-tool store` registration command and its rationale (three cards, one Secret Service entry per serial, automatic discard on a rejected PIN).
- `docs/install.md:59-73` — "Prepare local decryption and signing keys" bootstrap step; confirms Plasma login (and therefore Secret Service) is already unlocked by this point, and shows the existing inline-command-plus-cross-reference convention.
- `home/h82/gpg.nix:46-59` — `services.gpg-agent` sets `default-cache-ttl 0` / `max-cache-ttl 0`; confirms this plan does not touch it.
- `flake.nix:357-381` — `gpg-agent-no-cache` check, whose comment states the zero-cache setting is load-bearing for "the card PIN handling"; confirms why this plan stays documentation-only (Key Decision above).
- `docs/verification.md:32` — existing hardware checklist item already covering PIN-registration verification generically.
- `.compound-engineering/artifacts/solutions/integration-issues/tmpfs-gnupghome-card-provisioning-traps.md` — confirms the tmpfs-`GNUPGHOME` card-provisioning trap applies to the card-*replacement* ceremony (`docs/recovery.md:143`), not to `recover-age-identity`, which runs in the real, already-configured `~/.gnupg` home; this plan's step needs no ceremony-home handling.
