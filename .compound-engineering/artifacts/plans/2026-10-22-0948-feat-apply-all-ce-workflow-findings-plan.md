---
title: Apply Every Finding From Any Compound Engineering Workflow - Plan
type: feat
date: 2026-10-22
topic: apply-all-ce-workflow-findings
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Apply Every Finding From Any Compound Engineering Workflow - Plan

## Goal Capsule

- **Objective:** A problem that any Compound Engineering workflow's review, verification, or check step finds in the work it produces gets fixed in the same change. A finding left unfixed shows in the pull request body under one allowed reason the reader can check at a glance.
- **Means:** Rewrite the `# Review findings` section of `home/h82/agents/instructions/instructions.md.tmpl`, the shared instructions every harness loads, update its render check in `tests/agent-instructions.nix`, and align `AGENTS.md` and the **Review finding** entry of `CONCEPTS.md` with it.
- **Product authority:** This Product Contract. It supersedes the coverage and exception requirements of `.compound-engineering/artifacts/plans/2026-10-12-0908-feat-review-findings-override-plan.md` for this section and keeps the rest.
- **Open blockers:** None.
- **Execution profile:** Lightweight; three units in one PR (U1-U3).
- **Stop conditions:** Stop if the render check cannot be made to fail when one of the new pinned sentences is removed or negated, or if a rendered harness file differs from the expected file for a reason outside this section.
- **Who finishes:** `ce-work` implements and verifies; `lfg` simplifies, reviews, opens the PR, and watches CI. Merging stays with the user.

---

## Product Contract

### Summary

Widen the review-findings rule from three review skills to every review, verification, or check step inside a Compound Engineering workflow. Close the three reasons recent pull requests used to leave findings unapplied. Require each entry under `Unapplied review findings` to start with one tag from a closed list of allowed reasons.

### Problem Frame

The rule today names `ce-code-review`, `ce-simplify-code`, and `ce-doc-review`, and allows a finding to stay unapplied only when it is verified wrong or every fix would weaken a safety check. Agents still leave findings behind, through two gaps.

First, other workflows run their own review or check steps and filter the results by their own rules, which the global rule does not name:

- `ce-plan` dismisses doc-review claims that miss its bar, advisory observations included, and drops deepening findings nobody accepted (`ce-plan/references/plan-handoff.md:25`).
- `ce-work` rejects "preferences whose benefit does not justify the change" and does not carry a skipped low-value suggestion forward (`ce-work/references/review-findings-followup.md:43`, `:78`).
- `lfg` applies only findings with confidence 100, or 75 with agreement, and a mechanical fix (`lfg/references/review-followup.md`, Step 5).
- `ce-debug` defers a divergent fix, `ce-optimize` defers findings that need a design decision or have no concrete fix, `ce-test-browser` in pipeline mode logs a failure and continues, and `ce-brainstorm` turns remaining review items into `Deferred to Planning` questions (`ce-debug/SKILL.md:70`, `ce-optimize/references/wrap-up.md:41`, `ce-test-browser/SKILL.md:45`, `ce-brainstorm/references/handoff.md:56`).

Second, even findings from the three named skills stay unapplied for reasons the rule does not allow. The `Unapplied review findings` sections of PRs #271-#293 show:

- out-of-scope fixes: "existing delivery behavior outside this diff" (#277), "sharing them means changing three existing helpers" (#272);
- reworded impact claims: "hides nothing visible" (#292), "Mitigated, not removed" (#277);
- conflicts with the user's scope, recorded without asking: "excluded from scope in the brainstorm the user confirmed" (#282), "the user chose to move them anyway" (#292).

Each entry gives a free-form reason, so a reader cannot tell an allowed exception from a new excuse without judging each one.

Paths to skill files are relative to the installed Compound Engineering plugin's `skills/` directory.

### Key Decisions

- **Cover every review, verification, and check step inside a CE workflow, not PR comments.** (session-settled: user-directed — chosen over also covering PR comments handled by `ce-resolve-pr-feedback` and `ce-babysit-pr`, and over only closing the filters callers apply to the three review skills.) Governs R1, R3.
- **A verdict that picks among options is not a finding.** (session-settled: user-approved — proposed in the scoping synthesis: an adoption grade or a rejected candidate is the answer the workflow was asked for, not a defect in its output.) Governs R2.
- **Close three reasons: out of scope, reworded no-impact or mitigation, and an unasked conflict with a user decision.** (session-settled: user-directed — chosen over also closing "no fix is possible in this repository".) Governs R4, R5, R6.
- **Allow "no fix in this repository" as a further reason, with no added condition.** (session-settled: user-directed — chosen over making it an explicit exception that requires the remaining risk documented, and over requiring a mitigation that counts as applied.) Governs R9.
- **Extend the existing section and add reason tags.** (session-settled: user-directed — chosen over a per-skill override list, which drifts with frequent CE releases, and over a closed list without a tag for "no fix in this repository".) Governs R8, R10.
- **A run with no person present lists a user-decision conflict with the `awaits your decision` tag.** (session-settled: user-approved — proposed in the scoping synthesis: such a run cannot ask.) Governs R7.
- **Change only the shared instructions, their render check, and the repository's `AGENTS.md` and `CONCEPTS.md`; patch no plugin file and add no hook.** Carried from the 2026-10-12 plan, where the user chose it because plugin patches break on automated CE bumps and a hook works in one harness only.

### Requirements

**Coverage**

- R1. The rule applies to every finding that a review, verification, or check step of any Compound Engineering skill reports about the work the workflow produces or changes: code, plan, document, or learning. This includes `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` wherever they run, and the steps other skills run themselves, such as `ce-plan`'s confidence check and deepening, `ce-debug`'s post-fix review, `ce-optimize`'s wrap-up review, `ce-test-browser`'s failed routes, `ce-compound`'s grounding validator, `ce-compound-refresh`'s recommended writes, `ce-brainstorm`'s claim verifier, and `ce-noslop` detect findings on text the workflow writes.
- R2. A verdict that chooses among alternatives, such as a `ce-pov` adoption grade, a `ce-bakeoff` judgment, or a `ce-ideate` candidate verdict, is not a finding.
- R3. No skill's own disposition narrows the rule: a dismissal, a rejection, a low-value skip, a deferral, a log-and-continue, a `Deferred to Planning` question, or an apply bar does not leave a finding unapplied.

**Reasons that do not leave a finding unapplied**

- R4. A fix that reaches outside the diff or the change's scope, such as existing behavior or helpers the change did not touch, is made in the same change.
- R5. A rewording of the already forbidden "low impact" and "no current instance", such as "hides nothing visible", "mitigated, not removed", or "the current configuration never triggers it", is not a reason to leave a finding.
- R6. A finding whose fix would reverse a decision the user made, including a brainstorm Scope Boundary or a `session-settled` entry, is asked in every run with a person present, autonomous runs such as `lfg` included, and is applied or dropped by the answer; a dropped fix is listed with the `declined by you` tag.
- R7. In a run with no person present, that finding is listed with the `awaits your decision` tag instead.

**Unapplied entries**

- R8. Each entry under `Unapplied review findings` starts with exactly one tag from the closed list `verified wrong`, `weakens a safety check`, `declined by you`, `awaits your decision`, `no fix in this repository`, followed by its evidence or reason.
- R9. `no fix in this repository` is a new reason: the agent uses it when no change in the repository can fix the finding, with no further condition.
- R10. A finding whose entry cannot carry one of those tags is applied, not listed.

**Kept behavior**

- R11. The current rules stay: an interactive run asks about a finding that needs a user decision; an autonomous run applies the recommended fix and reports it, but asks before reversing a decision the user made, per R6; a review-only request ends with one apply-all question; applied fixes are reported in the PR body and the final report; the section is omitted when nothing is unapplied.

**Guard**

- R12. The render check fails when the coverage sentence, the forbidden-reason sentence with its R4 and R5 additions, the exception sentence, the user-decision sentence, or the tag sentence is missing from any harness's rendered file, and when the old three-skill lead sentence returns.

### Acceptance Examples

- AE1. **Covers R1, R3.** Given `ce-plan` dismisses an advisory doc-review observation on its plan, when planning ends, then the plan is edited to resolve it, or the observation is listed as `verified wrong` with evidence.
- AE2. **Covers R3, R4.** Given `lfg` leaves an anchor-50 finding that a new script repeats helpers from three existing scripts, when the PR opens, then the helpers are shared in the same PR and the PR body has no entry for it.
- AE3. **Covers R6, R7.** Given a finding whose fix contradicts a brainstorm Scope Boundary, when an attended `lfg` run reaches it, then the agent asks before going on; when a headless run reaches it, then the PR body lists it as `awaits your decision`.
- AE4. **Covers R1, R3.** Given `ce-test-browser` in pipeline mode logs a failed route for the change, when the work ships, then the route passes.
- AE5. **Covers R2.** Given `ce-pov` returns "Hold" on adopting a tool, then nothing is applied or listed, because the verdict is not a finding.
- AE6. **Covers R8, R10.** Given a draft PR body entry whose reason is "outside this diff", then that entry cannot take any tag, so the agent fixes the finding and removes the entry.

### Scope Boundaries

- PR comments handled by `ce-resolve-pr-feedback` or `ce-babysit-pr`, and Claude Code's built-in `/code-review`, `/simplify`, and `/security-review`, are not covered.
- The Compound Engineering skill files are not patched, and no hook enforces the rule.
- The harness-specific parts of the template are not changed; the rule stays in the shared part.
- No check reads real PR bodies for tags; the guard pins the instruction text only.

### Sources

- `home/h82/agents/instructions/instructions.md.tmpl` — the current `# Review findings` section.
- `tests/agent-instructions.nix` — `reviewFindingsSentences`, `checkedSections`, and `supersededDirectives`.
- `.compound-engineering/artifacts/plans/2026-10-12-0908-feat-review-findings-override-plan.md` — the plan whose rule this one widens.
- `CONCEPTS.md` — the **Review finding** entry.
- `AGENTS.md` — the repository's own copy of the review rule.
- `tests/agent-instructions.nix` `removedTerms` — terms no rendered file may carry.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` and `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md` — required reading before changing the check.

Product Contract preservation: changed: R6, R8 — code review found that a fix the user declines when asked had no allowed reason, so it added the `declined by you` tag; also clarified, no scope change: the deferred question about the repository `AGENTS.md` copy is resolved as KTD4 and removed from Outstanding Questions; R9 and its Key Decision name the no-fix tag as a new reason; R11 keeps the current rule's ask-before-reversing clause, per R6; R12 names the guarded sentences; the change-scope Key Decision and the Means line name every file the units touch.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Keep `# Review findings` one paragraph in the shared part of the template, and keep the current sentence order: coverage, override, forbidden reasons, cost, exceptions, outlet, user decisions, review-only, report.** The render check compares the section to `reviewFindingsSentences` in order, so each new sentence takes the slot of the concern it extends. Implements R1-R11.
- KTD2. **Write the tags as backticked lowercase literals, exactly `verified wrong`, `weakens a safety check`, `declined by you`, `awaits your decision`, and `no fix in this repository`, in one sentence that says each `Unapplied review findings` entry starts with one of them.** An agent writing a PR body matches the literal, and a reader scans for it. Implements R8-R10.
- KTD3. **Pin every new or changed sentence in `reviewFindingsSentences`, add the old lead fragment, "Apply every finding that `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` report", to `removedTerms`, and add four self-test mutants for the section.** `onlyPinnedSentences`, `requireSentences`, and `sentencesInOrder` fail on a missing, negated, extra, or reordered sentence only while the section's `checkedSections` entry exists, so the mutants (a narrowing sentence added, the tag sentence moved, removed, and negated) prove that entry still fires, and the `docs/provisioning.md` mutant count becomes 70. The `removedTerms` entry still fails a rendering that brings the three-skill rule back if that entry is ever dropped. Implements R12.
- KTD4. **Align the repository `AGENTS.md` copy and the `CONCEPTS.md` **Review finding** entry in the same change, and check both.** Both state the rule for readers who may not load the global file. `AGENTS.md` carries every pinned template sentence, and the check fails when one is missing where a sentence starts or a retired three-skill lead returns; the glossary entry must keep the Compound Engineering scope and the five tags. Resolves the brainstorm's deferred question.

### Assumptions

- The section stays free of template actions, so the expected file the check builds needs no new action in its replacement table.
- The removed-term fragment does not occur in any other pinned sentence: the `# Korean text` sentence names the three skills in another order and wording.

### Sequencing

U1 and U2 land together, because the check fails against the rewritten template until its literals match. U3 has no dependency and no check.

---

## Implementation Units

### U1. Rewrite the review-findings section

- **Goal:** Render the widened rule, the closed reasons, and the tag requirement into every harness's instruction file.
- **Requirements:** R1-R11; KTD1, KTD2. The session-settled Key Decisions govern R1-R10.
- **Dependencies:** none.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. Replace the lead sentence with a coverage sentence per R1: every finding a review, verification, or check step of any Compound Engineering skill reports about the work the workflow produces or changes, whatever its severity, confidence, or list. Name only `ce-code-review`, `ce-simplify-code`, and `ce-doc-review` as examples beside that generic clause; the in-workflow steps R1 lists stay in the Product Contract as illustration and out of the pinned text, so a CE release that renames a step does not leave the instructions naming one that no longer exists.
  2. Add the verdict exclusion per R2 right after it.
  3. Extend the override sentence per R3 so it names the dispositions: a dismissal, rejection, low-value skip, deferral, log-and-continue, `Deferred to Planning` question, apply bar, or confidence threshold, `lfg`'s included.
  4. Keep the forbidden-reason sentence and add its rewordings per R5; add one sentence per R4 that a fix reaching outside the diff or the change's scope is made in the same change.
  5. Keep the cost sentence; rewrite the exception sentence so it allows exactly the five cases R8 tags, in the same order as the tag literals in step 6: verified wrong with quoted evidence, every fix weakens a safety check, the user declined the fix when asked, a user-decision conflict in a run with no person present per R7, and no change in the repository can fix it per R9.
  6. Replace the outlet sentence with the tag sentence per R8-R10 and KTD2; keep the "omit that section when there are none" clause.
  7. Extend the user-decision sentence per R6 and R7: a fix that would reverse a user decision, a brainstorm Scope Boundary or `session-settled` entry included, is asked in every run with a person present, autonomous runs included, and listed as `awaits your decision` in a run with no person present.
  8. Keep the review-only and report sentences per R11.
- **Patterns to follow:** The current `# Review findings` wording where it still fits; the imperative, second-person voice of the surrounding sections.
- **Test scenarios:** Covered by U2.
- **Verification:** Each rendered file carries the section once, with no harness tool name and no unescaped tilde outside a code span.

### U2. Pin the new sentences in the render check

- **Goal:** Make the check fail when any new or changed sentence is missing, negated, reordered, or unpinned, or when the old three-skill lead returns.
- **Requirements:** R12; KTD3.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Replace `reviewFindingsSentences` with the U1 sentences, copied verbatim and in section order, the rewritten exception sentence included.
  2. Add the old lead fragment to `removedTerms`.
- **Execution note:** Read `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`, `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`, and `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md` before the mutation runs, and run them in a scratch copy.
- **Patterns to follow:** The existing `reviewFindingsSentences` and `removedTerms` lists.
- **Test scenarios:**
  - Happy path: with U1 and U2 applied, `checks.x86_64-linux.agent-instructions` builds.
  - Covers AE6. Mutation: deleting the tag sentence from the template fails the check for every delivery path.
  - Mutation: prefixing the coverage sentence with "Do not" fails the check.
  - Mutation: adding a fifth tag to the tag sentence fails the check as an unpinned sentence.
  - Mutation: deleting the R4 out-of-scope clause from the forbidden-reason sentence fails the check.
  - Mutation: restoring the old two-reason exception sentence in place of the rewritten one fails the check.
  - Mutation: restoring the old lead sentence beside the new section fails the check on the removed term.
- **Verification:** The check passes on the branch and fails under each mutation.

### U3. Align the repository rule and the glossary

- **Goal:** Keep the repository `AGENTS.md` and `CONCEPTS.md` saying what the shared rule says.
- **Requirements:** R1-R10; KTD4.
- **Dependencies:** none.
- **Files:** `AGENTS.md`, `CONCEPTS.md`.
- **Approach:**
  1. In `AGENTS.md`'s "Always apply all review findings" paragraph, widen the coverage sentence per R1 and R2, add the out-of-scope and reworded-reason closures per R4 and R5, and require the tags per R8.
  2. In `CONCEPTS.md`'s **Review finding** entry, replace the exception list with the five tagged reasons and state that a user-decision conflict is asked when a person is present, per R6 and R7.
- **Test expectation:** none -- prose that no check reads; Markdown lint covers formatting.
- **Verification:** Neither file names only the three review skills as the rule's scope, and both list the same five reasons as the template.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| Render check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` |
| All checks | `nix flake check` |
| Markdown lint | `mise run lint-staged-markdown` (pre-commit hook) |
| Host outputs | Build every `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations` output as `AGENTS.md` lists; macOS and aarch64 outputs are left to CI off a matching builder |

---

## Definition of Done

- R1-R12 hold: every rendered file carries the rewritten section, and the render check guards it.
- Every U2 mutation turns the check red, and the unmutated branch is green.
- `AGENTS.md` and `CONCEPTS.md` match the template's scope and reasons.
- `nix fmt -- --ci`, `nix flake check`, and the host-output builds succeed.
- No abandoned-attempt text remains in the template, the check, or the docs.
