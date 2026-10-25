# OMP tools and Compound Engineering

Use native `web_search` for search and `read` with an HTTP URL for fetching.
Search uses the managed Synthetic credential command; never read or print keys.
Use `read history://` for the agent roster and `read history://current/full`
for the current transcript. Runtime model and effort evidence comes from the
protocol state or captured provider requests; configuration and model prose do
not establish the effective runtime selection.

Outside T3, native `task` runs CLI children. Read its advertised schema before
dispatch: batch calls require `context` and `tasks`, with `agent` per task.
Structured results are enabled; pass the owning workflow's `outputSchema` and
collect the child's terminal `yield` rather than accepting a prose summary.
Collect terminal results through `agent://<id>` and inspect `history://<id>`
when needed. A started job, partial yield, cancellation, or failure is not a
completed child. Preserve full result artifacts and required schema fields.
Inside T3, use the injected app-owned MCP delegation, status and cancellation
tools according to their live descriptions. Do not replace app delegation with
new top-level conversations.

Compound Engineering skills live in the complete pinned tree under
`~/.omp/agent/plugins/compound-engineering`. Read referenced assets relative to
that tree. Retain each skill's recipient permission, tool restrictions, identity
checks, result schema, and lifecycle rules. GLM does not establish a recognized
CE host family: explicitly requested cross-model review must follow the skill's
supported identity route or report that pass unavailable. Never invent an OMP
peer token, infer independent serving families from provider labels, or turn a
missing, failed or cancelled result into a successful empty review. Preserve
attributed findings, residual risks and testing gaps; label serving identity and
independence unverified unless supported evidence establishes them.

For an explicitly requested `ce-code-review` cross-model pass from GLM, keep
the host serving family `unknown` and host harness `omp`. Automatic unknown-host
review remains skipped. The OMP-only CE source patch permits the explicit CLI
route below; the other harnesses retain the unmodified pinned source.

Outside T3, first follow `ce-code-review/references/cross-model-review.md` for
checkout policy, recipient consent and disclosure, fixed-route resolution,
model/effort selection, read-only restrictions, constraints, and lifecycle.
For this run only, add `CROSS_MODEL_EXPLICIT_UNKNOWN_HOST=1` to the worker's
`env` prefix in the existing `peer-job-runner.py start` command. Also pass
`CROSS_MODEL_HOST_HARNESS=omp`, one `CROSS_MODEL_FIXED_ROUTE`, a nonempty
`CROSS_MODEL_PEERS` that sanctions every recipient, host family `unknown`, and
exactly that route's target as the candidate. A stored preference alone is not
an explicit opt-in. Do not export the opt-in as a session default. Normalize
through the shipped worker and consume only its verified terminal artifact;
exit 0 without an artifact means the pass did not produce a usable review.

Inside T3, use app-owned delegation instead of launching the CLI peer worker.
Discover the selected provider/model and option descriptors, disclose all
recipients, and preserve the skill's prescribed identity, effort, scope, schema,
deadlines and cleanup. The user permits explicitly requested OMP cross-model
reviews through T3's ordinary delegated permissions without enforced read-only
access. Tell the reviewer to inspect without editing, and report that this is an
instruction rather than a technical restriction. This exception does not change
CLI restrictions, recipient consent, or any other agent's review policy. Validate the
complete terminal artifact, retain task IDs and requested/returned selection,
and keep serving model/effort `unverified` without serving evidence. Neither
native task fixtures nor T3 selection metadata are independent-review receipts.

In both routes, label the result a cross-harness review with independence
unverified. Preserve attributed findings, but never promote agreement from an
unknown host: `independence_verified` must remain `false`. Never substitute a
recognized family for GLM to get past an identity guard.
