---
title: Automatic Learning Refresh Before Push - Plan
type: feat
date: 2026-10-12
topic: auto-compound-refresh
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Automatic Learning Refresh Before Push - Plan

## Goal Capsule

- **Objective:** In every project with a Compound Engineering learning store, a branch that deletes, moves, or renames something a learning cites carries the fix for that learning when it is pushed, so drift never reaches the default branch.
- **Means:** Add a `# Learning refresh` section to the global agent instructions in `home/h82/agents/instructions/instructions.md.tmpl`, which every harness loads, and guard it in the render check `tests/agent-instructions.nix` (KTD1, KTD4).
- **Product authority:** This Product Contract, then the Planning Contract.
- **Open blockers:** None.
- **Execution profile:** Lightweight; two units in one PR (U1, U2).
- **Stop conditions:** Stop if a harness's rendered file cannot carry the new section, or if the render check cannot be made to fail when one of the guarded sentences is removed or negated.
- **Who finishes:** `ce-work` implements and verifies; `lfg` reviews, opens the PR, and watches CI. Merging stays with the user.

---

## Product Contract

Product Contract preservation: changed R3 — added the already-handled-learning skip (R7) so AE3 holds when a re-check sees the same deleting commits; added a line-number-drift Scope Boundary. The three Deferred to Planning questions are resolved in KTD2, KTD3, and KTD5 and removed from Outstanding Questions; R1 names the push range per KTD2.

### Summary

Before each push, the coding agent checks the commits that push would send for deleted, moved, or renamed paths and identifiers, finds the learnings that cite them, and runs `ce-compound-refresh` scoped to those learnings. The refresh lands as its own commit on the same branch.

### Problem Frame

Learnings under the solutions store cite files, hosts, packages, and options by name. When a change removes or moves one of them, nothing prompts a refresh, so the stale reference stays until someone audits the whole store. In this repository that audit came as PR #201, which fixed learnings broken by the removed ThinkPad host, the removed Orca package, moved paths, and drifted line references, long after the changes that broke them. `ce-compound` only recommends a refresh when it writes a new learning, and never in non-interactive runs, so ordinary code changes have no trigger at all.

### Key Decisions

- **Trigger on changes that touch cited references.** A refresh runs because this branch broke a learning's reference, not on a timer and not when a new learning is written. (session-settled: user-directed — chosen over periodic sweeps, a `ce-compound` new-learning trigger, and a pre-ship check on every PR: it catches drift at the change that causes it.) Governs R1, R2.
- **Global agent instructions, not a per-repository check.** The rule applies to every project the user works in. (session-settled: user-directed — chosen over this repository only and over both: the drift problem is not specific to this repository.) Governs R6.
- **Separate commit on the same branch.** (session-settled: user-directed — chosen over a separate PR and over leaving the edits uncommitted: the reviewer sees the cause and the fix together and the default branch never holds the drift.) Governs R4.
- **Ask in interactive sessions, mark stale in autonomous runs.** (session-settled: user-directed — chosen over always running non-interactive: the user wants to make delete, replace, and consolidate calls when present.) Governs R5.
- **Instruction rule, not a harness hook.** A Claude Code hook could detect references mechanically but would cover one harness of three; a shared instruction covers all three. Governs R6.

### Requirements

**Detection**

- R1. Before each push, the agent collects the paths and identifiers that the commits the push would send delete, move, or rename, such as file paths, host names, package names, and option names.
- R2. The agent searches the project's learning store for learnings that cite any collected item; a learning that cites none is not refreshed.
- R3. The check is skipped when the project has no learning store, when the commits the push would send change only learnings, or when no collected item is cited.
- R7. A learning is not refreshed again when it already carries `status: stale`; the R2 search reads learnings as they stand at the branch tip, so a learning a refresh already fixed no longer matches.

**Refresh and commit**

- R4. When R2 finds learnings, the agent runs `ce-compound-refresh` scoped to only those learnings, and commits the result as its own commit on the current branch before pushing.
- R5. In an interactive session the refresh runs in interactive mode and asks the user its judgment calls; in an autonomous run such as `lfg` it runs with `mode:non-interactive`, which marks ambiguous learnings stale instead of asking.

**Coverage**

- R6. The rule lives in the shared global instructions, so Claude Code, Codex, and Antigravity all render it, and the render check fails when the rule is removed or negated.

### Acceptance Examples

- AE1. **Covers R1, R2, R4.** **Given** a branch that deletes a host directory named in two learnings, **when** the agent prepares to push, **then** it runs `ce-compound-refresh` scoped to those two learnings and pushes a branch whose last commit is the refresh.
- AE2. **Covers R3.** **Given** a branch that only edits a module's body and renames nothing, **when** the agent pushes, **then** no refresh runs.
- AE3. **Covers R3, R7.** **Given** a branch whose new commits are the refresh commit itself, **when** the agent pushes again, **then** no second refresh runs.
- AE4. **Covers R5.** **Given** an `lfg` run whose refresh finds a learning it cannot classify, **then** the learning gets `status: stale` and the run continues without a question.
- AE5. **Covers R1.** **Given** a branch already pushed once after a refresh, **when** a later commit moves another cited file, **then** the next push checks only the later commit.

### Scope Boundaries

- Periodic full-store audits are not part of this rule.
- `ce-compound` keeps its current refresh behavior: it recommends, and in non-interactive mode does not invoke.
- Drift that changes behavior without deleting, moving, or renaming anything a learning cites (semantic drift) is not detected.
- Line-number drift from edits that delete, move, or rename nothing is not detected.
- No deterministic repository check, CI job, or harness hook is added.
- The worth lens (culling accurate learnings) never runs from this rule.

### Dependencies / Assumptions

- `ce-compound-refresh` narrows by one scope hint (subdirectory, frontmatter, filename, then content keyword) per its `references/scope.md`; a hint that matches nothing exits in non-interactive mode.
- `ce-compound-refresh` commits its own changes per its `references/commit.md`, but its defaults differ from R4: in interactive mode it asks where to commit, and in non-interactive mode on the default branch it creates a new branch and PR. KTD5 overrides that step.
- Agent judgment from the diff is precise enough to find cited items; misses of semantic drift are accepted.

### Sources / Research

- `home/h82/agents/instructions/default.nix` renders the one template for all three harnesses.
- `tests/agent-instructions.nix` is the render check for the template.
- Commit `8a64208` (PR #201) shows the drift this rule targets.
- `ce-compound`'s `references/refresh-and-discoverability.md` (Phase 2.5) holds the existing recommend-only refresh trigger.
- `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md` governs how R6's check must reject a negated rule.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **New top-level `# Learning refresh` section after `# Review findings` and before `# Branch names`.** Every rule in the template is a top-level section with a lead paragraph and bullets; the refresh runs before a push, and the branch-name rule also runs before the first push, so the two sit together. Governs R6.
- KTD2. **The push range is the set of unchecked commits.** The rule checks the commits the remote branch does not have yet, or, before the first push, the commits since the branch left the default branch. Commits an earlier push sent were checked then, so no state file is needed. Governs R1, AE5.
- KTD3. **One `ce-compound-refresh` run per cited learning, with its filename as the scope hint.** The skill takes one hint per run and matches filenames before content keywords, so a filename hint narrows to exactly that learning. Usually only one or two learnings match. Governs R4.
- KTD4. **Guard the rule with literal sentences in `tests/agent-instructions.nix`.** Add a `learningRefreshSentences` list checked with the existing `requireSentences` helper, which matches a sentence only where one begins, so a negated copy fails. Governs R6.
- KTD5. **The rule overrides `ce-compound-refresh`'s commit step and its Discoverability Check follow-up.** It tells the agent to commit on the current branch without asking where, not to move the refresh to a new branch or PR, and to fold any instruction-file or `CONCEPTS.md` edit those steps make into the refresh commit. The skill never pushes on its own: its discoverability step pushes a follow-up commit when the branch was already pushed (`references/discoverability.md` step 6), which would push mid-check before the other KTD3 runs finish. The agent pushes once, after every scoped run. This follows the pattern of `# Review findings`, which names the skill rules it overrides. Governs R4.

---

## Implementation Units

### U1. Add the learning-refresh rule to the shared instructions

- **Goal:** The rendered instruction file for every harness carries the rule R1 through R5 describe.
- **Requirements:** R1, R2, R3, R4, R5, R6, R7; KTD1, KTD2, KTD3, KTD5.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:** Insert a `# Learning refresh` section between `# Review findings` and `# Branch names`, outside any `.harness.id` branch. A lead paragraph states the rule (check the commits a push would send, and refresh any learning they break before pushing) and defines a learning as a document under `solutions/` in the CE artifact root, which is `docs` unless `docs_root` in `.compound-engineering/config.yaml` names another directory. Bullets cover: the push range (KTD2); what to collect and search for (R1, R2); the skip conditions (R3, R7); one run per learning with its filename as the scope hint (KTD3); the mode for interactive and autonomous runs (R5); and the commit on the current branch with no push by the skill, overriding `ce-compound-refresh`'s commit step and discoverability follow-up (KTD5). Write in the template's voice: imperative, one rule per sentence, code-formatted identifiers.
- **Patterns:** `# Review findings` and `# Branch names` in the same file.
- **Test scenarios:** Covered by U2's render check; this unit is instruction text.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes after U2.

### U2. Guard the rule in the render check

- **Goal:** `agent-instructions` fails when the rule is missing, negated, or moved into one harness's branch.
- **Requirements:** R6; KTD4.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:** Add `learningRefreshSentences` holding the U1 sentences that carry the trigger (R1), the push range (KTD2), the already-handled skip (R7), the scope hint (KTD3), the modes (R5), the commit override, and the no-push clause (KTD5), copied literally. Call `requireSentences "${label} lacks the learning-refresh rule:" learningRefreshSentences` beside the other rule checks. Add a docstring bullet in the same style as the existing ones.
- **Test scenarios:**
  - The check passes on the rendered files for all three harnesses on every host and fixture.
  - Deleting one guarded sentence from the template makes the check fail and name that sentence.
  - Prefixing a guarded sentence with "Do not " makes the check fail.
  - Moving the section inside the Claude Code `.harness.id` branch makes the check fail for Codex and Antigravity.
- **Verification:** Each mutation above, run in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`, turns the check red; the unmutated tree is green.

---

## Verification Contract

| Command | Proves |
| --- | --- |
| `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U1 and U2: the rule renders for every harness and is guarded |
| `nix fmt -- --ci` | Nix formatting |
| `nix flake check` | No other check regressed |
| Mutation runs from U2's test scenarios | The new assertions are not decorative |

The change edits the template and the render check, so the rendered instruction files change for every harness on every host; the host output builds in `AGENTS.md`'s shipping list change only in those files.

---

## Definition of Done

- U1 and U2 are complete, and every command in the Verification Contract passes.
- Each U2 mutation was observed to fail the check, and the mutation scratch copies are removed.
- The PR body reports the check results and names the resolved planning decisions KTD2, KTD3, and KTD5.
- No abandoned-attempt text remains in the template or the check.
