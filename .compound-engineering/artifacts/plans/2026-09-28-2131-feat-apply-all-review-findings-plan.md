---
title: Apply All Review Findings Instruction - Plan
type: feat
date: 2026-09-28
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Apply All Review Findings Instruction - Plan

## Goal Capsule

- **Objective:** Coding agents on this machine fix every finding that `ce-code-review` and `ce-simplify-code` report, including P2, P3, and lower, instead of deferring the low-severity ones to residual lists, tickets, or PR notes.
- **Means:** A new shared section in the global agent instructions template, guarded by the existing render check (KTD1, KTD2).
- **Authority:** This plan's Requirements, then KTDs, then units.
- **Stop conditions:** Stop if the template cannot render the new section for both harnesses, or if the check cannot be made to fail when the section is removed.
- **Execution profile:** Lightweight; two small units in one PR.

## Product Contract

### Summary

Add a `# Review findings` section to `home/h82/agents/instructions/instructions.md.tmpl`, outside the per-harness tool branch, telling agents to apply all findings from `ce-code-review` and `ce-simplify-code` at every severity. Extend `tests/agent-instructions.nix` so each harness's rendered file must carry that rule.

### Problem Frame

The Compound Engineering review skills apply P0 and P1 findings and routinely leave P2, P3, and lower findings as residuals for later. The user wants every finding applied in the same run. The repository's own `AGENTS.md` already says "Always apply all review findings", but that only reaches agents working in this repository. The global instruction file is what every harness loads in every workspace.

### Requirements

- R1. The rendered global instructions for every harness tell agents to apply every `ce-code-review` and `ce-simplify-code` finding, naming P2, P3, and lower severities explicitly, and not to defer them.
- R2. The rule names the deferral outlets it forbids: residual lists, follow-up tickets, and PR-body notes.
- R3. The rule keeps one narrow exception: a finding verified to be wrong, or impossible to apply, stays unapplied, and the agent reports which and why.
- R4. The render check fails when the rule is missing from either harness's rendered file.

### Key Decisions

- **Apply findings at every severity, not only P0/P1.** (session-settled: user-directed — chosen over the skills' default of applying P0/P1 and deferring the rest: the user explicitly asked that no findings be deferred.) Governs R1, R2.
- **The rule lives in the global template, not only in repository `AGENTS.md`.** (session-settled: user-directed — chosen over adding it to repository `AGENTS.md` only: the user named the template file.) Governs R1.

### Scope Boundaries

- Harness-specific tool tables stay unchanged.
- The repository `AGENTS.md` rule stays as it is; it already matches this intent.
- Changing the Compound Engineering skills themselves is out of scope.

## Planning Contract

### Key Technical Decisions

- KTD1. **Place the section after the harness branch's `{{- end }}`, as shared text.** Both harnesses run the same review skills, so the rule belongs outside the `.harness.id` branch. Refer to the skills by bare name (`ce-code-review`, `ce-simplify-code`) rather than a Claude Code slash form, since Antigravity invokes them differently.
- KTD2. **Guard the rule with a literal sentence in `tests/agent-instructions.nix`.** The check already greps each rendered file for a shared literal sentence; add a second literal (the rule's lead sentence) to every harness entry, so deleting or rewording the rule turns the check red. This follows `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`.

### Assumptions

- The exception in R3 (wrong or impossible findings) matches what the user means by "do not defer"; a false positive is rejected with reasons rather than deferred.
- A trailing section after `{{- end }}` renders with correct blank-line spacing; the implementer adjusts the whitespace trim markers if the rendered output runs sections together.

## Implementation Units

### U1. Add the review-findings rule to the global template

- **Goal:** Render the rule into every harness's instruction file.
- **Requirements:** R1, R2, R3 (KTD1).
- **Dependencies:** none.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. Append a `# Review findings` heading after the harness branch.
  2. Lead with one sentence stating the rule for `ce-code-review` and `ce-simplify-code` at every severity, naming P2 and P3.
  3. Follow with short bullets:
     - Fix low-severity findings on the branch like high-severity ones, and verify each fix.
     - Do not move findings to residual lists, tickets, or PR-body notes.
     - When a fix needs a decision only the user can make, ask with the question tool instead of deferring (R3).
     - Reject only a finding verified wrong or impossible, and report which and why.
  4. Keep harness tool names in backticks out of the shared section; `tests/agent-instructions.nix` fails a harness whose file names another harness's backticked tool.
- **Patterns to follow:** The existing `# Tool use` section's voice: imperative, short bullets, no filler.
- **Test scenarios:** Covered by U2.
- **Verification:** Both rendered files contain the section once, with a blank line separating it from the preceding tool list.

### U2. Assert the rule in the render check

- **Goal:** Make the check fail when the rule is missing.
- **Requirements:** R4 (KTD2).
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:** Add the rule's lead sentence as a literal shared by both harness entries, grep for it in each rendered file, and update the header comment's list of verified properties.
- **Test scenarios:**
  - Happy path: with U1 applied, `nix build .#checks.x86_64-linux.agent-instructions` succeeds.
  - Mutation: deleting the rule's lead sentence from the template makes the check fail for both Claude Code and Antigravity.
- **Verification:** The check passes on the branch and fails under the mutation, run in a scratch copy per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| Render check | `nix build .#checks.x86_64-linux.agent-instructions` |
| All checks | `nix flake check` |
| Every host output | build each `nixosConfigurations.<name>.config.system.build.toplevel`, as `AGENTS.md` lists |

## Definition of Done

- R1 through R4 hold, shown by the render check and the mutation run.
- `nix flake check` and every `nixosConfigurations` output build.
- No abandoned-attempt code remains in the diff.
