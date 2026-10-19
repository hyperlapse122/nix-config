---
title: Agent Instructions for Every Harness - Plan
type: feat
date: 2026-10-19
topic: agent-instructions-every-harness
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Agent Instructions for Every Harness - Plan

## Goal Capsule

- **Objective:** Every coding agent this repository manages works under the same personal rules on every run, except T3 Code's Antigravity sessions, whose runtime reads no rules file; changing the card key means editing one value.
- **Means:** Render the instructions once from a typed fingerprint option and link the result to each harness's always-loaded path (KTD1, KTD2), removing the OpenCode wrapper's per-run branch (KTD4).
- **Product authority:** The Product Contract below, written from the user's brainstorm. Planning resolves HOW only.
- **Stop conditions:** Stop if a harness turns out to rewrite its instructions path, if the pinned OpenCode bundle shows the global `AGENTS.md` is not loaded under the wrapper's switches (U3 step 1), or if any host output fails to build.
- **Execution profile:** Nix configuration, Markdown, shell, and Nix checks. No hardware or `nr switch` validation; the live-run steps in U5 are documented for after deploy, not run here.
- **Open blockers:** None.

---

## Product Contract

Product Contract preservation: restructured, no scope change: the Summary now names the T3 Code Antigravity exception its Key Decisions and R11 already carry.

### Summary

The shared instructions file reaches Claude Code, OpenCode, and the Antigravity CLI identically, with no run that gets a different file or none; T3 Code's Antigravity sessions remain the documented exception. The card key fingerprint lives in one shared option that both Git signing and the rendered instructions read. The branch-naming default moves to full-word GitHub Flow prefixes, and the cross-model peer rule is removed.

### Problem Frame

Which runs see the shared instructions depends on the harness and on how it was started. The Antigravity CLI gets no file at all. OpenCode gets the file only when started from a shell, because the wrapper adds it only when `OPENCODE_CONFIG_CONTENT` and `OPENCODE_CONFIG` are unset; T3 Code's OpenCode sessions and Compound Engineering review peer runs set the first and get nothing. Even shell runs are unreliable, since OpenCode v2's shared background server keeps the environment of whichever client started it.

The card key fingerprint is written by hand in `home/h82/agents/instructions/instructions.md` and in `home/h82/dev/git.nix`, so a key rotation has to find both. The branch-naming default, `type/short-kebab-slug` with a Conventional Commits type, produces `feat/...`, while the user follows GitHub Flow's `feature/...`. The peer sentence pins `opencode` as the review peer, which the user no longer wants to override.

### Key Decisions

- **No delivery branches.** Every run of every managed harness gets the file, including T3 Code's OpenCode sessions and review peer runs. Governs R1, R2. (session-settled: user-directed — chosen over keeping the wrapper's shell-only delivery that withholds the file from reviewer runs: the user wants every branch removed.)
- **Managed means installed.** Claude Code, OpenCode, and the Antigravity CLI are in; Gemini CLI and Codex, which this flake does not install, are out. Governs R1, R4. (session-settled: user-directed — chosen over also writing paths for uninstalled harnesses: only installed harnesses count.)
- **T3 Code's Antigravity sessions stay a documented limitation.** Its ACP runtime reads no rules file, so nothing in this repository can deliver the file there; it is not mirrored into a skill. Governs R11. (session-settled: user-directed — chosen over also shipping the instructions as an Antigravity skill: a skill applies only when the model invokes it.)
- **The fingerprint becomes a new shared host option.** Git signing and the instructions render read it. Governs R5, R6. (session-settled: user-directed — chosen over reusing `programs.git.signing.key` or extracting it from `keys/signing.asc`: one option independent of Git.)
- **Full-word branch prefixes.** Governs R8. (session-settled: user-directed — chosen over `feature/` for every change and over `feature/` plus `bugfix/` only.)
- **Compound Engineering picks the peer.** No sentence in the instructions and no repository `cross_model_peer` setting replace the removed rule. Governs R9. (session-settled: user-directed — chosen over moving `cross_model_peer: opencode` into repository config and over keeping the sentence: the user accepts that OpenCode stops being the peer.)

### Requirements

**Delivery**

- R1. Claude Code (`~/.claude/CLAUDE.md`), OpenCode (`~/.config/opencode/AGENTS.md`), and the Antigravity CLI (`~/.gemini/config/AGENTS.md`) each receive byte-identical instructions on every host.
- R2. OpenCode receives the instructions the same way in shell sessions, T3 Code sessions, and review peer runs; the wrapper no longer adds or withholds them per run.
- R3. An OpenCode session holds the instructions once, not also through OpenCode reading `~/.claude/CLAUDE.md`.
- R4. No instruction file is written for Gemini CLI (`~/.gemini/GEMINI.md`) or Codex (`~/.codex/AGENTS.md`).

**Card key**

- R5. The card key fingerprint `621512777E6933FEB4458FDC4945855D4F283F05` is declared once, as a shared host option, and `programs.git.signing.key` reads it.
- R6. The instructions are rendered from that option, so each delivered file states the fingerprint literally.
- R7. A rendered file that still holds an unsubstituted placeholder fails the checks.

**Instruction content**

- R8. When the project documents no branch-naming rule, branches are named `<kind>/short-kebab-slug` with a full-word kind: `feature/`, `fix/`, `docs/`, `chore/`, or `refactor/`.
- R9. Both cross-model peer sentences are removed: the one naming `opencode` and the one about skipping a failed peer pass.

**Checks and documentation**

- R10. `tests/agent-instructions.nix` follows the new delivery: it requires all three files and their byte identity, requires the Gemini CLI and Codex paths to stay absent, stops banning `Antigravity`, bans `cross-model peer`, and pins the new branch-naming sentence.
- R11. `docs/provisioning.md` and `CONCEPTS.md` describe delivery to all three harnesses, the fingerprint option, and that T3 Code's Antigravity sessions still receive no instructions.

### Scope Boundaries

- The hardcoded fingerprints in `docs/` install commands are not rendered from the option.
- No check that the option matches `keys/signing.asc`; `home/h82/security/gpg.nix` imports the key file and names no fingerprint, so it does not read the option.
- `scripts/t3code-antigravity-link` keeps removing `config/AGENTS.md` links from instance homes; nothing is linked there.
- The instructions stay one file with no per-harness variant, even where a harness lacks Compound Engineering skills or T3 Code tools.
- OpenCode's `OPENCODE_DISABLE_CLAUDE_CODE` switch stays on (R3 depends on it).
- Considered and not built: a guard that keeps review peer runs from acting on the PR-babysitting and apply-every-finding rules. Compound Engineering's review prompts scope the peer; a peer that pushes or comments during a review would change this.
- Considered and not built: a Nix check that OpenCode loads `~/.config/opencode/AGENTS.md`. `opencode debug config` on the pinned 2.0.32 lists only the config directory, never the file, so no sandboxed check can observe loading; U5 documents a live run instead.

### Dependencies / Assumptions

- OpenCode v2 loads `~/.config/opencode/AGENTS.md` for every session, including those started with `OPENCODE_CONFIG_CONTENT`. The pinned 2.0.32 bundle reads `path.join(Global.config, "AGENTS.md")` behind a `global` scope flag that no environment variable maps to, but where that flag is set was not traced. Per `.compound-engineering/artifacts/solutions/integration-issues/opencode-plugin-loading-verifiable-only-by-a-live-run.md`, this is confirmed only by a live run after deploy. A caller that sets `OPENCODE_CONFIG_DIR` is an untested edge; T3 Code was observed not to set it on 2026-10-17.
- The Antigravity CLI reads `~/.gemini/config/AGENTS.md`, per the marker probe in `.compound-engineering/artifacts/solutions/integration-issues/agy-cli-ignores-gemini-home-cannot-verify-t3-instance-homes.md`.
- A review peer that now reads the PR-babysitting and apply-every-finding rules stays within its review brief because Compound Engineering's review prompts scope it.

### Sources / Research

- `home/h82/agents/instructions/default.nix`, `packages/opencode.nix:16-22,53-58,68`, `scripts/opencode:9,35-36,45-51` — the current delivery and the shell-only branch.
- `tests/agent-instructions.nix:54-95` (pins, `removedTerms`), `:122-143` (`fileRules`), `:147-172` (`homeFile`), `:174-225` (`opencodeFile`, `assertEntry`).
- `tests/opencode.nix:34-36,314-317,367-371` — currently fails when `.config/opencode/AGENTS.md` exists. `tests/opencode.sh:6-22,47-48,73,83,198-219` and `flake.nix:1358-1410` assert the wrapper branch.
- `home/h82/dev/git.nix:8-9`, `modules/shared/host.nix:36-45` — the second hardcoded fingerprint and the `my.user.*` defaults it will sit beside.
- `git show 1b075b5^:home/h82/agents/instructions/default.nix` — `.gemini/config/AGENTS.md` shipped as a plain store link for weeks with no clobber; removed only to drop Antigravity.
- `tests/agent-plugins.nix:126-137` — fails on a `home.file` at or above `.gemini/config/plugins`; a sibling `AGENTS.md` link is allowed.
- `flake.nix:980-1003` (`codex-absent`) — already guards Codex for R4.
- `.compound-engineering/artifacts/plans/2026-10-18-2318-feat-opencode-ce-plugin-and-peer-plan.md` — R9 there restored the peer rule this plan removes; Compound Engineering's default order `codex → claude → grok → antigravity` never reaches `opencode`.
- `.compound-engineering/artifacts/solutions/integration-issues/opencode-v2-shared-background-server-keeps-first-client-env.md` — why environment-based delivery reaches only the first client.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **The option is `my.user.gpgKey`, typed `lib.types.strMatching "[0-9A-F]{40}"`, defaulting to the card fingerprint in `modules/shared/host.nix`.** One user and one key match the `my.user.name` and `my.user.home` defaults beside it, so no host must set it. The type rejects an empty, null, or lowercase value at evaluation, which keeps an empty word out of the instructions sentence and out of Git's `signingkey`. `lib/host-facts.nix` already projects every `host.nix` option into Home Manager, and `tests/host-options.nix` derives its list from the same projection. Governs R5.
- KTD2. **Render with `pkgs.replaceVars` from a file holding `@gpgKey@`; all three `home.file` entries use that one store path as `source`.** `replaceVars` fails the build when any `@name@` survives, which enforces R7 at build time, and it matches the repository's `@UPPER_SNAKE@` plus `--replace-fail` idiom without an installPhase. The template stays a file because `instructions.md` holds `${TMPDIR:-/tmp}`, which a Nix `''…''` string would interpolate. Governs R1, R6, R7.
- KTD3. **Store `home.file` links for `.config/opencode/AGENTS.md` and `.gemini/config/AGENTS.md`, never a directory link or an activation merge.** Neither harness writes those files: OpenCode rewrites only `opencode.json` and `service.json`, and the Antigravity CLI writes `plugins/` and `config.json`. Linking a directory would trip `tests/agent-plugins.nix` and take over files those CLIs own. Governs R1.
- KTD4. **Delete the wrapper's `INSTRUCTIONS_CONFIG` constant and branch, and drop `instructions` and `instructionsConfig` from `packages/opencode.nix`'s passthru.** Once the file is always loaded nothing reads them, and `--replace-fail '@INSTRUCTIONS_CONFIG@'` fails the build the moment the token leaves `scripts/opencode`, so the package, the wrapper, `tests/opencode.sh`, and the `flake.nix` wrapper checks change in one unit. The wrapper's remaining contract is that it never sets `OPENCODE_CONFIG` and passes a caller's `OPENCODE_CONFIG` and `OPENCODE_CONFIG_CONTENT` through unchanged. Governs R2, R3.
- KTD5. **The x86_64 Linux fixture sets a distinct fake `my.user.gpgKey`, and the check asserts it in the rendered instructions and in the materialized Git config.** Every real host carries the same value as the literal now in `instructions.md` and `git.nix`, so a mutation that hardcodes the literal again passes against real hosts alone. The fake value turns that bypass red; per `.compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md`. The check selects those entries by the fake value, never by name, because `host-name-guard` fails on any fixture name written under `tests/`. Governs R5, R6.
- KTD6. **Ban removed wording case-insensitively.** `removedTerms` gains `cross-model peer`, `type/short-kebab-slug`, and `Conventional Commits type`, matched with `grep -qiF` so a capitalized sentence start cannot slip past, and loses `Antigravity`. A reversal written as a separate sentence would otherwise pass the anchored pin, per `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`. Governs R9, R10.

### Assumptions

- The fixture's fake fingerprint does not reach `scripts/antigravity-acp-probe`, which reads one 40-hex value from a signed-in instance home on a real host only.
- `tests/agent-instructions.nix` keeps running over `configurations.userEntries`, which covers NixOS, both Linux fixtures, and bootstrap twins; macOS gets the same Home Manager module and stays covered by CI's `build-darwin` job only.

### Sequencing

U1 adds the option, U2 renders and delivers the file from it, U3 removes the OpenCode branch together with every test that asserts it, U4 rewrites the instructions check against the landed delivery, and U5 updates documentation to describe the landed state. U3 and U4 both edit `tests/agent-instructions.nix` (U3 removes `opencodeFile`, U4 rewrites the rest); U4 runs after U3.

---

## Implementation Units

### U1. Declare the fingerprint option and read it from Git

- **Goal:** One typed option holds the card fingerprint, and Git signing reads it.
- **Requirements:** R5; KTD1, KTD5.
- **Dependencies:** None.
- **Files:**
  - Modify `modules/shared/host.nix`, `home/h82/dev/git.nix`, `tests/fixtures/hosts/hollyhock/default.nix`.
  - Test: `tests/agent-instructions.nix` (U4 adds the Git assertion).
- **Approach:**
  1. Add `my.user.gpgKey` beside `my.user.home` with the KTD1 type and default, and a description naming both readers.
  2. Point `programs.git.signing.key` at `config.my.user.gpgKey`; `git.nix` gains `config` in its arguments.
  3. Set a fake 40-hex uppercase value in `tests/fixtures/hosts/hollyhock/default.nix`, with a comment that it exists so a check can tell the option from a hardcoded literal; the comment does not name the fixture.
- **Patterns to follow:** `my.user.home` in `modules/shared/host.nix`; `config.my.*` reads in `home/h82/security/ssh.nix`.
- **Test scenarios:**
  - The fake-key fixture's home generation `.config/git/config` carries `signingkey = <fake value>`, and a real host's carries the card fingerprint (asserted in U4).
  - Setting the option to a lowercase or 39-character value fails evaluation (type behavior, confirmed once by hand, not a check).
- **Verification:** `tests/host-options.nix` still passes with the new option, and every host output evaluates.

### U2. Render the instructions and deliver them to all three paths

- **Goal:** One rendered store file carries the new content and reaches Claude Code, OpenCode, and the Antigravity CLI.
- **Requirements:** R1, R4, R6, R7, R8, R9; KTD2, KTD3.
- **Dependencies:** U1.
- **Files:**
  - Modify `home/h82/agents/instructions/instructions.md`, `home/h82/agents/instructions/default.nix`.
  - Test: `tests/agent-instructions.nix` (rewritten in U4).
- **Approach:**
  1. In `instructions.md`, replace the fingerprint literal with `@gpgKey@`, replace the branch default with one sentence naming the five prefixes per R8, and delete both peer sentences from the review findings section.
  2. Keep the file free of the words `Gemini` and `Codex`, which `removedTerms` still bans, and keep exactly one fingerprint so `scripts/antigravity-acp-probe` still parses it.
  3. In `default.nix`, render the file with `replaceVars` from `config.my.user.gpgKey` and declare three full `home.file` entries (`target` and `source`) for `.claude/CLAUDE.md`, `.config/opencode/AGENTS.md`, and `.gemini/config/AGENTS.md`, all with the rendered path as `source`.
- **Patterns to follow:** the single `home.file` entry in `home/h82/agents/instructions/default.nix`; the pre-`1b075b5` version of the same file, which declared `.gemini/config/AGENTS.md`.
- **Test scenarios:** covered by U4, which asserts the three materialized files.
- **Verification:** every host's Home Manager generation contains the three files with identical bytes and the real fingerprint in place of `@gpgKey@`.

### U3. Remove the OpenCode wrapper's instructions branch

- **Goal:** Every OpenCode run gets the instructions from the always-loaded file, and the wrapper no longer touches `OPENCODE_CONFIG`.
- **Requirements:** R2, R3; KTD4.
- **Dependencies:** U2.
- **Files:**
  - Modify `packages/opencode.nix`, `scripts/opencode`, `tests/opencode.sh`, `tests/opencode.nix`, `flake.nix` (the OpenCode wrapper checks around the `--packaged` call and the `wrapped.json` and `driven.json` greps), `tests/agent-instructions.nix` (remove `opencodeFile` and its call).
- **Approach:**
  1. Before any edit, trace in the pinned OpenCode bundle where the `global` scope flag that gates `path.join(Global.config, "AGENTS.md")` is set, and confirm it stays on with `OPENCODE_DISABLE_PROJECT_CONFIG`, `OPENCODE_CONFIG_PROJECT_DISABLE`, and `OPENCODE_CONFIG_CONTENT` set. If it does not, stop per the Goal Capsule; the shell-only branch is the only working delivery today.
  2. Remove the `instructions` and `instructionsConfig` bindings, the `@INSTRUCTIONS_CONFIG@` substitution, and the passthru entries from `packages/opencode.nix`, and its comment about withholding instructions from reviewer runs.
  3. Remove the constant and the `OPENCODE_CONFIG` branch from `scripts/opencode`, keep `OPENCODE_DISABLE_CLAUDE_CODE=true`, and reword the comment that says a process loads no Claude Code instructions so it says the instructions come from `~/.config/opencode/AGENTS.md`.
  4. In `tests/opencode.sh`, drop the fourth argument, the packaged-constant assertion, its substitution, and the instructions block, and assert the new contract from KTD4.
  5. In `flake.nix`, drop the `instructionsConfig` argument and the two instruction greps; keep every other assertion those checks make.
  6. In `tests/opencode.nix`, delete the `globalAgents` binding, its comment, the assertion that fails when `.config/opencode/AGENTS.md` exists, and the matching header bullet; U4 owns that path's delivery.
  7. In `tests/agent-instructions.nix`, delete `opencodeFile` and its call; U4 adds the replacement assertion.
- **Patterns to follow:** the stub-recorded environment assertions already in `tests/opencode.sh`.
- **Test scenarios:**
  - A shell run with no `OPENCODE_CONFIG` reaches the binary with `OPENCODE_CONFIG` still unset.
  - A run with `OPENCODE_CONFIG_CONTENT` set reaches the binary with that value unchanged and `OPENCODE_CONFIG` unset.
  - A run with a caller's `OPENCODE_CONFIG` reaches the binary with exactly that value.
  - Every run still reaches the binary with `OPENCODE_DISABLE_CLAUDE_CODE=true`.
- **Verification:** the OpenCode checks pass, and `rg INSTRUCTIONS_CONFIG\|instructionsConfig` finds nothing outside plans and learnings.

### U4. Rewrite the instructions check for the new delivery

- **Goal:** The check fails on any broken delivery path, any reintroduced or reversed rule, and any fingerprint that bypasses the option.
- **Requirements:** R1, R4, R5, R6, R7, R10; KTD5, KTD6.
- **Dependencies:** U1, U2, U3.
- **Files:**
  - Modify `tests/agent-instructions.nix`.
- **Approach:**
  1. Expect exactly one enabled entry for each of `.claude/CLAUDE.md`, `.config/opencode/AGENTS.md`, and `.gemini/config/AGENTS.md`, and zero for `.codex/AGENTS.md`, `.gemini/GEMINI.md`, and `.t3/instructions/claude-code/CLAUDE.md`, matching by resolved `target` and reading `enable` as `homeFile` does now.
  2. Read all three files out of the materialized `home-files` rather than the `source` option, and compare them pairwise with `cmp`.
  3. Update `pinnedSentences`: drop the two peer sentences, add the R8 sentence with all five prefixes, and move the fingerprint sentence out of the shared list so step 6 checks it per branch.
  4. Update `removedTerms` per KTD6 and switch its match to case-insensitive.
  5. Extend the unrendered-template check to `@[A-Za-z_]+@`.
  6. Branch on the entry's evaluated `my.user.gpgKey`, never on its name. An entry whose value equals the test's fake literal must hold the fingerprint sentence with the fake value (through `requireSentences`), `signingkey = <fake>` in `home-files/.config/git/config`, and no card fingerprint. Every other entry must hold the literal card-fingerprint sentence and `signingkey = <card fingerprint>`. On an x86_64-linux build, the builder fails when no entry carries the fake value, so the branch cannot go silently empty.
  7. Update the header comment to describe the new assertions and drop the OpenCode wrapper paragraph.
- **Execution note:** Prove each assertion by mutation in a scratch copy, per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`, and confirm in `nix log` that the failure comes from the builder rather than from evaluation or the `replaceVars` build step.
- **Patterns to follow:** `requireSentences`, `homeFile`, and the collect-every-failure style already in the file; the materialized `home-files` read in `tests/opencode.nix`.
- **Test scenarios:**
  - Each of the three entries set to `enable = false` fails the check, naming that path.
  - Each entry's `target` renamed fails the check.
  - A `.gemini/GEMINI.md` entry added fails the check.
  - The fingerprint literal written back into `instructions.md` in place of `@gpgKey@` fails on the fake-key fixture.
  - The fingerprint literal written back into `git.nix` fails on the fake-key fixture.
  - The fake value removed from the fixture fails the check on x86_64-linux.
  - The R8 sentence deleted, prefixed with "Do not", duplicated, or missing one prefix fails.
  - A separate sentence restoring `type/short-kebab-slug` fails.
  - "Cross-model peer" reintroduced with a capital C fails.
  - A placeholder left unrendered in the delivered file fails inside the check builder (simulate by bypassing `replaceVars` for the mutation).
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes, and every mutation above turns it red with a message naming the broken assertion.

### U5. Update documentation and the stale rationale

- **Goal:** The documentation describes the landed delivery, the option, the live-run checks, and the T3 Code Antigravity limitation.
- **Requirements:** R11.
- **Dependencies:** U1, U2, U3, U4.
- **Files:**
  - Modify `docs/provisioning.md`, `CONCEPTS.md`, `docs/verification.md`, `scripts/t3code-antigravity-link` (docstring only).
- **Approach:**
  1. In `docs/provisioning.md` "Shared agent instructions", replace "no template" with the single `@gpgKey@` substitution, update the delivery table to the three paths, rewrite the OpenCode paragraph so every run reads `~/.config/opencode/AGENTS.md`, drop the peer sentence, and describe the new check assertions.
  2. In the same file, update the OpenCode section's peer bullet, the T3 Code Antigravity paragraph's rationale for removing the `config/AGENTS.md` link (the runtime reads no rules file, not that the CLI's rules are unwritten), and the "Surfaces that stay unmanaged" entry that still calls `~/.claude/CLAUDE.md` user state.
  3. In `CONCEPTS.md`, refine "Delivery path" to say every installed harness's every run reads the same file, and keep "Provider instance home" accurate.
  4. In `docs/verification.md`, add a hardware check under "Every host": after a rebuild that produces a new generation, ask a shell `opencode run`, a T3 Code OpenCode thread, a Compound Engineering review-peer run, and `agy -p` for the fingerprint the instructions name, and report each separately from check evidence.
  5. Reword the `scripts/t3code-antigravity-link` docstring rationale to match step 2, with no code change.
- **Patterns to follow:** the existing "Every host" checklist entries in `docs/verification.md`.
- **Test scenarios:** Test expectation: none -- documentation only; the pre-commit `markdownlint-cli2` run covers the Markdown files.
- **Verification:** `rg -i "cross-model peer|no template|INSTRUCTIONS_CONFIG" docs CONCEPTS.md` returns only intended mentions.

---

## Verification Contract

| Gate | Command | Covers |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | U1–U4 |
| Flake checks | `nix flake check` | U1–U4 |
| Instructions check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U4 |
| OpenCode checks | `nix build --no-link .#checks.x86_64-linux.opencode` and the `flake.nix` OpenCode wrapper check | U3 |
| VM tests | `nix build --no-link .#vmChecks.all` | regression |
| Host outputs | every `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations` output, production and bootstrap, as `AGENTS.md` lists; aarch64 and darwin outputs go to CI | U1, U2 |
| Markdown lint | `mise run lint-staged-markdown` (pre-commit hook) | U5 |
| Mutation evidence | U4's mutation list, each in a scratch copy | U4 |
| Live runs | U5's `docs/verification.md` entry, after deploy, reported separately | R1, R2 |

---

## Definition of Done

- Every unit's verification holds, and every gate above passes except the live runs, which stay documented for after deploy.
- No file outside plans and learnings mentions `INSTRUCTIONS_CONFIG` or `instructionsConfig`, and no file writes `~/.gemini/GEMINI.md` or `~/.codex/AGENTS.md`.
- Before push, the learnings that cite the removed wrapper branch or shifted line numbers are refreshed with `ce-compound-refresh`: `opencode-v2-shared-background-server-keeps-first-client-env.md`, `opencode-plugin-loading-verifiable-only-by-a-live-run.md`, and `substring-sentence-check-passes-a-negated-instruction.md`.
- Mutation copies, scratch files, and abandoned attempts are removed from the diff.
