# Agent role routing

`home/h82/agents/instructions/instructions.md.tmpl` defines one role vocabulary shared by Claude Code, Codex, OMP, and the Antigravity CLI (`agy`). Antigravity ACP sessions, which T3 Code's `antigravity` instance and Compound Engineering peers run, load no global instruction files, so a delegating agent puts the rules such a task needs in its prompt. Each role maps a kind of work (from quick status lookups and code search through implementation, review, and architecture consultation) to a model chain tried left to right. Inside T3 Code, the cross-provider T3 Code table replaces each harness's own table for delegated work, while the `root` row renders per harness and selects the starting model when a thread or session begins. Outside T3 Code, each harness uses its own provider-scoped table.

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

## Conversation language

The shared instructions include the OS Locale and preferred language, captured when the user environment is applied.
NixOS reads the effective Plasma translation preference, while macOS reads the first entry in the user's preferred-language list.
Region does not determine the conversation language.
An explicit language request takes precedence, and repository or task rules still determine the language of saved artifacts.

The installed prompts are static between applies; agents do not query OS language settings at startup.
On NixOS, use `nr switch` or `nr test` to refresh after a preference change even when the Home Manager generation is unchanged.
Direct `nixos-rebuild` can skip Home Manager activation in that case.
On macOS, each apply runs the refresh through Home Manager activation.
Build-only and boot-only operations leave the currently installed prompts unchanged.
Non-NixOS Linux retains its configured Home Manager language preference without OS discovery.

### Rolling back across this migration

On NixOS and macOS, this change replaces the three Home Manager instruction symlinks with generated regular files.
Generations built before this change still expect to install symlinks at those paths and will refuse to overwrite the regular files during rollback.
Before activating such a generation, move the generated files into a private backup directory:

```bash
mkdir -p "$HOME/.local/state/nix-config"
backup=$(mktemp -d "$HOME/.local/state/nix-config/instructions-rollback.XXXXXX")
for file in .claude/CLAUDE.md .codex/AGENTS.md .omp/agent/AGENTS.md; do
  if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
    mkdir -p "$backup/$(dirname "$file")"
    mv "$HOME/$file" "$backup/$file"
  fi
done
printf 'Instruction backup: %s\n' "$backup"
```

Then run the normal rollback procedure.
If that activation fails, restore these files from the printed backup directory before using the agents again.
Already-built generations cannot acquire a cleanup hook from this repository change; their collision checks remain intact.

## When delegation starts

The common instructions call for early delegation when substantial research or triage contains independently answerable questions. Examples include comparing sources, reconciling datasets, and investigating distinct plausible causes. Agents assign bounded investigations with evidence and uncertainty in the return, then the root reconciles the results and gives the final answer.

Simple lookups and indivisible dependent reasoning stay local. This policy works within user authorization, runtime restrictions, recipient permissions, and each invoked skill's ownership and sequencing rules. The role tables select the model after the agent identifies useful work to delegate.

## T3 Code table

Inside T3 Code, Claude Code, Codex, and OMP each receive their own `root` row and the same delegated role rows. The Antigravity CLI receives only the delegated rows, because no Antigravity-led T3 Code session reads these instructions. Entries marked `(S)` use Synthetic and expire after 2026-11-18, and OMP may use them automatically inside and outside T3 Code until then; Codex entries marked `Fast` run at `serviceTier` `priority`, and all other Codex entries run at `default`.

| Role | Chain |
| --- | --- |
| `root` (Claude Code) | `claudeAgent` `claude-opus-5-5` `medium` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) |
| `root` (Codex) | `codex` `gpt-6.1-sol` `high` → `codex` `gpt-6.1-sol` `medium` Fast → `codex` `gpt-6.1-sol` `medium` |
| `root` (OMP) | `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) |
| `scout` | `codex` `gpt-6-luna` `low` Fast → `claudeAgent` `claude-haiku-5-5` `medium` → `omp` `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `high` (S) |
| `quick` | `codex` `gpt-6-luna` `low` Fast → `claudeAgent` `claude-haiku-5-5` `medium` → `omp` `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `off` (S) → `omp` `synthetic/hf:zai-org/GLM-5.3-Flash` `low` (S) |
| `writing` | `antigravity` `gemini-4-argon-low` → `claudeAgent` `claude-opus-5-5` `low` |
| `visual` | `antigravity` `gemini-4-argon-low` → `claudeAgent` `claude-fable-5-1` `max` → `claudeAgent` `claude-opus-5-5` `max` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) |
| `implement` | `claudeAgent` `claude-sonnet-5-5` `medium` → `grok` `grok-4.7` `xhigh` → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) → `codex` `gpt-6.1-sol` `medium` → `antigravity` `gemini-3.8-flash-high` |
| `implement-high` | `claudeAgent` `claude-opus-5-5` `medium` → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `codex` `gpt-6.1-sol` `medium` → `antigravity` `gemini-4-argon-high` |
| `deep` | `codex` `gpt-6.1-sol` `medium` → `codex` `gpt-6.1-sol` `medium` Fast → `claudeAgent` `claude-opus-5-5` `xhigh` |
| `hard-decision` | `codex` `gpt-6.1-sol` `max` → `claudeAgent` `claude-fable-5-1` `max` |
| `review` | `codex` `gpt-6.1-sol` `medium` → `codex` `gpt-6.1-sol` `high` → `claudeAgent` `claude-opus-5-5` `high` |
| `review-gate` | `codex` `gpt-6.1-sol` `max` → `claudeAgent` `claude-opus-5-5` `max` |
| `architect` | `claudeAgent` `claude-fable-5-1` `max` → `claudeAgent` `claude-opus-5-5` `max` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `codex` `gpt-6.1-sol` `xhigh` |
| `peer` | The external model and effort the owning CE skill selects |

The `antigravity` model IDs are those Antigravity ACP `1.3.0` offers, the release the pinned T3 Code embeds and runs by absolute path; each ID ends in its effort. An `antigravity` entry sets `target.model` only, with no effort option, and the agent compares the returned model ID with the requested one. Inside T3 Code, a Compound Engineering `antigravity` peer runs on the T3 instance: the skill's bare model ID and effort map to `<id>-<effort>`, such as `gemini-4-argon` with `high` to `gemini-4-argon-high`. The newest Antigravity ACP runtime on `PATH` serves Compound Engineering peers only outside T3 Code. The `agent-instructions` check fails when the ACP version in `packages/t3code-release.json` differs from the one the template records, so a T3 Code bump that changes the embedded ACP release needs a fresh model-ID probe and a routing update.

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

OMP sessions use only `synthetic` and `openrouter`. The `openai-codex` and `google-antigravity` providers are disabled in both standalone OMP and T3 Code's OMP instance. Native Codex and Antigravity remain available through their own CLIs, T3 Code's `codex` and `antigravity` instances, and sanctioned external reviews. Existing authentication and conversation state are preserved.

Standalone OMP uses the Synthetic models below automatically and runs OpenRouter models only on explicit request. Kimi K3, GLM 5.3, and GLM 5.3 Flash accept only `low`, `high`, and `max`; DeepSeek V4.1 Flash accepts `none` through `max`; none offers `medium`. With `task.enableEffort`, OMP maps task effort `"lo"` to `low`, `"med"` to `high`, and `"hi"` to `max`, capped at `high`, so the `task` subagent runs `implement`, `implement-high`, and `deep` at `"med"`. From 2026-11-19, Synthetic has expired and standalone OMP has no automatic model: it starts no new work and asks the user which model to use.

| Role | Chain |
| --- | --- |
| `root` | `synthetic/hf:moonshotai/Kimi-K3` `high` (S) |
| `scout` | `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `low` (S) |
| `quick` | `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `low` (S) |
| `writing` | `synthetic/hf:moonshotai/Kimi-K3` `high` (S) |
| `visual` | `synthetic/hf:moonshotai/Kimi-K3` `high` (S) |
| `implement` | `synthetic/hf:zai-org/GLM-5.3` `high` (S) |
| `implement-high` | `synthetic/hf:zai-org/GLM-5.3` `high` (S) |
| `deep` | `synthetic/hf:zai-org/GLM-5.3` `high` (S) |
| `hard-decision` | `synthetic/hf:moonshotai/Kimi-K3` `high` (S) |
| `review` | `synthetic/hf:zai-org/GLM-5.3` `high` (S) |
| `review-gate` | `synthetic/hf:moonshotai/Kimi-K3` `high` (S) |
| `architect` | `synthetic/hf:moonshotai/Kimi-K3` `high` (S) |
| `peer` | CE selection |

## Usage pace

Before delegating, the root runs `agent-usage --json` to read cached usage windows for Codex, Claude, Gemini, Grok, and Synthetic. The `gemini` key reports Antigravity's Gemini weekly and 5-hour buckets, read from Google's quota summary with the shell Antigravity ACP runtime's own sign-in; without that sign-in it stays `unknown` with a `reason`. A window is ahead of pace when its used share exceeds the share of the window that has elapsed by more than 10 percentage points, and below the floor when less than 10% remains. A provider-wide window that is ahead of pace or below the floor skips that provider across the chain; a model-scoped window skips only that model's entries. Chain order never changes. Windows whose length is unknown, and Synthetic's rolling weekly quota, are judged by the floor alone, and `stale` or `unknown` status alone skips nothing. When every runnable entry in a chain was skipped only for usage, the root uses the least-ahead entry, ranking entries skipped for the floor after those skipped for pace, and reports that every entry was skipped for usage, without reviving any entry skipped for a disabled provider, unoffered model, exhausted quota, passed Synthetic expiry, or confirmed launch rejection.

## Comparison with oh-my-openagent

This routing is compared against `docs/guide/agent-model-matching.md` in <https://github.com/code-yeongyu/oh-my-openagent> on branch `dev` (commit `e31528c08b224c51af98006593f1f811de066015`), read on 2026-10-27. Syncing with oh-my-openagent is manual and on request.

| Role | This repository (T3 Code) | oh-my-openagent default | Difference |
| --- | --- | --- | --- |
| `root` (Claude Code) | `claudeAgent` `claude-opus-5-5` `medium` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) | Daily · Normal root: Opus 5.5 `medium` → Kimi K3 `max` → GLM-5.3 `max` | OMP effort caps at `high`, so `max` becomes `high` on Kimi K3 and GLM-5.3; Synthetic entries expire after 2026-11-18. |
| `root` (Codex) | `codex` `gpt-6.1-sol` `high` → `codex` `gpt-6.1-sol` `medium` Fast → `codex` `gpt-6.1-sol` `medium` | Obsessive · Normal root: Astra `medium` → Sol Fast `medium` → Sol `medium` (+GPT-5.6 Sol) | Uses Sol `high` as primary; retains the Sol fallbacks and drops the older GPT-5.6 Sol fallback. |
| `root` (OMP) | `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) | None | The OMP root has no oh-my-openagent counterpart; Kimi K3 expires after 2026-11-18. |
| `scout` | `codex` `gpt-6-luna` `low` Fast → `claudeAgent` `claude-haiku-5-5` `medium` → `omp` `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `high` (S) | `explore`, `librarian`: Kimi highspeed → Luna Fast `low` → Haiku `medium` → DeepSeek Flash `max` → Qwen/MiniMax | Kimi highspeed, Qwen, and MiniMax are unavailable here; DeepSeek Flash runs at `high` instead of `max` under the OMP cap and expires after 2026-11-18. |
| `quick` | `codex` `gpt-6-luna` `low` Fast → `claudeAgent` `claude-haiku-5-5` `medium` → `omp` `synthetic/hf:deepseek-ai/DeepSeek-V4.1-Flash` `off` (S) → `omp` `synthetic/hf:zai-org/GLM-5.3-Flash` `low` (S) | `quick`: Luna Fast `low` → Haiku `medium` → DeepSeek Flash `off` → … Grok 4.20 non-reasoning → GLM-5.3-Flash `low` → MiMo | Grok 4.20 and MiMo are unavailable here; Synthetic entries expire after 2026-11-18. |
| `writing` | `antigravity` `gemini-4-argon-low` → `claudeAgent` `claude-opus-5-5` `low` | `writing`: Argon `low` → Opus 5.5 `low` → Opus 4.6 | Argon runs on T3 Code's `antigravity` instance; drops the older Opus 4.6 fallback. |
| `visual` | `antigravity` `gemini-4-argon-low` → `claudeAgent` `claude-fable-5-1` `max` → `claudeAgent` `claude-opus-5-5` `max` → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) | `visual-engineering`: Argon `low` → Fable 5.1 `max` → Opus 5.5 `max` → Kimi K3 `max` | Argon runs on T3 Code's `antigravity` instance; Kimi K3 runs at `high` instead of `max` under the OMP cap and expires after 2026-11-18. |
| `implement` | `claudeAgent` `claude-sonnet-5-5` `medium` → `grok` `grok-4.7` `xhigh` → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) → `codex` `gpt-6.1-sol` `medium` → `antigravity` `gemini-3.8-flash-high` | `unspecified-low`: Sonnet `medium` → MiMo → Grok 4.7 `xhigh` → GLM-5.3 `high` → Sol `medium` … | MiMo is unavailable here; appends Gemini 3.8 Flash `high` on the `antigravity` instance; GLM-5.3 expires after 2026-11-18. |
| `implement-high` | `claudeAgent` `claude-opus-5-5` `medium` → `omp` `synthetic/hf:zai-org/GLM-5.3` `high` (S) → `omp` `synthetic/hf:moonshotai/Kimi-K3` `high` (S) → `codex` `gpt-6.1-sol` `medium` → `antigravity` `gemini-4-argon-high` | `unspecified-high`: Opus `medium` → GLM-5.3 `max` → Kimi K3 `max` | GLM-5.3 and Kimi K3 run at `high` under the OMP cap and expire after 2026-11-18; appends Sol `medium` and Argon `high` on the `antigravity` instance. |
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
- The OMP root (`synthetic/hf:moonshotai/Kimi-K3` `high`) has no oh-my-openagent counterpart.
- Gemini entries run on T3 Code's `antigravity` instance, whose model IDs carry their effort.
- GPT-6.1 Terra `medium` handles standalone Codex writing, visual work, and routine implementation, plus the managed default subagent.
- Synthetic entries expire after 2026-11-18; other catalog Synthetic models (Qwen 3.8 27B, Nemotron 3 Super 120B, GPT-OSS-120B, GLM-4.7-Flash, and the `syn:*` aliases) run only on explicit request under the same expiry.

## Follow-up issues

- [#376](https://github.com/hyperlapse122/nix-config/issues/376): Decide whether Gemini 3.8 Flash leads the `scout` and `quick` roles.
- [#377](https://github.com/hyperlapse122/nix-config/issues/377): Remove Synthetic models from routing after 2026-11-18.
- [#378](https://github.com/hyperlapse122/nix-config/issues/378): Decide whether to remove Grok Build again.
- [#380](https://github.com/hyperlapse122/nix-config/issues/380): Report delegated tasks to the user as a table.
