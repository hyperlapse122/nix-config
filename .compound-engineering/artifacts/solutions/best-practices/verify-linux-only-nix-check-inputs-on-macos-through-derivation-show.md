---
title: Verify a Linux-only Nix check's text inputs on macOS through nix derivation show
date: "2026-10-16"
category: best-practices
module: "Nix flake checks (local verification on macOS)"
problem_type: best_practice
component: testing_framework
severity: low
applies_when:
  - "Changing a check that exists only under checks.x86_64-linux while working on the macOS host, which has no Linux builder"
  - "The check compares files built with pkgs.writeText or another text-file builder, such as an expected declaration against a rendered one"
  - "Mutation-testing such a check locally before CI builds it"
tags: ["mutation-testing", "flake-checks", "macos", "aarch64-darwin", "linux-builder", "derivation-show", "structured-attrs", "write-text", "verification"]
related_components:
  - tooling
retire_when: "The macOS host gains a Linux builder (a nix-darwin linux-builder or a remote builder), so the check builds locally"
---

# Verify a Linux-only Nix check's text inputs on macOS through nix derivation show

## Context

Many repository checks exist only under `checks.x86_64-linux`, such as `t3code-traits`, which runs `cmp -s` between an expected JSON declaration and the one a fixture host's activation hands to `scripts/agent-settings` (the `cmp -s "$declared" "$want"` line in `tests/t3code-traits.nix`). The macOS host has no Linux builder, so `nix build .#checks.x86_64-linux.t3code-traits` cannot run there, and waiting for CI to learn whether a test edit goes red and then green makes mutation testing slow. Issue #224 changed both the module and that check from the Mac.

## Guidance

Evaluation is platform-independent, so the check's derivation graph is available on macOS even though it cannot be built there. A text file built with `pkgs.writeText` carries its whole content in its derivation, under `structuredAttrs.text` in `nix derivation show` output. Compare those strings directly:

```python
import json, subprocess, sys

drv = subprocess.check_output(
    ["nix", "eval", "--raw", ".#checks.x86_64-linux.t3code-traits.drvPath"], text=True
).strip()
graph = json.loads(subprocess.check_output(["nix", "derivation", "show", "-r", drv], text=True))
graph = graph.get("derivations", graph)

def text(fragment):
    names = [k for k in graph if k.endswith(fragment + ".drv")]
    if len(names) != 1:
        sys.exit("expected one derivation for {}, found {}".format(fragment, names))
    return graph[names[0]]["structuredAttrs"]["text"]

ok = True
for kind in ("settings", "client-settings"):
    same = text("t3code-expected-" + kind + ".json") == text("t3code-declared-" + kind + ".json")
    ok &= same
    print(kind, "match" if same else "MISMATCH")
sys.exit(0 if ok else 1)
```

`nix derivation show -r` walks every input of the check, so the declared file appears even though it reaches the check only through the fixture host's activation script. Match on the derivation name, and fail when a name matches zero or several derivations rather than picking one.

## Why This Matters

With this, the red-green loop and each mutation run locally in seconds. For issue #224, updating the expectation first produced a MISMATCH, the module change turned both files to `match`, and three mutations (the key back in `settings`, an empty `retiredKeys`, no `inherit remove`) each produced a MISMATCH again.

It is a check of the inputs, not of the check. The comparison never runs the check's shell logic: the activation exercise, the merger's exit status, or the `cmp` itself. A mutation that breaks only that logic passes here. CI's `check-shards` build stays the evidence for the check as a whole, and a report should say which of the two produced each result.

## When to Apply

- The check's assertion reduces to equality or content of text files the graph already holds.
- You are on the macOS host and need red-green or mutation evidence before pushing.

It does not apply to a check whose inputs are built outputs rather than text derivations, such as a host closure, or to assertions made inside the check's builder script.

## Examples

Without this, the only local evidence for a `checks.x86_64-linux` edit made on the Mac is `nix flake check --no-build --all-systems`, which proves the check still evaluates and nothing about whether it passes. With it, run the script before the module change (expect MISMATCH), after it (expect match), and once per mutation (expect MISMATCH), then restore the tree before committing.

## Related

- [Mutation testing reveals decorative assertions in a Nix flake check](mutation-testing-reveals-decorative-nix-check-assertions.md): why each guard needs a mutation that breaks it.
- [Mutations that only break evaluation](unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md): a mutation must reach the compared text, not just fail evaluation.
- [A T3 Code setting declared in settings.json outranks every repository's t3.json](../integration-issues/t3code-settings-json-value-outranks-repository-t3-json.md): the change this technique verified.
