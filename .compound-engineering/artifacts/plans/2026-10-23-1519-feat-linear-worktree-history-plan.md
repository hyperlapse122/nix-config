---
title: Linear Worktree History - Plan
type: feat
date: 2026-10-23
topic: linear-worktree-history
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Linear Worktree History - Plan

## Goal Capsule

- **Objective:** A pull or merge request an agent ships reads as a straight line of its own commits on top of the base, with no merge commits from worktree merge-backs or base syncs, so the repository's history graph stays readable.
- **Means:** Change the shared agent instructions so agents rebase and fast-forward instead of merging (KTD1-KTD6).
- **Product Authority:** User `h82`. The session-settled entries in Key Decisions bind; R-IDs win on behavior, KTDs win on mechanism.
- **Open blockers:** None.
- **Stop conditions:** Stop if a change would edit the Compound Engineering plugin's own skill files, let an agent merge a request into its base, or force-push a branch other than the agent's own request branch.
- **Execution profile:** Instruction template text, one Nix check, and docs; no host generation changes beyond the rendered instruction files.
- **Who finishes:** `ce-work` implements; `lfg` reviews and ships.

---

## Product Contract

Product Contract preservation: changed: R5 — its example no longer implies `gh pr update-branch --rebase` is allowed, because KTD4 forbids every server-side rewrite; R8 — names which branches count as the agent's own, including T3 Code worktree branches, and the report fallback for any other; AE4 — its conflict now lies in a hunk the request edits, because a rebase replays only the request's own commits; the rebase-conflict Key Decision's body now says which conflicts R6 lets the agent resolve; its two `Deferred to Planning` questions are answered by KTD5 and KTD6 and removed, and the babysitting assumption now cites the skill text that grounds it.

### Summary

The shared agent instructions tell agents to bring a subagent's worktree branch back by rebasing it onto the current branch and fast-forwarding, and to bring their own pushed request branch up to date by rebasing it onto the base and pushing with `--force-with-lease`. GitLab follows the same rule, and the old "never rebase" clause goes away.

### Problem Frame

Agents merge in two places today, and both leave merge commits in the graph. The Subagents section of `home/h82/agents/instructions/instructions.md.tmpl` tells an agent to "merge those branches back" from subagent worktrees, which produces commits such as `Merge branch 'worktree-agent-a321f9bd575bcc948' into chore/run-ce-sweep`. When a request branch falls behind its base, agents merge the base in, which produces commits such as `Merge commit '1a88836…' into chore/run-ce-sweep`. A single pull request then shows several crossing lanes in `git log --graph`, and the history around it is hard to follow.

### Key Decisions

- **Both merge points become linear.** Worktree merge-backs and base syncs both stop producing merge commits. Governs R1, R5. (session-settled: user-directed — chosen over changing only the subagent merge-back or only the base sync: both produce the merge commits the user wants gone)
- **GitLab rebases too.** The GitLab "never rebase" clause in the Pull and merge requests section is removed, reversing R7 of `.compound-engineering/artifacts/plans/2026-10-15-1558-feat-forge-neutral-pr-babysitting-plan.md`. Governs R7. (session-settled: user-directed — chosen over keeping GitLab as an exception: the user wants the same linear history on both forges)
- **Rebase then fast-forward, not cherry-pick, is the default merge-back.** A fast-forward keeps the task branch's commits as ancestors, so the existing `git branch -d` cleanup still works and `-D` stays forbidden; cherry-picked commits get new IDs and would make `-d` refuse. Governs R1, R2, R4. (session-settled: user-approved — chosen over cherry-picking every task commit: cherry-pick breaks the `git branch -d` safety check)
- **A rebase conflict the agent cannot settle is aborted and reported.** Every merge-back rebase conflict is aborted, carrying the current merge-conflict rule over to rebases, and a base-sync conflict is aborted unless R6 lets the agent resolve it. Governs R3, R6. (session-settled: user-approved — chosen over resolving every conflict: a guessed resolution rewrites someone's work silently)
- **Force pushes stay narrow.** Rewriting a pushed branch is allowed only on the agent's own request branch and only with `--force-with-lease`. Governs R8.

### Requirements

**Subagent worktree merge-back**

- R1. An agent brings a subagent's worktree branch into its current branch by rebasing that branch onto the current branch's tip and then merging it with `git merge --ff-only`, never with a merge commit.
- R2. An agent uses `git cherry-pick` only when it takes some but not all of a task branch's commits, and then keeps that branch and reports it as holding unmerged commits.
- R3. When the merge-back rebase conflicts, the agent aborts it with `git rebase --abort` and keeps the worktree and the branch, as the current rule does for a conflicting merge.
- R4. After a fast-forward without a conflict, the agent removes the worktree with `git worktree remove` and the branch with `git branch -d`, never with `--force` or `-D`, unchanged from today.

**Bringing a request branch up to date with its base**

- R5. When an agent brings its own pushed pull or merge request branch up to date with its base, it fetches the base, rebases the branch onto it, and pushes with `git push --force-with-lease`; it never merges the base into the branch, including through a skill's or forge tool's merge-based update such as GitHub's update-branch endpoint.
- R6. When that rebase conflicts, the agent resolves only conflicts confined to the request's own changes whose resolution it can verify, and otherwise aborts the rebase and reports the branch as a blocker for the user.
- R7. On GitLab, a merge request branch behind or conflicting with its base follows R5 and R6 instead of being reported without a rebase.
- R8. An agent force-pushes only the head branch of a pull or merge request it opened, in this or an earlier session and including a branch T3 Code created for its worktree, only with `--force-with-lease`, and never a base branch; for any other request behind its base, it reports the branch as a blocker instead of rebasing or merging.

**Consistency and guards**

- R9. Every place in the shared instructions that tells an agent to merge task or worktree branches, including the `ce-work` rule about merging task branches, follows R1.
- R10. The repository's instruction checks pin the new sentences and fail on their removal or negation, and the docs that quote the changed sentences match the new wording.

### Acceptance Examples

- AE1. **Covers R1, R4.** **Given** a subagent that committed in its own worktree while the parent branch gained a commit, **when** the agent merges it back, **then** the parent branch ends with the parent commit followed by the subagent's commits, has no merge commit, and the worktree and branch are removed with `git worktree remove` and `git branch -d`.
- AE2. **Covers R3.** **Given** a subagent branch whose rebase onto the parent conflicts, **when** the agent merges it back, **then** the agent aborts the rebase, leaves the parent branch unchanged, keeps the worktree and branch, and names the branch in its report.
- AE3. **Covers R5, R8.** **Given** an open GitHub pull request whose branch is behind `main`, **when** the agent updates it, **then** the branch is rebased onto the fetched `main`, pushed with `--force-with-lease`, and contains no `Merge commit … into …` commit.
- AE4. **Covers R6.** **Given** a request branch whose rebase onto its base conflicts in a hunk where the base changed behavior the request also edits, and the request's intent does not settle which side wins, **when** the agent updates it, **then** it aborts the rebase, pushes nothing, and reports the branch as a blocker.
- AE5. **Covers R7.** **Given** a GitLab merge request whose branch is behind its base, **when** a babysitting tick runs, **then** the agent rebases and force-pushes with lease as in AE3 instead of only reporting it.

### Scope Boundaries

- How the user merges a request into the base, such as GitHub's merge, squash, or rebase button, stays the user's choice; `Merge pull request #N` commits remain.
- When an agent decides to sync a branch with its base does not change; this work changes only how it syncs.
- History already merged into `main` is not rewritten.
- The Compound Engineering plugin's own skill files are not edited; the shared instructions override their merge steps.
- Considered and not built: a cap on how often a babysitting tick may rebase. `ce-babysit-pr` already acts only on the one `branch_currency` item its snapshot emits, so a rebase loop needs a base that moves on every tick; evidence of such a loop would change the call.
- Considered and not built: `git rebase --rebase-merges` for a branch that already holds merge commits. The goal is a straight line, so flattening those merges is the wanted result.

### Dependencies / Assumptions

- `ce-babysit-pr` updates a behind branch through GitHub's update-branch endpoint and repairs a conflicting one with a local merge, saying "Never rebase or force-push" (`ce-babysit-pr/references/branch-currency.md` in the installed plugin). The shared instructions outrank that procedure, so KTD5 replaces only those two mutations.
- A task branch checked out in a subagent's worktree cannot be rebased from the parent checkout, so the rebase runs inside that worktree before it is removed (KTD1).

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl`: the GitLab "never rebase" clause in the Pull and merge requests section, the `ce-work` no-edit rule ("keep merging task branches"), and the merge-back sentences in the Subagents section.
- `tests/agent-instructions.nix`: pins those sentences in `pullRequestsSentences`, `workNoEditSentence`, `overlappingEditSentence`, `parallelEditsSentence`, `rewriteTriggerSentence`, `worktreeCleanupSentence`, and `leftoverSentence`.
- `docs/provisioning.md` (Shared agent instructions) and `docs/verification.md` (the `ce-work` worktree and parallel-edits items): describe the merge-back and cleanup rules.
- `.compound-engineering/artifacts/plans/2026-10-15-1558-feat-forge-neutral-pr-babysitting-plan.md`: R7 and AE3 record the GitLab no-rebase decision this work reverses.
- `.github/workflows/update-dependencies.yml` already rebases, aborts on failure, and pushes with `--force-with-lease`; `home/h82/dev/git.nix` sets `pull.rebase = true` and signs every commit by default.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **The parent runs the merge-back rebase inside the task worktree, one branch at a time.** Once the subagent has finished and its worktree has no uncommitted changes, the parent runs the rebase in that worktree onto its own current branch, then fast-forwards; with several task branches, each is rebased onto the tip the previous fast-forward left. The parent holds the signing card's agent, and a branch checked out in a worktree can be rebased only there. Implements R1, R9.
- KTD2. **A refused fast-forward is not a conflict and never triggers a stash or reset.** When `--ff-only` fails because the parent's tip moved, the agent rebases once more and retries; when it fails for any other reason, such as uncommitted edits in the parent, the agent keeps the worktree and branch and reports them. The git stash stack is shared across worktrees and sessions, so `git stash`, `--autostash`, and `git reset` stay out. Implements R1, R3.
- KTD3. **The lease names the head the agent expects to replace.** Before rebasing, the agent records the request's current head SHA as the forge reports it, and pushes with `--force-with-lease=<branch>:<that-sha>`. Before rebasing, it confirms its local branch tip equals that SHA and its checkout has no uncommitted changes; when the tip differs, it neither rebases nor resets, and reports the branch, because a rebase of an older local tip would pass the lease and delete the forge-only commits. A bare `--force-with-lease` compares against the remote-tracking ref, which the required fetch may already have moved past someone else's push. When the lease is rejected, the agent never retries with `--force`; it reports the branch. Implements R5, R8.
- KTD4. **The rebase is local, and a signing or hook failure aborts it.** `gh pr update-branch` in either form, GitHub's update-branch endpoint, and `glab mr rebase` all rewrite commits on the server, which drops the user's GPG signatures. A rebase re-signs each commit through the usual pinentry; when signing or a hook fails mid-rebase, the agent aborts the rebase and reports, and never disables signing or passes `--no-verify`. Implements R5, R7.
- KTD5. **One Pull and merge requests bullet overrides `ce-babysit-pr`'s two base mutations, and one names GitLab's trigger.** `ce-babysit-pr` is GitHub-only, so on GitHub the bullet keeps the skill's `branch_currency` trigger and its claim, outcome, and confirm bookkeeping, performs the R5 rebase in place of the `BEHIND` host update and the `DIRTY` local merge, and gates both on the `DIRTY` path's proven direct-push authority to the exact head ref rather than `host_branch_update_capability`. On GitLab, the agent runs the R5 rebase when `glab mr view` reports `detailed_merge_status` as `need_rebase` or `conflict`, takes the merge request's `sha` as the KTD3 lease, and reports the outcome in its babysitting summary. The GitLab readiness sentence loses its "; never rebase" tail. Implements R5, R6, R7.
- KTD6. **Each changed or added sentence gets a removal and a negation mutation, and the retired wording becomes a removed term.** New sentences join `pullRequestsSentences` or the Subagents sentence bindings; the retired clause "is unresolved; never rebase" and "merge those branches back" join `removedTerms`, so a reverted line fails even when it sits beside the new one. Phrase-level mutations cover the new commands: `--ff-only` dropped, the lease widened to `--force`, the abort dropped, and a merge-based update allowed again. Implements R10.

### Assumptions

- `ce-work` in this repository routes units through the native `Agent` tool or `delegate_task`, so its cross-model integration path (`git cherry-pick --no-commit` into one host commit) never runs here and needs no override.
- A merged-back branch whose commits were rebased stays an ancestor of the parent tip after the fast-forward, so `git branch -d` succeeds without `-D`.

---

## Implementation Units

### U1. Instructions template

- **Goal:** Render the rebase-and-fast-forward merge-back and the rebase-and-lease base sync.
- **Requirements:** R1-R9; KTD1-KTD5.
- **Dependencies:** none.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. In the Subagents section, replace "merge those branches back one at a time" and "merge that branch back once it has finished" with wording that names the R1 rebase-then-fast-forward, and keep "one at a time" with the KTD1 ordering.
  2. Rewrite the worktree cleanup sentence so cleanup follows a fast-forward without a conflict and a conflicting rebase is aborted with the worktree and branch kept (R3, R4); add one sentence for KTD1's location and clean-worktree precondition and KTD2's refused fast-forward, and one for the R2 partial cherry-pick.
  3. In the overlapping-edit sentence, keep "a worktree you will merge back" only if it still reads true under R1; otherwise name the fast-forward.
  4. In the Compound Engineering section, change "keep merging task branches" in the `ce-work` no-edit sentence to name the R1 merge-back (R9).
  5. In the Pull and merge requests section, drop "; never rebase" from the GitLab readiness sentence and add bullets for R5 with KTD3's lease and local-tip check, R6, R8 with its report fallback, KTD4's local-only and abort rule, and KTD5's `ce-babysit-pr` override and GitLab trigger.
- **Patterns to follow:** the existing one-rule-per-sentence bullets with commands in code spans, as in the worktree cleanup sentence.
- **Test scenarios:** covered by U2.
- **Verification:** the rendered `~/.claude/CLAUDE.md` holds each new sentence exactly once and no longer contains "is unresolved; never rebase" or "merge those branches back".

### U2. Instruction guards

- **Goal:** Pin the new sentences and fail every reversal of them.
- **Requirements:** R10; KTD6.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Update `pullRequestsSentences`, `workNoEditSentence`, `overlappingEditSentence`, `parallelEditsSentence`, `rewriteTriggerSentence`, and `worktreeCleanupSentence` to the U1 text, and add bindings for each new sentence.
  2. Add the retired phrases to `removedTerms`.
  3. Add `removedAndNegatedIn` cases for every new or changed sentence, including the Pull and merge requests ones, which have no such cases today.
  4. Rework the three worktree cleanup mutations to the new wording and add the KTD6 phrase-level mutations.
  5. Update the check's header comment that lists what each mutant guards.
- **Execution note:** Mutation-test each new guard per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` and `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`; run it in a separate worktree, never a copied checkout (`.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`).
- **Test scenarios:**
  - The rendered instructions with the U1 text pass `agent-instructions`.
  - Each new or changed sentence removed fails with "moves a … sentence out of its section".
  - Each new or changed sentence prefixed with "Do not" fails with "does not hold this sentence exactly once".
  - The "; never rebase" tail restored on the GitLab readiness sentence fails on the removed term.
  - "merge those branches back one at a time" restored in the parallel-edits sentence fails on the removed term.
  - `git merge --ff-only` replaced with `git merge` in the merge-back sentence fails its pin.
  - The lease widened to `--force` fails the R5 sentence's pin.
  - The `git rebase --abort` clause dropped from the cleanup sentence fails its pin.
  - The KTD5 override reworded to allow GitHub's update-branch endpoint fails its pin.
  - The KTD3 local-tip check dropped from the R5 sentence fails its pin.
  - The GitLab trigger sentence removed or negated fails as the other removal and negation cases do.
  - The existing "worktree removal forced" and "branch deletion forced" mutations still fail against the new cleanup sentence.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.agent-instructions` passes, and each listed mutation fails as described.

### U3. Docs

- **Goal:** Describe the linear merge-back and base sync.
- **Requirements:** R10.
- **Dependencies:** U1.
- **Files:** `docs/provisioning.md`, `docs/verification.md`.
- **Approach:**
  1. In `docs/provisioning.md`, Shared agent instructions: add the base-sync rule to the pull and merge requests summary, and rewrite the `ce-work` worktree paragraph ("the orchestrator merges its branch", "A merge that conflicts is aborted") and the three-cases sentence ("merges the branches back one at a time") to the rebase-and-fast-forward wording.
  2. In `docs/verification.md`, change the `ce-work` worktree item to expect a rebase inside the worktree, a fast-forward, and an aborted rebase on conflict, and the parallel-edits item to expect fast-forwards one at a time; add one item that a behind request branch is rebased and pushed with `--force-with-lease`, with no merge commit.
- **Test scenarios:** Test expectation: none -- prose only; the doc-term checks in `tests/agent-instructions.nix` must still pass.
- **Verification:** `nix flake check` passes, and no doc line still says the orchestrator merges a task branch or that GitLab branches are never rebased.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Format | `nix fmt -- --ci` |
| Checks | `nix flake check` |
| Focused | `nix build --no-link .#checks.x86_64-linux.agent-instructions` |
| Outputs | build every output under `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations`, production and bootstrap, per `AGENTS.md`; leave macOS and aarch64 outputs to CI off those builders |

## Definition of Done

- R1-R10 hold, and each U2 mutation scenario fails as stated.
- No sentence in the rendered instructions tells an agent to create a merge commit when it brings a task branch or the base into a branch, or to rebase on the server.
- No abandoned-attempt code remains in the diff.
