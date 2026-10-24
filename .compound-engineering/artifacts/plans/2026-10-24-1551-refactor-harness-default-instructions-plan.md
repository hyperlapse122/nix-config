---
title: Restore harness defaults in shared agent instructions - Plan
type: refactor
date: 2026-10-24
topic: harness-default-instructions
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Restore harness defaults in shared agent instructions - Plan

## Goal Capsule

- **Objective:** Let each coding harness use its default orchestration behavior while preserving the user's personal working policies.
- **Means:** Simplify the shared instructions and audit the tests that enforce them.
- **Product authority:** The user selected targeted removal over a broader reduction of personal workflow policies, then confirmed the scope below.
- **Open blockers:** None.

---

## Product Contract

### Summary

Remove custom orchestration, model routing, T3 Code guidance, and manual Pi-over-ACP instructions from the shared agent instructions.
Edit the remaining policies for clarity without changing their meaning, and align related tests and documentation with the resulting contract.

### Key Decisions

- **Targeted removal, not a policy reset.** Governs R1, R2, R3. (session-settled: user-directed — chosen over also removing PR babysitting and skill-driven policies: the user selected the first scope option.)
- **Include the ACP appendix and related proof.** Governs R4, R5, R6, R7. (session-settled: user-approved — chosen over editing only the named template: the user confirmed a scope that includes the separate ACP instructions, related tests, and documentation.)

### Requirements

**Instruction behavior**

- R1. Shared instructions must no longer prescribe delegation, worker or reviewer models, model-family selection, subagent lifecycle, or manual ACP execution.
- R2. Shared instructions must contain no T3 Code-specific directions or exceptions, including those embedded in otherwise retained policies.
- R3. Preserve the meaning of the remaining GPG, general Git and PR, Markdown, Korean-writing, testing, and review-finding policies while simplifying their wording.
- R4. Every supported harness must receive the retained shared policies without the Pi-over-ACP appendix.

**Proof and documentation**

- R5. Audit instruction-related tests with `test-audit`, removing obsolete orchestration contracts and consolidating duplicate or implementation-coupled proof only after identifying the behavior and remaining proof for each candidate.
- R6. Preserve independent verification of instruction delivery, template rendering, host-specific GPG recipients, and the retained policies; rewording alone must not require preserving obsolete prose.
- R7. Update current documentation that describes the affected instruction contract so it agrees with R1 through R6.

### Scope Boundaries

- The work concerns shared instruction content, its assembly and delivery, directly related tests, and current explanatory documentation.
- T3 Code and Pi installation, application settings, model catalogs, provider configuration, and ACP tooling remain outside scope.
- The broader personal-policy reduction offered during the discussion is excluded by R3; this includes removing PR babysitting, required skills, or the review-findings policy.
- Audit only tests related to the instruction change, not the repository's entire test suite.
- Historical plans and captured learnings are not rewritten merely because they describe the former behavior.
- No replacement orchestration policy, new default model selection, or harness-specific routing layer is introduced.

### Acceptance Examples

- AE1. **Covers R1, R2, R4.** An installed harness reads the generated instructions and finds the retained personal policies, with no custom worker selection, delegated-task lifecycle, T3 Code exception, or Pi-over-ACP appendix.
- AE2. **Covers R2, R3.** Removing T3-specific Git and PR clauses leaves coherent general branch and signed-rebase policies, rather than dangling references to deleted rules.
- AE3. **Covers R3, R6.** A clarity edit changes a retained sentence's wording without changing its policy; the test suite does not reject it solely for differing from an obsolete sentence inventory.
- AE4. **Covers R5, R6.** A missing delivered instruction file, an incorrectly rendered template, or a host receiving the wrong GPG recipient still fails the relevant independent check after the audit.
- AE5. **Covers R5.** A test exists only to pin a removed model-routing rule; both that test and any support code used only by that obsolete contract are removed.
- AE6. **Covers R7.** A reader of the current provisioning guide sees the simplified instruction contract and is not told that shared instructions still route workers or append a manual ACP recipe.

### Sources

- `home/h82/agents/instructions/instructions.md.tmpl`: shared policies and custom orchestration sections.
- `home/h82/agents/instructions/acp.md.tmpl`: manual Pi-over-ACP appendix.
- `home/h82/agents/instructions/default.nix`: template rendering and instruction delivery to Pi, Claude Code, Codex, and Antigravity.
- `tests/agent-instructions.nix`: delivery and rendering checks, policy assertions, and orchestration-specific proof to audit.
- `tests/claude-effort-absent.nix`: adjacent checks that also refer to instruction-level worker assignments.
- `docs/provisioning.md`: current explanation of instruction assembly, routing, and related checks.
- `test-audit`: audit authority supplied by the user; implementation must collect candidate evidence before deleting tests.

---

## Planning Contract

### Problem Frame

The shared prompt currently couples personal policies to model and orchestration choices, and the instruction check duplicates those choices as exact sentences.
Removing only headings would leave T3-specific exceptions, delegated-review clauses, and the separately appended ACP recipe active.

### Key Technical Decisions

- KTD1. Use one rendered shared body for all four existing delivery paths, removing the ACP-only assembly and template. Implements R1, R2, R4.
- KTD2. Remove orchestration-only clauses from retained sections and rewrite the remaining prose without adding new policy. Implements R2, R3.
- KTD3. Audit the existing instruction check by contract: retain materialized delivery, independent rendering, recipient variation, and retained policy proof; remove obsolete model/section inventories and their mutation cases. Implements R5, R6.
- KTD4. Remove obsolete instruction exemptions from the Claude-effort check while preserving its settings, environment, retirement, and application-selection contracts. Implements R5, R6.
- KTD5. Update current provisioning and vocabulary descriptions, plus affected active repository guidance; leave historical artifacts intact unless the pre-push learning-refresh rule requires a targeted refresh. Implements R7.

### Evidence and Constraints

`home/h82/agents/instructions/default.nix` already separates rendering from delivery, so a single shared source can preserve the current destinations.
`tests/agent-instructions.nix` combines materialized-file checks with sentence inventories and mutation tests; deleting it wholesale would lose independent delivery and recipient proof.
The audit follows `test-audit` and the repository's check-proof guidance, especially `nix-check-reads-option-value-not-materialized-output.md`, `substring-sentence-check-passes-a-negated-instruction.md`, and `verify-linux-only-nix-check-inputs-on-macos-through-derivation-show.md` under `.compound-engineering/artifacts/solutions/best-practices/`.
Instruction text is itself consumed behavior: preserve exact bytes only when they form an intentional independent contract, not merely because the old check copies them.

---

## Implementation Units

### U1. Simplify the instruction contract and its proof

- **Goal:** Implement R1 through R6 using KTD1 through KTD4 as one cohesive change.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `home/h82/agents/instructions/acp.md.tmpl`, `home/h82/agents/instructions/default.nix`, `tests/agent-instructions.nix`, `tests/agent-instructions.py`, `tests/claude-effort-absent.nix`, and directly affected test support or registrations.
- **Approach:** Inventory the full tests and callers before deletion, map retained contracts to their primary proof, then remove obsolete content and update the remaining checks together.
- **Test scenarios:** All delivery targets remain materialized; host keys differ correctly; missing or redirected delivery and wrong keys fail; retained policy limits survive; removed orchestration cannot remain in another appended file.
- **Execution note:** Capture the baseline where the environment permits, then use focused negative controls for retained guards; report platform limitations separately from passing evidence.
- **Dependencies:** None.

### U2. Align current documentation

- **Goal:** Implement R7 using KTD5 after U1 fixes the final contract.
- **Files:** `docs/provisioning.md`, `CONCEPTS.md`, `AGENTS.md` where its repository overview describes the shared instructions, and directly affected current documentation.
- **Approach:** Replace obsolete routing explanations with the actual shared-content and delivery contract; preserve unrelated T3 and Pi setup documentation.
- **Test scenarios:** Current explanations name the actual destinations and do not claim the removed appendix or routing rules still apply.
- **Dependencies:** U1.

---

## Verification Contract

- Run focused instruction and Claude-effort checks plus the renderer's existing tests; verify negative controls reach the intended retained guards.
- Run `nix fmt -- --ci`, Markdown lint for changed documents, and `git diff --check`.
- Run `nix flake check`, enumerate and build production/bootstrap outputs, and run VM checks on compatible builders per `AGENTS.md`; report unavailable architectures explicitly and use CI where required.
- Review the complete change with `ce-simplify-code` and `ce-code-review`, applying all valid findings before shipping.
- Before pushing, refresh learnings that cite deleted or renamed paths as the repository requires.

## Definition of Done

R1 through R7 and their acceptance examples hold, retained checks have meaningful evidence, current documentation matches the result, and all available required checks pass.
The change is committed and pushed as a pull request, with CI decided and any platform limitation reported; merging remains the user's action.
