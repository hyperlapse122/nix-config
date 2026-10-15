---
title: Forge-neutral pull request shipping and babysitting - Plan
type: feat
date: 2026-10-15
topic: forge-neutral-pr-babysitting
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

## Goal Capsule

- **Objective:** When a coding agent ships a change for user `h82`, a GitLab merge request gets the Compound Engineering treatment a GitHub pull request gets, minus the steps with no GitLab counterpart (R3), and the agent stays with the request until it looks ready to merge instead of handing it back while CI is still running.
- **Means:** Add a section to the shared agent instructions template, `home/h82/agents/instructions/instructions.md.tmpl`, that every harness renders, and pin it in the `agent-instructions` check (KTD1, KTD2).
- **Product Authority:** User `h82`. The session-settled entries in Key Decisions bind; a change to them stops the run.
- **Open blockers:** None.
- **Stop conditions:** Stop when a change would edit the Compound Engineering plugin's own skill files, let an agent merge, rebase, or force-push on the user's behalf, or touch a file outside those named in Implementation Units.
- **Execution profile:** Instruction text and one Nix check; no host generation changes beyond the rendered instruction files.
- **Finish and ship:** `lfg` implements, reviews, and opens the pull request.

---

## Product Contract

### Summary

The shared agent instructions gain a section on forges and T3 Code. GitHub-only Compound Engineering skills run their same procedure on GitLab through `glab`. After an agent opens or pushes a pull or merge request, it babysits it to looks-ready without being asked, waking through T3 Code's pull request watch when T3 Code is available. The final report no longer lists the forge adaptation as a decision made for the user.

### Problem Frame

The user ships work through Compound Engineering, whose shipping and babysitting skills speak only GitHub. `ce-babysit-pr` stops outright on a non-GitHub remote. The user also works on GitLab projects. In a recent GitLab session the agent opened the merge request with `glab`, armed a T3 Code watch, and ended its turn with "CI hasn't finished yet". Its report listed "the shipping skill is written for GitHub, so I opened the MR with `glab`" under "Decisions I made for you". The user wants GitLab handled as a normal case, not as a deviation to justify. They also want the agent to keep working the merge request through CI results and review comments rather than handing back a request whose state is unknown.

### Key Decisions

- **GitLab runs the babysit procedure through `glab`.** (session-settled: user-directed — chosen over only reporting CI results on wake, or fixing only CI failures: the user wants the merge request carried to looks-ready.) Governs R1, R5, R6.
- **Babysitting starts automatically after a pull or merge request is opened or pushed.** (session-settled: user-directed — chosen over starting only in autonomous runs or only on request: ending on "CI hasn't finished" leaves the user with unknown state.) Governs R4.
- **The forge adaptation is not a decision for the user.** (session-settled: user-directed — chosen over continuing to report it under decisions made for the user: GitLab is a normal case.) Governs R9.
- **T3 Code's watch is the wake source on both forges when it is available.** The T3 Code harness already requires its watch over polling or a separate watcher; short background waits cover only what its wakes cannot: the settle window and a stalled watch. Governs R5, R13, R14.
- **Drafts stay opt-in.** `ce-babysit-pr` treats drafts as opt-in, and automatic babysitting keeps that boundary. Governs R12.
- **On GitLab, a branch behind its base is reported, not rebased.** GitLab offers no base-into-head merge endpoint, only rebase, and the babysit procedure forbids rebasing. Governs R7.
- **The rule lives in the shared template.** Claude Code, Codex, and Antigravity all render it, so all three get the same forge behavior. Governs R10.

### Requirements

**Forge handling**

- R1. When a Compound Engineering skill that speaks only GitHub (`ce-commit-push-pr`, `ce-babysit-pr`, `ce-resolve-pr-feedback`, `ce-code-review` on a pull request target, `lfg`) runs in a GitLab project, the agent carries out that skill's procedure with `glab` equivalents instead of stopping or skipping the forge steps.
- R2. The instructions map each GitHub concept those skills use to its GitLab counterpart: pull request to merge request, review thread to resolvable discussion, Actions run and check to pipeline and job, and the `gh` commands to their `glab` or `glab api` counterparts.
- R3. When a skill step has no GitLab counterpart, the agent skips that step only, keeps the rest of the procedure, and names the skipped step in its report.

**Babysitting**

- R4. After an agent opens a pull or merge request, or pushes to one, it starts babysitting that request without being asked, in interactive and autonomous runs alike.
- R12. A draft request is babysat only when the user asked for that draft to be watched; otherwise the agent reports it as a draft and arms no watch.
- R5. When T3 Code's pull request tools are available, the agent links the request, handles comments that already exist, then arms T3 Code's watch and ends its turn. Each wake runs one babysit tick in the skill's order: review feedback, then CI on the current head, then branch currency.
- R13. When a tick finds the request ready except for the skill's settle window or its bounded wait for a review still coming, the agent keeps the T3 Code watch and starts a background wait for that window only, then runs another tick when the wait ends.
- R14. While T3 Code watches, the agent also keeps one background fallback wait of 30 minutes that runs a tick when no wake arrived, so a watch that stopped reading the request does not strand it.
- R6. When T3 Code is unavailable, a GitHub request uses `ce-babysit-pr` unchanged, and a GitLab request runs the same ticks with a background watcher, never a foreground sleep loop; a harness that cannot run a background command reports the open request and how to resume babysitting.
- R15. The GitLab background watcher polls every two to three minutes and exits when the head pipeline finishes, a note or discussion appears, the conflict or merge status changes, or the merge request closes or merges.
- R7. On GitLab, a branch behind its base, or one that conflicts with it, is reported as a blocker for the user rather than rebased.
- R8. Babysitting stops at the skill's true stops. On looks-ready, blocked, or out of budget, the agent stops the T3 Code watch before handing back. Merging stays with the user.

**Reporting**

- R9. The final report does not present the choice of `glab` over `gh`, or of T3 Code's watch over the skill's own watcher, as a decision made for the user; it mentions the forge only for a step skipped under R3 or a blocker under R7.

**Scope of the rule**

- R10. The section is harness-neutral: it names T3 Code's tools by their unprefixed names, as the existing Cross-model delegation section does, and holds for every harness the template renders.
- R11. This repository's own `AGENTS.md` guidance on arming the babysit watch with `--settle-seconds 0` stays consistent with R5, so a session in this repository has one wake source.

### Acceptance Examples

- AE1. **Covers R1, R4, R5, R9.** **Given** a GitLab project and a T3 Code session, **when** the agent ships a fix with `ce-commit-push-pr`, **then** it opens the merge request with `glab`, links and watches it through T3 Code, and its report has no decision entry about using `glab`.
- AE2. **Covers R5.** **Given** a watched merge request, **when** T3 Code wakes the agent because a pipeline job failed, **then** the agent first handles any new discussion, then diagnoses the failure with `ce-debug`, or retries the job when the failure is infrastructure, and re-arms the watch if no true stop was reached.
- AE3. **Covers R7.** **Given** a merge request whose branch has fallen behind its base, **when** a tick runs, **then** the agent does not rebase and reports the branch as a blocker for the user.
- AE4. **Covers R6, R15.** **Given** a Claude Code session without T3 Code and a GitLab project, **when** the merge request is open, **then** the agent waits on a background watcher and runs a tick when it exits; a harness with no background command instead reports the open merge request and how to resume.
- AE6. **Covers R13.** **Given** a watched pull request whose checks just passed with no open feedback, **when** the wake arrives before the settle window has elapsed, **then** the agent starts a background wait for the rest of the window and runs another tick when it ends, instead of re-arming and waiting on a wake that will not come.
- AE7. **Covers R12.** **Given** the agent opened a draft merge request the user did not ask to watch, **when** shipping ends, **then** the agent reports it as a draft and arms no watch.
- AE5. **Covers R8.** **Given** a request that reaches looks-ready, **when** the agent hands back, **then** it has stopped the T3 Code watch and leaves the merge to the user.

### Scope Boundaries

- Stack postures (`stack-ready`, `stack-land`) on GitLab: there is no `gh stack` counterpart, so a GitLab request is babysat as a single target.
- Changing the Compound Engineering plugin's skills themselves; the adaptation lives in the user's instructions.
- Forges other than GitHub and GitLab.
- Merging on the user's behalf.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` and `home/h82/agents/instructions/default.nix`: one template rendered per harness with gomplate.
- `ce-babysit-pr` `references/setup.md`: the skill stops on any non-GitHub remote.
- T3 Code's `watch_pull_request` tool: accepts a `host`, wakes on failed or passed checks, new comments, and conflicts, wakes only for comments posted after it is armed, and states that a wake is news, not a merge decision.
- `AGENTS.md`, Commit and pull request guidelines: the `--settle-seconds 0` arming rule for this repository.
- `glab` 1.114.0 offers `glab mr note list`, `glab mr note resolve <discussion-id>`, `glab ci retry <job-id>`, `glab ci status`, and `glab mr view`; `glab mr rebase` exists but R7 forbids it.

---

## Planning Contract

Product Contract preservation: changed: R4 gains the draft exception R12; R5 gains R13 and R14; R6 gains the no-background fallback and R15; AE4 reworded, AE6 and AE7 added; Objective names the R3 exception — document review found that T3 Code wakes cannot deliver the settle window, drafts conflicted with the skill's opt-in, and the no-T3 fallback was unstated.

### Key Technical Decisions

- KTD1. **One new top-level section, `# Pull and merge requests`, placed after `# Branch names`.** It sits beside the other shipping rules and before the media section, which already covers GitLab uploads. It cites the T3 Code tools by unprefixed name, as `# Cross-model delegation` does. Covers R1–R10 and R12–R15.
- KTD2. **Pin every sentence of the new section in `tests/agent-instructions.nix`.** Add a `pullRequestSentences` list checked with `requireSentences`, plus `onlyPinnedSentences` over the section heading with pattern `.`, the same guard the GPG section uses, so a dropped, reworded, negated, or contradicting added sentence fails. Follows `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`.
- KTD3. **The concept map in the instructions stays at concept level, with `glab` commands named only where a babysit step depends on them.** The skills already carry the procedure; the instructions say what replaces `gh`, not a full command reference. Named commands: `glab mr create`, `glab mr view -F json` as the tick's snapshot, `glab mr note list -F json`, `glab mr note create --reply` and `glab mr note resolve`, `glab ci retry`, and `glab api` for anything else. Governs how R2 is written.
- KTD4. **A GitLab tick reads its state from `glab mr view <id> -F json` and `glab mr note list <id> -F json`, and looks-ready needs a finished pipeline for the current head.** The fields are `state`, `draft`, `sha`, `head_pipeline.sha`, `head_pipeline.status`, `detailed_merge_status`, `has_conflicts`, and `blocking_discussions_resolved`, plus unresolved discussions and new top-level notes. Looks-ready requires `head_pipeline.sha` equal to `sha`, a terminal pipeline status, `detailed_merge_status` of `mergeable`, no unresolved discussion, no unhandled note or `needs-human` item, and the skill's settle window elapsed (R13). `glab ci status` reads a branch, not a commit, so it is not this evidence. A wake or an empty pipeline list is not evidence either; this mirrors `.compound-engineering/artifacts/solutions/best-practices/merge-ready-wake-fires-on-zero-check-evidence.md`. Applies to R5, R8, and R15.
- KTD5. **`AGENTS.md` keeps its evidence rule and scopes `--settle-seconds 0` to sessions that run `ce-babysit-pr`'s own watcher.** With T3 Code, the wake comes from T3 Code's watch and the evidence rule still decides readiness. Covers R11.
- KTD6. **R9 is written as an exception to the review-findings sentence that asks for every decision made on the user's behalf.** The new sentence says the forge and wake-source substitutions are not such decisions, so the two rules do not conflict. The existing pinned sentence stays unchanged.

### Assumptions

- T3 Code's watch can be armed on a GitLab merge request on a self-hosted host by URL, as the motivating session did on `git.jpi.app`. Whether it delivers wakes there is not verified; R14's fallback wait covers a watch that never wakes.
- Claude Code's `run_in_background` and Antigravity's `schedule` can re-invoke the agent after a background wait; Codex has no such primitive in this template, so it takes R6's report-and-resume path.

### Implementation Constraints

- Every sentence in the new section is harness-neutral text outside the `.harness.id` branches (R10).
- Match the template's existing voice: English, imperative sentences, one rule per bullet.

---

## Implementation Units

### U1. Add the pull and merge request section to the template

**Goal:** Agents get one rule set for forge adaptation, automatic babysitting, and reporting.

**Requirements:** R1–R10, R12–R15; KTD1, KTD3, KTD4, KTD6. Implements the session-settled Key Decisions that govern R1, R4, R5, R6, and R9.

**Dependencies:** None.

**Files:**

- `home/h82/agents/instructions/instructions.md.tmpl`

**Approach:**

1. Open the section with a one-paragraph statement: GitHub and GitLab are both normal forges, and a pull request opened or pushed is babysat to looks-ready.
2. Add bullets for R1 and R3 (skill procedure on `glab`, skip only steps with no counterpart and name them), then the concept map for R2 per KTD3.
3. Add bullets for the babysit loop, one rule per bullet:
   - start automatically, drafts excepted (R4, R12);
   - with T3 Code, link, handle existing comments, watch, end the turn, and run one tick per wake in the skill's order (R5);
   - the settle-window wait and the 30-minute fallback wait beside the watch (R13, R14);
   - without T3 Code, the GitHub and GitLab paths and the report-and-resume fallback (R6), with the GitLab watcher's exit events (R15);
   - the GitLab tick's snapshot fields and readiness evidence (KTD4);
   - never rebase on GitLab (R7);
   - stop the watch and the background waits before handing back, and leave merging to the user (R8).
4. Add the reporting bullet for R9 per KTD6.

**Patterns to follow:** `# Branch names` and `# Cross-model delegation` in the same template.

**Test scenarios:**

- Covers AE1, AE6, AE7. The rendered Claude Code, Codex, and Antigravity files each contain the section with every sentence U2 pins, including the R12 draft, R13 settle-wait, R14 fallback-wait, and R15 exit-event sentences.
- The rendered files contain no `{{`, `}}`, or `<no value>`.

**Verification:** Every rendered instruction file carries the section once, outside the tool-table branches.

### U2. Pin the section in the agent-instructions check

**Goal:** A future edit cannot silently drop or invert the new rules.

**Requirements:** R10; KTD2.

**Dependencies:** U1.

**Files:**

- `tests/agent-instructions.nix`

**Approach:**

1. Add `pullRequestSentences` with every sentence of the new section, literal in the test.
2. Call `requireSentences` and `onlyPinnedSentences` for the section, with the heading `# Pull and merge requests` and pattern `.`.
3. Extend the header comment's "Verifies" list with one item for the new rule.

**Patterns to follow:** `gpgSentences` and its two calls.

**Test scenarios:**

- Happy path: the check passes on the U1 template for every user entry and harness.
- Mutation: deleting one pinned sentence from the template fails the check, naming the sentence.
- Mutation: prefixing a pinned sentence with "Do not " fails the check.
- Mutation: adding an unpinned sentence such as "Rebase the branch when GitLab reports it behind." to the section fails the check.
- Mutation: moving the section inside the `claude-code` branch fails the check for Codex and Antigravity.

**Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes on the change and fails on each mutation above, run in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.

### U3. Reconcile the repository's babysit readiness rule

**Goal:** A session in this repository has one wake source and keeps the evidence rule.

**Requirements:** R11; KTD5.

**Dependencies:** U1.

**Files:**

- `AGENTS.md`

**Approach:** Rewrite the "When watching a pull request from a local session" paragraph so `--settle-seconds 0` applies when `ce-babysit-pr`'s own watcher runs, and say that with T3 Code the watch wakes the agent and the same evidence rule decides readiness. Keep every other clause of the paragraph.

**Test expectation:** none -- documentation for this repository's agents; the paragraph has no check.

**Verification:** The paragraph names both wake sources and keeps the evidence, skipped-job, and blocker clauses.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | U2 |
| Markdown lint | `mise run lint-staged-markdown` (pre-commit) | U1, U3 |
| Instruction check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U1, U2 |
| Flake checks | `nix flake check` | all |
| Home outputs | build every `nixosConfigurations.<host>.config.system.build.toplevel` and every `homeConfigurations` activation package, per `AGENTS.md` | U1 |

VM tests and macOS outputs are unaffected by instruction text; CI's `build-darwin` job covers the macOS fixture.

---

## Definition of Done

- The three rendered instruction files carry the new section and the `agent-instructions` check pins every sentence of it.
- Each U2 mutation fails the check and the unmutated tree passes.
- `AGENTS.md` names both wake sources without losing its evidence rule.
- `nix flake check` and the host builds pass.
- No scratch or abandoned-attempt edits remain in the diff.
