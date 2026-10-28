---
title: Usage Pace Routing - Plan
type: feat
date: 2026-10-28
topic: usage-pace-routing
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

# Usage Pace Routing - Plan

## Goal Capsule

- **Objective:** Delegated work stops landing on a provider that is spending its allowance faster than its window allows, and stops being kept off a provider whose leftover allowance is about to reset unused.
- **Means:** Replace the fixed 25% remaining threshold in `agent-usage` and the routing instructions with a per-window pace judgment plus a 10% hard floor (KTD2, KTD3).
- **Product authority:** The user chose skip-only routing, a 10 percentage point tolerance, pace on every window length, a least-ahead fallback, and a 10% floor in the brainstorm on 2026-10-28 for issue #379. The Product Contract wins on behavior; KTDs win on mechanism.
- **Execution profile:** Standard; three implementation units in `scripts/agent-usage`, the shared instructions template, `docs/agent-routing.md`, and their tests.
- **Stop conditions:** Stop and report if a provider's live payload contradicts a duration KTD1 assigns, or if the instructions template cannot express R6 without new template data.
- **Open blockers:** None.

---

## Product Contract

### Summary

`agent-usage` judges each usage window by pace: a window is ahead of pace when its used share exceeds its elapsed share by more than 10 percentage points.
A 10% remaining floor replaces the 25% threshold.
The root keeps chain order and skips only entries whose provider or model is ahead of pace or below the floor; when every entry is skipped, it uses the least-ahead one.

### Problem Frame

The T3 role routing plan (`.compound-engineering/artifacts/plans/2026-10-27-1037-feat-t3-role-routing-plan.md`, R21) skips a provider when any window has less than 25% left, wherever the window is in its cycle.
A weekly window with 20% left an hour before reset is skipped although that allowance will be discarded, while a provider that burned 70% on the first day keeps receiving work until it crosses 25%.
On 2026-10-28 Codex's weekly window showed 78% used with about 29% of the window elapsed; Codex is the first entry of the `deep`, `review`, `review-gate`, `scout`, and `quick` chains.

### Key Decisions

- **Pace only skips; it never reorders a chain.** Chain order encodes which family does each kind of work best, so a behind-pace provider never jumps ahead of an earlier entry. (session-settled: user-directed — chosen over reordering behind-pace entries ahead and over using pace only in the all-skipped fallback: keep best-fit order while stopping overspend.) Governs R4.
- **The tolerance is an absolute 10 percentage points.** It absorbs an early burst in a window and still catches heavy overspend. (session-settled: user-directed — chosen over 20 points, a 1.25x ratio, and zero tolerance.) Governs R1.
- **Every window is judged by pace, whatever its length.** (session-settled: user-directed — chosen over floor-only judgment for windows shorter than a day and over ignoring short windows: one rule for every window.) Governs R1, R2.
- **When every entry is skipped, use the least-ahead one.** (session-settled: user-directed — stated by the user in place of the current most-remaining fallback.) Governs R6.
- **A 10% hard floor replaces the 25% threshold.** It blocks a window that one large task could exhaust without discarding late-window allowance, and it is the only judgment for windows whose elapsed share cannot be known. (session-settled: user-directed — chosen over keeping 25% and over no floor.) Governs R3.
- **Floor-skipped entries rank after pace-skipped entries in the fallback.** An entry below 10% is closer to failing mid-task than one that is only ahead of pace. Governs R6.

### Requirements

**Window judgment**

- R1. A window is ahead of pace when its used percent is strictly greater than its elapsed percent plus 10, where elapsed percent is the share of the window's duration that has passed before its reset time.
- R2. A window's duration comes from the duration its provider reports, or else from the kind of limit the provider names (`five_hour` is 5 hours; `seven_day`, `weekly`, and Claude's model-scoped limits are 7 days); a window with neither, and Synthetic's rolling weekly quota, is judged by R3 alone.
- R3. A window is below the floor when its remaining percent is strictly less than 10, regardless of pace.
- R4. A provider-wide window that is ahead of pace or below the floor skips every entry of that provider; a model-scoped window skips only that model's entries; chain order is otherwise unchanged.
- R5. A `stale` or `unknown` provider status alone skips nothing, and a stale window whose reset time has passed takes no part in R1 or R3, as today.

**Fallback and reporting**

- R6. When every runnable entry of a chain was skipped only under R4, the root uses the pace-skipped entry with the smallest overshoot, where an entry's overshoot is the largest used-minus-elapsed-minus-10 across its applicable windows; entries skipped for the floor rank after all pace-skipped entries, among themselves by most remaining.
- R7. Entries skipped for any other reason (disabled provider, unoffered model, exhausted usage, passed Synthetic expiry, confirmed launch rejection) are never revived by R6.
- R8. The root reports each skipped entry with whether it was ahead of pace or below the floor, and reports when R6 chose an entry because every entry was skipped.

**Ownership and consistency**

- R9. `agent-usage` performs the R1 to R4 arithmetic and exposes the result per window, per provider, and per model, plus what R6 needs to rank entries, so all three harnesses act on the same judgment.
- R10. The routing rule in `home/h82/agents/instructions/instructions.md.tmpl`, the "Usage threshold" section of `docs/agent-routing.md`, and the tests that pin either one describe the pace rule and no longer mention the 25% threshold.

### Acceptance Examples

- AE1. **Covers R1, R4.** **Given** Codex's weekly window is 78% used with 29% elapsed, **when** the root delegates `deep` work, **then** it skips Codex `gpt-6.1-sol` and reports Codex as ahead of pace.
- AE2. **Covers R1, R3.** **Given** a provider's only window is 80% used with one hour of a 7-day window left, **when** the root delegates to it, **then** the entry is used, because it is behind pace and 20% remains.
- AE3. **Covers R1, R2.** **Given** Claude's `five_hour` window is 30 minutes in (10% elapsed), **when** it is 21% used, **then** every Claude entry is skipped; **when** it is 20% used, **then** none is.
- AE4. **Covers R2, R3.** **Given** Synthetic's rolling weekly quota has 8% remaining, **when** a chain reaches a Synthetic entry, **then** it is skipped as below the floor; with 30% remaining it is not skipped.
- AE5. **Covers R4.** **Given** Claude's model-scoped Fable window is ahead of pace and its provider-wide windows are not, **when** the root delegates `architect` work, **then** it skips Claude Fable 5.1 and uses Claude Opus 5.5.
- AE6. **Covers R6, R8.** **Given** every entry of a chain is ahead of pace, with overshoots of 25, 5, and 12 points, **when** the root delegates, **then** it uses the entry overshooting by 5 and reports that every entry was skipped.
- AE7. **Covers R6.** **Given** a chain has one entry ahead of pace with 40% remaining and one below the floor with 6% remaining, **when** both are skipped, **then** the root uses the ahead-of-pace entry.
- AE8. **Covers R5.** **Given** a provider is `stale` and its cached weekly window's reset time has passed, **when** the root reads it, **then** that window skips nothing.

### Scope Boundaries

- Reordering chains by pace, or moving work to a behind-pace provider ahead of its chain position.
- Pace judgment for Synthetic's rolling quota from its regeneration rate.
- Changing which providers `agent-usage` reads, its cache lifetimes, or its stale handling beyond R5.
- Changing any routing table or chain entry.

### Sources / Research

- `scripts/agent-usage`: `thresholds()` holds the current 25% arithmetic; the readers show which providers report `durationMins` (Codex, Gemini), which report a period start and end (Grok), which report only a reset time (Claude), and Synthetic's `nextRegenAt` rolling quota.
- `home/h82/agents/instructions/instructions.md.tmpl`: the current usage-check and fallback sentences in the model chains section.
- `tests/test_agent_usage.py` and `tests/agent-instructions.py`: tests that pin the threshold flags and the instruction sentences.
- `docs/agent-routing.md`: the "Usage threshold" section.
- Issue [#379](https://github.com/hyperlapse122/nix-config/issues/379).

---

## Planning Contract

Product Contract preservation: changed R2 — the duration source now names Claude's model-scoped limits as 7-day windows, resolving the brainstorm's deferred question so those windows are paced instead of floor-only; the two deferred questions are answered by KTD1 and KTD2; no other scope change.

### Key Technical Decisions

- KTD1. **Each reader records `durationMins` on the windows whose length it knows; the judgment reads only that field.** Codex already records it; the Gemini reader records it only when the limit reports a positive `durationMs`, instead of today's 0 when it is missing. The Claude reader sets 300 for `five_hour`, 10080 for `seven_day`, the legacy `seven_day_*` model windows, and every `model_scoped` entry. The Grok reader sets `currentPeriod.end` minus `currentPeriod.start` in minutes when both are present. Synthetic's `subscription` window and a Grok period without a start get none, so R2 sends them to R3 alone. Keeping the label knowledge in the reader that parses the payload means the judgment never pattern-matches labels. Implements R2.
- KTD1a. **Amended after #403 retired OMP's Antigravity provider.** The Gemini reader now refreshes the shell Antigravity ACP runtime's own OAuth credential (`$GEMINI_HOME/antigravity-acp/acp_token.json`) and reads Google's `retrieveUserQuotaSummary`, keeping only `gemini-` buckets. It maps the `weekly` window to 10080 minutes and `5h` to 300, and any other window gets no `durationMins`. The service omits the Gemini buckets unless the User-Agent names a current ACP client, so the `agent-usage` wrapper passes the pinned ACP version. Without a sign-in the provider stays `unknown` with a reason. U1 step 3 below describes the superseded OMP reader.
- KTD2. **A new judgment step replaces `thresholds()` and the `belowThreshold` fields are removed rather than kept with new meaning.** Each routing window gains `elapsedPercent` (null without a positive duration and a reset time), `aheadOfPace`, `belowFloor`, and `overshootPercent` (used minus elapsed minus 10, null when unpaced). Each provider gains `skip`, `skipReason` (`below floor` when any skipping provider-wide window is below the floor, otherwise `ahead of pace`, null when not skipped), `overshootPercent` and `remainingPercent` over its provider-wide windows, and `skipModels`, a map from each skipped model to its `skipReason`, `overshootPercent`, and `remainingPercent` combined with the provider-wide values (the larger overshoot, the smaller remaining share, `below floor` when either is). Renaming makes any consumer still reading `belowThreshold` fail loudly instead of acting on a changed meaning; the only consumers are the instructions and the tests this plan updates. Implements R1, R3, R4, R5, R9.
- KTD3. **Elapsed share is computed at report time from the cached window, clamped to 0-100.** The cache already stores raw windows and the judgment already runs per report, so a cached record keeps aging correctly within its 60-second freshness. A reset time further away than the duration (a window not yet started) clamps to 0; a passed reset on a fresh `ok` record clamps to 100. Implements R1.
- KTD4. **The root, not the utility, ranks the fallback, using the provider and `skipModels` fields.** An entry reads its model's `skipModels` values when present and its provider's otherwise, so the root compares one set of values per entry; the utility cannot rank entries because it does not know the chains. The instruction sentence carries this rule. Implements R6, R7, R8.
- KTD5. **The text report adds elapsed share and pace state per window.** People running `agent-usage` by hand see why a provider would be skipped, using the same fields as the JSON. Implements R8, R9.

### Assumptions

- Claude's `model_scoped` limits are weekly. Evidence: on 2026-10-28 the `Fable` window's reset time matched `seven_day`'s to the second, and the legacy model windows are named `seven_day_opus` and `seven_day_sonnet`.
- Grok's billing reply carries `currentPeriod.start`, as the existing test fixture does; a reply without it leaves Grok floor-only.
- Synthetic's `subscription` window behaved like a 5-hour window on 2026-10-28, but no source confirms its length, so it stays floor-only under R2.

### Sequencing

U1 lands first because U2's pace tests need durations on Claude and Grok windows. U3 depends on U2's field names.

---

## Implementation Units

### U1. Record window durations in the Claude and Grok readers

**Goal:** Every window whose length is known carries `durationMins` before judgment.

**Requirements:** R2; KTD1.

**Dependencies:** None.

**Files:**

- `scripts/agent-usage`
- `tests/test_agent_usage.py`

**Approach:**

1. In `claude()`, pass the duration KTD1 assigns to each `window(...)` call for `five_hour`, `seven_day`, `seven_day_*`, and `model_scoped` entries.
2. In `grok()`, pass the period length from `start` and `end` when both are present.
3. In `gemini()`, pass `durationMins` only when `durationMs` is present and positive.
4. Leave Synthetic's readers unchanged.

**Patterns to follow:** `codex()` and `gemini()` already pass `durationMins=` through `window(...)`'s `**extra`.

**Test scenarios:**

- The fixture's Claude windows report `durationMins` 300 for `five_hour`, 10080 for `seven_day`, and 10080 for the `Fable` model-scoped window.
- The legacy `seven_day_opus` and `seven_day_sonnet` windows report 10080.
- A Grok period with `start` and `end` seven days apart reports 10080, and a Grok period without `start` reports no `durationMins`.
- A Gemini limit without `durationMs` reports no `durationMins`.
- Synthetic's `subscription` and `weekly rolling` windows report no `durationMins`.

**Verification:** The live smoke run of the working-tree script shows durations on every Claude window and on Grok's window, and none on Synthetic.

### U2. Replace the 25% threshold with pace and floor judgment

**Goal:** `agent-usage` reports per-window pace and floor state and per-provider and per-model skip results.

**Requirements:** R1, R3, R4, R5, R9; KTD2, KTD3, KTD5.

**Dependencies:** U1.

**Files:**

- `scripts/agent-usage`
- `tests/test_agent_usage.py`

**Approach:**

1. Replace `thresholds()` with the judgment KTD2 defines, keeping its resource split and its stale-past-reset handling (R5).
2. Compute `elapsedPercent` per KTD3; leave pace fields null when the window has a missing or non-positive duration, no `resetsAt`, or a null `remainingPercent`.
3. Aggregate provider-wide windows into the provider fields and model-scoped windows into `skipModels`.
4. Extend the text report per KTD5.
5. Replace the threshold tests with pace tests; keep the stale-window test, asserting `skip` is false.

**Execution note:** Write the boundary tests first; strict comparisons at exactly 10 points and exactly 10% remaining are where an off-by-one hides. Pin the 10-point boundary on a window whose elapsed share clamps to 0, because elapsed share computed from wall-clock time drifts past any mid-window target.

**Patterns to follow:** The existing tests set fixture `resetsAt` relative to `time.time()` and call `self.invoke('--refresh')` after `self.save()`.

**Test scenarios:**

- Covers AE1. A 10080-minute window 78% used with about 29% elapsed sets `aheadOfPace`, provider `skip`, and `skipReason` `ahead of pace`.
- Covers AE2. A 10080-minute window 80% used with one hour left is not ahead and not below the floor, so the provider is not skipped.
- Covers AE3. A 300-minute window with 270 minutes left (10% elapsed) skips at 21% used and does not skip at 20% used.
- Covers AE4. Synthetic's rolling weekly quota with 8% remaining skips with `below floor`; with 30% remaining it does not skip and has null pace fields.
- A window whose reset is further away than its duration (elapsed clamped to 0) is not ahead of pace at exactly 10% used and is ahead at 10.1% used.
- A window with exactly 10% remaining is not below the floor; 9.9% is.
- A window with `durationMins` 0 reports null pace fields and does not raise.
- Covers AE5. A model-scoped `Fable` window ahead of pace lists `Fable` in `skipModels` with its overshoot and leaves provider `skip` false.
- When the provider is also skipped, a `skipModels` entry carries the larger of the two overshoots, the smaller remaining share, and `below floor` if either side is below the floor.
- A provider-wide window both ahead of pace and below the floor reports `skipReason` `below floor`.
- Provider `overshootPercent` is the largest overshoot among its provider-wide paced windows.
- A reset time further away than the duration yields `elapsedPercent` 0.
- Covers AE8. A stale provider whose window reset has passed reports null pace fields and `skip` false.
- The JSON output contains no `belowThreshold` or `belowThresholdModels` key.
- The text report shows elapsed share and pace state for a paced window.

**Verification:** The `agent-usage` check passes, and the live smoke run shows Codex skipped as ahead of pace when its weekly window is ahead.

### U3. Update the routing instructions, routing guide, and instruction test

**Goal:** The root acts on the pace fields, ranks the fallback by least overshoot, and the documentation describes the same rule.

**Requirements:** R6, R7, R8, R10; KTD4.

**Dependencies:** U2.

**Files:**

- `home/h82/agents/instructions/instructions.md.tmpl`
- `tests/agent-instructions.py`
- `docs/agent-routing.md`

**Approach:**

1. Rewrite the two usage sentences in the model chains section: skip on provider `skip` and `skipModels`, report `skipReason`, and keep the `stale`/`unknown` sentence.
2. Rewrite the fallback sentence per R6 and KTD4, keeping "never revive an entry skipped for any other reason".
3. Mirror both sentences in `ROUTING_SENTENCES` and the rendered contract in `tests/agent-instructions.py`.
4. Rewrite the "Usage threshold" section of `docs/agent-routing.md` for pace and the floor, and drop #379 from its follow-up issues list.

**Patterns to follow:** The existing sentence style in the model chains section; `docs/agent-routing.md` describes the same rule in prose without field names beyond `agent-usage --json`.

**Test scenarios:**

- The rendered instructions for Claude Code, Codex, and OMP contain the new skip and fallback sentences verbatim.
- No rendered instruction file mentions `below-threshold` or 25%.

**Verification:** The `agent-instructions` check passes, and `docs/agent-routing.md` no longer mentions a 25% threshold.

---

## Verification Contract

| Gate | Command | Applies to |
| --- | --- | --- |
| Usage utility tests | `nix build --no-link .#checks.x86_64-linux.agent-usage` | U1, U2 |
| Instruction rendering | `nix build --no-link .#checks.x86_64-linux.agent-instructions` | U3 |
| Formatting and whitespace | `nix fmt -- --ci` and `git diff --check` | all |
| Markdown lint | `markdownlint-cli2` on changed Markdown | U3, this plan |
| Live smoke | `python3 scripts/agent-usage --refresh --json` and the same without `--json`, with `NODE_PATH` set to the value the installed `agent-usage` wrapper exports | U1, U2 |
| Full evidence | Current-head CI, which builds every check shard and host output | before readiness |

The installed `agent-usage` keeps running the previous script until the next rebuild, so the live smoke runs the working-tree script. Host outputs change only through the rendered instructions and the `agent-usage` package; CI's host builds cover them, so no local full host build is required beyond the checks above.

---

## Definition of Done

- Every R1 to R10 holds and every AE has a passing test or rendered-text assertion.
- No file in the repository refers to the 25% usage threshold or the `belowThreshold` fields, except historical plans and learnings.
- The `agent-usage` and `agent-instructions` checks pass locally, and current-head CI is green.
- No abandoned-attempt code remains in the diff.
