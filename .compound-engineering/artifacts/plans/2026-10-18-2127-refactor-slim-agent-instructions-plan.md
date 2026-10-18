---
title: Slim Agent Instructions - Plan
type: refactor
date: 2026-10-18
topic: slim-agent-instructions
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Slim Agent Instructions - Plan

## Goal Capsule

- **Objective:** Every Claude Code and standalone OpenCode session the user starts reads one short set of personal instructions, and changing a rule means editing one place.
- **Means:** Replace the three-part gomplate template with one plain Markdown file delivered to Claude Code and standalone OpenCode, and retire the separate T3 Code delivery path (KTD1, KTD2).
- **Product authority:** The Product Contract below, written from the user's brainstorm. Planning resolves HOW only.
- **Stop conditions:** Stop if a retained rule cannot be expressed without naming the CE skill rule it overrides, or if any host output fails to build.
- **Execution profile:** Nix configuration, Markdown, and Nix checks. No hardware or `nr switch` validation.
- **Open blockers:** None.

---

## Product Contract

Product Contract preservation: changed: R4, R10 — R4's "no longer exist" became "no longer take effect", and R10 names the file and `launchArgs` checks instead of every removed artifact, because the settings merge cannot delete the old environment entry (KTD3).

### Summary

The shared agent instructions become one short file, identical for Claude Code and standalone OpenCode. It keeps the GPG/SOPS, Git, pull and merge request, and review-findings preferences in a few lines each, adds a general T3 Code section that applies only when T3 Code's tools are present, and drops the system part, the separate T3 Code delivery path, and every clause that enumerates which Compound Engineering skill rule it overrides.

### Problem Frame

The template grew to 226 lines split into three parts (system, user, T3 Code) with per-harness branches for the tool table and the cross-model peer. Each part has its own delivery path: the Claude Code and OpenCode files carry system and user merged, and T3 Code sessions get a third file through `--add-dir` launch arguments and an environment upsert. `render.nix`, `home/h82/t3code.nix`, `packages/opencode.nix`, an 851-line `tests/agent-instructions.nix` that pins individual sentences, `CONCEPTS.md`, and `docs/provisioning.md` all encode that structure. A one-line rule change touches several of them, and much of the text is detailed override bookkeeping against specific CE skill steps that drifts whenever the plugin changes.

### Key Decisions

- **One part, no harness branches.** The system part and the per-harness tool table go away; harnesses follow their own native-tool guidance. Governs R1, R2. (session-settled: user-directed — chosen over keeping the T3 Code part as a separate part or trimming it in place: the user wants only a slim user instruction.)
- **T3 Code guidance is general and conditional, not a separate delivery path.** It lives in the same file and says to use T3 Code's tools when the session has them. Governs R8, R9. (session-settled: user-directed — chosen over deleting T3 Code guidance entirely: the user asked for a general "use the tools when present" section.)
- **Keep CE preferences, drop override enumerations.** Rules that say what to do with CE skills stay in short form; lists of which skill steps they override are removed. Governs R5, R6, R7. (session-settled: user-directed — chosen over removing every CE-related sentence: the user chose to keep the CE content.)
- **The cross-model peer rule is dropped.** It lived in the system part and was not among the rules the user kept, so CE falls back to its own peer choice. Governs R3. (session-settled: user-directed — chosen over keeping the system part rules: the user kept only GPG/SOPS, Git, PR/MR, and review findings.)

### Requirements

**Structure and delivery**

- R1. The instructions render as a single section set with no `part` selection and no harness-specific branches.
- R2. Claude Code's `~/.claude/CLAUDE.md` and the standalone OpenCode instructions file receive the same rendered content.
- R3. The Tool use section, the per-harness native-tool table, and the Cross-model review section are removed.
- R4. The T3 Code-only delivery path is removed: the `~/.t3/instructions/claude-code/CLAUDE.md` file, the Claude instance's `--add-dir` launch argument, and the `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` environment entry no longer take effect after activation, including on machines where an earlier generation wrote them.

**Retained rules, each reduced to a few lines**

- R5. GPG and SOPS: the agent runs GPG work itself, never exposes decrypted values, leaves card and key administration to the user, and uses the card key fingerprint `621512777E6933FEB4458FDC4945855D4F283F05` for a new SOPS setup unless the project already uses another method.
- R6. Git work: branch naming before first push, the mise-trust retry for commit hooks, and refreshing learnings that the pushed commits break.
- R7. Pull and merge requests and review findings: GitLab is handled like GitHub through `glab`, opened requests are babysat until ready, media is masked and stripped of metadata before upload, and every review finding is applied regardless of severity. These are stated as preferences without the enumerated lists of CE skill rules they override.

**T3 Code**

- R8. When the session lists T3 Code's delegation tools, the agent delegates subagent work through them; otherwise it uses its native subagent tool.
- R9. When the session lists T3 Code's pull request watch tools, the agent uses them to watch a request it babysits instead of its own background wait.

**Checks and documentation**

- R10. The checks verify that both delivery files exist with the same content, that no template action or `<no value>` survives, that `.t3/instructions/claude-code/CLAUDE.md` is absent, and that the Claude instance's `launchArgs` is empty; they no longer pin every sentence of the removed parts or forbid the string `T3 Code`.
- R11. `CONCEPTS.md` and `docs/provisioning.md` describe the single-file structure; the "Instruction part" entry is removed and "Delivery path" reflects that every path gets the same file.

### Scope Boundaries

- The detailed T3 Code delegation procedure (model tier mapping, async notification handling, `task_status` limits, fallback rules, babysit tick and bridge-watcher details) is not carried over.
- The repository's own `AGENTS.md` rules on PR watching and applying findings are unchanged; only its description of the instruction parts is updated.
- No per-repository `cross_model_peer` configuration is added to replace the dropped peer rule.
- The OpenCode wrapper's behavior of withholding instructions from reviewer runs is unchanged.
- Antigravity and Gemini still receive no instruction file.
- Considered and not built: a list-entry removal feature in `scripts/agent-settings` to delete the stale `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` environment entry. Without `--add-dir` the variable only gates loading `CLAUDE.md` from added directories, of which there are none, so the leftover entry has no effect (KTD3). Evidence that the variable affects a session with no added directory would change this.

### Dependencies / Assumptions

- Short preference sentences, without explicit override lists, are assumed sufficient; where a CE skill's own default conflicts (for example `ce-code-review`'s report-only default), the skill may now win.
- T3 Code's own injected guidance is assumed to cover the delegation and watch mechanics the removed procedure spelled out.

### Sources / Research

- `home/h82/agents/instructions/instructions.md.tmpl`, `render.nix`, `default.nix` — current template and renderer; gomplate is used nowhere else.
- `home/h82/t3code.nix` — T3 Code part delivery (`claudeInstructionsDir`, `claudeAgent.config.launchArgs`, `upserts`, `home.file.t3code-claude-instructions`) and the `codex.config.launchArgs = ""` retirement precedent.
- `scripts/agent-settings` — `remove` reaches only top-level keys, `setPaths` overwrites a nested scalar, `upsertPaths` replaces or appends but never deletes.
- `packages/opencode.nix` — `instructions` and `instructionsConfig` passthru consumed by `flake.nix` and `tests/opencode.sh`, which assert the config path, not its content.
- `tests/agent-instructions.nix`, `tests/agent-instruction-channels.py`, `tests/t3code-traits.nix`, and the `t3code-instruction-channels` check in `flake.nix`.
- `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md` — anchored sentence matching for the pins that remain.
- `.compound-engineering/artifacts/solutions/best-practices/home-manager-activation-does-not-run-on-every-rebuild.md` — the launch-argument reset lands only on a new generation.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **A plain Markdown file replaces the gomplate template.** With no parts and no harness branches, the only remaining template input was `.opencode.model`, used only inside the removed T3 Code Delegation section. `home/h82/agents/instructions/instructions.md` becomes the source for both delivery files, and `render.nix` and the gomplate build go away. Governs R1, R2.
- KTD2. **Reset the Claude instance's `launchArgs` to an empty string rather than dropping the leaf.** The settings merge only assigns, so a dropped leaf would leave `--add-dir <deleted dir>` on every machine that ran an earlier generation. This follows the `codex.config.launchArgs = ""` precedent in `home/h82/t3code.nix`. Governs R4.
- KTD3. **Stop upserting the environment entry and leave the existing one in place.** `scripts/agent-settings` cannot delete a list entry, and the entry has no effect once `--add-dir` is gone. Governs R4; the alternative is recorded under Scope Boundaries.
- KTD4. **Shrink `agent-instructions` to delivery, identity, and anchored pins of the new text.** The check keeps reading the materialized Home Manager file and the OpenCode wrapper's `INSTRUCTIONS_CONFIG`, adds a byte comparison between the two, and pins the new file's key sentences with the anchored matching the substring-negation learning requires. The per-part and per-path machinery, the T3 Code channel, and the forced-off configurations are deleted. Governs R10.
- KTD5. **Delete the `t3code-instruction-channels` check and `tests/agent-instruction-channels.py`.** Both exist only to pin upstream behavior the `--add-dir` delivery relied on. Governs R4, R10.

### Assumptions

- The pre-commit Markdown lint globs (`docs/**/*.md`, `*.md`, `.compound-engineering/artifacts/**/*.md`) do not cover `home/h82/agents/instructions/`, so the instruction file keeps its own style without lint constraints.

### Sequencing

U1 changes the content and delivery, U2 retires the T3 Code path, U3 rewrites the checks against both, and U4 updates the documentation last so it describes the landed state.

---

## Implementation Units

### U1. Write the slim instruction file and deliver it

- **Goal:** One plain Markdown file holds the retained rules and the general T3 Code section, and both harnesses receive it.
- **Requirements:** R1, R2, R3, R5, R6, R7, R8, R9; KTD1.
- **Dependencies:** None.
- **Files:**
  - Create `home/h82/agents/instructions/instructions.md`.
  - Delete `home/h82/agents/instructions/instructions.md.tmpl` and `home/h82/agents/instructions/render.nix`.
  - Modify `home/h82/agents/instructions/default.nix` and `packages/opencode.nix`.
  - Test: `tests/agent-instructions.nix` (rewritten in U3).
- **Approach:**
  1. Write sections for GPG and encryption, Git work (branch names, commit hooks, learning refresh), pull and merge requests (GitLab through `glab`, babysitting, issue and PR media), review findings, and T3 Code. Keep each to a short paragraph or a few bullets; the whole file should read in about a minute.
  2. Keep the concrete facts the rules depend on: the card fingerprint, the `MISE_TRUSTED_CONFIG_PATHS` retry with `pwd -P`, the `type/short-kebab-slug` default, `ffmpeg -map_metadata -1` and opaque-box masking, and the GitLab readiness fields.
  3. Remove every sentence that lists a CE skill's rule being overridden (R7), every reference to the deleted Tool use, Cross-model review, and Delegation sections, and every harness name outside the T3 Code section, which keeps naming T3 Code and its tools (R8, R9).
  4. Point `default.nix`'s `.claude/CLAUDE.md` entry and `packages/opencode.nix`'s `instructions` at the same file, keeping `passthru.instructions` and `passthru.instructionsConfig`.
- **Patterns to follow:** the existing `home.file` store-link entry in `home/h82/agents/instructions/default.nix`.
- **Test scenarios:**
  - The Claude Code file and the OpenCode instructions file are byte-identical.
  - The file contains the card fingerprint, `glab`, and the T3 Code tool names `delegate_task` and `watch_pull_request`.
  - The file contains no `Tool use`, `Cross-model review`, `{{`, or `<no value>`.
- **Verification:** Both files build from one store path and the retained rules read correctly without the removed sections.

### U2. Retire the T3 Code delivery path

- **Goal:** T3 Code's Claude sessions get the same `~/.claude/CLAUDE.md` as a terminal and nothing extra.
- **Requirements:** R4, R10 (the `launchArgs` check); KTD2, KTD3.
- **Dependencies:** U1.
- **Files:**
  - Modify `home/h82/t3code.nix`.
  - Test: `tests/t3code-traits.nix`.
- **Approach:**
  1. Remove the `instructions` import, `claudeInstructionsDir`, the `home.file` entry for the T3 Code part, and the environment upsert.
  2. Set `providerInstances.claudeAgent.config.launchArgs` to `""` with a comment like the Codex one, saying it retires the old `--add-dir` value.
  3. In `tests/t3code-traits.nix`, drop the instruction-file assertions and the render import, expect `launchArgs = ""`, and expect an empty `upsertPaths`.
- **Patterns to follow:** the `codex` instance block in `home/h82/t3code.nix` and its expectation in `tests/t3code-traits.nix`.
- **Test scenarios:**
  - With a T3 Code trait on, the declared settings set `claudeAgent.config.launchArgs` to `""` and contain no `--add-dir`.
  - With a T3 Code trait on, no `home.file` targets `.t3/instructions/claude-code/CLAUDE.md`.
  - The declared `upsertPaths` is empty.
  - Mutation: restoring the `--add-dir` value or the upsert fails the check.
- **Verification:** `t3code-traits` passes and the T3 Code settings declaration carries only the reset.

### U3. Simplify the instruction checks

- **Goal:** The checks guard the new single file and the removed path without the per-part machinery.
- **Requirements:** R10; KTD4, KTD5.
- **Dependencies:** U1, U2.
- **Files:**
  - Modify `tests/agent-instructions.nix` and `flake.nix`.
  - Delete `tests/agent-instruction-channels.py`.
- **Approach:**
  1. Keep per-user discovery from `tests/lib/configurations.nix`, `homeFile` for `.claude/CLAUDE.md`, the want-zero checks for `.codex/AGENTS.md`, `.gemini/config/AGENTS.md`, `.gemini/GEMINI.md`, and `.config/opencode/AGENTS.md`, and `opencodeFile`.
  2. Add a want-zero check for `.t3/instructions/claude-code/CLAUDE.md` on every user.
  3. Compare the Claude Code file and the OpenCode file byte for byte.
  4. Pin a small set of key sentences from the new file with anchored, whole-line matching, and keep the unrendered-template and removed-terms greps. Update `removedTerms` so it no longer bans names the new file uses legitimately.
  5. Delete the part and path rules, the per-harness tool lists, the T3 Code channel and `declaredOf`, the forced-off configurations, and `sidesGuard`.
  6. Remove the `t3code-instruction-channels` check from `flake.nix`.
- **Execution note:** Mutation-test each kept assertion by editing the instruction file in a scratch copy, following the mutation-testing and copied-worktree learnings.
- **Patterns to follow:** the collect-all-failures style already in `tests/agent-instructions.nix`.
- **Test scenarios:**
  - Negating a pinned sentence (for example inserting "never" before "apply") fails the check.
  - Deleting the GPG section fails the check.
  - Making the OpenCode file differ from the Claude file fails the check.
  - Re-adding a `home.file` at `.t3/instructions/claude-code/CLAUDE.md` fails the check.
  - Leaving a `{{` in the file fails the check.
- **Verification:** `agent-instructions` passes on every host and each mutation above fails it.

### U4. Update the documentation

- **Goal:** The docs describe one instruction file and no T3 Code part.
- **Requirements:** R11.
- **Dependencies:** U1, U2, U3.
- **Files:**
  - Modify `AGENTS.md`, `CONCEPTS.md`, `docs/provisioning.md`, `docs/verification.md`, and the comments in `scripts/opencode`.
- **Approach:**
  1. `AGENTS.md`: reword the `agents/` bullet to say the shared instructions are one file.
  2. `CONCEPTS.md`: remove "Instruction part", rewrite "Delivery path" for one file reaching every path, and drop the cross-model peer and T3 Code part wording from "Cross-model delegation".
  3. `docs/provisioning.md`: rewrite "Shared agent instructions" for the plain file, the two delivery targets, the `launchArgs` reset, and the simplified check, and remove the gomplate, part, and peer-rule text there and in the OpenCode and T3 Code paragraphs.
  4. `docs/verification.md`: replace the T3 Code instruction checks with checking that `launchArgs` is empty and that `~/.t3/instructions/claude-code/CLAUDE.md` is absent.
- **Test expectation:** none -- documentation only.
- **Verification:** No doc mentions `instructions.md.tmpl`, `render.nix`, gomplate, an instruction part, or `t3code-instruction-channels`.

---

## Verification Contract

| Gate | Command or evidence | Applies to |
| --- | --- | --- |
| Delivery build | the Claude Code file and the OpenCode instructions file build from one store path and are byte-identical | U1 |
| Formatting | `nix fmt -- --ci` | U3 (after U1 and U2 land) |
| Flake checks | `nix flake check`, plus building `agent-instructions` and `t3code-traits` | U3 (after U1 and U2 land) |
| Host outputs | every `nixosConfigurations`, `homeConfigurations`, `systemConfigs`, and `darwinConfigurations` output per `AGENTS.md`; Linux-only checks through CI or `nix derivation show` on macOS | U1, U2 |
| Mutations | the U2 and U3 mutation scenarios each fail the check | U2, U3 |
| Markdown lint | pre-commit `markdownlint-cli2` on staged docs | U4 |

## Definition of Done

- The template, `render.nix`, `tests/agent-instruction-channels.py`, and the `t3code-instruction-channels` check are gone.
- Claude Code and standalone OpenCode receive the same slim file, and T3 Code receives nothing extra.
- Checks and host outputs pass, and the mutation scenarios fail as expected.
- Docs and `CONCEPTS.md` match the new structure.
- No dead code or abandoned experiments remain in the diff.
