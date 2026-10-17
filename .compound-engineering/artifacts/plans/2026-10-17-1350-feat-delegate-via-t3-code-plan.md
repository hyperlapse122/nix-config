---
title: Delegate All Subagent Work Through T3 Code - Plan
type: feat
date: 2026-10-17
topic: delegate-via-t3-code
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Delegate All Subagent Work Through T3 Code - Plan

## Goal Capsule

- **Objective:** Inside T3 Code, every piece of subagent work an agent starts runs as a T3 Code delegated task, so the user can see, track, and route all of it from T3 Code, while terminal sessions behave exactly as before.
- **Means:** Change the T3 Code part of the shared agent instructions so `delegate_task` replaces the harness's native subagent tool whenever the T3 Code MCP tools are available (KTD1).
- **Product authority:** The user, in this brainstorm; the Product Contract below wins over the Planning Contract on behavior.
- **Open blockers:** None.
- **Stop conditions:** Stop if the agent-instructions check cannot pin the new rule without weakening an existing guard, or if a terminal channel would have to change.
- **Execution profile:** Instruction-text and Nix check change; proof is the `agent-instructions` check plus mutation of each new pin.
- **Finishes and ships:** `lfg`, through `ce-work`, review, and a pull request; the user merges.

---

## Product Contract

### Summary

The T3 Code instruction part stops limiting T3 Code delegation to cross-provider work. When the T3 Code tools are available, scouts, workers, and the reviewers a skill dispatches all go through `delegate_task`, with models still chosen by the Model routing table. The native subagent tool stays as the fallback when T3 Code tools are missing or every T3 Code provider fails.

### Problem Frame

Today the T3 Code part tells an agent to delegate through T3 Code only when the work needs another provider or a model the native subagent tool cannot select; otherwise it keeps using the native tool (`home/h82/agents/instructions/instructions.md.tmpl`, the `# Cross-model delegation` section's applicability bullet). In practice most subagent work in a T3 Code session is same-provider: a Claude Code session's Haiku scouts, Sonnet workers, and the parallel reviewers `ce-code-review` dispatches all run through the Claude Code `Agent` tool. That work never appears as a T3 Code child task, so the user sees only part of what a thread is doing, cannot manage those children from T3 Code, and model choice is bounded by what each harness's native tool can select.

### Key Decisions

- **Every subagent job goes through T3 Code, including skill-internal reviewer fan-out.** Visibility and routing only hold if nothing slips past T3 Code. Governs R1, R2. (session-settled: user-directed — chosen over exempting skill-internal parallel reviewer fan-out, and over routing only work that needs a specific model class: the user wants all subagent work tracked in T3 Code and accepts the extra child threads and startup latency.)
- **Native subagent tool remains the fallback, with a one-line notice.** Work should not stop because T3 Code delegation is unavailable. Governs R5, R6. (session-settled: user-directed — chosen over forbidding the native tool and stopping, and over doing the work inline in the orchestrator: a degraded but completed run beats a halted one.)
- **The change lives only in the T3 Code part.** Terminal sessions never read that part, so their native-tool behavior and the system part's "let the subagent inherit your session model" rule stay untouched. Governs R8.
- **The Workflow tool is out of scope.** Agents inside a Workflow script are started by the Workflow runtime, which these instructions cannot redirect, and the user opts into a workflow explicitly.

### Requirements

**Routing**

- R1. When the T3 Code MCP tools are available, an agent delegates every subagent job through `delegate_task` instead of its harness's native subagent tool, whatever the provider or model the job needs.
- R2. This covers short and broad scouts, workers, and the reviewers or other parallel agents a skill dispatches in-process, such as `ce-code-review`'s reviewer fan-out.
- R3. The model for each delegated job still comes from Model routing and the existing T3 Code rules: the same-provider cells of the table pick a model on the agent's own provider instance, and the cross-model rules keep picking other providers.
- R4. A job whose result the agent needs before its next step, such as a short scout, is delegated so the agent gets the result before continuing; other jobs use the existing asynchronous launch-and-notify flow.

**Fallback**

- R5. When the T3 Code MCP tools are not available in the session, the agent uses its native subagent tool as it does outside T3 Code.
- R6. When a delegated job fails, reports a provider error, or shows no progress, the agent follows the existing retry-on-another-provider rule; when no T3 Code provider succeeds, it runs the job with its native subagent tool and tells the user in one line that it did.

**Safety and precedence**

- R7. A delegated job that must not change files, such as a review or a scout that native tooling would have run as a read-only agent type, states that in its task prompt, since the T3 Code child has no read-only agent type.
- R8. The T3 Code part states that it overrides both the system part's instruction to hand parallel work to the native subagent tool and T3 Code's own built-in guidance to prefer native subagent tools for same-provider work.
- R9. Terminal sessions, which never receive the T3 Code part, keep using their native subagent tool unchanged.

**Guards**

- R10. The repository's agent-instruction checks pin the new routing rule in every T3 Code delivery path and fail if the superseded "only when the work needs another provider" applicability rule reappears.

### Acceptance Examples

- AE1. **Covers R1, R3.** **Given** a Claude Code session in T3 Code with T3 Code tools available, **when** a skill needs a short scout, **then** the agent delegates it through `delegate_task` to the Claude provider instance on the latest runnable Haiku, not through the `Agent` tool.
- AE2. **Covers R2, R7.** **Given** the same session, **when** `ce-code-review` dispatches its reviewers, **then** each reviewer runs as a T3 Code delegated task whose prompt says not to change files.
- AE3. **Covers R5.** **Given** a session started by T3 Code whose harness exposes no T3 Code MCP tools, **when** a skill needs a worker, **then** the agent uses its native subagent tool.
- AE4. **Covers R6.** **Given** a delegated worker that fails on its provider and on the retry provider, **when** no T3 Code provider succeeds, **then** the agent runs the worker with its native subagent tool and says so in one line.
- AE5. **Covers R9.** **Given** a Claude Code session in a terminal, **when** a skill needs a scout, **then** the agent uses the `Agent` tool as before.

### Scope Boundaries

- The Claude Code Workflow tool and the agents its scripts start.
- A limit on how deep delegated children may themselves delegate; children receive the same T3 Code part and delegate the same way.
- Changes to the system or user instruction parts, or to how terminal sessions route subagents.
- Changes to the cross-model peer rules (Antigravity and OpenCode peers, retry exclusions) beyond what R6 reuses.

### Dependencies / Assumptions

- T3 Code's `delegate_task` can target the agent's own provider instance with any model `orchestrator_capabilities` lists, so same-provider routing in R3 needs no native tool.
- Each delegated child starts a full session, so heavy fan-out is slower than the native tool; the user accepted that cost.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl` — the `t3code` part (`# T3 Code` and `# Cross-model delegation`) holds the rules this changes; the `system` part's Model routing holds the native-inheritance rule R9 keeps.
- `tests/agent-instructions.nix` — pins the T3 Code part's sentences, including the superseded applicability sentence and the "When your native subagent tool cannot select the table's class, delegate through T3 Code" sentence.
- `CONCEPTS.md` — "Instruction part" defines the system, user, and T3 Code parts and their delivery paths.

Product Contract preservation: Product Contract unchanged.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Put the routing rule in the `# T3 Code` introduction and widen the `# Cross-model delegation` section's applicability.** The introduction already states that T3 Code rules take precedence over Tool use and Model routing, so the new rule inherits that precedence; the delegation section keeps owning the mechanics (capabilities, model choice, async waits, retry), which now apply to every delegated job. Covers R1, R2, R8.
- KTD2. **Keep the `# Cross-model delegation` heading.** Tests, the substring-negation learning, and `CONCEPTS.md` anchor on it; renaming it would churn those for no behavior change. The section's intro line and applicability sentence change so its scope reads as all T3 Code delegation.
- KTD3. **Replace the "native tool cannot select the table's class" sentence in the T3 Code introduction.** Under R1 every job already goes through T3 Code, so that conditional is superseded. The system part's matching sentence ("let the subagent inherit your session model") stays for terminal sessions (R9).
- KTD4. **Reuse the existing retry rule and add one native fallback sentence for jobs that are not cross-model passes.** The existing "Fall back to the skill's own cross-model method" sentence still governs cross-model passes; the new sentence covers every other job (R6), and a sibling sentence sends a retried job only to a provider that has a column in the Model routing table, never to OpenCode, taking its role's class from that column. Without it, the existing "another runnable T3 Code provider" retry could send ordinary repository work to OpenCode Zen's free tier, which the table has no class for and the peer rules allow only after a data-terms notice. Covers R3, R6.
- KTD5. **R4 needs no new sentence.** The two pinned launch sentences already meet it: a `mode: "wait"` launch when the next step needs the result and nothing else can run, and otherwise an `async` launch whose dependent step resumes only after the notification arrives. Either way the agent holds the result before the step that needs it. Adding a second wait sentence would also trip the wait-topic guard.
- KTD6. **Pin every new or changed sentence as a literal and list each superseded phrase in `supersededDirectives`.** That is the repository's existing guard shape, and it fails when the old applicability rule or class-conditional sentence comes back (R10).

### Directional wording

The implementer may tune the wording, but each sentence must keep the meaning below, start a sentence (the guard rejects a negated prefix), and avoid the wait-topic words the delegation section guards (`wait`, `block`, `check`, `finish`, `notif`, `poll`, `wake`, `sleep`, `timer`, `background`, `schedul`, `task_status`). Any new delegation sentence that names `Antigravity`, `Argon`, `OpenCode`, or `opencode` must be pinned in `delegationSentences`, which admits it to the peer guard; a sentence inside an Antigravity branch must also join `antigravityT3Omitted`, with its six-entry assertion updated. Name the native tool only as "native subagent tool": a harness tool name such as `Agent`, `spawn_agent`, or `invoke_subagent` fails the check on every other harness's channel.

- Introduction, replacing the class-conditional sentence: delegate every subagent job through T3 Code when its MCP tools are available, whatever provider or model the job needs, instead of the native subagent tool; this covers scouts, workers, and a skill's in-process reviewers such as `ce-code-review`'s; it overrides Tool use's instruction to hand parallel work to the subagent tool and T3 Code's own guidance to prefer native subagent tools for same-provider work; the native tool is used only when the T3 Code tools are absent or no T3 Code provider succeeds.
- Delegation section intro line: "Delegate subagent work through the T3 Code MCP server, …" instead of "work that needs another model".
- Applicability: the section applies to every subagent job whenever the T3 Code MCP tools are available, on the agent's own provider or another.
- Provider choice: choose the provider and model that suit the task under Model routing, the agent's own provider for a same-provider cell and another provider for cross-model work.
- Read-only: extend the existing "must not change files" sentence to name jobs the native tool would have run as a read-only agent type.
- Fallback: when no T3 Code provider succeeds for a job that is not a cross-model pass, run it with the native subagent tool and tell the user in one line.
- Retry target and class: a retried job that is not a cross-model pass goes only to a provider with a column in the Model routing table, never to OpenCode, and takes its role's class from that column.

### Assumptions

- T3 Code's `delegate_task` accepts the calling agent's own provider instance with any model `orchestrator_capabilities` lists (Dependencies / Assumptions above).
- The Antigravity T3 Code render keeps every new sentence, since none sits inside a harness branch; `antigravityT3Omitted` keeps its six entries.

---

## Implementation Units

### U1. Rewrite the T3 Code delegation rules

- **Goal:** The rendered T3 Code part routes every subagent job through T3 Code with the native fallback.
- **Requirements:** R1, R2, R3, R5, R6, R7, R8; KTD1–KTD5.
- **Dependencies:** None.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. In the `t3code` part's `# T3 Code` list, replace the class-conditional sentence with the routing, coverage, override, and native-use sentences from Directional wording.
  2. In `# Cross-model delegation`, rewrite the intro line, the applicability bullet, and the provider-choice bullet.
  3. Extend the "must not change files" bullet.
  4. Append the fallback and retry-target sentences to the retry bullet, after the cross-model fallback sentence.
  5. Leave the system and user parts untouched.
- **Patterns to follow:** The existing one-sentence-per-rule bullets in the same part; `{{- if ne .harness.id "antigravity" }}` branches stay where they are.
- **Test scenarios:** Covered by U2's check; this unit has no separate test file.
- **Verification:** The rendered Claude Code T3 Code file and the Codex launch override both carry the new sentences, and terminal channels are byte-identical to before.

### U2. Pin the new rules in the agent-instructions check

- **Goal:** The check fails when any new rule is dropped, negated, moved out of its section, or when a superseded rule returns.
- **Requirements:** R10, R9.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:**
  1. Update `t3IntroSentences` to the new introduction, in order.
  2. In `delegationSentences`, replace the applicability sentence and add the provider-choice, read-only, fallback, and retry-target sentences.
  3. Add the superseded phrases to `supersededDirectives`: the old applicability clause, the old "instead of letting the subagent inherit your session model" ending, and "choose a provider other than your own".
  4. Update the header comment's T3 Code bullet so it names all-subagent delegation.
- **Execution note:** Mutation-test each new pin in a scratch copy, following `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` and `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.
- **Patterns to follow:** The literal sentence lists and `requireSentences`, `sentencesInOrder`, `sentencesInSection` uses already in the file.
- **Test scenarios:**
  - Covers AE1, AE2. The rendered T3 Code part for Claude Code and Codex carries each new introduction sentence once and in order; the check passes.
  - Removing the routing sentence from the template turns the check red with "lacks the T3 Code introduction".
  - Prefixing the routing sentence with "Do not " turns the check red.
  - Covers AE3, AE4. Removing the fallback sentence turns the check red with "lacks the cross-model delegation rule".
  - Moving the fallback sentence into `# Pull and merge requests in T3 Code` turns the check red.
  - Restoring the old applicability sentence turns the check red with "carries a superseded directive".
  - Dropping "never to OpenCode" from the retry-target sentence turns the check red.
  - Dropping the Tool use override clause from the introduction turns the check red.
  - Covers AE5. Adding any new sentence to the system part turns the check red, because terminal channels must not contain `T3 Code` or a T3 Code sentence.
- **Verification:** `agent-instructions` builds green on the unmutated tree, and every mutation above turns it red.

### U3. Update the glossary and provisioning docs

- **Goal:** Readers of `CONCEPTS.md` and `docs/provisioning.md` learn that inside T3 Code all subagent work goes through the app.
- **Requirements:** R1, R5.
- **Dependencies:** U1.
- **Files:** `CONCEPTS.md`, `docs/provisioning.md`.
- **Approach:**
  1. Refine the **Cross-model delegation** entry: inside an orchestrating app that tracks delegated tasks, the session's own subagent work goes through the app as well, with the native subagent tool as the fallback.
  2. In the shared-agent-instructions paragraph, describe the T3 Code part as carrying delegation of every subagent job through T3 Code.
- **Test scenarios:** Test expectation: none -- documentation only; the Markdown pre-commit lint covers formatting.
- **Verification:** Both files read correctly and pass `markdownlint-cli2`.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Agent instructions check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U1, U2 |
| Flake checks | `nix flake check` | all units |
| Formatting | `nix fmt -- --ci` | U2 |
| Markdown lint | `mise run lint-staged-markdown` (pre-commit) | U3 |
| VM checks | `nix build --no-link .#vmChecks.all` | all units |
| Host outputs | the build loop in `AGENTS.md` for every `nixosConfigurations` and `homeConfigurations` output; macOS and aarch64 outputs are left to CI | U1 |

---

## Definition of Done

- The rendered T3 Code part for every harness that receives it carries the new routing, fallback, and read-only rules, and no terminal channel changed.
- `agent-instructions` is green, and each U2 mutation was observed red.
- `nix flake check` and `nix fmt -- --ci` pass.
- `CONCEPTS.md` and `docs/provisioning.md` match the new behavior.
- No scratch mutation copies or abandoned edits remain in the diff.
