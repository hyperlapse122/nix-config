---
title: "A substring check for a required instruction sentence passes when the sentence is negated"
date: 2026-10-12
last_updated: 2026-10-14
category: best-practices
module: "Agent instructions render check (tests/agent-instructions.nix)"
problem_type: best_practice
component: testing_framework
severity: medium
applies_when:
  - "A flake check requires a sentence of agent instructions or other prose to be present with grep -F or another substring match"
  - "The guarded text is an imperative whose meaning flips when words are added in front of it, such as Do not or Never"
  - "Mutation-testing a prose check where the mutation list only deletes guarded sentences"
  - "A rule whose reversal could be added as a separate sentence beside the guarded one, which no required-sentence check can see"
root_cause: logic_error
resolution_type: test_fix
related_components:
  - tooling
tags:
  - mutation-testing
  - flake-checks
  - nix
  - grep
  - agent-instructions
---

# A substring check for a required instruction sentence passes when the sentence is negated

## Context

`tests/agent-instructions.nix` renders the shared agent instructions for each harness and requires a list of literal sentences in every rendered file. Until this change, its helper `requireSentences` tested each one with `grep -qF -- "$sentence" "$file"`. The check had been mutation-tested by deleting each guarded sentence, and every deletion turned it red.

While rewriting the `# Review findings` section (plan `.compound-engineering/artifacts/plans/2026-10-12-0908-feat-review-findings-override-plan.md`), a cross-model adversarial review ran a mutation the deletion rounds never tried: it prefixed the guarded coverage sentence with "Do not". Every assertion still passed for Claude Code, Antigravity, and Codex. The sentence was still a substring of the line, so the check stayed green while the rendered instruction now told agents the opposite of the rule. The same review found that the new stop for a fix that would reverse a user decision had no guard at all; deleting that bullet also left the check green.

A deletion round proves only that the check notices the text is gone. Prose instructions change meaning through additions as easily as through removal, and a substring match cannot see additions.

## Guidance

Match a required sentence only where a sentence begins, and add a negation round to the mutation list.

The helper now accepts a sentence only when the text before its first occurrence on a line is empty, a list marker (a hyphen and a space), or ends with the full stop and space of the previous sentence (`tests/agent-instructions.nix:266-281`):

```nix
requireSentences = message: sentences: ''
  for sentence in ${lib.escapeShellArgs sentences}; do
    if ! awk -v s="$sentence" '
      {
        i = index($0, s)
        if (i == 0) next
        pre = substr($0, 1, i - 1)
        if (pre == "" || pre == "- " || pre ~ /\. $/) found = 1
      }
      END { exit !found }
    ' "$file"; then
      echo ${esc message} "$sentence" >&2
      failed=1
    fi
  done
'';
```

`index` is a fixed-string search, so backticks, `#`, `/`, and other punctuation in the sentences need no escaping. `awk -v` does interpret backslash escapes, so a guarded sentence must not contain a backslash. None does today.

A sentence-start match still passes when the reversal is a separate sentence. Adding the Antigravity cross-model peer for issue #206, a cross-model adversarial review kept the pinned "also delegate that pass to Antigravity" sentence and added "Do not delegate the pass to Antigravity." after it. The pinned sentence still began where a sentence begins, so the check stayed green while the section now said both things. No list of forbidden phrases closes this, because a reversal can be worded any way.

Close it with an allowlist over the section instead: every sentence in the named section that mentions the guarded subject must be one of the pinned sentences, and the section heading must exist, or the allowlist checks nothing (`tests/agent-instructions.nix:283-311`). The pinned subset is derived from the required list, so there is one list to maintain:

```nix
antigravitySentences = lib.filter (
  sentence: lib.hasInfix "Antigravity" sentence || lib.hasInfix "Argon" sentence
) delegationSentences;
```

`onlyPinnedSentences` takes the lines under `# Cross-model delegation` up to the next top-level heading, strips the list marker, splits sentences on a full stop followed by a space, keeps those matching `Antigravity|Argon`, and fails on any that is not in the pinned list. The split assumes no guarded sentence contains a full stop followed by a space, such as "e.g. "; a sentence that did would be reported as unpinned, which fails red.

When a rule has a safety stop, guard the stop as its own sentence. The review-findings rule tells autonomous runs to apply the recommended fix. Without a guarded sentence for the stop that protects user decisions, deleting the stop leaves the permissive half guarded and green.

## Why This Matters

A guard on agent instructions exists to catch an edit that changes what agents do. Negating an imperative is the smallest such edit, and a substring check accepts it. The failure is silent: the build stays green, and the rendered `~/.claude/CLAUDE.md`, `~/.gemini/config/AGENTS.md`, and `~/.codex/AGENTS.md` all carry the inverted rule.

## When to Apply

- Any check that requires sentences of prose, not identifiers, to be present.
- Whenever a prose guard is mutation-tested: add one round that prefixes a guarded sentence with "Do not", and one that adds a reversal as a separate sentence and as a separate bullet, beside the deletion rounds.
- When a section's rules about one subject must not be contradicted, check that every sentence in the section naming that subject is pinned, not only that the pinned sentences are present.
- When a rule pairs a permission with a limit on it, such as "apply the recommended fix" with "stop when it reverses a user decision": guard the limit too.

## Examples

The mutation runner used for this change applied each edit in a scratch copy built per `copied-git-worktree-writes-the-real-index.md`, then built `checks.x86_64-linux.agent-instructions`:

| Mutation | `grep -qF` helper | Sentence-start helper |
| --- | --- | --- |
| Delete the coverage sentence | red | red |
| Prefix the coverage sentence with "Do not" | green (missed) | red, 12 assertion lines |
| Delete the user-decision stop bullet | green (unguarded) | red after adding its sentence |

Twelve lines means three harnesses times four host generations: the NixOS host and its bootstrap twin, and the x86_64 fixture host and its twin.

The helper checks only the first occurrence of a sentence on each line. A line that holds a negated copy before a real one is reported as missing. That error fails red, which is the safe direction, so it was left as is.

For the Antigravity peer, the same runner showed:

| Mutation | Sentence-start helper alone | With the section allowlist |
| --- | --- | --- |
| Add "Do not delegate the pass to Antigravity." after the pinned bullet's last sentence | green (missed) | red |
| Add a bullet "Never use Argon for a cross-model pass." | green (missed) | red |
| Rename the `# Cross-model delegation` heading | green | red, section missing |

## Related

- `unanchored-grep-fragment-misses-destination-argument.md`: a `grep -F` fragment that omits the part carrying the claim still matches after the claim changes.
- `compound-condition-clause-assertions-miss-connective-mutations.md`: per-clause substring checks pass when the connective between clauses flips.
- `mutation-testing-reveals-decorative-nix-check-assertions.md`: text assertions fail in the direction of passing; mutate the check and require red.
