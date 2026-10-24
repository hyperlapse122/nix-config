---
title: Prefer native file I/O tools in shared agent instructions
date: 2026-10-24
type: docs
artifact_contract: ce-unified-plan/v1
execution: code
product_contract_source: ce-plan-bootstrap
---

# Prefer native file I/O tools

## Goal Capsule

Deliver issue #327 by adding a harness-neutral file I/O policy to the shared instructions and verifying its delivery to all four configured harnesses.
Implementation and PR publication are authorized; merging remains with the user.

## Product Contract

### Summary and Problem Frame

The shared instructions do not currently direct agents to use available native file tools, allowing routine reads and edits to be performed through unnecessary shell scripts.

### Requirements

- R1. Prefer the harness's available native read, write, edit, or patch tools for routine file I/O when a suitable tool exists.
- R2. Allow shell commands or scripts when no suitable native tool exists or the operation requires a command-line tool.
- R3. Preserve the existing secret-handling policy, including piping decrypted output directly to its consumer without opening it with file tools.
- R4. Deliver the rule to Claude Code, Codex, Pi, and Antigravity through their existing shared template.

The scope is shared prose and its existing delivery contract; harness configuration and secret processing remain unchanged.

## Planning Contract

- KTD1. Add a dedicated File I/O section in `home/h82/agents/instructions/instructions.md.tmpl`; name capabilities rather than harness-specific tool identifiers.
- KTD2. Extend the existing policy table and heading contract in `tests/agent-instructions.py`, guarding the preference, fallback, and secret-handling exception with its deletion, negation, and duplication controls and materialized-delivery checks in `tests/agent-instructions.nix`.
- KTD3. Explicitly defer secret handling to the existing GPG and encryption rules; retain those rules verbatim.

## Implementation Units

### U1. Define and guard the shared file I/O policy

- **Files:** `home/h82/agents/instructions/instructions.md.tmpl`, `tests/agent-instructions.py`.
- **Approach:** Implement R1-R3 in a short section and extend the existing policy contract for the preference, fallback, and secret-handling exception sentences.
- **Test scenarios:** Removing, negating, or duplicating any of the three policy sentences must fail; the unchanged secret policy must still pass.
- **Verification:** Run the existing Python content checks, including a baseline against the previous template to establish the intended failure.

### U2. Verify delivery and repository integration

- **Files:** Existing instruction rendering and delivery declarations; no planned production changes beyond U1.
- **Approach:** Verify R4 at materialized Home Manager delivery paths using the existing agent-instructions check on supported builders.
- **Test scenarios:** All four files match independent rendering and contain the new policy; existing recipient and secret boundaries remain valid.
- **Verification:** Run formatting, flake checks, and applicable output builds. Report platform-dependent builds separately and use CI for Linux VM evidence unavailable on macOS.

## Verification Contract

Run the Python instruction content checks and the applicable Nix agent-instructions check, plus repository-required formatting, flake checks, VM builds, and host output builds where the platform supports them.
Local content checks prove policy boundaries; materialized-delivery checks prove packaging and delivery.
No real credentials or system activation are needed.

## Definition of Done

R1-R4 are implemented and verified, the existing secret policy is preserved, all review findings are resolved, and a PR linked to issue #327 has decided CI evidence.
