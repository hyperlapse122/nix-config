"""Check delivered prompt bytes and independent policy boundaries across variants."""

import json
import re
import sys
import tempfile
from pathlib import Path

CARD_KEY = "621512777E6933FEB4458FDC4945855D4F283F05"
FAKE_KEY = "0123456789ABCDEF0123456789ABCDEF01234567"
ACTION = "{{ .user.gpgKey }}"
CODEX_OPEN = "{{ if .codex }}"
OMP_OPEN = "{{ if .omp }}"
BLOCK_CLOSE = "{{ end -}}"
CODEX_HEADING = "Codex role orchestration"
OMP_TOOLS_HEADING = "OMP tools and Compound Engineering"
OMP_ROLE_HEADING = "OMP role orchestration"

PROFILES = {
    "P1": ("gpt-6-luna", "low", "Fast"),
    "P2": ("gpt-6-luna", "low", "Fast"),
    "P3": ("gpt-6.1-sol", "low", "Standard"),
    "P4": ("gpt-6.1-sol", "medium", "Standard"),
    "P5": ("gpt-6.1-sol", "low", "Standard"),
    "P6": ("gpt-6.1-sol", "medium", "Standard"),
    "P7": ("CE-selected external model", "CE-prescribed effort", "Provider default"),
}
OMP_PROFILES = {
    "P1": ("google-antigravity/gemini-3.5-flash-lite", "minimal", "Standard"),
    "P2": ("google-antigravity/gemini-3.5-flash-lite", "low", "Standard"),
    "P3": ("google-antigravity/gemini-3.8-flash", "low", "Standard"),
    "P4": ("google-antigravity/gemini-3.8-flash", "medium", "Standard"),
    "P5": ("google-antigravity/gemini-4-argon", "high", "Standard"),
    "P6": ("google-antigravity/gemini-4-argon", "high", "Standard"),
    "P7": ("CE-selected external model", "CE-prescribed effort", "Provider default"),
}
CODEX_SENTENCES = [
    "When a skill requires interactive setup and a person can reply in this conversation, use the dedicated question tool when it is available and usable; otherwise ask the next required question in ordinary chat with the same choices, order, and consent gates.",
    "Tool absence or mode restrictions alone do not make that conversation non-interactive; this overrides a skill's tool-based non-interactive inference.",
    "After each required chat question, yield and wait for the user's actual answer before dependent work; never invent configuration, source selection, or approval, and never treat elapsed time or a preselected option as an answer.",
    "Honor explicitly non-interactive or headless invocations and unattended scheduled or piped runs; do not substitute chat for required secret entry or protected authentication and permission mechanisms.",
    "This section applies only to the active Codex harness, including Codex-led T3 sessions.",
    "Never automatically switch to separately billed API access or purchase credits when allowance is exhausted.",
    "Fill unspecified fields from that profile, never implicitly from the parent.",
    "Use P3 for unlisted or newly introduced delegated responsibilities.",
    "Root-owned work stays in the active root (profiled as Sol P5/P6) without reconfiguring an active session unless asked; delegated authoring assignments do not move that work out of the root.",
    "Before an above-profile increase, record the named unresolved question or substantive verification failure, evidence, previous configuration and next supported configuration.",
    "Formatting errors, transient network failures, busy slots and missing credentials do not justify deeper reasoning.",
    "GPT `max` and `ultra` require an explicit user request for the affected work.",
    "Standard is the default except for P1/P2 Luna tasks, which have standing user authorization for Fast (`priority`) when the route and account support it, even when allowance is unknown.",
    "This authorization does not extend to root, Sol or external peers.",
    "Other automatic Fast selections require advertised support, a task currently blocking dependent work, known available allowance and a recorded reason for extra usage.",
    "For those other roles, unknown allowance retains Standard unless the user requests acceleration.",
    "Ultrafast requires an explicit user request and advertised model/account support; never select it automatically.",
    "Inside T3, use `delegate_task` for Codex-led children and P7 peers, never top-level conversations or direct provider CLI workers.",
    "Compare returned provider, model and options with the request before counting configuration as applied.",
    "Explicitly set `target.model` and provider-specific effort and supported tier in `target.options`.",
    "Distinguish omitted enumeration, missing descriptors, discovery failure, disabled capabilities, provider rejection and returned-selection mismatch.",
    "For Codex use `reasoningEffort` and `serviceTier`: Standard=`default`, Fast=`priority`.",
    "Preserve CE's conversation-over-checkout-over-project-over-default peer precedence, recipient allowlist, prohibitions, checkout egress gate and only its permitted live opt-in exception to checkout `off`.",
    "Before launch, map the invoked skill's pre-launch failure, started failure, no-review, retry/replacement and local-lens fallback outcomes to the observed T3 states.",
    "On abandonment/deadline, cancel owned live work, retain terminal failure classification and perform the skill's scratch cleanup.",
    "Code review retains reviewer, findings, residual risks and testing gaps; document review retains reviewer, findings, residual risks and deferred questions.",
    "POV retains its settled `final: true` answer, reasoning and round contract; a non-final position does not finish the panel.",
    "Requested/returned configuration is not serving attestation: unknown actual values stay `unverified`; peer self-reports or provider labels do not establish distinct serving families.",
    "Treat child service tier as inherited from the root unless the installed client demonstrably supports independent control.",
    "Only Codex-led CE-required Claude peer tasks may receive the owning skill's exact prescribed effort.",
    "This exception assigns no blanket Claude effort and changes no Claude settings or session environment.",
    "In Codex-led T3, replace CE CLI launch/status/result/reap mechanics with `delegate_task`, `task_status`, task notifications and `task_cancel`.",
    "Capture scope identity and recheck before fold-in; drift requires a fresh bounded round or explicitly incomplete coverage.",
    "Retain valid attributed findings without an independence promotion when the required evidence is missing.",
    "Missing arrays, truncated/malformed output, missing artifacts and fluent summaries never become an empty successful review.",
    "Every new review round uses a fresh delegated task and request ID with the original brief plus prior findings/responses, not a message to its backing thread.",
    "A wait timeout leaves live work running; questions, approvals, nested children and transient retries are incomplete states.",
    "Preserve surviving findings and identify uncovered lenses after partial failure.",
    "Parent tools do not authorize answering a child's reserved approval.",
    "Instructions asking a shared-checkout child not to write do not enforce read-only access.",
    "Establish required enforced read-only/tool restrictions before peer egress.",
    "If the selected route cannot preserve a required boundary, report that pass unavailable/degraded and use only the owning skill's compatible fallback.",
]
CODEX_CONTRACT = """- This section applies only to the active Codex harness, including Codex-led T3 sessions. It supplies profiles, not permission to delegate: preserve each skill's root ownership, selection triggers, sequencing, concurrency, prompts, tools, permissions and artifact contracts. Use bounded briefs and shared evidence; retain required review and verification stages.
- Prefer ChatGPT-authenticated Codex for ordinary work. Never automatically switch to separately billed API access or purchase credits when allowance is exhausted.
- When a skill requires interactive setup and a person can reply in this conversation, use the dedicated question tool when it is available and usable; otherwise ask the next required question in ordinary chat with the same choices, order, and consent gates.
- Tool absence or mode restrictions alone do not make that conversation non-interactive; this overrides a skill's tool-based non-interactive inference.
- After each required chat question, yield and wait for the user's actual answer before dependent work; never invent configuration, source selection, or approval, and never treat elapsed time or a preselected option as an answer.
- Honor explicitly non-interactive or headless invocations and unattended scheduled or piped runs; do not substitute chat for required secret entry or protected authentication and permission mechanisms.

## Profiles and responsibility resolution

| Profile | Responsibility | Model | Effort | Service |
| --- | --- | --- | --- | --- |
| P1 | Exact lookup, fixed-field extraction, status | `gpt-6-luna` | `low` | Fast |
| P2 | Grounding scouts, bounded classification, evidence summaries | `gpt-6-luna` | `low` | Fast |
| P3 | General implementation, ordinary planning, synthesis, claim verification, learning authoring | `gpt-6.1-sol` | `low` | Standard |
| P4 | Complex logic, substantive review, security, concurrency, data integrity | `gpt-6.1-sol` | `medium` | Standard |
| P5 | Root orchestration, delegation, progress | `gpt-6.1-sol` | `low` | Standard |
| P6 | Complex planning, architecture alternatives, high-risk decisions, conflicting evidence | `gpt-6.1-sol` | `medium` | Standard |
| P7 | CE-required independent Claude or Gemini review or diverse candidate | CE-selected external model | CE-prescribed effort | Provider default |

- Resolve current user overrides for their stated task, recipient, fields and duration, applicable skill constraints, then the responsibility profile. Fill unspecified fields from that profile, never implicitly from the parent. A root-only selection does not change child profiles; preserve explicit project/invocation/conversation selections and resume state at their supported precedence. Managed startup defaults are reasserted by apply, not a promise to preserve edits to owned baseline fields.
- Use P3 for unlisted or newly introduced delegated responsibilities. Mixed work takes its substantive responsibility's profile; split only where the owning skill already permits it. Root-owned work stays in the active root (profiled as Sol P5/P6) without reconfiguring an active session unless asked; delegated authoring assignments do not move that work out of the root.
- Before an above-profile increase, record the named unresolved question or substantive verification failure, evidence, previous configuration and next supported configuration. Interpretation discovered by P1/P2 returns evidence for a new P3 dispatch; difficult implementation/validation uses P4, unresolved architectural tradeoffs P6. Do not walk an escalation ladder on every retry. Formatting errors, transient network failures, busy slots and missing credentials do not justify deeper reasoning.
- GPT `max` and `ultra` require an explicit user request for the affected work. Role titles, large context and importance do not authorize an increase, including to `xhigh`. This GPT limit does not rewrite P7's prescribed external effort.
- Standard is the default except for P1/P2 Luna tasks, which have standing user authorization for Fast (`priority`) when the route and account support it, even when allowance is unknown. This authorization does not extend to root, Sol or external peers. Other automatic Fast selections require advertised support, a task currently blocking dependent work, known available allowance and a recorded reason for extra usage. For those other roles, unknown allowance retains Standard unless the user requests acceleration. Ultrafast requires an explicit user request and advertised model/account support; never select it automatically.

## CE coverage

| Workflow / identity | Profile and boundary |
| --- | --- |
| General fetch/status/file/symbol lookup; `ce-sweep` source-persona fetch | P1; unclear connector semantics P3 |
| `ce-sweep` media analyzer | P3 for frame/transcript interpretation |
| `ce-sweep` decisions/reconciliation; `lfg` coordination | P5; conflicting evidence or difficult scope P6 |
| `ce-brainstorm` grounding; `ce-pov` project/precedent scouts | P2; brainstorm claim verifier P3 |
| `ce-plan` repo/history/learnings/framework-docs/web/best-practices researchers | P2 gathering, P3 applicability/reconciliation |
| `ce-plan` spec-flow analyzer and data-integrity guardian | P4 |
| `ce-plan` architecture strategist/complex plan author | P6; ordinary delegated plan author P3 |
| `ce-work` implementation/design-sync; PR comment resolver | P3; complex diagnosis P4, architecture P6 |
| `ce-debug` investigation/root cause; `ce-optimize` attribution | P4; exact gathering P1/P2 does not transfer diagnosis |
| `ce-explain` work-recap/behavior-trace scouts | P2; complex causal tracing P4 |
| `ce-ideate` evidence researchers/issue intelligence | P2 retrieval, P3 interpretation |
| `ce-ideate` generation/ceiling; `ce-bakeoff` candidates | P3/P6/P7 according to the skill's frame and diversity contract |
| `ce-pov` verdict/synthesis; independent peer | P6; P7 peer |
| `ce-code-review` correctness, standards, testing, maintainability, agent-native, security, performance, API-contract, data-migration, reliability, adversarial fallback, previous-comments, frontend-races, Swift/iOS, deployment-verification personas | P4 even on small changes |
| `ce-code-review` learnings researcher; merge/validator/report leaves | P2 retrieval/P3 applicability; P3/P4/P3 leaves preserving all findings |
| `ce-doc-review` whole-doc, coherence, scope, feasibility, product, design, security, local adversarial lenses | P4; independent peer P7 |
| `ce-simplify-code` reuse, quality, efficiency, comment, test-value reviewers | P4 regardless of output length |
| `ce-compound` Related Docs Finder | P2 bounded matching; overlap interpretation P3 |
| `ce-compound` session historian, synthesis, grounding validation | P3; root retains classification/drafting ownership |
| `ce-compound` security sentinel, performance oracle, data-integrity guardian, pattern-recognition specialist | P4; research-only framework/best-practices gathering P2 |
| `ce-compound-refresh` investigators/replacement authors | P3; complex behavior verification P4; root retains deletion/metadata decisions |
| Browser/device/prototype execution, ordinary writing, handoff, general workers | P3 with required modalities/tools; status only P1 |
| Commit/publication/babysitting coordination | P5; deterministic commands need no extra model call; diagnosis P4 |

## Dispatch and compatibility

- Inside T3, use `delegate_task` for Codex-led children and P7 peers, never top-level conversations or direct provider CLI workers. Discover the exact provider instance, model and option descriptors with `orchestrator_capabilities`; search omitted models before declaring absence. Check child/cross-provider eligibility and required modalities/tools. Explicitly set `target.model` and provider-specific effort and supported tier in `target.options`. For Codex use `reasoningEffort` and `serviceTier`: Standard=`default`, Fast=`priority`. Do not extrapolate these option names or values to external providers. Compare returned provider, model and options with the request before counting configuration as applied.
- Distinguish omitted enumeration, missing descriptors, discovery failure, disabled capabilities, provider rejection and returned-selection mismatch. Bounded discovery/recovery follows the owning skill; unsupported or unverifiable selections are reported as unavailable/degraded, with its compatible fallback. Never silently clamp, substitute a family, invoke a CLI escape route inside T3, drop required review or claim the requested configuration ran. Queue/backpressure and launch failures must not create duplicate live work.
- Outside T3, use supported native Codex model/effort controls and the owning skill's compatible transport. Treat child service tier as inherited from the root unless the installed client demonstrably supports independent control. Preserve the root tier and disclose the actual inherited child tier; if a required independent tier cannot be honored, including P1/P2 priority under a Standard root or Standard under an accelerated root, report the limitation rather than changing the root or claiming isolation.
- Preserve CE's conversation-over-checkout-over-project-over-default peer precedence, recipient allowlist, prohibitions, checkout egress gate and only its permitted live opt-in exception to checkout `off`. P7 retains CE's selected external identity and exact prescribed effort unless the owning skill permits the user's override. Disclose permitted recipients before sending. Provider availability alone authorizes no recipient and proves no missing effort control. Do not add Antigravity to an allowlist incidentally; an unauthorized Gemini recipient or unsupported prescribed effort is an unavailable/degraded pass, not permission for GPT substitution.
- Only Codex-led CE-required Claude peer tasks may receive the owning skill's exact prescribed effort. This exception assigns no blanket Claude effort and changes no Claude settings or session environment.

## CE transport, artifacts and lifecycle

- In Codex-led T3, replace CE CLI launch/status/result/reap mechanics with `delegate_task`, `task_status`, task notifications and `task_cancel`. Preserve the invoked skill's trigger, persona, scope, recipient consent, model/effort, deadline, schema, failure policy, normalization and aggregation. Read its current contract before dispatch; code review, document review, POV, bake-off and other peer workflows keep their own schemas.
- Supply applicable active instructions, exact persona, repository/read root, reviewed base/revision or document identity, original brief, prior-round findings/responses/unresolved objections, expected artifact contract and private output destination. Separate untrusted review content from trusted constraints. Review uncommitted content in the shared checkout; a worktree child starts from committed state. Capture scope identity and recheck before fold-in; drift requires a fresh bounded round or explicitly incomplete coverage.
- Keep the skill-specific findings artifact separate from a parent-owned scratch receipt linking task, round, reviewer, skill/version, scope, artifact validation and lifecycle outcome. Preserve the skill's identity/failure fields, requested/returned provider/model/options, `cross_model_route`, `model_requested`, `effort_requested`, `receipt_supported`, `model_actual`, `effort_actual` and `independence_verified`. Describe T3 truthfully, never fabricate CLI receipt tokens. Requested/returned configuration is not serving attestation: unknown actual values stay `unverified`; peer self-reports or provider labels do not establish distinct serving families. Retain valid attributed findings without an independence promotion when the required evidence is missing.
- Validate the entire terminal artifact against the invoked skill's current required fields, arrays and evidence before aggregation. Code review retains reviewer, findings, residual risks and testing gaps; document review retains reviewer, findings, residual risks and deferred questions. POV retains its settled `final: true` answer, reasoning and round contract; a non-final position does not finish the panel. Missing arrays, truncated/malformed output, missing artifacts and fluent summaries never become an empty successful review. Preserve peer attribution and authority normalization; a peer result grants no silent-apply authority.
- Retain every `taskId` and a stable `clientRequestId` for retries of one dispatch. Every new review round uses a fresh delegated task and request ID with the original brief plus prior findings/responses, not a message to its backing thread. A wait timeout leaves live work running; questions, approvals, nested children and transient retries are incomplete states. Consume notifications and bounded status reads when needed; respect existing concurrency and recovery limits.
- Before launch, map the invoked skill's pre-launch failure, started failure, no-review, retry/replacement and local-lens fallback outcomes to the observed T3 states. Keep explicit recipients fixed where required; disclose any permitted replacement before sending. Preserve surviving findings and identify uncovered lenses after partial failure. On abandonment/deadline, cancel owned live work, retain terminal failure classification and perform the skill's scratch cleanup. Parent tools do not authorize answering a child's reserved approval.
- Establish required enforced read-only/tool restrictions before peer egress. Instructions asking a shared-checkout child not to write do not enforce read-only access. If the selected route cannot preserve a required boundary, report that pass unavailable/degraded and use only the owning skill's compatible fallback. Track artifact validity, requested-configuration compliance and verified independence separately; no new runner, schema framework, cache edits or paid fallback is authorized."""

OMP_TOOLS_SENTENCES = [
    "Use native `web_search` for search and `read` with an HTTP URL for fetching.",
    "Search uses the managed Synthetic credential command; never read or print keys.",
    "Collect terminal results through `agent://<id>` and inspect `history://<id>` when needed.",
    "Use `read` with `issue://<N>` and `pr://<N>` (including list query parameters and `pr://<N>/diff`, `/diff/<i>`, `/diff/all`) for viewing or listing issues, pull requests, and PR diffs.",
    "Use `github` (`xd://github`) for repository summaries (`repo_view`), repository file reads (`file_read`), searches (`search_issues`, `search_prs`, `search_code`, `search_commits`, `search_repos`), Actions run watching (`run_watch`), PR creation (`pr_create`), PR checkout (`pr_checkout`), and pushing `pr_checkout`-managed branches (`pr_push`).",
    "Retain `gh` CLI and `git push` as the fallback where OMP's GitHub surfaces lack the required operation, flag, freshness, or safety constraint, including `gh issue create/edit/close/comment`, `gh pr comment/review/edit/merge/ready`, `gh api graphql`, `gh --attach`, explicit cross-checkout `--repo HOST/OWNER/REPO` and `--hostname HOST` qualification, repository `<kind>/short-kebab-slug` branch naming, and uncached head-SHA verification with `git push --force-with-lease=<branch>:<sha>`.",
    "Preserve existing GitLab rules (`glab` and `mr://` diffs).",
    "When the runtime attests a `google-antigravity` Gemini model serving the OMP session, pass host family `gemini` and `CROSS_MODEL_HOST_HARNESS=omp` so sanctioned `claude` and `codex` peers run as different-family reviews.",
    "GLM does not establish a recognized CE host family: for an explicitly requested `ce-code-review` cross-model pass from GLM or another unattested OMP model, keep host family `unknown` with `CROSS_MODEL_HOST_HARNESS=omp` and `CROSS_MODEL_EXPLICIT_UNKNOWN_HOST=1` on the worker's `env` prefix for that run only, and keep `independence_verified` `false`.",
    "The user permits sanctioned OMP cross-model reviews (automatic attested-Gemini peer passes and explicitly requested unknown-host passes) through T3's ordinary delegated permissions without enforced read-only access.",
    "Tell the reviewer to inspect without editing, and report that this is an instruction rather than a technical restriction.",
]

OMP_ROLE_SENTENCES = [
    "This section applies only to the active OMP harness, including OMP-led T3 sessions.",
    "Restrict ordinary orchestration (`P1`-`P6`) to the selected `google-antigravity` Gemini models; never automatically switch to separately billed API providers (`synthetic`, `openrouter`) or `openai-codex` unless explicitly requested by the user.",
    "Upstream Gemini API validation on `gemini-3.8-flash` and `gemini-4-argon` accepts only `low`, `medium`, and `high`; never send `minimal`, `xhigh`, or `max` to either model.",
    "Fill unspecified fields from that profile, never implicitly from the parent.",
    "Use P3 for unlisted or newly introduced delegated responsibilities.",
    "Before an above-profile increase, record the named unresolved question or substantive verification failure, evidence, previous configuration and next supported configuration.",
    "Inside T3, use `delegate_task` on `instanceId` `omp` for OMP-led children and external instances for P7 peers, setting `target.model` and `target.options` with option id `thinking` and comparing the returned selection before counting configuration as applied.",
    'Outside T3, route subagents through `task` (`sonic` for P1, `scout` and `seance` for P2, `task` for P3 with `effort` `"lo"` or P4 with `effort` `"med"`, `reviewer` and `security-reviewer` for P4, and `architect` for P6), keeping `tasks[].model` reserved for `seance` consults and preserving `modelRoles.web` as `web/synthetic`.',
    "Only OMP-led CE-required Claude peer tasks may receive the owning skill's exact prescribed effort.",
    "This exception assigns no blanket Claude effort and changes no Claude settings or session environment.",
]

OMP_TOOLS_CONTRACT = """- Use native `web_search` for search and `read` with an HTTP URL for fetching. Search uses the managed Synthetic credential command; never read or print keys.
- Use `read history://` for the agent roster and `read history://current/full` for the current transcript. Runtime model and effort evidence comes from the protocol state or captured provider requests; configuration and model prose do not establish the effective runtime selection.
- Outside T3, native `task` runs CLI children. Read its advertised schema before dispatch: batch calls require `context` and `tasks`, with `agent` per task when selecting a non-default agent. Structured results are enabled; pass the owning workflow's `outputSchema` and collect the child's terminal `yield` rather than accepting a prose summary. Collect terminal results through `agent://<id>` and inspect `history://<id>` when needed. A started job, partial yield, cancellation, or failure is not a completed child; preserve full result artifacts and required schema fields.
- Inside T3, use the injected app-owned MCP delegation, status, and cancellation tools according to their live descriptions; do not replace app delegation with new top-level conversations.

## GitHub tools

- Use `read` with `issue://<N>` and `pr://<N>` (including list query parameters and `pr://<N>/diff`, `/diff/<i>`, `/diff/all`) for viewing or listing issues, pull requests, and PR diffs.
- Use `github` (`xd://github`) for repository summaries (`repo_view`), repository file reads (`file_read`), searches (`search_issues`, `search_prs`, `search_code`, `search_commits`, `search_repos`), Actions run watching (`run_watch`), PR creation (`pr_create`), PR checkout (`pr_checkout`), and pushing `pr_checkout`-managed branches (`pr_push`).
- Retain `gh` CLI and `git push` as the fallback where OMP's GitHub surfaces lack the required operation, flag, freshness, or safety constraint, including `gh issue create/edit/close/comment`, `gh pr comment/review/edit/merge/ready`, `gh api graphql`, `gh --attach`, explicit cross-checkout `--repo HOST/OWNER/REPO` and `--hostname HOST` qualification, repository `<kind>/short-kebab-slug` branch naming, and uncached head-SHA verification with `git push --force-with-lease=<branch>:<sha>`.
- Preserve existing GitLab rules (`glab` and `mr://` diffs).

## Cross-model review identity and permissions

- Compound Engineering skills live in the complete pinned tree under `~/.omp/agent/plugins/compound-engineering`; read referenced assets relative to that tree and retain each skill's recipient permission, tool restrictions, identity checks, result schema, and lifecycle rules.
- When the runtime attests a `google-antigravity` Gemini model serving the OMP session, pass host family `gemini` and `CROSS_MODEL_HOST_HARNESS=omp` so sanctioned `claude` and `codex` peers run as different-family reviews.
- GLM does not establish a recognized CE host family: for an explicitly requested `ce-code-review` cross-model pass from GLM or another unattested OMP model, keep host family `unknown` with `CROSS_MODEL_HOST_HARNESS=omp` and `CROSS_MODEL_EXPLICIT_UNKNOWN_HOST=1` on the worker's `env` prefix for that run only, and keep `independence_verified` `false`. Automatic unknown-host review remains skipped; never invent an OMP peer token, export the opt-in as a session default, substitute a recognized family for GLM, or turn a missing, failed, or cancelled result into a successful empty review.
- Inside T3, use app-owned delegation instead of launching the CLI peer worker. The user permits sanctioned OMP cross-model reviews (automatic attested-Gemini peer passes and explicitly requested unknown-host passes) through T3's ordinary delegated permissions without enforced read-only access. Tell the reviewer to inspect without editing, and report that this is an instruction rather than a technical restriction. This exception does not change CLI restrictions, recipient consent, or any other agent's review policy. Validate the complete terminal artifact, retain task IDs and requested/returned selection, and keep serving model/effort `unverified` without serving evidence."""

OMP_ROLE_CONTRACT = """- This section applies only to the active OMP harness, including OMP-led T3 sessions. It supplies profiles, not permission to delegate: preserve each skill's root ownership, selection triggers, sequencing, concurrency, prompts, tools, permissions, and artifact contracts.
- Restrict ordinary orchestration (`P1`-`P6`) to the selected `google-antigravity` Gemini models; never automatically switch to separately billed API providers (`synthetic`, `openrouter`) or `openai-codex` unless explicitly requested by the user.

## Profiles and responsibility resolution

| Profile | Responsibility | Model | Effort | Service |
| --- | --- | --- | --- | --- |
| P1 | Exact lookup, fixed-field extraction, commit messages, status | `google-antigravity/gemini-3.5-flash-lite` | `minimal` | Standard |
| P2 | Grounding scouts, bounded classification, evidence summaries | `google-antigravity/gemini-3.5-flash-lite` | `low` | Standard |
| P3 | General implementation, ordinary planning, synthesis, claim verification, learning authoring | `google-antigravity/gemini-3.8-flash` | `low` | Standard |
| P4 | Complex logic, substantive review, security, concurrency, data integrity | `google-antigravity/gemini-3.8-flash` | `medium` | Standard |
| P5 | Root orchestration, delegation, progress | `google-antigravity/gemini-4-argon` | `high` | Standard |
| P6 | Complex planning, architecture alternatives, high-risk decisions, conflicting evidence | `google-antigravity/gemini-4-argon` | `high` | Standard |
| P7 | CE-required independent Claude or Codex review or diverse candidate | CE-selected external model | CE-prescribed effort | Provider default |

- Upstream Gemini API validation on `gemini-3.8-flash` and `gemini-4-argon` accepts only `low`, `medium`, and `high`; never send `minimal`, `xhigh`, or `max` to either model.
- Resolve current user overrides for their stated task, recipient, fields, and duration, applicable skill constraints, then the responsibility profile. Fill unspecified fields from that profile, never implicitly from the parent.
- Use P3 for unlisted or newly introduced delegated responsibilities. Root-owned work stays Argon P5/P6; delegated authoring assignments do not move that work out of the root.
- Before an above-profile increase, record the named unresolved question or substantive verification failure, evidence, previous configuration and next supported configuration. Formatting errors, transient network failures, busy slots, and missing credentials do not justify deeper reasoning.

## CE coverage

| Workflow / identity | Profile and boundary |
| --- | --- |
| General fetch/status/file/symbol lookup; `ce-sweep` source-persona fetch | P1; unclear connector semantics P3 |
| `ce-sweep` media analyzer | P3 for frame/transcript interpretation |
| `ce-sweep` decisions/reconciliation; `lfg` coordination | P5; conflicting evidence or difficult scope P6 |
| `ce-brainstorm` grounding; `ce-pov` project/precedent scouts | P2; brainstorm claim verifier P3 |
| `ce-plan` repo/history/learnings/framework-docs/web/best-practices researchers | P2 gathering, P3 applicability/reconciliation |
| `ce-plan` spec-flow analyzer and data-integrity guardian | P4 |
| `ce-plan` architecture strategist/complex plan author | P6; ordinary delegated plan author P3 |
| `ce-work` implementation/design-sync; PR comment resolver | P3; complex diagnosis P4, architecture P6 |
| `ce-debug` investigation/root cause; `ce-optimize` attribution | P4; exact gathering P1/P2 does not transfer diagnosis |
| `ce-explain` work-recap/behavior-trace scouts | P2; complex causal tracing P4 |
| `ce-ideate` evidence researchers/issue intelligence | P2 retrieval, P3 interpretation |
| `ce-ideate` generation/ceiling; `ce-bakeoff` candidates | P3/P6/P7 according to the skill's frame and diversity contract |
| `ce-pov` verdict/synthesis; independent peer | P6; P7 peer |
| `ce-code-review` correctness, standards, testing, maintainability, agent-native, security, performance, API-contract, data-migration, reliability, adversarial fallback, previous-comments, frontend-races, Swift/iOS, deployment-verification personas | P4 even on small changes |
| `ce-code-review` learnings researcher; merge/validator/report leaves | P2 retrieval/P3 applicability; P3/P4/P3 leaves preserving all findings |
| `ce-doc-review` whole-doc, coherence, scope, feasibility, product, design, security, local adversarial lenses | P4; independent peer P7 |
| `ce-simplify-code` reuse, quality, efficiency, comment, test-value reviewers | P4 regardless of output length |
| `ce-compound` Related Docs Finder | P2 bounded matching; overlap interpretation P3 |
| `ce-compound` session historian, synthesis, grounding validation | P3; root retains classification/drafting ownership |
| `ce-compound` security sentinel, performance oracle, data-integrity guardian, pattern-recognition specialist | P4; research-only framework/best-practices gathering P2 |
| `ce-compound-refresh` investigators/replacement authors | P3; complex behavior verification P4; root retains deletion/metadata decisions |
| Browser/device/prototype execution, ordinary writing, handoff, general workers | P3 with required modalities/tools; status only P1 |
| Commit/publication/babysitting coordination | P5; deterministic commands need no extra model call; diagnosis P4 |

## Dispatch and compatibility

- Inside T3, use `delegate_task` on `instanceId` `omp` for OMP-led children and external instances for P7 peers, setting `target.model` and `target.options` with option id `thinking` and comparing the returned selection before counting configuration as applied. Do not extrapolate Codex option names (`reasoningEffort`, `serviceTier`) to OMP or external providers.
- Outside T3, route subagents through `task` (`sonic` for P1, `scout` and `seance` for P2, `task` for P3 with `effort` `"lo"` or P4 with `effort` `"med"`, `reviewer` and `security-reviewer` for P4, and `architect` for P6), keeping `tasks[].model` reserved for `seance` consults and preserving `modelRoles.web` as `web/synthetic`.
- Preserve CE's conversation-over-checkout-over-project-over-default peer precedence, recipient allowlist (`CROSS_MODEL_PEERS`), prohibitions, checkout egress gate, and disclosure before sending. P7 retains CE's selected external identity and exact prescribed effort unless the owning skill permits the user's override; never route a P7 Gemini-led review back to `google-antigravity`.
- Only OMP-led CE-required Claude peer tasks may receive the owning skill's exact prescribed effort. This exception assigns no blanket Claude effort and changes no Claude settings or session environment."""

ROLE_PROFILES = {
    "source-persona fetch": "P1; unclear connector semantics P3",
    "media analyzer": "P3 for frame/transcript interpretation",
    "decisions/reconciliation": "P5; conflicting evidence or difficult scope P6",
    "`ce-brainstorm` grounding": "P2; brainstorm claim verifier P3",
    "repo/history/learnings/framework-docs/web/best-practices": "P2 gathering, P3 applicability/reconciliation",
    "spec-flow analyzer": "P4",
    "architecture strategist/complex plan author": "P6; ordinary delegated plan author P3",
    "implementation/design-sync": "P3; complex diagnosis P4, architecture P6",
    "investigation/root cause": "P4; exact gathering P1/P2 does not transfer diagnosis",
    "work-recap/behavior-trace": "P2; complex causal tracing P4",
    "evidence researchers/issue intelligence": "P2 retrieval, P3 interpretation",
    "generation/ceiling": "P3/P6/P7 according to the skill's frame and diversity contract",
    "verdict/synthesis": "P6; P7 peer",
    "correctness, standards": "P4 even on small changes",
    "merge/validator/report": "P2 retrieval/P3 applicability; P3/P4/P3 leaves preserving all findings",
    "whole-doc, coherence": "P4; independent peer P7",
    "reuse, quality": "P4 regardless of output length",
    "Related Docs Finder": "P2 bounded matching; overlap interpretation P3",
    "session historian": "P3; root retains classification/drafting ownership",
    "security sentinel": "P4; research-only framework/best-practices gathering P2",
    "investigators/replacement authors": "P3; complex behavior verification P4; root retains deletion/metadata decisions",
    "Browser/device/prototype": "P3 with required modalities/tools; status only P1",
    "Commit/publication/babysitting": "P5; deterministic commands need no extra model call; diagnosis P4",
}

HEADINGS = [
    "GPG and encryption",
    "File I/O",
    "Git",
    "Pull and merge requests",
    "Markdown",
    "Korean text",
    "Tests",
    "Review findings",
    "Browser and device verification",
    "Cross-model reviews",
]

POLICIES = {
    "GPG and encryption": [
        "Stop and report only when the PIN is rejected, the prompt times out, or the card is missing.",
        "Never print decrypted values, pass them as arguments, or open decrypted files with the file tools; pipe decrypted output straight into the command that consumes it.",
        "Leave card administration and key management to the user.",
    ],
    "File I/O": [
        "Use the harness's native read, write, edit, or patch tools for routine file reads, writes, and edits when a suitable tool is available.",
        "Use shell commands or scripts such as Python and `sed` for file I/O only when the harness has no suitable native tool or the operation requires a command-line tool.",
        "The GPG and encryption rules take precedence for decrypted output: pipe it straight into the consuming command without opening decrypted files with file tools.",
    ],
    "Git": ["Never rename onto or push over an existing branch."],
    "Pull and merge requests": [
        "After you open or push to a pull or merge request, babysit it until it looks ready to merge, then leave the merge to the user.",
        "Babysit a draft only when asked.",
        "Confirm with `git merge-base --is-ancestor <sha> HEAD` that the forge's head is an ancestor of your local branch tip and that your checkout has no uncommitted changes.",
        "If either check fails, neither rebase nor reset; report the branch.",
        "When the commits since the base include a merge commit, compare the rebased tip's tree with the tree `git merge-tree --write-tree <base> <old-tip>` prints for the base and your pre-rebase tip before you push, and when it reports a conflict or the trees differ, return the branch to that tip with `git reset --hard <old-tip>`, push nothing, and report the branch, because a default rebase drops a change made only inside a merge commit.",
        "When signing or a hook fails during the rebase, run `git rebase --abort` and report, and never disable signing or pass `--no-verify`.",
        "When the lease is rejected, never retry with `--force`; report the branch instead.",
        "Force-push only the head branch of a pull or merge request you opened, in this or an earlier session, or whose rebase the user explicitly authorized, only with `--force-with-lease`, and never a base branch.",
    ],
    "Markdown": [
        'In text that does not render as Markdown, such as commit messages, code comments, and plain-text or config files, write a range with a dash or a word, and an approximation with a word, and never with `\\~`.',
    ],
    "Korean text": [
        "Before you write covered text, load the `humanizer`, `grammar-checker`, and `style-guide` skills, once per session.",
        "Leave text the user asks you to post as written, and verbatim quotes, unchanged.",
    ],
    "Tests": [
        "Load the `test-audit` skill before writing, changing, reviewing, or deleting a test.",
        "When `ce-code-review` or `ce-simplify-code` meets a changed test, audit it with `test-audit` and report each problem as a finding of that review.",
        "Use the skill's `CAMPAIGN.md` only when the user asks to prune a whole subsystem's tests.",
    ],
    "Review findings": [
        "Assess every finding that a review, verification, or check step of any Compound Engineering skill reports about the work the workflow produces or changes, including testing gaps and residual risks.",
        "Apply substantiated defects and requirement violations in the same change, regardless of severity, confidence labels, or which list contains them.",
        "Reject a finding when evidence shows its facts are wrong, it requires assumptions outside supported behavior, or it depends on a speculative failure chain without a credible execution path.",
        "Reject preference-only suggestions with no basis in project rules, clarity, or maintainability, and refactoring suggestions with no concrete benefit.",
        "Reject added complexity for a vanishingly unlikely edge case only when the expected harm does not justify the implementation and maintenance cost; record the failure scenario, likelihood evidence, impact, and cost.",
        "Rarity alone does not justify rejecting a credible security or data-loss defect, and a reproducer is not required when code analysis establishes the failure path.",
        "Investigate uncertain claims before deciding; lack of evidence is not proof that a defect is impossible.",
        "Assess findings yourself without asking for routine approval to reject them, and record each rejection with its evidence or concrete reason.",
        "Leave a substantiated finding unapplied when every fix would weaken a safety check, the user declined its fix, its fix awaits a user decision, or no change in this repository can fix it.",
        "A fix that would reverse a decision the user made, a brainstorm Scope Boundary or `session-settled` entry included, is asked in every run with a person present, autonomous runs included, and listed as `awaits your decision` in a run with no person present.",
        "When the user asked only for a review, report the assessed findings and ask once whether to apply all substantiated fixes.",
    ],
    "Browser and device verification": [
        "When running in T3 Code and its browser or device tools are available, prefer `preview_*` tools for browser navigation, inspection, interaction, screenshots, and recordings: start with `preview_status`, then call `preview_open` if no automation-capable preview is attached.",
        "Respect tab ownership and prefer snapshot-provided locators: read user-driven tabs without taking them over, or open an agent-owned tab (`reuseExistingTab` `false`) for interaction.",
        "Prefer `device_list`, then `device_open`, for mobile verification, follow the returned exact `agent-device` launcher and session configuration, prefer interactive snapshot refs, and use `device_screenshot` for visual inspection while keeping `xcrun simctl` and `adb` available for builds, logs, port forwarding, and unsupported capabilities.",
        "Fall back to other browser or device tools only when T3 tools are absent, explicitly unavailable, repeatedly fail as described by active T3 instructions, or the user requests another tool; never switch merely because the preview is initially closed or the first call needs corrected arguments.",
    ],
    "Cross-model reviews": [
        "When running in T3 Code, conduct cross-model reviews through T3 Code delegated child tasks (`delegate_task`) rather than separate top-level conversations or direct CLI peer workers, selecting the requested provider and model from live capabilities and preserving requested model options.",
        "Run T3 Code cross-model reviews against the current workspace without worktree isolation, and never create a worktree through T3 Code or Git solely for a review; outside T3 Code this rule does not require T3 Code, and implementation tasks may still use worktrees.",
        "Keep reviewers read-only — enforce read-only tool restrictions where `delegate_task` exposes them, and where T3 Code provides only prompt-level read-only delegation over the shared workspace (unless a harness section requires enforced restrictions), instruct the reviewer to inspect without editing and disclose in Coverage that read-only access was prompt-instructed rather than technically enforced — supply the review brief, relevant diff, and context including uncommitted workspace changes when those are the review target, and report unavailable capabilities rather than silently substituting another model or execution path.",
    ],
}

REMOVED_COMMON = re.compile(
    r"\bPi\b|\bOpenCode\b|\.t3/|"
    r"model[- ](?:routing|selection|family)|CROSS_MODEL_|"
    r"claudeAgent|claude-(?:opus|sonnet|haiku)-|gpt-[0-9]|gemini-[0-9]|"
    r"\b(?:opus|sonnet|haiku|fable)\b|"
    r"\bacpx\b|Pi over ACP|pi-readonly|thought_level|"
    r"t3_thread_|task_status|task_cancel|clientRequestId|runtimeMode",
    re.IGNORECASE,
)
REMOVED_NON_T3_SECTIONS = re.compile(
    r"\bT3\b|\bsubagents?\b|\bdelegat(?:e|ed|es|ing|ion)\b|delegate_task|cross-model",
    re.IGNORECASE,
)
T3_SCOPED_COMMON_HEADINGS = {"Browser and device verification", "Cross-model reviews"}


def render(template, key, delivery="common"):
    if delivery not in ("common", "codex", "omp"):
        raise ValueError(f"unknown delivery: {delivery}")
    if template.count(CODEX_OPEN) != 1 or template.count(OMP_OPEN) != 1 or template.count(BLOCK_CLOSE) != 2:
        raise ValueError("missing or repeated delivery conditional")
    common, after_codex_open = template.split(CODEX_OPEN, 1)
    if BLOCK_CLOSE not in after_codex_open:
        raise ValueError("unclosed codex conditional")
    codex_extra, after_codex_close = after_codex_open.split(BLOCK_CLOSE, 1)
    if not after_codex_close.startswith("\n" + OMP_OPEN):
        raise ValueError("omp conditional must immediately follow codex conditional")
    _, after_omp_open = after_codex_close.split(OMP_OPEN, 1)
    omp_extra, trailing = after_omp_open.split(BLOCK_CLOSE, 1)
    if trailing != "\n":
        raise ValueError("delivery conditional must end the template")
    selected = common
    if delivery == "codex":
        selected += codex_extra
    elif delivery == "omp":
        selected += omp_extra
    actions = re.findall(r"{{.*?}}", selected, flags=re.DOTALL)
    if not actions or any(action != ACTION for action in actions):
        raise ValueError("unknown or missing template action")
    result = selected.replace(ACTION, key)
    if "{{" in result or "}}" in result:
        raise ValueError("incomplete template action")
    return result


def sentence_once(text, sentence):
    matches = list(re.finditer(re.escape(sentence), text))
    if len(matches) != 1:
        return False
    match = matches[0]
    before, after = text[:match.start()], text[match.end():]
    return bool(
        (not before or re.search(r"(?:^|\n)\s*- $|\. $|\n$", before))
        and (not after or after[0].isspace())
    )


def expected_headings(delivery):
    if delivery == "codex":
        return HEADINGS + [CODEX_HEADING]
    if delivery == "omp":
        return HEADINGS + [OMP_TOOLS_HEADING, OMP_ROLE_HEADING]
    return list(HEADINGS)


def content_problems(text, key, delivery="common"):
    problems = []
    matches = list(re.finditer(r"^# (.+)$", text, re.MULTILINE))
    if [m[1] for m in matches] != expected_headings(delivery) or not text.startswith("# "):
        problems.append("unexpected instruction sections")
    sections = {
        match[1]: text[match.end(): matches[i + 1].start() if i + 1 < len(matches) else len(text)]
        for i, match in enumerate(matches)
    }
    for heading, sentences in POLICIES.items():
        body = sections.get(heading, "")
        for sentence in sentences:
            if not sentence_once(body, sentence):
                problems.append(f"missing, repeated or negated policy in {heading}: {sentence}")
    recipient = f"For a new SOPS setup or secret file, use the card key `{key}` as the user's recipient, plus a machine's own recipient when it must decrypt without the card."
    if sections.get("GPG and encryption", "").count("- " + recipient) != 1:
        problems.append("incorrect host recipient")
    if key == FAKE_KEY and CARD_KEY in text:
        problems.append("literal card key in fake-key instructions")
    # Store paths are opaque identifiers, not prose or policy.
    prose = re.sub(r"/nix/store/[a-z0-9]{32}-[^\s`\"]*", "", text)
    if delivery == "codex":
        common = prose.split("# " + CODEX_HEADING, 1)[0]
    elif delivery == "omp":
        common = prose.split("# " + OMP_TOOLS_HEADING, 1)[0]
    else:
        common = prose
    if REMOVED_COMMON.search(common):
        problems.append("removed orchestration instructions")
    for heading in HEADINGS:
        sec = re.sub(r"/nix/store/[a-z0-9]{32}-[^\s`\"]*", "", sections.get(heading, ""))
        if heading in T3_SCOPED_COMMON_HEADINGS:
            for approved in POLICIES[heading]:
                sec = sec.replace("- " + approved, "", 1)
        if REMOVED_NON_T3_SECTIONS.search(sec):
            problems.append("removed orchestration instructions")
            break
    if delivery == "codex":
        body = sections.get(CODEX_HEADING, "")
        for sentence in CODEX_SENTENCES:
            if not sentence_once(body, sentence):
                problems.append(f"missing, repeated or negated Codex policy: {sentence}")
        for profile, values in PROFILES.items():
            rows = re.findall(rf"^\| {profile} \| (.+)$", body, re.MULTILINE)
            fields = [field.strip().strip("`") for field in rows[0].split("|")[1:-1]] if len(rows) == 1 else []
            if fields != list(values):
                problems.append(f"incorrect Codex profile {profile}")
        for role, profile in ROLE_PROFILES.items():
            rows = [line for line in body.splitlines() if line.startswith("| ") and role in line]
            if len(rows) != 1 or rows[0].split("|")[-2].strip() != profile:
                problems.append(f"missing Codex responsibility mapping: {role}")
        if body.strip() != CODEX_CONTRACT:
            problems.append("unapproved Codex normative section")
    elif delivery == "omp":
        tools_body = sections.get(OMP_TOOLS_HEADING, "")
        for sentence in OMP_TOOLS_SENTENCES:
            if not sentence_once(tools_body, sentence):
                problems.append(f"missing, repeated or negated OMP tools policy: {sentence}")
        role_body = sections.get(OMP_ROLE_HEADING, "")
        for sentence in OMP_ROLE_SENTENCES:
            if not sentence_once(role_body, sentence):
                problems.append(f"missing, repeated or negated OMP role policy: {sentence}")
        for profile, values in OMP_PROFILES.items():
            rows = re.findall(rf"^\| {profile} \| (.+)$", role_body, re.MULTILINE)
            fields = [field.strip().strip("`") for field in rows[0].split("|")[1:-1]] if len(rows) == 1 else []
            if fields != list(values):
                problems.append(f"incorrect OMP profile {profile}")
        for role, profile in ROLE_PROFILES.items():
            rows = [line for line in role_body.splitlines() if line.startswith("| ") and role in line]
            if len(rows) != 1 or rows[0].split("|")[-2].strip() != profile:
                problems.append(f"missing OMP responsibility mapping: {role}")
        if tools_body.strip() != OMP_TOOLS_CONTRACT or role_body.strip() != OMP_ROLE_CONTRACT:
            problems.append("unapproved OMP normative section")
    if any(token in text for token in ("{{", "}}", "<no value>")) or re.search(r"@\w+@", text):
        problems.append("unrendered placeholder")
    for line in text.splitlines():
        outside_code = "".join(line.split("`")[::2])
        if re.search(r"(?<!\\)~", outside_code):
            problems.append("unescaped Markdown tilde")
            break
    return problems


def delivery_problems(path, expected, key, delivery="common"):
    try:
        text = path.read_bytes().decode("utf-8")
    except OSError:
        return ["missing delivered instructions"]
    problems = content_problems(text, key, delivery)
    if text != expected:
        problems.append("delivered instructions differ from independent rendering")
    return problems


def self_test(template):
    """Negative controls run the same boundaries as real deliveries."""
    expected = render(template, FAKE_KEY, "common")
    errors = content_problems(expected, FAKE_KEY, "common")
    if errors:
        raise AssertionError(f"unmodified common rendering fails: {errors}")
    for heading, sentences in POLICIES.items():
        for sentence in sentences:
            for replacement in ("", "Do not " + sentence, sentence + " " + sentence):
                mutated = expected.replace(sentence, replacement, 1)
                assert mutated != expected
                assert any(f"policy in {heading}: {sentence}" in problem for problem in content_problems(mutated, FAKE_KEY, "common")), sentence
    for snippet in ("\n# Pi over ACP\n",):
        assert "removed orchestration instructions" in content_problems(expected + snippet, FAKE_KEY, "common")
    for injected in (
        "- Delegate work to a subagent.\n",
        "- Use T3 Code.\n",
        "- Use `delegate_task` for implementation.\n",
    ):
        for mutated in (expected.replace("# Tests\n", "# Tests\n\n" + injected, 1), expected + "\n" + injected):
            assert "removed orchestration instructions" in content_problems(mutated, FAKE_KEY, "common"), injected
    for alias in ("opus", "sonnet", "haiku", "fable"):
        for role in ("reviewers", "workers"):
            text = expected + f"\n- Run {role} on `{alias}`.\n"
            assert "removed orchestration instructions" in content_problems(text, FAKE_KEY, "common")
    assert "incorrect host recipient" in content_problems(expected.replace(FAKE_KEY, CARD_KEY), FAKE_KEY, "common")
    assert "unrendered placeholder" in content_problems(expected + "\n@missing@\n", FAKE_KEY, "common")
    assert "unescaped Markdown tilde" in content_problems(expected + "\nabout ~5 minutes\n", FAKE_KEY, "common")
    assert not content_problems(expected.replace("PIN is usually cached", "PIN is generally cached"), FAKE_KEY, "common")
    for bad in (template + "{{ .unknown }}", template + "{{"):
        try:
            render(bad, FAKE_KEY, "common")
        except ValueError:
            pass
        else:
            raise AssertionError("invalid action was accepted")
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "AGENTS.md"
        assert delivery_problems(path, expected, FAKE_KEY, "common") == ["missing delivered instructions"]
        path.write_text(expected)
        assert not delivery_problems(path, expected, FAKE_KEY, "common")
        path.write_text(expected + "\nAn unintended appendix.\n")
        assert "delivered instructions differ from independent rendering" in delivery_problems(path, expected, FAKE_KEY, "common")
        path.write_text(render(template, CARD_KEY, "common"))
        assert "incorrect host recipient" in delivery_problems(path, expected, FAKE_KEY, "common")

    codex = render(template, FAKE_KEY, "codex")
    errors = content_problems(codex, FAKE_KEY, "codex")
    assert not errors, errors
    for sentence in CODEX_SENTENCES:
        for replacement in ("", "Do not " + sentence, sentence + " " + sentence):
            mutated = codex.replace(sentence, replacement, 1)
            assert mutated != codex
            assert any(sentence in error for error in content_problems(mutated, FAKE_KEY, "codex")), sentence
    for profile, (model, effort, service) in PROFILES.items():
        row = next(line for line in codex.splitlines() if line.startswith(f"| {profile} |"))
        mutant = row.replace(f"`{model}`", "`gpt-6-astra`") if profile != "P7" else row.replace("CE-selected external model", "automatic model")
        assert mutant != row
        assert f"incorrect Codex profile {profile}" in content_problems(codex.replace(row, mutant), FAKE_KEY, "codex")
        mutant = row.replace(f"`{effort}`", "`max`") if profile != "P7" else row.replace("CE-prescribed effort", "automatic max")
        assert mutant != row
        assert f"incorrect Codex profile {profile}" in content_problems(codex.replace(row, mutant), FAKE_KEY, "codex")
        mutant = row.replace(f"| {service} |", "| Ultrafast |")
        assert mutant != row
        assert f"incorrect Codex profile {profile}" in content_problems(codex.replace(row, mutant), FAKE_KEY, "codex")
    for role in ROLE_PROFILES:
        row = next(line for line in codex.splitlines() if line.startswith("| ") and role in line)
        assert f"missing Codex responsibility mapping: {role}" in content_problems(codex.replace(row, ""), FAKE_KEY, "codex")
        for assignment in ("inherit root", "P40 regardless of output length", "P3; P4 is prohibited"):
            wrong = row.rsplit(" | ", 1)[0] + f" | {assignment} |"
            assert f"missing Codex responsibility mapping: {role}" in content_problems(codex.replace(row, wrong), FAKE_KEY, "codex")
    assert "unexpected instruction sections" in content_problems(expected, FAKE_KEY, "codex")
    assert "unexpected instruction sections" in content_problems(codex, FAKE_KEY, "common")
    assert "unexpected instruction sections" in content_problems(codex, FAKE_KEY, "omp")
    for contrary in (
        "Use Fast when allowance is unknown.",
        "Always run reviewers at max effort.",
        "Use Ultrafast without an explicit user request.",
        "Treat a no-write prompt as sufficient enforcement for a restricted peer.",
        "Count a completed peer with missing arrays as a successful empty review.",
        "Treat returned provider labels as verified serving-family evidence.",
    ):
        for separator in (" ", "\n- "):
            mutated_template = template.replace(BLOCK_CLOSE + "\n" + OMP_OPEN, separator + contrary + "\n" + BLOCK_CLOSE + "\n" + OMP_OPEN, 1)
            mutated = render(mutated_template, FAKE_KEY, "codex")
            assert "unapproved Codex normative section" in content_problems(mutated, FAKE_KEY, "codex"), contrary

    omp = render(template, FAKE_KEY, "omp")
    errors = content_problems(omp, FAKE_KEY, "omp")
    assert not errors, errors
    for sentence in OMP_TOOLS_SENTENCES + OMP_ROLE_SENTENCES:
        for replacement in ("", "Do not " + sentence, sentence + " " + sentence):
            mutated = omp.replace(sentence, replacement, 1)
            assert mutated != omp
            assert any(sentence in error for error in content_problems(mutated, FAKE_KEY, "omp")), sentence
    for profile, (model, effort, service) in OMP_PROFILES.items():
        row = next(line for line in omp.splitlines() if line.startswith(f"| {profile} |"))
        mutant = row.replace(f"`{model}`", "`synthetic/hf:zai-org/GLM-5.3`") if profile != "P7" else row.replace("CE-selected external model", "automatic model")
        assert mutant != row
        assert f"incorrect OMP profile {profile}" in content_problems(omp.replace(row, mutant), FAKE_KEY, "omp")
        mutant = row.replace(f"`{effort}`", "`max`") if profile != "P7" else row.replace("CE-prescribed effort", "automatic max")
        assert mutant != row
        assert f"incorrect OMP profile {profile}" in content_problems(omp.replace(row, mutant), FAKE_KEY, "omp")
        mutant = row.replace(f"| {service} |", "| Ultrafast |")
        assert mutant != row
        assert f"incorrect OMP profile {profile}" in content_problems(omp.replace(row, mutant), FAKE_KEY, "omp")
        if profile in ("P3", "P4", "P5", "P6"):
            min_mutant = row.replace(f"`{effort}`", "`minimal`")
            assert f"incorrect OMP profile {profile}" in content_problems(omp.replace(row, min_mutant), FAKE_KEY, "omp")
    assert "unapproved OMP normative section" in content_problems(omp + "\n- Route P3 tasks to `synthetic` automatically.\n", FAKE_KEY, "omp")
    for role in ROLE_PROFILES:
        row = next(line for line in omp.splitlines() if line.startswith("| ") and role in line)
        assert f"missing OMP responsibility mapping: {role}" in content_problems(omp.replace(row, ""), FAKE_KEY, "omp")
    assert "unexpected instruction sections" in content_problems(expected, FAKE_KEY, "omp")
    assert "unexpected instruction sections" in content_problems(omp, FAKE_KEY, "common")
    assert "unexpected instruction sections" in content_problems(omp, FAKE_KEY, "codex")


REPOSITORY_SENTENCES = {
    "AGENTS.md": POLICIES["Review findings"],
    "CONCEPTS.md": [
        "**Review finding** — any item a review, verification, or check step of a Compound Engineering workflow reports about the work that workflow produces or changes, whatever its severity, its confidence, or the list the step files it in.",
        "Every item is assessed; substantiated defects and requirement violations are fixed in the same change.",
        "Agents may reject factually wrong claims, unsupported scenarios, preference-only suggestions, refactors without concrete benefit, and edge-case complexity whose expected benefit does not justify its cost.",
        "Rejections require evidence or a concrete reason; rarity alone does not dismiss credible security or data-loss defects, and code analysis can establish a defect without a reproducer.",
        "A substantiated finding can remain unapplied when every fix would weaken a safety check, the user declined it, a user decision is pending, or no repository change can fix it.",
        "A fix that would reverse a decision the user already made is asked about whenever a person is present, autonomous runs included, and is left unapplied as awaiting that decision only when nobody is there to ask; any other fix that needs a decision only the user can make is asked about in an interactive run, and an autonomous run applies the recommended fix and reports it.",
        "The shared instructions define the disposition tags for unapplied findings; each entry records its evidence or reason.",
    ],
}


def repository_doc_problems(text, kind):
    pattern = (
        r"(?ms)^## Commit and pull request guidelines\n(.*?)(?=^## |\Z)"
        if kind == "AGENTS.md"
        else r"(?ms)^\*\*Review finding\*\*.*?(?=\n\s*\n|\Z)"
    )
    match = re.search(pattern, text)
    body = match[0] if match else ""
    return [
        f"{kind}: missing, repeated or negated review policy: {sentence}"
        for sentence in REPOSITORY_SENTENCES[kind]
        for _ in (0,)
        if not sentence_once(body, sentence)
    ]


def check_repository_docs(agents, concepts):
    problems = []
    for kind, text in (("AGENTS.md", agents), ("CONCEPTS.md", concepts)):
        current = repository_doc_problems(text, kind)
        problems.extend(current)
        if current:
            continue
        for sentence in REPOSITORY_SENTENCES[kind]:
            for replacement in ("", "Do not " + sentence, sentence + " " + sentence):
                mutated = text.replace(sentence, replacement, 1)
                assert mutated != text
                assert any(sentence in problem for problem in repository_doc_problems(mutated, kind)), sentence
    return problems


def main():
    template = Path(sys.argv[1]).read_bytes().decode("utf-8")
    self_test(template)
    if len(sys.argv) == 2:
        return
    entries = json.loads(Path(sys.argv[2]).read_text())
    problems = check_repository_docs(Path(sys.argv[3]).read_text(), Path(sys.argv[4]).read_text())
    for problem in problems:
        print(problem, file=sys.stderr)
    failed = bool(problems)
    expected_renderings = {}
    for entry in entries:
        key = entry["key"]
        for item in entry["paths"]:
            path, delivery = item["path"], item["delivery"]
            variant = (key, delivery)
            if variant not in expected_renderings:
                expected_renderings[variant] = render(template, key, delivery)
            expected = expected_renderings[variant]
            for problem in delivery_problems(Path(path), expected, key, delivery):
                print(f"{entry['name']} {path}: {problem}", file=sys.stderr)
                failed = True
        git = Path(entry["git"])
        git_text = git.read_text() if git.is_file() else ""
        if f'\tsigningKey = "{key}"' not in git_text.splitlines():
            print(f"{entry['name']}: Git does not sign with my.user.gpgKey", file=sys.stderr)
            failed = True
        if key == FAKE_KEY and CARD_KEY in git_text:
            print(f"{entry['name']}: Git names the card key instead of my.user.gpgKey", file=sys.stderr)
            failed = True
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
