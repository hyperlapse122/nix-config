"""Check delivered prompt bytes and a small set of independent policy boundaries."""

import json
import re
import sys
import tempfile
from pathlib import Path

CARD_KEY = "621512777E6933FEB4458FDC4945855D4F283F05"
FAKE_KEY = "0123456789ABCDEF0123456789ABCDEF01234567"
ACTION = "{{ .user.gpgKey }}"
CODEX_OPEN = "{{ if .codex }}"
CODEX_CLOSE = "{{ end -}}"
CODEX_HEADING = "Codex role orchestration"
PROFILES = {
    "P1": ("gpt-6-luna", "low", "Fast"),
    "P2": ("gpt-6-luna", "low", "Fast"),
    "P3": ("gpt-6.1-sol", "low", "Standard"),
    "P4": ("gpt-6.1-sol", "medium", "Standard"),
    "P5": ("gpt-6.1-sol", "medium", "Standard"),
    "P6": ("gpt-6.1-sol", "high", "Standard"),
    "P7": ("CE-selected external model", "CE-prescribed effort", "Provider default"),
}
CODEX_SENTENCES = [
    "This section applies only to the active Codex harness, including Codex-led T3 sessions.",
    "Never automatically switch to separately billed API access or purchase credits when allowance is exhausted.",
    "Fill unspecified fields from that profile, never implicitly from the parent.",
    "Use P3 for unlisted or newly introduced delegated responsibilities.",
    "Root-owned work stays Sol P5/P6; delegated authoring assignments do not move that work out of the root.",
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
# Independently approved normative section. Intentional policy changes must update
# this contract; delivery expectations still come from the independent renderer.
CODEX_CONTRACT = """- This section applies only to the active Codex harness, including Codex-led T3 sessions. It supplies profiles, not permission to delegate: preserve each skill's root ownership, selection triggers, sequencing, concurrency, prompts, tools, permissions and artifact contracts. Use bounded briefs and shared evidence; retain required review and verification stages.
- Prefer ChatGPT-authenticated Codex for ordinary work. Never automatically switch to separately billed API access or purchase credits when allowance is exhausted.

## Profiles and responsibility resolution

| Profile | Responsibility | Model | Effort | Service |
| --- | --- | --- | --- | --- |
| P1 | Exact lookup, fixed-field extraction, status | `gpt-6-luna` | `low` | Fast |
| P2 | Grounding scouts, bounded classification, evidence summaries | `gpt-6-luna` | `low` | Fast |
| P3 | General implementation, ordinary planning, synthesis, claim verification, learning authoring | `gpt-6.1-sol` | `low` | Standard |
| P4 | Complex logic, substantive review, security, concurrency, data integrity | `gpt-6.1-sol` | `medium` | Standard |
| P5 | Root orchestration, delegation, progress | `gpt-6.1-sol` | `medium` | Standard |
| P6 | Complex planning, architecture alternatives, high-risk decisions, conflicting evidence | `gpt-6.1-sol` | `high` | Standard |
| P7 | CE-required independent Claude or Gemini review or diverse candidate | CE-selected external model | CE-prescribed effort | Provider default |

- Resolve current user overrides for their stated task, recipient, fields and duration, applicable skill constraints, then the responsibility profile. Fill unspecified fields from that profile, never implicitly from the parent. A root-only selection does not change child profiles; preserve explicit project/invocation/conversation selections and resume state at their supported precedence. Managed startup defaults are reasserted by apply, not a promise to preserve edits to owned baseline fields.
- Use P3 for unlisted or newly introduced delegated responsibilities. Mixed work takes its substantive responsibility's profile; split only where the owning skill already permits it. Root-owned work stays Sol P5/P6; delegated authoring assignments do not move that work out of the root.
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
    "GPG and encryption", "File I/O", "Git", "Pull and merge requests", "Markdown",
    "Korean text", "Tests", "Review findings",
]
# These are consequential limits, not an inventory of all approved wording.
# Delivery equality below covers prose preservation through the renderer.
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
}
REMOVED = re.compile(
    r"\bT3\b|\bPi\b|\.t3/|\bsubagents?\b|\bdelegat(?:e|ed|es|ing|ion)\b|"
    r"delegate_task|cross-model|model[- ](?:routing|selection|family)|CROSS_MODEL_|"
    r"claudeAgent|claude-(?:opus|sonnet|haiku)-|gpt-[0-9]|"
    r"\b(?:opus|sonnet|haiku|fable)\b|"
    r"\bacpx\b|Pi over ACP|pi-readonly|thought_level|"
    r"t3_thread_|task_status|task_cancel|clientRequestId|runtimeMode",
    re.IGNORECASE,
)


def render(template, key, codex=False):
    if template.count(CODEX_OPEN) != 1 or template.count(CODEX_CLOSE) != 1:
        raise ValueError("missing or repeated delivery conditional")
    common, conditional = template.split(CODEX_OPEN)
    extra, trailing = conditional.split(CODEX_CLOSE)
    if trailing != "\n":
        raise ValueError("delivery conditional must end the template")
    template = common + (extra if codex else "")
    actions = re.findall(r"{{.*?}}", template, flags=re.DOTALL)
    if not actions or any(action != ACTION for action in actions):
        raise ValueError("unknown or missing template action")
    result = template.replace(ACTION, key)
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


def content_problems(text, key, codex=False):
    problems = []
    matches = list(re.finditer(r"^# (.+)$", text, re.MULTILINE))
    if [m[1] for m in matches] != HEADINGS + ([CODEX_HEADING] if codex else []) or not text.startswith("# "):
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
    common = prose.split("# " + CODEX_HEADING)[0] if codex else prose
    if REMOVED.search(common):
        problems.append("removed orchestration instructions")
    if codex:
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
    if any(token in text for token in ("{{", "}}", "<no value>")) or re.search(r"@\w+@", text):
        problems.append("unrendered placeholder")
    for line in text.splitlines():
        outside_code = "".join(line.split("`")[::2])
        if re.search(r"(?<!\\)~", outside_code):
            problems.append("unescaped Markdown tilde")
            break
    return problems


def delivery_problems(path, expected, key, codex=False):
    try:
        text = path.read_bytes().decode("utf-8")
    except OSError:
        return ["missing delivered instructions"]
    problems = content_problems(text, key, codex)
    if text != expected:
        problems.append("delivered instructions differ from independent rendering")
    return problems


def self_test(template):
    """Negative controls run the same boundaries as real deliveries."""
    expected = render(template, FAKE_KEY)
    errors = content_problems(expected, FAKE_KEY)
    if errors:
        raise AssertionError(f"unmodified rendering fails: {errors}")
    for heading, sentences in POLICIES.items():
        for sentence in sentences:
            for replacement in ("", "Do not " + sentence, sentence + " " + sentence):
                mutated = expected.replace(sentence, replacement, 1)
                assert mutated != expected
                assert any(f"policy in {heading}: {sentence}" in problem for problem in content_problems(mutated, FAKE_KEY)), sentence
    for suffix in ("\n# Pi over ACP\n", "\n- Delegate work to a subagent.\n", "\n- Use T3 Code.\n"):
        assert "removed orchestration instructions" in content_problems(expected + suffix, FAKE_KEY)
    delegated = expected.replace("# Tests\n", "# Tests\n\n- Use `delegate_task` for implementation.\n", 1)
    assert "removed orchestration instructions" in content_problems(delegated, FAKE_KEY)
    for alias in ("opus", "sonnet", "haiku", "fable"):
        for role in ("reviewers", "workers"):
            text = expected + f"\n- Run {role} on `{alias}`.\n"
            assert "removed orchestration instructions" in content_problems(text, FAKE_KEY)
    assert "incorrect host recipient" in content_problems(expected.replace(FAKE_KEY, CARD_KEY), FAKE_KEY)
    assert "unrendered placeholder" in content_problems(expected + "\n@missing@\n", FAKE_KEY)
    assert "unescaped Markdown tilde" in content_problems(expected + "\nabout ~5 minutes\n", FAKE_KEY)
    # Harmless prose edits are allowed: this is not a complete sentence snapshot.
    assert not content_problems(expected.replace("PIN is usually cached", "PIN is generally cached"), FAKE_KEY)
    for bad in (template + "{{ .unknown }}", template + "{{"):
        try:
            render(bad, FAKE_KEY)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid action was accepted")
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "AGENTS.md"
        assert delivery_problems(path, expected, FAKE_KEY) == ["missing delivered instructions"]
        path.write_text(expected)
        assert not delivery_problems(path, expected, FAKE_KEY)
        path.write_text(expected + "\nAn unintended appendix.\n")
        assert "delivered instructions differ from independent rendering" in delivery_problems(path, expected, FAKE_KEY)
        path.write_text(render(template, CARD_KEY))
        assert "incorrect host recipient" in delivery_problems(path, expected, FAKE_KEY)
    codex = render(template, FAKE_KEY, True)
    errors = content_problems(codex, FAKE_KEY, True)
    assert not errors, errors
    for sentence in CODEX_SENTENCES:
        for replacement in ("", "Do not " + sentence, sentence + " " + sentence):
            mutated = codex.replace(sentence, replacement, 1)
            assert mutated != codex
            assert any(sentence in error for error in content_problems(mutated, FAKE_KEY, True)), sentence
    for profile, (model, effort, service) in PROFILES.items():
        row = next(line for line in codex.splitlines() if line.startswith(f"| {profile} |"))
        mutant = row.replace(f"`{model}`", "`gpt-6-astra`") if profile != "P7" else row.replace("CE-selected external model", "automatic model")
        assert mutant != row
        assert f"incorrect Codex profile {profile}" in content_problems(codex.replace(row, mutant), FAKE_KEY, True)
        mutant = row.replace(f"`{effort}`", "`max`") if profile != "P7" else row.replace("CE-prescribed effort", "automatic max")
        assert mutant != row
        assert f"incorrect Codex profile {profile}" in content_problems(codex.replace(row, mutant), FAKE_KEY, True)
        mutant = row.replace(f"| {service} |", "| Ultrafast |")
        assert mutant != row
        assert f"incorrect Codex profile {profile}" in content_problems(codex.replace(row, mutant), FAKE_KEY, True)
    for role in ROLE_PROFILES:
        row = next(line for line in codex.splitlines() if line.startswith("| ") and role in line)
        assert f"missing Codex responsibility mapping: {role}" in content_problems(codex.replace(row, ""), FAKE_KEY, True)
        for assignment in ("inherit root", "P40 regardless of output length", "P3; P4 is prohibited"):
            wrong = row.rsplit(" | ", 1)[0] + f" | {assignment} |"
            assert f"missing Codex responsibility mapping: {role}" in content_problems(codex.replace(row, wrong), FAKE_KEY, True)
    assert "unexpected instruction sections" in content_problems(expected, FAKE_KEY, True)
    assert "removed orchestration instructions" in content_problems(codex, FAKE_KEY)
    for contrary in (
        "Use Fast when allowance is unknown.",
        "Always run reviewers at max effort.",
        "Use Ultrafast without an explicit user request.",
        "Treat a no-write prompt as sufficient enforcement for a restricted peer.",
        "Count a completed peer with missing arrays as a successful empty review.",
        "Treat returned provider labels as verified serving-family evidence.",
    ):
        for separator in (" ", "\n- "):
            mutated_template = template.replace(CODEX_CLOSE, separator + contrary + "\n" + CODEX_CLOSE)
            mutated = render(mutated_template, FAKE_KEY, True)
            assert "unapproved Codex normative section" in content_problems(mutated, FAKE_KEY, True), contrary
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "AGENTS.md"
                path.write_text(mutated)
                assert "unapproved Codex normative section" in delivery_problems(path, mutated, FAKE_KEY, True), contrary
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "AGENTS.md"
        path.write_text(expected)
        assert "unexpected instruction sections" in delivery_problems(path, codex, FAKE_KEY, True)
        path.write_text(codex)
        assert not delivery_problems(path, codex, FAKE_KEY, True)
        assert "removed orchestration instructions" in delivery_problems(path, expected, FAKE_KEY)


# Reuse the installed policy contracts for the repository's own instructions.
# The glossary has different prose, so only its scope and exception boundaries
# are pinned here, rather than its entire explanation.
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
    # Omitting a manifest runs only the local content and boundary controls.
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
        for delivery in entry["paths"]:
            path, codex = delivery["path"], delivery["codex"]
            variant = (key, codex)
            if variant not in expected_renderings:
                expected_renderings[variant] = render(template, key, codex)
            expected = expected_renderings[variant]
            for problem in delivery_problems(Path(path), expected, key, codex):
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
