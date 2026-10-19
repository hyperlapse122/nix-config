---
title: T3 Code No Native Subagents - Plan
type: feat
date: 2026-10-19
topic: t3-code-no-native-subagents
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# T3 Code No Native Subagents - Plan

## Goal Capsule

- **Objective:** In a T3 Code session whose harness loads the shared instructions, every subagent an agent starts, including the ones a skill dispatches internally, shows up as a T3 Code delegated task the user can see and manage, and none runs through the harness's own subagent tool.
- **Means:** Replace the first rule of the `# T3 Code` section in the shared agent instructions template with a prohibition plus model, context, nesting, and failure rules, and pin the new sentences in `tests/agent-instructions.nix` (KTD1-KTD5).
- **Product authority:** The settled decisions from the 2026-10-19 `ce-brainstorm` dialogue; the Product Contract below wins over the Planning Contract on any conflict.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when the change would need to weaken or drop an existing pinned sentence or check, or to change an implementation-unit or cross-model peer rule.
- **Execution profile:** One instructions-and-check change plus docs and glossary updates, implemented by `ce-work` and shipped through `lfg`.

## Product Contract

### Summary

The `# T3 Code` section stops offering the harness's own subagent tool as an option whenever T3 Code's delegation tools are listed. Every subagent goes through `delegate_task`, including scouts, verifiers, reviewers, and workers a skill dispatches. A subagent that no other rule assigns a model runs on the session's own provider instance, at the model that fits the skill's tier or at the session's own model. Delegation stays one level deep, and a launch that keeps failing turns into inline work, never native work. When T3 Code's tools are missing, the harness's own subagent tool stays the route.

### Problem Frame

The section's first rule reads "delegate subagent work through them; otherwise use your native subagent tool". It names no prohibition, and T3 Code's own guidance tells agents to prefer native subagent tools for same-provider work. Agents in T3 Code sessions therefore still start Claude Code `Agent` scouts, Explore searches, forks, and skill-internal reviewers natively. That work never appears as a T3 Code child task, so the user cannot see it, answer its approvals, or cancel it from T3 Code, and its model is whatever the native tool picks.

### Requirements

**Instruction content**

- R1. When the session lists T3 Code's delegation tools, the instructions tell the agent to launch every subagent through `delegate_task`, naming the subagents a skill dispatches internally, and never to use the harness's own subagent or multi-agent tools.
- R2. The rule states that it holds even where T3 Code's own guidance prefers native tools for same-provider work.
- R3. A subagent that no skill or rule assigns a model runs on the session's own provider instance, with the listed model the agent judges to fit the tier the skill names, or with the session's own model when the skill names no tier or no listed model fits it. When the chosen model is not the session's own and takes an effort, the agent sets the effort `orchestrator_capabilities` marks as that model's default. Implementation units and cross-model peers keep their existing rules.
- R4. The instructions tell the agent that a delegated subagent sees none of the conversation and none of the tool limits its native agent type had, so its task prompt carries everything it needs, including that it stays read-only when it only searches, reads, or reviews.
- R10. The instructions tell the agent to have each delegated subagent launch no subagents of its own, so delegation stays one level deep, as the native depth limit kept it.
- R5. When a `delegate_task` launch fails and one relaunch with the same `clientRequestId` fails too, the agent does that work itself, never through its harness's own subagent tool, and edits no file a running task in the same checkout is editing. Cross-model peers and implementation units keep their own failure rules.
- R6. When the session lists no T3 Code delegation tools, the agent uses its harness's own subagent tool, as today.
- R7. Every sentence stays harness-neutral, because the template renders for Claude Code, OpenCode, Grok Build, and Antigravity.

**Check and docs**

- R8. `agent-instructions` pins each new sentence in section order and drops the replaced one, so removing, negating, reordering, or contradicting a new rule fails the build.
- R9. `docs/provisioning.md` and `CONCEPTS.md` describe the new routing for sessions that load the shared instructions, and keep T3 Code's Antigravity instance as the exception that loads none.

### Scope Boundaries

- T3 Code's Antigravity instance reads no instructions file (`docs/provisioning.md`, delivery table), so this rule does not reach it; its sessions keep following T3 Code's own guidance.
- Read-only subagents keep sharing the checkout; the section's existing worktree rules for tasks that edit files stay as they are.
- Outside T3 Code nothing changes.
- Considered and not built: blocking native subagent tools through harness settings, such as a Claude Code `permissions.deny` entry or a T3 Code wrapper flag. The request asks for an instruction, and a settings block would also stop native subagents in terminal sessions, which R6 keeps.

### Risks

- The rule is enforced only by instruction, so a skill whose own text names a native subagent tool can still pull an agent toward it. The rule names skill-internal dispatch explicitly (R1) and overrides T3 Code's own guidance (R2); the pinned sentences keep both present on every host that loads them. A native subagent that still slips through is visible in the session transcript.
- Losing the native fork costs inherited context, and a large diff or conversation must now fit in a task prompt. R4 makes the prompt carry it.
- Every scout is now a delegated task, so with a person present the parent ends its turn and waits for a notification where a native scout returned in-turn. This is the cost of making the work visible, and the existing batching rule keeps independent scouts in one wait.
- Inline work after a failed launch (R5) runs in the parent's own context, so a review done that way is not independent of the parent's reasoning. The agent reports that it ran inline, through the report the skill already makes on a missing reviewer.

### Sources

- Settled decisions from the 2026-10-19 `ce-brainstorm` dialogue (KTD1, KTD2). That brainstorm ended in chat and wrote no requirements artifact, so this plan is a direct plan (`ce-plan-bootstrap`) that carries the brainstorm's decisions as session-settled entries.
- `.compound-engineering/artifacts/plans/2026-10-17-1350-feat-delegate-via-t3-code-plan.md`: an earlier change of the same intent whose wording the 2026-10-18 slimming refactor reduced to the current first rule.
- `home/h82/agents/claude.nix`: `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "1"`, the native depth limit R10 carries over.
- `docs/provisioning.md`: `delegate_task` inherits the parent's model options, such as effort, unless the launch sets them (R3).
- `.compound-engineering/artifacts/solutions/integration-issues/t3-thread-wait-cannot-carry-in-turn-delegation-waits-alone.md`: the waiting rules in the same section, which this change leaves as they are.
- `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`, `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`, and `.compound-engineering/artifacts/solutions/best-practices/verify-linux-only-nix-check-inputs-on-macos-through-derivation-show.md`: how the pins work and how to prove them from this Mac.

## Planning Contract

### Key Technical Decisions

- KTD1. **Prohibit every native subagent and multi-agent tool, skill-internal dispatch included.** Governs R1, R2. (session-settled: user-directed — chosen over forbidding only subagents the agent launches directly and over doing light searches inline instead of delegating: the user wants all delegated work to go through T3 Code)
- KTD2. **Model for a subagent with no assigned model: the session's own provider instance, at the skill's tier, otherwise at the session's own model.** Governs R3. `orchestrator_capabilities` lists each instance's models and their default effort but no tier, so the agent judges the tier fit from the listed models and falls back to the session's own model when none fits. (session-settled: user-directed — chosen over always using the session's own model and over a fixed `claudeAgent` Haiku, Sonnet, and Opus mapping: closest to what the native tools did, and keeps the skills' tiering)
- KTD3. **Sentence placement.** The prohibition replaces the current first sentence, and the outside-T3 fallback (R6) follows it, so the existing "The delegation rules that follow apply only when the session lists those tools." still scopes everything after it. The model, context, nesting, and failure sentences (R3, R4, R10, R5) come right after that scoping sentence, before the batching rules.
- KTD4. **Wording constraints.** Pinned sentences contain no full stop followed by a space, because `sectionSentences` splits there. They say "your harness's own subagent tool" and name no harness's tool, and avoid the check's `removedTerms`, such as "another harness".
- KTD5. **Carry the native depth limit as an instruction to the child.** A delegated child is itself a T3 Code session that renders the same rules, so without R10 each child would delegate its own scouts and reviewers with no depth bound. Telling the child in its prompt is the mechanism the peer rule already uses ("and delegate nothing").

### Recommended wording

The implementer may adjust the wording, provided the sentences still satisfy R1-R7, R10, and KTD4:

```text
- When the session lists T3 Code's delegation tools, such as `delegate_task`, launch every subagent through `delegate_task`, including the scouts, verifiers, reviewers, and workers a skill dispatches, and never use your harness's own subagent or multi-agent tools, even where T3 Code's own guidance prefers them for same-provider work.
- When the session lists no T3 Code delegation tools, use your harness's own subagent tool.
- The delegation rules that follow apply only when the session lists those tools.
- When no skill or rule names a model for a subagent, launch it on your own provider instance with the model from that instance's list in `orchestrator_capabilities` that you judge fits the tier the skill names, or with your own model when the skill names no tier or no listed model fits it; when that model is not your own, set its `effort` to the value `orchestrator_capabilities` marks as its default.
- A delegated subagent sees none of your conversation and none of the tool limits its native agent type had, so put everything it needs in its task prompt, including that it stays read-only when it only searches, reads, or reviews.
- Tell each delegated subagent to launch no subagents of its own, so delegation stays one level deep.
- When a `delegate_task` launch fails and one relaunch with the same `clientRequestId` fails too, do that work yourself instead of using your harness's own subagent tool, and edit no file a running task in this checkout is editing; cross-model peers and implementation units keep their own failure rules.
```

### Assumptions

This plan ran inside `lfg` without a scoping confirmation. These were shown to the user in the brainstorm synthesis without objection and are not session-settled:

- A subagent that cannot be delegated is done inline, never natively (R5).
- The rule states that it overrides T3 Code's guidance to prefer native tools for same-provider work (R2).
- Read-only subagents share the checkout; outside T3 Code nothing changes (Scope Boundaries, R6).

Added by document review, not shown to the user before: the one-level nesting rule (R10, KTD5), the read-only line in the context rule (R4), the effort setting (R3), and the single relaunch before inline work (R5).

## Implementation Units

### U1. Replace the first T3 Code rule and pin the new sentences

- **Goal:** The template carries the prohibition and its companion rules, and the check pins them.
- **Requirements:** R1-R8, R10; KTD1-KTD5
- **Dependencies:** None
- **Files:**
  - `home/h82/agents/instructions/instructions.md.tmpl`
  - `tests/agent-instructions.nix`
- **Approach:**
  1. Replace the first bullet of `# T3 Code` with the prohibition and the outside-T3 fallback, then insert the model, context, nesting, and failure bullets after "The delegation rules that follow apply only when the session lists those tools." (KTD3).
  2. Mirror the same sentences, in the same order, in `t3CodeSentences`, dropping the replaced sentence.
  3. Leave the header comment as it is unless it quotes the replaced sentence.
- **Patterns to follow:** The existing `t3CodeSentences` list; the Nix string escaping its neighbours use for backticks and quotes.
- **Execution note:** Prove each assertion by mutation, in a scratch copy that follows the copied-worktree learning in `AGENTS.md`, rather than trusting a green build. On this Mac, run the check's builder script, taken from `nix derivation show .#checks.x86_64-linux.agent-instructions`, against the rendering the macOS host builds, once for the unmutated tree and once per mutation.
- **Test scenarios:**
  - The unmodified template passes every sentence assertion of `agent-instructions`.
  - Restoring the old first sentence ("…otherwise use your native subagent tool.") fails, both as a missing pinned sentence and as an unpinned sentence in `# T3 Code`.
  - Deleting the prohibition sentence fails and names it.
  - Deleting the nesting sentence fails and names it.
  - Prefixing the model sentence with "Do not" fails, because it no longer starts where a sentence starts.
  - Adding an unpinned sentence such as `You may use your harness's own subagent tool for quick searches.` under `# T3 Code` fails.
  - Swapping the context and nesting sentences fails the order check.
- **Verification:** The check's assertions pass on the real template, each mutation above turns them red with a message naming the broken rule, and CI's `check-shards` build of `checks.x86_64-linux.agent-instructions` is green.

### U2. Describe the routing in the provisioning guide and the glossary

- **Goal:** The guide and the glossary say that, in a T3 Code session that loads the shared instructions, subagents go only through T3 Code, and that T3 Code's Antigravity instance is the exception.
- **Requirements:** R9
- **Dependencies:** U1
- **Files:**
  - `docs/provisioning.md`
  - `CONCEPTS.md`
- **Approach:**
  1. In the `### Shared agent instructions` paragraph of `docs/provisioning.md`, extend the T3 Code section's description: with T3 Code's delegation tools listed, every subagent goes through `delegate_task`, one level deep, and never through the harness's own subagent tool. Leave the existing statement that T3 Code's Antigravity instance loads no instructions file as it is.
  2. In `CONCEPTS.md`, add one sentence to the **Delegated task** entry: when the orchestrating app's delegation tools are available and the session loads the shared instructions, every subagent the session agent starts is a delegated task, and the agent's native subagent tool is used only when those tools are missing.
  3. In the **Cross-model delegation** entry, replace the contrast with "parallel work handed to the session agent's own subagents" so it no longer implies that same-provider subagents run natively inside the app; the entry's distinction becomes cross-model work versus same-model delegated tasks.
- **Test expectation:** none -- docs and glossary sentences; `markdownlint-cli2` through the pre-commit hook covers their form.
- **Verification:** Both documents describe the same routing as the template, name the Antigravity exception, and the **Cross-model delegation** and **Delegated task** entries no longer contradict each other.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Sentence assertions, local | The `agent-instructions` builder script from `nix derivation show`, run against the macOS host's rendering (U1) | R1-R8, R10, and every U1 mutation |
| Sentence assertions, CI | `checks.x86_64-linux.agent-instructions` in CI's `check-shards` | R1-R8, R10 on every configuration |
| Flake evaluation | `nix flake check --no-build` | Every check and output still evaluates |
| Formatting | `nix fmt -- --ci` | Nix layout |
| macOS outputs | `nix build --no-link` of every `darwinConfigurations.<host>.system` and `.#checks.aarch64-darwin.darwin-outputs` | The macOS host builds with the new instructions |
| Linux outputs | CI's `vm-checks`, `check-shards`, and host build jobs | Every Linux output still builds |
| Markdown lint | `.githooks/pre-commit` on commit | The plan and both docs pass `markdownlint-cli2` |

This Mac has no Linux builder, so the `x86_64-linux` and `aarch64-linux` checks and host builds run in CI, as `AGENTS.md` says for outputs a machine cannot build.

## Definition of Done

- The `# T3 Code` section carries the new sentences in the KTD3 order, and the replaced sentence is gone.
- `agent-instructions` pins every new sentence, every U1 mutation turns its assertions red, and CI builds it green.
- `docs/provisioning.md` and `CONCEPTS.md` describe the routing and the Antigravity exception without contradicting each other.
- No scratch copies or mutation leftovers remain in the diff.
