# Agent role routing

`home/h82/agents/instructions/instructions.md.tmpl` defines one role vocabulary shared by Claude Code, Codex, and OMP. Each role maps a kind of work (from quick status lookups and code search through implementation, review, and architecture consultation) to a model chain tried left to right. Inside T3 Code, the cross-provider T3 Code table replaces each harness's own table for delegated work, while the `root` row renders per harness and selects the starting model when a thread or session begins. Outside T3 Code, each harness uses its own provider-scoped table.

| Role | Work |
| --- | --- |
| `root` | Conversation with the user, delegation, progress |
| `scout` | Code search, grounding, evidence gathering |
| `quick` | Mechanical edits, status lookups, commit messages |
| `writing` | Documentation and prose |
| `visual` | Frontend and UI |
| `implement` | Ordinary implementation |
| `implement-high` | Feature work across several files |
| `deep` | Hard logic or debugging that evidence can settle |
| `hard-decision` | A central decision evidence cannot settle |
| `review` | CE review personas (code, doc, simplify) |
| `review-gate` | Plan review, final gate, adversarial review |
| `architect` | Architecture and plan consultation |
| `peer` | CE-required independent cross-model review |

## When delegation starts

The common instructions call for early delegation when substantial research or triage contains independently answerable questions. Examples include comparing sources, reconciling datasets, and investigating distinct plausible causes. Agents assign bounded investigations with evidence and uncertainty in the return, then the root reconciles the results and gives the final answer.

Simple lookups and indivisible dependent reasoning stay local. This policy works within user authorization, runtime restrictions, recipient permissions, and each invoked skill's ownership and sequencing rules. The role tables select the model after the agent identifies useful work to delegate.

## T3 Code table

Inside T3 Code, every harness receives its own `root` row and the same delegated role rows. Entries marked `(S)` use Synthetic and expire after 2026-11-18; Codex entries marked `Fast` run at `serviceTier` `priority`, and all other Codex entries run at `default`.

| Role | Chain |
| --- | --- |
| `root` (Claude Code) | `claudeAgent` `claude-opus-5-5` `medium` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) |
| `root` (Codex) | `codex` `gpt-6.1-sol` `high` → `codex` `gpt-6.1-sol` `medium` Fast → `codex` `gpt-6.1-sol` `medium` |
| `root` (OMP) | `omp` `google-antigravity/gemini-4-argon` `high` |
| `scout` | `codex` `gpt-6-luna` `low` Fast → `claudeAgent` `claude-haiku-5-5` `medium` → `omp` `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `high` (S) |
| `quick` | `codex` `gpt-6-luna` `low` Fast → `claudeAgent` `claude-haiku-5-5` `medium` → `omp` `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `off` (S) → `omp` `synthetic/hf:zai-org/GLM-5.3-Flash` `low` (S) |
| `writing` | `omp` `google-antigravity/gemini-4-argon` `low` → `claudeAgent` `claude-opus-5-5` `low` |
| `visual` | `omp` `google-antigravity/gemini-4-argon` `low` → `claudeAgent` `claude-fable-5-1` `max` → `claudeAgent` `claude-opus-5-5` `max` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) |
| `implement` | `claudeAgent` `claude-sonnet-5-5` `medium` → `grok` `grok-4.7` `xhigh` → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) → `codex` `gpt-6.1-sol` `medium` → `omp` `google-antigravity/gemini-3.8-flash` `high` |
| `implement-high` | `claudeAgent` `claude-opus-5-5` `medium` → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `codex` `gpt-6.1-sol` `medium` → `omp` `google-antigravity/gemini-4-argon` `high` |
| `deep` | `codex` `gpt-6.1-sol` `medium` → `codex` `gpt-6.1-sol` `medium` Fast → `claudeAgent` `claude-opus-5-5` `xhigh` |
| `hard-decision` | `codex` `gpt-6.1-sol` `max` → `claudeAgent` `claude-fable-5-1` `max` |
| `review` | `codex` `gpt-6.1-sol` `medium` → `codex` `gpt-6.1-sol` `high` → `claudeAgent` `claude-opus-5-5` `high` |
| `review-gate` | `codex` `gpt-6.1-sol` `max` → `claudeAgent` `claude-opus-5-5` `max` |
| `architect` | `claudeAgent` `claude-fable-5-1` `max` → `claudeAgent` `claude-opus-5-5` `max` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `codex` `gpt-6.1-sol` `xhigh` |
| `peer` | The external model and effort the owning CE skill selects |

## Per-harness tables

Outside T3 Code, each harness routes delegated roles within its own provider.

### Claude Code

| Role | Chain |
| --- | --- |
| `root` | `opus` `medium` |
| `scout` | `haiku` `medium` |
| `quick` | `haiku` `medium` |
| `writing` | `opus` `low` |
| `visual` | `fable` `max` → `opus` `max` |
| `implement` | `sonnet` `medium` |
| `implement-high` | `opus` `medium` |
| `deep` | `opus` `xhigh` |
| `hard-decision` | `fable` `max` |
| `review` | `opus` `high` |
| `review-gate` | `opus` `max` |
| `architect` | `fable` `max` |
| `peer` | CE selection |

### Codex

Managed startup settings use Sol `high` at service tier `default`; the default subagent uses Terra `medium`.
Sol `max` is automatic only for `hard-decision` and `review-gate`.
All other GPT `max` uses and every GPT `ultra` use require an explicit request for the affected work.

| Role | Chain |
| --- | --- |
| `root` | `gpt-6.1-sol` `high` → `gpt-6.1-sol` `medium` Fast → `gpt-6.1-sol` `medium` |
| `scout` | `gpt-6-luna` `low` Fast |
| `quick` | `gpt-6-luna` `low` Fast |
| `writing` | `gpt-6.1-terra` `medium` |
| `visual` | `gpt-6.1-terra` `medium` |
| `implement` | `gpt-6.1-terra` `medium` |
| `implement-high` | `gpt-6.1-sol` `medium` |
| `deep` | `gpt-6.1-sol` `medium` |
| `hard-decision` | `gpt-6.1-sol` `max` |
| `review` | `gpt-6.1-sol` `medium` |
| `review-gate` | `gpt-6.1-sol` `max` |
| `architect` | `gpt-6.1-sol` `medium` |
| `peer` | CE selection |

### OMP

OMP sessions use only `synthetic`, `google-antigravity`, and `openrouter`. The `openai-codex` provider is disabled in both standalone OMP and T3 Code's OMP instance. Native Codex remains available through its own CLI, T3 Code's `codex` instance, and sanctioned external reviews. Existing authentication and conversation state are preserved.

| Role | Chain |
| --- | --- |
| `root` | `google-antigravity/gemini-4-argon` `high` |
| `scout` | `google-antigravity/gemini-3.5-flash-lite` `low` |
| `quick` | `google-antigravity/gemini-3.5-flash-lite` `minimal` |
| `writing` | `google-antigravity/gemini-4-argon` `low` |
| `visual` | `google-antigravity/gemini-4-argon` `low` |
| `implement` | `google-antigravity/gemini-3.8-flash` `low` |
| `implement-high` | `google-antigravity/gemini-3.8-flash` `medium` |
| `deep` | `google-antigravity/gemini-3.8-flash` `medium` |
| `hard-decision` | `google-antigravity/gemini-4-argon` `high` |
| `review` | `google-antigravity/gemini-3.8-flash` `medium` |
| `review-gate` | `google-antigravity/gemini-4-argon` `high` |
| `architect` | `google-antigravity/gemini-4-argon` `high` |
| `peer` | CE selection |

## Usage threshold

Before delegating, the root runs `agent-usage --json` to read cached usage windows for Codex, Claude, Gemini, Grok, and Synthetic. Any provider whose provider-wide window has less than 25% remaining sets its provider-wide below-threshold flag and is skipped across the chain; a model-scoped window below 25% skips only that model's entries, while `stale` or `unknown` status alone skips nothing. When every runnable entry in a chain was skipped only because of the 25% threshold, the root uses the entry whose lowest applicable `remainingPercent` is highest and reports that every entry was below the threshold, without reviving any entry skipped for a disabled provider, unoffered model, exhausted quota, passed Synthetic expiry, or confirmed launch rejection.

## Comparison with oh-my-openagent

This routing is compared against `docs/guide/agent-model-matching.md` in <https://github.com/code-yeongyu/oh-my-openagent> on branch `dev` (commit `e31528c08b224c51af98006593f1f811de066015`), read on 2026-10-27. Syncing with oh-my-openagent is manual and on request.

| Role | This repository (T3 Code) | oh-my-openagent default | Difference |
| --- | --- | --- | --- |
| `root` (Claude Code) | `claudeAgent` `claude-opus-5-5` `medium` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) | Daily · Normal root: Opus 5.5 `medium` → Kimi K3 `max` → GLM-5.3 `max` | OMP effort caps at `high`, so `max` becomes `high` on Kimi K3 and GLM-5.3; Synthetic entries expire after 2026-11-18. |
| `root` (Codex) | `codex` `gpt-6.1-sol` `high` → `codex` `gpt-6.1-sol` `medium` Fast → `codex` `gpt-6.1-sol` `medium` | Obsessive · Normal root: Astra `medium` → Sol Fast `medium` → Sol `medium` (+GPT-5.6 Sol) | Uses Sol `high` as primary; retains the Sol fallbacks and drops the older GPT-5.6 Sol fallback. |
| `root` (OMP) | `omp` `google-antigravity/gemini-4-argon` `high` | None | OMP root Argon `high` has no oh-my-openagent counterpart. |
| `scout` | `codex` `gpt-6-luna` `low` Fast → `claudeAgent` `claude-haiku-5-5` `medium` → `omp` `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `high` (S) | `explore`, `librarian`: Kimi highspeed → Luna Fast `low` → Haiku `medium` → DeepSeek Flash `max` → Qwen/MiniMax | Kimi highspeed, Qwen, and MiniMax are unavailable here; DeepSeek Flash runs at `high` instead of `max` under the OMP cap and expires after 2026-11-18. |
| `quick` | `codex` `gpt-6-luna` `low` Fast → `claudeAgent` `claude-haiku-5-5` `medium` → `omp` `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `off` (S) → `omp` `synthetic/hf:zai-org/GLM-5.3-Flash` `low` (S) | `quick`: Luna Fast `low` → Haiku `medium` → DeepSeek Flash `off` → … Grok 4.20 non-reasoning → GLM-5.3-Flash `low` → MiMo | Grok 4.20 and MiMo are unavailable here; Synthetic entries expire after 2026-11-18. |
| `writing` | `omp` `google-antigravity/gemini-4-argon` `low` → `claudeAgent` `claude-opus-5-5` `low` | `writing`: Argon `low` → Opus 5.5 `low` → Opus 4.6 | Drops the older Opus 4.6 fallback. |
| `visual` | `omp` `google-antigravity/gemini-4-argon` `low` → `claudeAgent` `claude-fable-5-1` `max` → `claudeAgent` `claude-opus-5-5` `max` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) | `visual-engineering`: Argon `low` → Fable 5.1 `max` → Opus 5.5 `max` → Kimi K3 `max` | Kimi K3 runs at `high` instead of `max` under the OMP cap and expires after 2026-11-18. |
| `implement` | `claudeAgent` `claude-sonnet-5-5` `medium` → `grok` `grok-4.7` `xhigh` → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) → `codex` `gpt-6.1-sol` `medium` → `omp` `google-antigravity/gemini-3.8-flash` `high` | `unspecified-low`: Sonnet `medium` → MiMo → Grok 4.7 `xhigh` → GLM-5.3 `high` → Sol `medium` … | MiMo is unavailable here; appends Gemini 3.8 Flash `high`; GLM-5.3 expires after 2026-11-18. |
| `implement-high` | `claudeAgent` `claude-opus-5-5` `medium` → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `codex` `gpt-6.1-sol` `medium` → `omp` `google-antigravity/gemini-4-argon` `high` | `unspecified-high`: Opus `medium` → GLM-5.3 `max` → Kimi K3 `max` | GLM-5.3 and Kimi K3 run at `high` under the OMP cap and expire after 2026-11-18; appends Sol `medium` and Argon `high`. |
| `deep` | `codex` `gpt-6.1-sol` `medium` → `codex` `gpt-6.1-sol` `medium` Fast → `claudeAgent` `claude-opus-5-5` `xhigh` | `deep-low`: Sol `medium` → Sol Fast `medium` | Appends Opus 5.5 `xhigh` as cross-provider fallback. |
| `hard-decision` | `codex` `gpt-6.1-sol` `max` → `claudeAgent` `claude-fable-5-1` `max` | `deep-high`: Astra `high`; `ultrabrain`: Astra `max` | Uses Sol `max` automatically for this role, followed by Fable 5.1 `max`. |
| `review` | `codex` `gpt-6.1-sol` `medium` → `codex` `gpt-6.1-sol` `high` → `claudeAgent` `claude-opus-5-5` `high` | `omo-native-code-reviewer`: `unspecified-high` (Opus `medium`) | Review personas run on GPT-6.1 Sol (`medium` then `high`) instead of Opus first, with Opus 5.5 `high` as fallback. |
| `review-gate` | `codex` `gpt-6.1-sol` `max` → `claudeAgent` `claude-opus-5-5` `max` | `plan-reviewer`: Astra `xhigh` → Opus `max`; `gate-reviewer`: Astra `high` → Opus `medium` | Uses Sol `max` automatically for this role, followed by Opus 5.5 `max`. |
| `architect` | `claudeAgent` `claude-fable-5-1` `max` → `claudeAgent` `claude-opus-5-5` `max` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `codex` `gpt-6.1-sol` `xhigh` | `architect`: Fable 5.1 `max`; `plan-consultant`: Fable `max` → Opus `max` → Kimi K3 `max` | Combines both into one chain; Kimi K3 runs at `high` under the OMP cap and expires after 2026-11-18; appends Sol `xhigh`. |
| `peer` | The external model and effort the owning CE skill selects | None | Compound Engineering cross-model peer role specific to this repository. |

### Summary of differences

- OMP effort caps at `high` (the highest effort T3 Code passes to OMP), so oh-my-openagent entries at `max` become `high` on OMP entries.
- Kimi highspeed, Qwen, MiniMax, MiMo, and Grok 4.20 are unavailable here.
- GPT-6.1 Sol replaces GPT-6 Astra in all managed GPT chains, including the root.
- Review personas (`review`) run on GPT-6.1 Sol instead of Claude Opus.
- The OMP root (`google-antigravity/gemini-4-argon` `high`) has no oh-my-openagent counterpart.
- GPT-6.1 Terra `medium` handles standalone Codex writing, visual work, and routine implementation, plus the managed default subagent.
- Synthetic entries expire after 2026-11-18; other catalog Synthetic models (Qwen 3.8 27B, Nemotron 3 Super 120B, GPT-OSS-120B, GLM-4.7-Flash, and the `syn:*` aliases) run only on explicit request under the same expiry.

## Follow-up issues

- [#376](https://github.com/hyperlapse122/nix-config/issues/376): Decide whether Gemini 3.8 Flash leads the `scout` and `quick` roles.
- [#377](https://github.com/hyperlapse122/nix-config/issues/377): Remove Synthetic models from routing after 2026-11-18.
- [#378](https://github.com/hyperlapse122/nix-config/issues/378): Decide whether to remove Grok Build again.
- [#379](https://github.com/hyperlapse122/nix-config/issues/379): Route by usage pace instead of a fixed 25% remaining threshold.
- [#380](https://github.com/hyperlapse122/nix-config/issues/380): Report delegated tasks to the user as a table.
