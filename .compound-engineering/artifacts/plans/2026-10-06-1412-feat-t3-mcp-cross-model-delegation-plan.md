---
title: T3 MCP Cross-Model Delegation in Agent Instructions - Plan
type: feat
date: 2026-10-06
topic: t3-mcp-cross-model-delegation
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# T3 MCP Cross-Model Delegation in Agent Instructions - Plan

## Goal Capsule

- **Objective:** When a coding agent running inside T3 Code needs work from a different model, it reaches that model through T3's own orchestration rather than through whatever harness discovery a skill prescribes, and the delegated work comes back verified.
- **Means:** One shared, harness-neutral delegation section in the agent instructions template (KTD1), pinned by literal-sentence assertions in the existing `agent-instructions` check (KTD3).
- **Authority:** This plan's R-IDs govern behavior and its KTDs govern mechanism. `AGENTS.md` governs repository conventions and verification. Skills are not edited.
- **Open blockers:** None.
- **Stop conditions:** Stop if the section cannot be worded without naming another harness's native tool from the check's absent lists, or without mentioning Orca, which the check forbids.
- **Execution profile:** Lightweight. One template edit and one check edit, verified by building the check, mutation-testing each new assertion, and the repository's ship checks.
- **Finishing:** The implementer lands and verifies the change; the user sees the rendered instructions after their own `nr switch`.
- **Product Contract preservation:** changed: R15 and AE7 added, with their Key Decision — the user added concurrent cross-model review during planning.

## Product Contract

### Summary

Add one harness-neutral section to the shared agent instructions that tells an agent how to delegate to another model when the T3 Code MCP server is present. It takes precedence over a skill's own way of finding and launching other harnesses, runs delegated work with full access, and falls back to another T3 provider before falling back to the skill's method.

### Problem Frame

Skills such as `ce-code-review` and `ce-doc-review` reach another model by attesting the host harness from environment variables and launching an installed CLI (`codex`, `claude`, `grok`, `cursor-agent`) through a fixed-route script. Inside T3 Code that path ignores what T3 already knows: which providers and models are runnable right now, and how to start, track, and cancel a child run. A session on 2026-10-06 showed the T3 path working end to end for Codex and, after a wrapper fix, Antigravity. It also showed the operating habits it needs: the child sees no parent history, a hung provider produces no output rather than an error, and the parent has to verify what comes back. The current instructions only say to hand parallel work to the harness's native subagent tool and say nothing about T3.

### Key Decisions

- **Delegate through T3 only when a different model is needed.** Same-provider parallel work keeps using the native subagent tool. Governs R1, R2. (session-settled: user-directed — chosen over routing every delegation through T3 and over replacing only skill-defined delegation: T3's own guidance already prefers native tools for same-provider work)
- **T3 discovery overrides skill harness discovery.** The instructions act as the "preference already in your project instructions" that the skills' peer resolution consults, and they replace CLI detection with T3's capability listing. Governs R3, R4. (session-settled: user-directed — chosen over leaving skills' CLI discovery in charge: the user asked to override how skills find other harnesses)
- **Skills stay unedited; agents bridge the gap.** Skill-specific contracts that assume their own route, such as identity receipts that mark a peer as independently verified, are left to the agent's judgment. Governs R4. (session-settled: user-approved — chosen over editing skills to call T3: the user scoped skills out and accepted outcomes that depend on agent capability)
- **The agent picks provider, model, and effort.** No fixed order or pinned model in the instructions. Governs R5. (session-settled: user-directed — chosen over a fixed provider order and over pinned per-harness models: pinned models go stale as T3's catalog changes)
- **Always full access.** Delegated runs never wait on approval prompts the parent cannot see. Governs R7, R8. (session-settled: user-directed — chosen over delegating read-only work only and over sending write work to a separate worktree: the parent splits work so children do not collide)
- **Fallback goes to another T3 provider first, then to the skill's method.** Governs R11, R12. (session-settled: user-directed — chosen over falling back straight to the skill's method and over stopping to report)
- **Hang detection is the agent's judgment, without a fixed timeout.** Governs R11. (session-settled: user-approved — chosen over a fixed timeout: provider latency varies and a stalled child shows no progress in its thread)
- **Run a skill's cross-model review concurrently, only when the skill turns it on.** The section does not add a cross-model review to reviews whose skill would not run one. Governs R15. (session-settled: user-directed — chosen over adding a T3 cross-model review to every review and over also applying it to the in-progress plan review: the skill's own activation rule stays the trigger)
- **No process cleanup instructions.** `task_cancel` can leave a provider process running; that is a T3 defect and agents are not told to kill processes. (session-settled: user-approved — chosen over instructing agents to find and kill leftover provider processes: broad process kills are risky)

### Requirements

**When the section applies**

- R1. The section applies only when the T3 Code MCP tools are actually available in the session; sessions without them, such as plain CLI or Orca sessions, behave as today.
- R2. The section governs work that needs a provider other than the agent's own, or a model the native subagent tool cannot serve; other parallel work keeps the native subagent tool guidance.

**Precedence over skills**

- R3. When a skill would discover or launch another harness for cross-model work, the agent uses T3 delegation instead, before any of the skill's own discovery or launch steps.
- R4. The agent still carries out the rest of the skill's procedure with the delegated result, adapting where the skill assumes its own route.

**Choosing and launching**

- R5. Before delegating, the agent lists T3's runnable providers and models and picks a provider other than its own, a model, and options suited to the task.
- R6. The agent tells the user which provider and model it delegated to.
- R7. Every delegated run uses full-access runtime mode.
- R8. When delegated work must not change files, such as a review, the agent says so explicitly in the child's task prompt.
- R9. The child's task prompt is self-contained: it carries every piece of context, prior findings, and constraints the child needs, since the child receives no parent history.
- R10. Long work is delegated asynchronously, and the agent ends its turn or continues other work instead of polling, reading status only when it needs the result mid-turn.
- R15. When a skill's review procedure turns on its cross-model pass, the agent delegates that pass asynchronously at the same time it dispatches the skill's in-process reviewers, and folds the result in when it arrives instead of starting the pass after them.

**Failure and fallback**

- R11. When a delegated run fails, reports a provider error, or shows no progress, the agent cancels it and retries the same task on another runnable T3 provider.
- R12. Only when no other T3 provider succeeds does the agent fall back to the skill's own cross-model method, and it tells the user that it did.

**Verification**

- R13. The parent verifies a delegated result against the repository or other primary evidence before relying on it or reporting it as fact.

**Coverage**

- R14. The rendered instructions for Claude Code, Codex, and Antigravity all carry the section.

### Acceptance Examples

- AE1. **Covers R1, R2.** Given a Claude Code session inside T3 that needs three parallel codebase searches, when it delegates, then it uses the native `Agent` tool, not T3.
- AE2. **Covers R3, R5, R6, R7.** Given a Claude Code session inside T3 running `ce-code-review` whose cross-model pass would launch the `codex` CLI, when the pass runs, then the agent lists T3 capabilities, delegates the adversarial brief to a Codex model with full access, and names the provider and model to the user.
- AE3. **Covers R11.** Given a delegated Antigravity run that produces no output after its prompt, when the agent judges it stalled, then it cancels the run and delegates the same task to another runnable T3 provider such as Codex.
- AE4. **Covers R12.** Given every runnable T3 provider has failed the task, when the agent falls back, then it uses the skill's own CLI route and says that the T3 attempts failed.
- AE5. **Covers R1.** Given a Codex session launched outside T3 with no T3 tools, when a skill asks for a cross-model peer, then the skill's own discovery runs unchanged.
- AE6. **Covers R8, R13.** Given a delegated review returns findings, when the parent reports them, then the child's prompt had forbidden file changes and the parent has checked each finding against the code.
- AE7. **Covers R15.** Given `ce-code-review` selects its adversarial reviewer, so its cross-model pass applies, when the agent dispatches the in-process reviewers, then it delegates the cross-model pass through T3 in the same step and merges the peer's findings once they return. Given `ce-doc-review` activates none of the personas that trigger its cross-model pass, then no T3 review is added.

### Scope Boundaries

- Editing any skill, including its cross-model scripts, receipts, or config keys, is out of scope.
- Routing same-provider delegation through T3 is out of scope (R2).
- Creating new top-level T3 threads or worktrees for delegated work is out of scope; delegation uses child tasks.
- Fixing the T3 defect where `task_cancel` leaves a provider process running is out of scope; it belongs upstream.
- The Antigravity CA bundle fix in `packages/t3code.nix` is separate work already made on this branch.

### Dependencies / Assumptions

- The T3 tool names differ by harness surface, such as an `mcp__t3-code__` prefix in Claude Code and a `tools.mcp__t3_code__` call in Codex code mode; the section must read correctly for each.
- `tests/agent-instructions.nix` asserts each rendered file holds its own harness's tool names and none of the other harnesses'; any T3 tool names the section adds must be harness-neutral or branch per harness so that check still holds.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` and `home/h82/agents/instructions/default.nix`: one gomplate template rendered to `.claude/CLAUDE.md`, `.gemini/config/AGENTS.md`, and `.codex/AGENTS.md`.
- `tests/agent-instructions.nix`: per-harness present and absent tool-name lists.
- Compound-engineering v3.30.3 `skills/ce-code-review/references/cross-model-review.md` and `skills/ce-doc-review/references/cross-model-review.md`: peer resolution order whose step 3 is "a preference already in your project instructions", then CLI routes in `codex → claude → grok → composer`.
- `.compound-engineering/artifacts/plans/2026-09-29-1355-refactor-remove-orca-orchestration-hooks-plan.md`: agents in Orca delegate through their harness's own subagent tools.
- `packages/t3code.nix`: the `SSL_CERT_FILE` wrapper fix that made T3's Antigravity provider respond.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **One shared section outside the harness branches.** The delegation rules are written once as a new top-level section of `home/h82/agents/instructions/instructions.md.tmpl`, outside the `{{ if eq .harness.id ... }}` branches, so all three rendered files carry identical text (R14). The tool table and its per-harness branches stay unchanged. Governs R1–R15.
- KTD2. **Name T3 tools by their bare MCP tool names.** The section names `orchestrator_capabilities`, `delegate_task`, `task_status`, and `task_cancel` without a harness prefix, and adds one sentence that a harness may expose them under a prefix such as `mcp__t3-code__`. The bare names collide with nothing in the check's per-harness absent lists, and they match how T3's own orchestration guidance names them. The section refers to native subagent tools generically ("the native subagent tool") rather than by name, so it never names another harness's tool. Governs R1, R2, R5.
- KTD3. **Pin the rules with literal sentences in the existing check.** `tests/agent-instructions.nix` gains a `delegationSentences` list asserted present in every harness's rendered file, mirroring `reviewFindingsSentences`. Each pinned sentence states one whole rule, so a mutation that flips a rule's condition or order fails the fixed-string match rather than slipping past clause-by-clause checks. Governs R1, R3, R7, R11, R12, R13, R14, R15.
- KTD4. **Cross-reference from the existing delegation bullet.** The "Hand independent work that can run in parallel to the subagent tool." bullet in the tool-use section gains a pointer to the new section for work that needs a different model, so an agent reading the native-tool guidance first is not left with an unconditional rule. The bullet's existing sentence stays intact. Governs R2.

### Research

- `tests/agent-instructions.nix` asserts, per host and harness, the shared opening sentence, the review-findings and branch-name sentences as fixed strings, each harness's own tool names present and the other two harnesses' tool names absent, no `orca` in any letter case, and no surviving template action. All expected strings are literals in the test, not read from the module.
- `.compound-engineering/artifacts/solutions/best-practices/compound-condition-clause-assertions-miss-connective-mutations.md`: assert a compound rule as one fixed string so swapping its connective fails the check.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`: every new assertion must be shown to fail against a mutation of the template.
- `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`: mutate the template in place and restore it, rather than in a copied checkout.

### Assumptions

- T3's MCP tool names stay `orchestrator_capabilities`, `delegate_task`, `task_status`, and `task_cancel`, as observed in this session's T3 Code 0.0.46 nightly.

---

## Implementation Units

### U1. Add the cross-model delegation section to the instructions template

- **Goal:** Every rendered instruction file tells an agent inside T3 Code when and how to delegate to another model.
- **Requirements:** R1–R15 (Key Decisions governing them carry the session-settled labels); KTD1, KTD2, KTD4.
- **Dependencies:** None.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`; test: `tests/agent-instructions.nix` (U2).
- **Approach:**
  1. Add a new top-level section, placed after the tool-use section and before `# Review findings`, outside every harness branch (KTD1).
  2. Open with the applicability rule: it applies only when the T3 Code MCP tools are available and the work needs a provider other than the agent's own or a model the native subagent tool cannot serve; otherwise the native subagent tool guidance stands (R1, R2). Add that tools the session lists by name count as available even when the harness must load their schemas before the first call, so a deferred tool list does not send the agent to a skill's own discovery.
  3. State the precedence rule: this replaces any skill's own discovery or launch of another harness for cross-model work, and the skill's remaining procedure continues with the delegated result, adapting where it assumes its own route (R3, R4).
  4. State the launch rules: list runnable providers and models with `orchestrator_capabilities`, choose a provider other than the agent's own plus model and options, tell the user the choice, delegate with `delegate_task` in full-access runtime mode, write a self-contained task prompt, say "do not modify files" in the prompt for read-only work such as reviews, and prefer async delegation without polling, using `task_status` only when the result is needed mid-turn (R5–R10; KTD2 for tool naming and the prefix note).
  5. State the failure rule: on failure, a provider error, or no progress, cancel with `task_cancel` and retry on another runnable T3 provider; only when none succeeds, fall back to the skill's own method and tell the user (R11, R12).
  6. State the concurrency rule: when a skill's review procedure turns on its cross-model pass, delegate that pass asynchronously in the same step that dispatches the skill's in-process reviewers, and merge its result when it returns; never add a cross-model pass the skill would not run (R15).
  7. State the verification rule: check a delegated result against the repository or other primary evidence before relying on it (R13).
  8. Append a pointer to the new section on the "Hand independent work…" bullet, leaving that sentence's existing text unchanged (KTD4).
- **Patterns to follow:** The `# Review findings` and `# Branch names` sections: a short lead paragraph, then imperative bullets, one rule per sentence.
- **Execution note:** Keep each rule a single self-contained sentence so U2 can pin it verbatim. Do not mention Orca, and do not name any harness-specific native tool in the shared text.
- **Test scenarios:** Covered by U2; the template has no behavior of its own beyond its rendered text.
- **Verification:** All three rendered files carry the section identically, and the existing `agent-instructions` assertions still pass.

### U2. Assert the delegation rules in the agent-instructions check

- **Goal:** Dropping or weakening the delegation section, or moving it into one harness's branch, turns `nix flake check` red.
- **Requirements:** R1, R3, R7, R11, R12, R13, R14, R15; KTD3.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Add a `delegationSentences` list of literal sentences copied from U1: the applicability rule, the precedence rule, the full-access rule, the fallback-order rule, the concurrency rule, and the verification rule.
  2. Loop over it in `sourcePresent` for every harness, as the review-findings loop does, with a failure message naming the missing rule.
  3. Extend the header comment's "Verifies" list with the new assertion.
- **Patterns to follow:** `reviewFindingsSentences` and its loop in the same file.
- **Execution note:** Mutation-test each pinned sentence in place against the template, then restore it.
- **Test scenarios:**
  - With the template as written, the check passes for every host and harness.
  - Deleting the new section from the template fails the check for all three harnesses.
  - Moving the section inside the `claude-code` branch fails the check for Antigravity and Codex.
  - Changing "full-access" to another runtime mode in the full-access sentence fails the check.
  - Swapping the fallback order so the skill's method comes before another T3 provider fails the check.
  - Removing the "only when" condition from the applicability sentence fails the check.
  - Removing the verification sentence fails the check.
  - Changing the concurrency sentence so the cross-model pass runs after the in-process reviewers fails the check.
- **Verification:** The check passes on the real template and fails on each mutation above, and the template is restored byte-identical afterward (`git diff` shows only the intended changes).

---

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Formatting | `nix fmt -- --ci` | Nix layout unchanged by the edit |
| Targeted check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U1 renders and U2's assertions hold |
| Mutation evidence | Each U2 mutation applied in place, the targeted check rebuilt, then reverted | U2's assertions are not decorative |
| Flake checks | `nix flake check` | No other check regressed |
| Host outputs | Every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output built per `AGENTS.md` | Rendered instructions still build into each host generation |

NixOS VM tests are not affected by an instructions-only change; build them only if `nix flake check` or a host build points at them.

## Definition of Done

- U1 and U2 are landed, and the three rendered instruction files carry the identical delegation section.
- Every Verification Contract gate passes, and each U2 mutation was observed to fail before being reverted.
- No skill file under the agent-plugins tree was edited.
- No experimental or abandoned edits remain in the diff.
