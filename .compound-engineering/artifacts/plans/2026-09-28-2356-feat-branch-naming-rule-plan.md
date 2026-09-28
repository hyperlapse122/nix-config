---
title: Branch Naming Rule Instruction - Plan
type: feat
date: 2026-09-28
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Branch Naming Rule Instruction - Plan

## Goal Capsule

- **Objective:** Branches that coding agents on this machine push carry a name that says what the change is, instead of a tool-generated placeholder such as an Orca worktree codename.
- **Means:** A new shared section in the global agent instructions template, guarded by the existing render check (KTD1, KTD2).
- **Authority:** This plan's Requirements, then Key Decisions, then KTDs, then units.
- **Stop conditions:** Stop if the template cannot render the new section for both harnesses, or if the render check cannot be made to fail when the section is removed.
- **Execution profile:** Lightweight; two small units in one PR.

## Product Contract

### Summary

Add a `# Branch names` section to `home/h82/agents/instructions/instructions.md.tmpl`, outside the per-harness tool branch. It tells agents to check a branch's name before its first push and rename it locally when the name does not describe the change. Documented project rules decide the new name. Without one, the name takes the form `type/short-kebab-slug`. Extend `tests/agent-instructions.nix` so each harness's rendered file must carry the rule.

### Problem Frame

Orca and other agent tools create worktree branches with placeholder names, such as `hyperlapse122/mooneye` or `worktree-memoized-juggling-hartmanis`. Agents push those names unchanged, so the pull request list and the remote branch list do not say what each branch holds. Every harness loads the global instruction file in every workspace, so a rule there reaches all projects.

### Requirements

**When to rename**

- R1. Before the first push of a branch, the agent checks whether the branch name describes the change. If it does not, the agent renames the branch locally before pushing. A descriptive name that keeps a tool-added owner prefix is also renamed unless a documented project rule uses that prefix. Any other descriptive name stays.
- R2. The agent renames only a branch that has never been pushed: no remote branch of the same name exists and no pull request uses it. Such a branch keeps its name, even when that name is a placeholder. An upstream pointing at a different branch, such as `origin/main` set when the worktree was created, does not count as pushed.
- R3. The agent never renames a branch onto, or pushes the renamed branch onto, a branch that already exists. Ordinary pushes to the agent's own branch are unaffected. Before renaming, it checks that the target name is free both locally and on the remote. When the name is taken or conflicts with another ref, including a push rejected for a conflicting remote ref, it picks a different descriptive name.

**How to name**

- R4. Documented project rules decide the name: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING`, project docs, and CI or hooks that check branch names. A pattern seen only in existing branch names is not a rule.
- R5. With no documented rule, the name is `type/short-kebab-slug`: a Conventional Commits type (`feat`, `fix`, `docs`, `refactor`, `chore`, and so on), a slash, and a few lowercase hyphenated words describing the change, following GitHub Flow's "short, descriptive" guidance. A tool-supplied owner prefix such as `hyperlapse122/` is dropped.

**Guard**

- R6. The render check fails when the rule is missing from either harness's rendered file.

### Key Decisions

- **Rename only before the first push.** (session-settled: user-directed — chosen over also renaming already-pushed branches that have no PR: renaming a pushed branch deletes a remote branch and can break review links.) Governs R2.
- **Only documented project rules count.** (session-settled: user-directed — chosen over also inferring a rule from a consistent pattern in existing branch history: tool-generated names in history are not a convention.) Governs R4.
- **Fallback is `type/short-kebab-slug` without an owner prefix.** (session-settled: user-directed — chosen over keeping the owner prefix as `hyperlapse122/<slug>` or `hyperlapse122/feat/<slug>`.) Governs R5.

### Scope Boundaries

- Harness-specific tool tables stay unchanged.
- Adding a branch-naming rule to this repository's `AGENTS.md` is out of scope. Under R4 this repository has no documented rule, so its future branches take the R5 form.
- Changing Orca's own branch naming, or the Compound Engineering skills that push, is out of scope.

## Planning Contract

### Key Technical Decisions

- KTD1. **Place the section after `# Review findings`, as shared text outside the `.harness.id` branch.** Both harnesses push branches, so the rule belongs to every harness. The section names git commands (`git branch -m`, `git check-ref-format --branch`) but no harness tool, because `tests/agent-instructions.nix` fails a harness whose file names the other harness's backticked tools.
- KTD2. **Guard the rule with literal sentences in `tests/agent-instructions.nix`.** Mirror `reviewFindingsSentences`: a second list holds the section's lead sentence (R1), its never-pushed sentence (R2), and its fallback-form sentence (R5). Each harness file is grepped for all three, and the header comment lists the new property. Deleting or rewording any of them then turns the check red, per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`.
- KTD3. **Cite Conventional Commits for the type vocabulary, not Conventional Branch.** Conventional Branch v1.1.0 lists only `feat`, `fix`, `hotfix`, `release`, and `chore`, and it endorses agent prefixes such as `claude/`. Conventional Commits with the commitlint types also covers `docs` and `refactor`, which this repository's history uses. Governs R5.

### Assumptions

- The branch shipping this plan has never been pushed and carries a placeholder-derived prefix (`hyperlapse122/add-branch-naming-convention`). It is renamed to `feat/branch-naming-rule` before its first push, applying R5 to itself.
- A rename leaves Orca's worktree view showing the branch's new name. Research did not verify whether Orca's registry records the old name. If Orca misbehaves after a rename, that is a follow-up for Orca, not a reason to drop R1.

### Sources

- GitHub Flow: "A short, descriptive branch name enables your collaborators to see ongoing work at a glance." <https://docs.github.com/en/get-started/using-github/github-flow>
- GitLab Flow (archived doc): "The name of a branch might be dictated by organizational standards." <https://gitlab.com/gitlab-org/gitlab/-/raw/v15.0.0-ee/doc/topics/gitlab_flow.md>
- Conventional Commits 1.0.0 types: <https://www.conventionalcommits.org/en/v1.0.0/>
- `git branch -m` carries the upstream config to the new name, still pointing at the old remote branch. This makes a rename after push unsafe and supports R2. <https://git-scm.com/docs/git-branch>
- A local branch named exactly `feat` or `fix` makes `git branch -m` fail for `feat/…` or `fix/…`. A remote branch with that name makes the push fail with a refname conflict, and a remote-only branch with the target name lets the rename succeed and the push land on that branch. These are the cases R3 covers. `git check-ref-format --branch` checks syntax only and sees none of them. <https://git-scm.com/docs/git-check-ref-format>

## Implementation Units

### U1. Add the branch-naming rule to the global template

- **Goal:** Render the rule into every harness's instruction file.
- **Requirements:** R1, R2, R3, R4, R5 (KTD1, KTD3).
- **Dependencies:** none.
- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`.
- **Approach:**
  1. Append a `# Branch names` heading after the `# Review findings` section.
  2. Lead with one sentence stating R1.
  3. Follow with short bullets, one each for R2, R3, R4, and R5. The R2 bullet tells the agent to push the renamed branch with `-u` so the new name becomes its upstream. The R3 bullet names a check of local and remote refs, such as `git ls-remote --heads origin <name>`. The R5 bullet gives one example name, such as `feat/add-branch-naming-rule`, and names `git check-ref-format --branch` as the syntax check.
- **Patterns to follow:** The `# Review findings` section's shape: an imperative lead sentence, then short bullets.
- **Test scenarios:** Covered by U2.
- **Verification:** Both rendered files contain the section once, separated from the section before it by a blank line.

### U2. Assert the rule in the render check

- **Goal:** Make the check fail when the rule is missing.
- **Requirements:** R6 (KTD2).
- **Dependencies:** U1.
- **Files:** `tests/agent-instructions.nix`.
- **Approach:** Add the three sentences KTD2 names as literals shared by both harness entries. Grep for each in every rendered file, and add the property to the header comment.
- **Test scenarios:**
  - Happy path: with U1 applied, the `agent-instructions` check builds.
  - Mutation: deleting the lead sentence from the template makes the check fail for both Claude Code and Antigravity.
  - Mutation: deleting the never-pushed sentence makes the check fail for both harnesses.
  - Mutation: deleting the fallback-form sentence makes the check fail for both harnesses.
- **Verification:** The check passes on the branch and fails under each mutation. Run the mutations in a scratch copy, per `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| Render check | `nix build .#checks.x86_64-linux.agent-instructions` |
| All checks | `nix flake check` |
| Every host output | build each `nixosConfigurations.<name>.config.system.build.toplevel`, as `AGENTS.md` lists |

## Definition of Done

- R1 through R5 appear in both rendered files. R6 holds, shown by the render check passing and by it failing under each U2 mutation.
- `nix flake check` and every `nixosConfigurations` output build.
- No abandoned-attempt code remains in the diff.
