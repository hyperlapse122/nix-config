---
title: Review Findings Rule That Overrides Skill Deferral - Plan
type: feat
date: 2026-10-12
topic: review-findings-override
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Review Findings Rule That Overrides Skill Deferral - Plan

## Goal Capsule

- **Objective:** When a coding agent on this machine acts on a Compound Engineering review, every item that `ce-code-review`, `ce-simplify-code`, or `ce-doc-review` reports gets applied on the same branch or document. The only exceptions are a finding the agent verified wrong, one that would cross a skill's safety boundary, one with no change to make, and one that needs a user decision the run must ask for.
- **Means:** Rewrite the `# Review findings` section of `home/h82/agents/instructions/instructions.md.tmpl`, the global instructions every harness loads, and update its render check.
- **Product authority:** This Product Contract. It supersedes the requirements of `.compound-engineering/artifacts/plans/2026-09-28-2131-feat-apply-all-review-findings-plan.md` for this section.
- **Open blockers:** None.
- **Execution profile:** Lightweight; two units in one PR (U1, U2).
- **Stop conditions:** Stop if a harness's rendered file cannot carry the new section, or if the render check cannot be made to fail when one of the guarded sentences is removed.
- **Who finishes:** `ce-work` implements and verifies; `lfg` reviews, opens the PR, and watches CI. Merging stays with the user.

---

## Product Contract

### Summary

Rewrite the global review-findings rule so it names every place the CE review skills move or park findings, and states that it overrides those skill rules. Autonomous runs apply the recommended fix for a finding that needs a decision. They stop only when the fix would reverse a decision the user already made.

### Problem Frame

The global instructions already say to apply every `ce-code-review` and `ce-simplify-code` finding, P2 and P3 included, and agents still leave findings unapplied. The cause is in the skills. Each skill carries a more specific rule that sorts findings out of the list an agent acts on, or tells the agent where to park them:

- `ce-code-review` moves a single-reviewer P2/P3 from the testing, maintainability, reliability, or adversarial reviewer into `testing_gaps` or `residual_risks` (`ce-code-review/references/finish-review.md:39`). It keeps advisory, `human`-owned, and `release`-owned items out of `actionable_findings`, and marks `unresolved` or validation-degraded findings as never applied.
- `lfg` applies only findings with a `suggested_fix`, confidence 100 (or 75 with cross-reviewer agreement), and a mechanical fix. It writes the rest into the PR body (`lfg/references/review-followup.md:35-68`).
- `ce-work` defers fixes that expand the agreed scope or need a product preference. Its Residual Work Gate records them in a `## Unapplied review findings` PR section or tracker tickets (`ce-work/references/shipping-workflow.md:35-41`).
- `ce-simplify-code` skips "low-value findings ... without asking the user" (`ce-simplify-code/SKILL.md:44`).
- `ce-doc-review` routes anchor-50 findings to a report-only FYI section and offers a Defer choice that moves a finding into the document's `## Deferred / Open Questions` section.

The agent reads the global rule as covering "findings", and each skill has already decided that these items are not findings to act on. The skill rule is the more specific instruction in context, so it wins.

Paths in this section are relative to the installed Compound Engineering plugin's `skills/` directory.

### Key Decisions

- **Cover the CE code review family and `ce-doc-review`, not built-in or PR-comment review.** (session-settled: user-directed — chosen over also covering Claude Code's `/code-review`, `/simplify`, `/security-review` and PR feedback handled by `ce-resolve-pr-feedback` or `ce-babysit-pr`: the user picked only the CE code and document reviewers.) Governs R1.
- **Every bucket a skill produces counts as a finding.** (session-settled: user-directed — chosen over excluding advisory items, or keeping only `findings` and `testing_gaps`: the user wants nothing parked.) Governs R2, R3, R4.
- **Change only the global instructions; do not patch the plugin or add a hook.** (session-settled: user-directed — chosen over patching the CE skill files in `agent-plugins.nix` and over a Claude Code Stop hook: plugin patches break on the frequent automated CE bumps, and a hook works in one harness only.) Governs the Scope Boundaries entry on skill files and hooks.
- **Autonomous runs apply the recommended fix for a finding that needs a decision.** (session-settled: user-directed — chosen over stopping to ask: the user wants autonomous runs to keep moving.) Governs R9.
- **A fix that reverses a user-made decision still stops an autonomous run.** (session-settled: user-directed — chosen over applying the recommendation anyway: the agent must not overturn the user's own choice.) Governs R10.
- **A standalone review request ends with one apply-all question.** (session-settled: user-directed — chosen over always applying and over report only: a user who asked only for a review keeps control, without a per-finding menu.) Governs R11.

### Requirements

**Coverage**

- R1. The rule applies to `ce-code-review` (its cross-model pass included), `ce-simplify-code`, and `ce-doc-review`.
- R2. A finding is any item these skills report, whatever its severity, confidence, owner, action class, or the list it sits in. This includes `findings`, `actionable_findings`, `testing_gaps`, `residual_risks`, advisory items, `human`- or `release`-owned items, `ce-doc-review` FYI observations, and items `ce-simplify-code` would skip as low-value or uncertain.
- R3. A testing gap is resolved by adding the missing test, and a residual risk or advisory item by the code or document change that removes it. Only an item with nothing to change, such as a rollout note or a learning, is reported without an edit.
- R4. A finding a skill left `unresolved` or validation-degraded is verified by the agent: applied when it holds, reported with the reason when it does not.

**Precedence and forbidden outlets**

- R5. The rule says it overrides the skills' own apply bars and deferral steps and names them: `lfg`'s apply bar and residual handoff, `ce-work`'s deferral criteria and Residual Work Gate, `ce-code-review`'s soft buckets and never-apply marks, `ce-code-review`'s report-only default and its no-blocking-prompts rule, `ce-simplify-code`'s low-value skip, and `ce-doc-review`'s grouped confirmation, routing question, per-finding Apply/Defer/Skip walk-through, FYI routing, and hold on findings only a cross-model peer raised. R9 and R11 replace those prompts and holds; the R11 apply-all question comes after the skill returns its report.
- R6. The rule lists the outlets a finding may not be parked in: a residual list, a follow-up ticket, a PR section of unapplied findings such as `## Unapplied review findings`, a document's `## Deferred / Open Questions` section, and a report-only or FYI listing.
- R7. Reporting what was applied, or which decisions the agent made on the user's behalf, is allowed in the PR body and the final report.

**Exceptions**

- R8. A finding stays unapplied only when the agent verified it wrong, or when applying it would cross a skill's safety boundary: editing outside `ce-simplify-code`'s mutation boundary, or thinning a safety check. The agent reports each such finding with the reason.
- R9. In an interactive run, a finding that needs a user decision (product behavior, or a change outside the agreed scope) is asked with the question tool. In an autonomous run such as `lfg`, the agent applies the recommended fix and lists each decision it made in the final report.
- R10. In an autonomous run, a finding whose fix would reverse a decision the user made, such as a `session-settled` entry in the plan, stops the run and is asked with the question tool.
- R11. When the user asked only for a review, the agent reports and then asks once whether to apply every finding. It does not offer a menu of which findings to apply. A review that runs inside a planning, work, or shipping flow (`ce-brainstorm`, `ce-plan`, `ce-work`, `lfg`, `ce-commit-push-pr`) applies findings without the apply-all question; a finding there that needs a user decision still follows R9.

**Guard**

- R12. The render check fails when the rule's coverage sentence, its override statement, or its forbidden-outlet sentence is missing from any harness's rendered file.

### Acceptance Examples

- AE1. **Covers R2, R3.** Given `ce-code-review` puts a single-reviewer P3 from the testing reviewer into `testing_gaps`, when the agent finishes, then the missing test exists on the branch.
- AE2. **Covers R5, R6.** Given an `lfg` run where a finding has confidence 50 and no `suggested_fix`, when the run ends, then the finding is fixed on the branch and the PR body has no unapplied-findings section.
- AE3. **Covers R9, R10.** Given an autonomous run with one finding that needs a product choice and another whose fix contradicts a `session-settled` plan decision, then the first is applied and named in the final report, and the run stops to ask about the second.
- AE4. **Covers R11.** Given the user types `/ce-code-review` with no other request, when the report is shown, then the agent asks one question, whether to apply every finding, and edits nothing before the answer.
- AE5. **Covers R2, R6.** Given `ce-doc-review` reports an anchor-50 FYI observation on a plan, then the agent edits the plan to resolve it rather than leaving it in the FYI list or moving it to `## Deferred / Open Questions`.

### Scope Boundaries

- Claude Code's built-in `/code-review`, `/simplify`, and `/security-review`, and PR comments handled by `ce-resolve-pr-feedback` or `ce-babysit-pr`, are not covered.
- The Compound Engineering skill files are not patched, and no hook enforces the rule.
- The repository `AGENTS.md` review rule is not changed.
- The harness-specific tool tables in the template are not changed.

### Sources

- `home/h82/agents/instructions/instructions.md.tmpl` — the current `# Review findings` section.
- `tests/agent-instructions.nix` — `reviewFindingsSentences`, the literal sentences the render check requires today.
- `.compound-engineering/artifacts/plans/2026-09-28-2131-feat-apply-all-review-findings-plan.md` — the plan that added the current rule.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` — required reading before changing the check.

Product Contract preservation: clarified, no scope change — the Objective lists the R8–R10 exceptions; R5 names the remaining skill prompts and holds that R2, R9, and R11 already override; R11 limits its in-flow clause to the apply-all question and adds `ce-brainstorm` and `ce-plan` as flows; the plugin-patch Key Decision cites Scope Boundaries instead of R6.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Keep one `# Review findings` section in the shared part of the template, after the harness branch.** All three harnesses (Claude Code, Antigravity, Codex) run the same CE skills, so the rule stays outside the `.harness.id` branch and keeps its current position between `# Cross-model delegation` and `# Branch names`. Implements R1–R11 (governed by the Key Decisions above).
- KTD2. **Order the section so the override comes before the details.** Lead with the coverage sentence and the override sentence (R1, R5), then the finding definition (R2–R4), the forbidden outlets (R6, R7), the exceptions (R8), and the run-shape rules (R9–R11). An agent reading a skill's apply bar mid-run must already have read that this rule wins.
- KTD3. **Refer to the question tool generically, never by a harness's tool name.** `tests/agent-instructions.nix` fails a harness whose file names another harness's backticked tool, so the shared section says "the question tool", as the current section does.
- KTD4. **Name skills, buckets, and outlets by their literal identifiers.** Agents match the skill text they are reading against this rule, so the rule uses the skills' own words: `testing_gaps`, `residual_risks`, `actionable_findings`, `advisory`, `unresolved`, FYI, Defer, `## Unapplied review findings`, `## Deferred / Open Questions`, Residual Work Gate. Paraphrase would not match the skill text in context.
- KTD5. **Replace `reviewFindingsSentences` with three new literals and retire the old lead sentence.** The check requires the coverage sentence, the override sentence, and the forbidden-outlet sentence (R12). The old lead sentence's fragment, "Apply every finding that `ce-code-review` and `ce-simplify-code` report", joins `supersededDirectives`, so the narrower two-skill rule cannot return beside its replacement.

### Assumptions

- The shared section is plain text without template actions, so gomplate renders it identically for every harness. The check's `{{`/`}}` scan confirms this.

### Sequencing

U1 changes the template and U2 changes the check's literals. They land in one commit range because the current check fails against the rewritten template until U2 updates its literals.

---

## Implementation Units

### U1. Rewrite the review-findings section

- **Goal:** Render the overriding rule into every harness's instruction file.
- **Requirements:** R1–R11 (Key Decisions govern them; KTD1–KTD4).
- **Dependencies:** none.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. Replace the body of `# Review findings`; leave every other section untouched.
  2. Open with a coverage sentence that names `ce-code-review` (with its cross-model pass), `ce-simplify-code`, and `ce-doc-review` and says every finding at every severity is applied (R1), then a separate override sentence saying this rule overrides the skills' own apply bars, deferral steps, and review prompts (R5).
  3. Follow with short bullets, one concern each:
     - what counts as a finding, naming each bucket from R2;
     - how testing gaps, residual risks, and advisory items are resolved, and the nothing-to-change exception (R3);
     - verifying `unresolved` and validation-degraded findings yourself (R4);
     - the named skill rules this overrides (R5);
     - the forbidden outlets in one sentence (R6), and that reporting applied work and decisions made is allowed (R7);
     - the wrong-or-boundary exception with the report requirement (R8);
     - interactive vs autonomous handling of decision-needing findings (R9), and the stop for a fix that reverses a user decision (R10);
     - the standalone-review apply-all question, asked after the skill returns its report, and the in-flow rule for planning, work, and shipping flows (R11).
  4. Match the voice of the surrounding sections: imperative, second person, short bullets, no headings below `#`.
- **Patterns to follow:** The `# Cross-model delegation` section's bullet style, and the current `# Review findings` section's wording where it still fits.
- **Test scenarios:** Covered by U2.
- **Verification:** Each harness's rendered file contains the section once, separated from its neighbors by blank lines, with no harness tool name.

### U2. Guard the new rule in the render check

- **Goal:** Make the check fail when the coverage, override, or outlet sentence is missing, or when the old two-skill lead sentence returns.
- **Requirements:** R12 (KTD5).
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Replace the two `reviewFindingsSentences` literals with the three sentences R12 names, copied verbatim from the template: the coverage sentence (R1), the override sentence (R5), and the forbidden-outlet sentence (R6).
  2. Add the old lead-sentence fragment to `supersededDirectives`.
  3. Update the header comment's bullet on the review-findings rule to describe what the check now guards.
- **Execution note:** Read `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` and `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md` before the mutation runs.
- **Patterns to follow:** The existing `requireSentences` and `supersededDirectives` blocks in the same file.
- **Test scenarios:**
  - Happy path: with U1 and U2 applied, `checks.x86_64-linux.agent-instructions` builds.
  - Mutation: deleting the coverage sentence from the template fails the check for all three harnesses.
  - Mutation: deleting the override sentence fails the check.
  - Mutation: deleting the forbidden-outlet sentence fails the check.
  - Mutation: adding the old lead sentence back to the template, alongside the new section, fails the check as a superseded directive.
- **Verification:** The check passes on the branch and fails under each mutation, run in a scratch copy as the execution note requires.

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

- R1–R12 hold: the rendered files carry the rewritten section, and the render check guards it.
- Every U2 mutation turns the check red, and the unmutated branch is green.
- `nix fmt -- --ci`, `nix flake check`, and the host-output builds succeed.
- No abandoned-attempt text remains in the template or the check.
