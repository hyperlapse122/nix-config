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
# Independent normative selection/limits, not values read back from the template.
PROFILES = {
    "P1": ("gpt-6-luna", "low", "Standard"),
    "P2": ("gpt-6-luna", "medium", "Standard"),
    "P3": ("gpt-6.1-sol", "medium", "Standard"),
    "P4": ("gpt-6.1-sol", "high", "Standard"),
    "P5": ("gpt-6-astra", "low", "Standard"),
    "P6": ("gpt-6-astra", "medium", "Standard"),
    "P7": ("CE-selected external model", "CE-prescribed effort", "Provider default"),
}
CODEX_SENTENCES = [
    "This section applies only to the active Codex harness, including Codex-led T3 sessions.",
    "Never automatically switch to separately billed API access or purchase credits when allowance is exhausted.",
    "Fill unspecified fields from that profile, never implicitly from the parent.",
    "Use P3 for unlisted or newly introduced delegated responsibilities.",
    "Before an above-profile increase, record the named unresolved question or substantive verification failure, evidence, previous configuration and next supported configuration.",
    "Formatting errors, transient network failures, busy slots and missing credentials do not justify deeper reasoning.",
    "GPT `max` and `ultra` require an explicit user request for the affected work.",
    "Standard is the default.",
    "Automatic Fast requires advertised support, a task currently blocking dependent work, known available allowance and a recorded reason for extra usage.",
    "Unknown allowance retains Standard unless the user requests acceleration.",
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
]
# Coverage rows assert responsibility/profile associations, independently of prose.
ROLE_PROFILES = {
    "source-persona fetch": "P1", "media analyzer": "P3",
    "decisions/reconciliation": "P5", "`ce-brainstorm` grounding": "P2",
    "repo/history/learnings/framework-docs/web/best-practices": "P2",
    "spec-flow analyzer": "P4", "architecture strategist/complex plan author": "P6",
    "implementation/design-sync": "P3", "investigation/root cause": "P4",
    "work-recap/behavior-trace": "P2", "evidence researchers/issue intelligence": "P2",
    "generation/ceiling": "P3/P6/P7", "verdict/synthesis": "P6",
    "correctness, standards": "P4", "merge/validator/report": "P3/P4/P3",
    "whole-doc, coherence": "P4", "reuse, quality": "P4",
    "Related Docs Finder": "P2", "session historian": "P3",
    "security sentinel": "P4", "investigators/replacement authors": "P3",
    "Browser/device/prototype": "P3", "Commit/publication/babysitting": "P5",
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
        "Force-push only the head branch of a pull or merge request you opened, in this or an earlier session, only with `--force-with-lease`, and never a base branch.",
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
        "Apply every finding that a review, verification, or check step of any Compound Engineering skill reports about the work the workflow produces or changes, such as `ce-code-review`, `ce-simplify-code`, and `ce-doc-review`, in the same change, whatever its severity, confidence, or list, including testing gaps and residual risks.",
        "A fix that reaches outside the diff or the change's scope, such as existing behavior or helpers the change did not touch, is made in the same change.",
        "Leave a finding unapplied only in these cases: you verified it is wrong, quoting the evidence; every fix for it would weaken a safety check; the user declined its fix when asked; its fix would reverse a decision the user made and no person is present to ask; or no change in this repository can fix it.",
        "A fix that would reverse a decision the user made, a brainstorm Scope Boundary or `session-settled` entry included, is asked in every run with a person present, autonomous runs included, and listed as `awaits your decision` in a run with no person present.",
        "When the user asked only for a review, report the findings and ask once whether to apply them all.",
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
    """Independent renderer for a field and one terminal delivery conditional."""
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
            if len(rows) != 1 or profile not in rows[0].split(" | ")[-1]:
                problems.append(f"missing Codex responsibility mapping: {role}")
        # Extra policy can reverse a guarded sentence while leaving it present.
        # Reject contrary dispatch instructions, including separate bullets.
        contrary = re.compile(
            r"(?:^|[.!?]\s+|\n)\s*(?:- )?(?:"
            r"(?:automatically|always) (?:select|use|choose|request) (?:GPT )?`?(?:max|ultra|Ultrafast|Fast)|"
            r"(?:inherit|use) (?:the )?parent(?:'s)? (?:model|effort|settings)|"
            r"(?:ignore|skip|drop|bypass) (?:CE|required|recipient|review)|"
            r"(?:never|do not) (?:use|retain|preserve) (?:P7|CE|independent)|"
            r"(?:missing arrays|wait timeout|pending approval|selection mismatch) (?:is|means|counts as) (?:success|complete)|"
            r"(?:use|select) (?:paid API|API fallback))", re.IGNORECASE,
        )
        if contrary.search(body):
            problems.append("contradictory Codex policy")
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
    # Guard policy, not just delivery equality against the same edited template.
    for sentence in CODEX_SENTENCES:
        for replacement in ("", "Do not " + sentence, sentence + " " + sentence):
            mutated = codex.replace(sentence, replacement, 1)
            assert mutated != codex
            assert any(sentence in error for error in content_problems(mutated, FAKE_KEY, True)), sentence
    for profile, (_, effort, _) in PROFILES.items():
        row = next(line for line in codex.splitlines() if line.startswith(f"| {profile} |"))
        mutant = row.replace(f"`{effort}`", "`max`") if profile != "P7" else row.replace("CE-prescribed effort", "automatic max")
        assert mutant != row
        assert f"incorrect Codex profile {profile}" in content_problems(codex.replace(row, mutant), FAKE_KEY, True)
        mutant = row.replace("Standard", "Fast") if profile != "P7" else row.replace("Provider default", "Ultrafast")
        assert mutant != row
        assert f"incorrect Codex profile {profile}" in content_problems(codex.replace(row, mutant), FAKE_KEY, True)
    for role in ROLE_PROFILES:
        row = next(line for line in codex.splitlines() if line.startswith("| ") and role in line)
        assert f"missing Codex responsibility mapping: {role}" in content_problems(codex.replace(row, ""), FAKE_KEY, True)
        wrong = row.rsplit(" | ", 1)[0] + " | inherit root |"
        assert f"missing Codex responsibility mapping: {role}" in content_problems(codex.replace(row, wrong), FAKE_KEY, True)
    assert "unexpected instruction sections" in content_problems(expected, FAKE_KEY, True)
    assert "removed orchestration instructions" in content_problems(codex, FAKE_KEY)
    for contrary in (
        "Automatically select max for reviewers.", "Always use Ultrafast.",
        "Use the parent's effort.", "Skip required review.",
        "Never use P7.", "Missing arrays means success.", "Use paid API fallback.",
    ):
        for separator in (" ", "\n- "):
            assert "contradictory Codex policy" in content_problems(codex + separator + contrary, FAKE_KEY, True), contrary
    # Variant wiring mutations exercise the same delivered-file boundary.
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
    "AGENTS.md": [POLICIES["Review findings"][i] for i in (0, 2, 3)],
    "CONCEPTS.md": [
        "**Review finding** — any item a review, verification, or check step of a Compound Engineering workflow reports about the work that workflow produces or changes, whatever its severity, its confidence, or the list the step files it in.",
        "Here every one of those items is a finding and is applied in the same change.",
        "The only exceptions are an item verified to be wrong, one whose fix would weaken a safety check, one whose fix the user declined when asked, one whose fix would reverse a decision the user made in a run with no person present to ask, and one that no change in the repository can fix.",
        "A fix that would reverse a decision the user already made is asked about whenever a person is present, autonomous runs included, and is left unapplied as awaiting that decision only when nobody is there to ask; any other fix that needs a decision only the user can make is asked about in an interactive run, and an autonomous run applies the recommended fix and reports it.",
        "Each item left unapplied is reported under the tag of the exception it falls under: verified wrong, weakens a safety check, declined by you, awaits your decision, or no fix in this repository.",
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
    for entry in entries:
        key = entry["key"]
        for delivery in entry["paths"]:
            path, codex = delivery["path"], delivery["codex"]
            expected = render(template, key, codex)
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
