---
title: Markdown Range Tilde Rule - Plan
type: feat
date: 2026-10-19
topic: markdown-range-tilde-rule
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Markdown Range Tilde Rule - Plan

## Goal Capsule

- **Objective:** Text an agent writes for the user, such as chat replies, pull request and issue bodies, and docs, renders without accidental strikethrough when it writes a range such as `1~3일` or an approximation such as `~5 min`.
- **Means:** Add a `# Markdown` section to the shared agent instructions template and pin its sentences in `tests/agent-instructions.nix` (KTD1, KTD2).
- **Product authority:** GitHub issue #266; the Product Contract below wins over the Planning Contract on any conflict.
- **Open blockers:** None.
- **Stop conditions:** Stop and report when the change would need to weaken or drop an existing pinned sentence or check.
- **Execution profile:** One instructions-and-check change plus a one-sentence docs update and a learning revision, implemented by `ce-work` and shipped through `lfg`.

## Product Contract

### Summary

The shared instructions gain a `# Markdown` section. In text that renders as Markdown, it tells every harness to write a range with a dash or an escaped tilde (`\~`) and an approximation with a word or an escaped tilde, in any language. Any other tilde, such as a path or a Git revision, goes in a code span, and code spans and code blocks stay as they are. In text that does not render as Markdown, it calls for a dash or a word, never `\~`. The `agent-instructions` check pins each new sentence, so removing or negating one fails the build.

### Problem Frame

GitHub-flavored Markdown treats a single pair of tildes as strikethrough. Korean, Japanese, and Chinese text often writes ranges with a tilde, such as `1~3일` or `5~10분`. When two of them sit in one paragraph, the renderer strikes through everything between them. A sentence like `빌드는 1~3분, 테스트는 5~10분 걸립니다.` renders `3분, 테스트는 5` struck through. An English approximation like `~5 min` strikes through too when a later tilde in the paragraph closes the pair, and so do two Git revisions such as `HEAD~1` and `HEAD~3` written outside a code span. Agents write this in chat replies, pull request bodies, issues, and docs, and both the terminal and T3 Code render it as Markdown. No instruction tells agents to avoid it.

### Requirements

**Instruction content**

- R1. The rendered instructions on every host tell the agent, in text that renders as Markdown, to write a range with a dash, as in `1-3` or `10:00-12:00`, or with an escaped tilde, as in `1\~3`, in every language.
- R2. The rule also covers a tilde that marks an approximation, such as `~5 min`, which the agent writes as a word or an escaped tilde.
- R3. The rule names the outputs it covers (chat replies, pull request and issue bodies and comments, and Markdown documents), tells the agent to put any other tilde, such as a path like `~/.config` or a Git revision like `HEAD~1`, in a code span, and leaves a tilde inside a code span or code block unchanged.
- R5. In text that does not render as Markdown, such as commit messages, code comments, and plain-text or config files, the rule tells the agent to write a range with a dash or a word and never with `\~`, because the backslash would show literally there.

**Check**

- R4. `agent-instructions` pins each new sentence and the new heading. It fails when a sentence is removed, reworded, negated, moved out of its section, reordered, or joined by an unpinned sentence in that section. At least one pinned sentence keeps a literal `\~`, so the check's handling of a backslash stays exercised (KTD2).

### Scope Boundaries

- Considered and not built: a check that scans repository Markdown for bare-tilde ranges. The issue asks for agent instructions only, and a stray tilde in a doc is visible in review.
- Considered and not built: rewriting existing bare-tilde ranges in tracked docs. Nothing in the issue asks for it.

### Risks

- The rule is enforced only by instruction, so a model's habit of writing `1~3일` or `~5 min` can still slip through in chat output. No deterministic gate is possible here: harness chat output is not post-processed by anything this repository configures. The pinned sentences keep the instruction present on every host; compliance is visible to the reader as soon as a strikethrough renders.

## Planning Contract

### Key Technical Decisions

- KTD1. **A new top-level `# Markdown` section, placed after `# Pull and merge requests`.** No existing section is about how agent output is written, and the rule spans chat, pull requests, and docs. The check's `topLevelHeadings` list and its per-section allowlist, membership, and order checks then cover the new section the same way they cover every other section.
- KTD2. **`requireSentences` reads its sentence through `ENVIRON` instead of `awk -v`.** `awk -v` processes escape sequences, so GNU Awk 5.4.1 turns a pinned `\~` into `~`, warns, and never finds the sentence (probed 2026-10-19: `index` returned 0 under `-v` and the right offset under `ENVIRON`). The other helpers already pass sentences through `printf '%s\n'` and `grep -F`, which keep backslashes; only `requireSentences` needs the change. `sectionSentences` passes only headings through `-v`, which hold no backslash.
- KTD3. **Pinned sentences contain no full stop followed by a space.** `sectionSentences` splits at every full stop followed by a space, so an abbreviation such as "e.g." followed by a space would split a pinned sentence in two.

### Recommended wording

The implementer may adjust the wording, provided the sentences still satisfy R1-R5 and KTD3, and at least one keeps a literal `\~` (R4):

```text
When you write a range in text that renders as Markdown, in any language, write it in prose, not in a code span, with a dash, as in `1-3` or `10:00-12:00`, or an escaped tilde, as in `1\~3`, and never with a bare `~` or `~~`, so tildes never render as strikethrough.
Treat a tilde that marks an approximation, such as `~5 min`, the same way: write "about 5 min" or `\~5 min` in prose, not in a code span.
This covers chat replies, pull request and issue bodies and comments, and Markdown documents; put any other tilde, such as a path like `~/.config` or a Git revision like `HEAD~1`, in a code span, and leave a tilde inside a code span or code block as it is.
In text that does not render as Markdown, such as commit messages, code comments, and plain-text or config files, write a range with a dash or a word, and an approximation with a word, and never with `\~`.
```

In the Nix list, each backslash in a sentence needs doubling (`\\~`), because Nix drops the backslash of an unknown escape in a double-quoted string.

### Sources

- `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`: why a pinned sentence has to start where a sentence starts.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`: mutate the instruction file to prove each new assertion fails.
- `.compound-engineering/artifacts/plans/2026-10-19-1736-feat-t3-code-notification-delegation-wait-plan.md`: the most recent change of the same shape, a template edit plus pins.

## Implementation Units

### U1. Add the Markdown section and pin it

- **Goal:** The template carries the `# Markdown` rule, and the check pins it.
- **Requirements:** R1, R2, R3, R4, R5
- **Dependencies:** None
- **Files:**
  - `home/h82/agents/instructions/instructions.md.tmpl`
  - `tests/agent-instructions.nix`
- **Approach:**
  1. Add the `# Markdown` section with the four sentences as bullets, after `# Pull and merge requests` (KTD1, KTD3).
  2. In the check, add `markdownHeading` and `markdownSentences`, then add them to `checkedSections`, `pinnedSentences`, and `topLevelHeadings` in file order.
  3. Switch `requireSentences` to read the sentence from `ENVIRON` (KTD2), and update the comment above it if it mentions how the sentence is passed.
  4. Extend the check's header comment only where it lists section-specific behavior; the generic bullets already cover the new section.
- **Patterns to follow:** `pullRequestsHeading` and `pullRequestsSentences` in `tests/agent-instructions.nix`, and their entries in `checkedSections`.
- **Execution note:** Prove each assertion by mutation, in a scratch copy that follows the copied-worktree learning in `AGENTS.md`, rather than trusting a green build.
- **Test scenarios:**
  - The unmodified template builds `checks.x86_64-linux.agent-instructions` green on every configuration.
  - Deleting the escaped-tilde sentence from the template fails the build and names that sentence.
  - Prefixing that sentence with "Do not" fails the build, because it no longer starts where a sentence starts.
  - Adding an unpinned sentence such as `Bare tildes are fine.` under `# Markdown` fails the build as an unpinned Markdown sentence.
  - Swapping two Markdown sentences fails the order check.
  - Moving the section's heading so it no longer matches the list, or renaming it, fails the top-level heading check.
  - Reverting `requireSentences` to `awk -v` fails the build on the sentence that contains `\~`, which shows the backslash reaches the check intact.
- **Verification:** The check passes on the real template, and each mutation above turns it red with a message naming the broken rule.

### U3. Revise the learning that forbids a backslash in a pinned sentence

- **Goal:** The learning on sentence-start pinning no longer tells a future editor that a pinned sentence must not contain a backslash, so nobody restores `awk -v` or strips the `\~` example on its word.
- **Requirements:** R4
- **Dependencies:** U1
- **Files:** `.compound-engineering/artifacts/solutions/best-practices/substring-sentence-check-passes-a-negated-instruction.md`
- **Approach:** Update its quoted `requireSentences` to read the sentence from `ENVIRON`, replace the sentence that bans a backslash with one that explains why `awk -v` cannot carry one (KTD2), and keep the rest of the learning as it is.
- **Test expectation:** none -- a learning document; `markdownlint-cli2` through the pre-commit hook covers its form.
- **Verification:** The learning's quoted helper matches `requireSentences` in `tests/agent-instructions.nix`, and nothing in it forbids a backslash in a pinned sentence.

### U2. Describe the section in the provisioning guide

- **Goal:** The guide's list of what the shared instructions hold includes the Markdown rule.
- **Requirements:** R1
- **Dependencies:** U1
- **Files:** `docs/provisioning.md`
- **Approach:** Add "Markdown (ranges, approximations, and other tildes without a bare tilde)" to the section list in the `### Shared agent instructions` paragraph, in file order after pull and merge requests.
- **Test expectation:** none -- one docs sentence; `markdownlint-cli2` through the pre-commit hook covers its form.
- **Verification:** The list in `docs/provisioning.md` names every top-level section of the template in order.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Pinned sentences | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | R1-R5 on every configuration |
| Full checks | `nix flake check` | No other check regressed |
| Formatting | `nix fmt -- --ci` | Nix layout |
| Host outputs | The build loop in `AGENTS.md` over `nixosConfigurations`, `homeConfigurations`, `systemConfigs` | Every output still builds with the new instructions |
| Markdown lint | `.githooks/pre-commit` on commit | `docs/provisioning.md`, the revised learning, and the plan pass `markdownlint-cli2` |

The macOS outputs build only in CI's `build-darwin` job.

## Definition of Done

- The template carries the `# Markdown` section, and the rendered files on every host hold its sentences.
- `agent-instructions` pins the heading and each sentence, and every U1 mutation turns it red.
- `docs/provisioning.md` lists the new section.
- The sentence-start learning matches the `ENVIRON` helper and no longer forbids a backslash.
- No scratch copies or mutation leftovers remain in the diff.
