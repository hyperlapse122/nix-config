---
title: Prefer the Latest Model of the Chosen Class When Delegating - Plan
type: feat
date: 2026-10-06
topic: latest-model-in-class
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Prefer the Latest Model of the Chosen Class When Delegating - Plan

## Goal Capsule

- **Objective:** When an agent delegates work to another model through T3 Code, the run lands on the newest generation of the model class the task needs, and the user can see why whenever it does not.
- **Means:** New sentences in the shared Cross-model delegation section of the agent instructions template (KTD1), pinned in the `agent-instructions` check for all three harnesses (KTD2).
- **Authority:** Issue #165 and this plan's R-IDs govern behavior; KTDs govern mechanism. `AGENTS.md` governs repository conventions and verification.
- **Open blockers:** None.
- **Stop conditions:** Stop if the wording cannot avoid a native tool name from another harness's absent list in `tests/agent-instructions.nix`, a mention of Orca in any letter case, or a `{{`/`}}` sequence, because the check rejects each.
- **Execution profile:** Lightweight. One template edit and one check edit, verified by building the check, a mutation test of the new assertions, and the repository's ship checks.
- **Finishing:** The implementer lands and verifies the change; the rendered files reach the machines after the user's own `nr switch`.

## Product Contract

### Summary

Add a rule to the Cross-model delegation section: after choosing a model class, pick the latest version of that class that `orchestrator_capabilities` lists as runnable. Compare versions only within the class. An older version is allowed only for a stated reason, and the agent says that reason when it names the model.

### Problem Frame

The delegation rules say to "choose a provider other than your own, a model, and options that suit the task" but say nothing about generations within a class. During the Twemoji work `orchestrator_capabilities` listed both `gpt-6.1-sol` and `gpt-6-sol` for Codex; the agent sent every review pass (two `ce-doc-review` cross-model passes and one `ce-code-review` adversarial pass) to the older `gpt-6-sol` and could not justify the choice. Delegated reviews can quietly run on a stale generation.

### Key Decisions

- **Compare versions within one class only.** Governs R1, R2. (session-settled: user-directed — chosen over ranking across classes, where a newer Luna would outrank an older Sol: the class choice reflects what the task needs)
- **An older version needs a stated reason.** Governs R3, R4. (session-settled: user-directed — chosen over free choice among versions: the agent picked a stale `gpt-6-sol` with no justification)

### Requirements

**Choosing the version**

- R1. Once the agent has decided which model class suits the task, it chooses the latest version of that class that `orchestrator_capabilities` lists as runnable.
- R2. Versions are compared only within the chosen class; a newer model of another class never displaces the class the task needs.
- R6. The agent sets the chosen version's options, such as reasoning effort, for the task instead of inheriting that version's defaults, because defaults differ between versions of one class (in the live catalog `gpt-6.1-sol` defaults to low effort and `gpt-6-sol` to medium).
- R3. The agent picks an older version only when the latest is unavailable, has failed in this session, or the user or project asked for that version.

**Telling the user**

- R4. When the agent picks an older version, it says why alongside the provider and model it already names to the user.

**Coverage**

- R5. The rendered instructions for Claude Code (`~/.claude/CLAUDE.md`), Antigravity (`~/.gemini/config/AGENTS.md`), and Codex (`~/.codex/AGENTS.md`) all carry the new sentences with no template residue.

### Scope Boundaries

- How T3 Code orders or labels models in `orchestrator_capabilities`.
- Choosing between providers; the existing rule already says to pick a provider other than your own.
- Choosing the class itself; the rule starts after the class is chosen.

## Planning Contract

### Key Technical Decisions

- KTD1. **Shared text in the existing Cross-model delegation section, outside any harness branch.** The template already renders one section for all three harnesses through `home/h82/agents/instructions/default.nix`, whose `harnesses` attrset already includes `codex` with target `.codex/AGENTS.md`; no new rendering path is needed. The new sentences go directly after the "Before delegating, list the runnable providers and models…" bullet, which they refine. Governs R1–R5.
- KTD2. **Pin the new sentences verbatim in `delegationSentences`.** `tests/agent-instructions.nix` already asserts every entry of that list against every harness's rendered file on every configuration via `requireSentences`, so adding the literals covers all three harnesses, Codex included, with no new assertion code. (session-settled: user-directed — chosen over a template-only change: dropping or rewording the rule in any one harness must fail the check)
- KTD3. **Name example classes per provider in the rule.** Listing Sol/Luna/Astra for Codex, Opus/Sonnet/Haiku for Claude, and Pro/Flash for Gemini makes "class" concrete for every harness. None of these words is a native tool name in the check's absent lists, and none contains "orca".

### Assumptions

- The exact wording is the implementer's to finalize in the repository's prose style; whatever lands is what the check pins. A directional draft: "Once you know which model class suits the task, such as Sol, Luna, or Astra for Codex, Opus, Sonnet, or Haiku for Claude, or Pro or Flash for Gemini, choose the latest version of that class that `orchestrator_capabilities` lists as runnable." / "Compare versions only within that class: a newer model of another class does not outrank the class the task needs." / "Choose an older version only when the latest is unavailable, has failed in this session, or the user or project asked for that version, and say why when you name the model." / "Set the chosen version's options, such as reasoning effort, for the task rather than inheriting its defaults, which can differ between versions of one class."
- Some catalog ids carry no version (`gemini-pro-agent` is labeled "Gemini 3.1 Pro (High)") or carry an effort suffix (`-high`, `-low`). The rule says "latest version" without prescribing id parsing; an agent reads the version from the label when the id lacks one.
- One sentence per bullet keeps each pinned literal on one line, which `grep -qF` needs.

## Implementation Units

### U1. Add the version rule to the delegation section

- **Goal:** The shared template states R1–R4 and R6.
- **Requirements:** R1, R2, R3, R4, R6; KTD1, KTD3.
- **Dependencies:** None.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`
- **Approach:** Insert the new bullets after the "Before delegating…" bullet in `# Cross-model delegation`, outside the `{{- if eq .harness.id … }}` tool-table branches.
- **Patterns to follow:** The existing one-sentence imperative bullets in the same section.
- **Test scenarios:** Covered by U2.
- **Verification:** Each harness's rendered file contains the new sentences exactly once and nothing unrendered.

### U2. Pin the sentences in the agent-instructions check

- **Goal:** Dropping or rewording any new sentence in any harness's file fails the `agent-instructions` check.
- **Requirements:** R5; KTD2.
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`
- **Approach:** Append the new sentences as literals to `delegationSentences`, and extend the header comment's list of verified delegation rules to name the version-choice rule.
- **Patterns to follow:** The existing `delegationSentences` entries and the literal-not-read-from-module rule in the file header.
- **Test scenarios:**
  - The check builds green with the change in place for every configuration and all three harnesses.
  - Mutation: removing the version-choice sentence from the template turns the check red, naming the missing sentence for each harness and host.
  - Mutation: rewording one word of the older-version sentence turns the check red.
  - Mutation: moving the sentences into the `codex` branch only turns the check red for Claude Code and Antigravity.
- **Verification:** All mutations fail the check and the restored tree passes. Follow `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md` when mutating in a scratch copy.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix formatting unchanged |
| Targeted check | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | R5 on every configuration |
| Flake checks | `nix flake check` | All declared checks pass |
| VM tests | `nix build --no-link .#vmChecks.all` | `AGENTS.md`'s pre-ship VM gate |
| Host outputs | The `AGENTS.md` loops over `nixosConfigurations`, `homeConfigurations`, `systemConfigs` | Every production and bootstrap output builds |

When the local machine lacks `/dev/kvm`, the VM gate stays pending until CI's `vm-checks` jobs pass on the pull request.

## Definition of Done

- U1 and U2 landed; the three rendered files carry the new sentences.
- The mutation scenarios in U2 were each observed red, then the tree restored and green.
- `nix flake check` passes, the VM tests build, and every host output builds.
- No leftover mutation edits or scratch copies remain in the diff.
