"""Drive synthetic-models-watch against the 2026-10-21 catalog snapshot.

The helper's network call and its Nix evaluation go through overridable
commands, so these tests feed it fixture catalogs and record what the stub
fetch command received instead of making network calls.

The models in use are the real home/h82/agents/synthetic-models.nix, never
a copy: the flake check passes its evaluated JSON in
SYNTHETIC_MODELS_SOURCE_JSON, and a local run evaluates it with nix.
"""

import atexit
import copy
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/synthetic-models-watch"
FIXTURES = ROOT / "tests/fixtures/synthetic-models"
SNAPSHOT = FIXTURES / "catalog-2026-10-21.json"
SOURCE_FILE = "home/h82/agents/synthetic-models.nix"


def evaluated_source():
    """The path of the real model source as JSON."""
    given = os.environ.get("SYNTHETIC_MODELS_SOURCE_JSON")
    if given:
        return Path(given)
    fd, name = tempfile.mkstemp(suffix=".json")
    atexit.register(os.unlink, name)
    with os.fdopen(fd, "w") as f:
        subprocess.run(
            ["nix", "eval", "--json", "--file", str(ROOT / SOURCE_FILE)],
            stdout=f, check=True, stdin=subprocess.DEVNULL,
        )
    return Path(name)


SOURCE = evaluated_source()


def load_watch():
    """The script as a module, for its pure functions."""
    loader = importlib.machinery.SourceFileLoader("synthetic_models_watch", str(SCRIPT))
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
    loader.exec_module(module)
    return module
URL = "https://api.synthetic.new/openai/v1/models"
DETECTED = "2026-10-21T09:00:00Z"
KEY = "syn-fake-key-0123456789"

GLM = "hf:zai-org/GLM-5.3"
KIMI = "hf:moonshotai/Kimi-K3"
DEEPSEEK = "hf:deepseek-ai/DeepSeek-V4.1-Flash-1017"

# Records its argv and stdin, then answers from a queue of outcomes: an
# integer exits with that status the way `curl -f` does, anything else is
# written to stdout as the response body.
FAKE_FETCH = """#!/usr/bin/env python3
import json, os, sys
log = os.environ['FAKE_LOG']
calls = json.load(open(log)) if os.path.exists(log) else []
calls.append({'argv': sys.argv[1:], 'stdin': sys.stdin.read(),
              'env_has_key': 'SYNTHETIC_API_KEY' in os.environ})
json.dump(calls, open(log, 'w'))
outcomes = json.loads(os.environ['FAKE_OUTCOMES'])
outcome = outcomes[min(len(calls), len(outcomes)) - 1]
if isinstance(outcome, int):
    if outcome == 22:
        sys.stderr.write('curl: (22) The requested URL returned error: 429\\n')
    if outcome == 6:
        sys.stderr.write('curl: (6) rejected header ' + calls[-1]['stdin'].strip() + '\\n')
    sys.exit(outcome)
sys.stdout.write(outcome)
"""

# Stand in for `nix` and `curl` on PATH, so the default command lines the
# script builds are the ones under test. Each records its argv.
FAKE_NIX = """#!{python}
import json, os, sys
json.dump(sys.argv[1:], open(os.environ['FAKE_NIX_LOG'], 'w'))
sys.stdout.write(open(os.environ['FAKE_EVAL_SOURCE']).read())
"""

FAKE_CURL = """#!{python}
import json, os, sys
json.dump({{'argv': sys.argv[1:], 'stdin': sys.stdin.read()}}, open(os.environ['FAKE_CURL_LOG'], 'w'))
sys.stdout.write(open(os.environ['FAKE_CATALOG']).read())
"""

SLOW_NIX = """#!{python}
import time
time.sleep(30)
"""


def snapshot():
    return json.loads(SNAPSHOT.read_text())


def row(model_id, created, efforts=("low", "high", "max"), **extra):
    entry = {"id": model_id, "created": created, "reasoning_parameters": {"efforts": list(efforts)}}
    entry.update(extra)
    return entry


def created_of(catalog, model_id):
    return next(m["created"] for m in catalog["data"] if m["id"] == model_id and "alias_of" not in m)


def without(catalog, model_id):
    catalog = copy.deepcopy(catalog)
    catalog["data"] = [m for m in catalog["data"] if m["id"] != model_id or "alias_of" in m]
    return catalog


def with_rows(catalog, *rows):
    catalog = copy.deepcopy(catalog)
    catalog["data"].extend(rows)
    return catalog


class WatchTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.result = self.root / "result.json"
        self.body = self.root / "issue.md"
        self.fetch = self.root / "fake-fetch"
        self.fetch.write_text(FAKE_FETCH)
        self.fetch.chmod(0o755)
        self.log = self.root / "fetch-log.json"

    def run_watch(self, catalog=None, extra=None, env=None):
        """Run the helper on a catalog file and return the process."""
        args = [sys.executable, str(SCRIPT), "--source-json", str(SOURCE)]
        if catalog is not None:
            path = self.root / "catalog.json"
            path.write_text(catalog if isinstance(catalog, str) else json.dumps(catalog))
            args += ["--catalog", str(path)]
        args += [
            "--detected-at", DETECTED,
            "--result", str(self.result),
            "--issue-body", str(self.body),
            "--retry-wait", "0",
        ]
        args += extra or []
        full_env = dict(os.environ)
        full_env.pop("SYNTHETIC_API_KEY", None)
        full_env.update(env or {})
        return subprocess.run(args, capture_output=True, text=True, env=full_env)

    def run_fetch(self, outcomes, key=None):
        """Run the helper through the stub fetch command."""
        env = {
            "SYNTHETIC_MODELS_FETCH": f"{sys.executable} {self.fetch}",
            "FAKE_LOG": str(self.log),
            "FAKE_OUTCOMES": json.dumps(outcomes),
        }
        if key is not None:
            env["SYNTHETIC_API_KEY"] = key
        return self.run_watch(env=env)

    def calls(self):
        return json.loads(self.log.read_text()) if self.log.exists() else []

    def drift(self, catalog):
        proc = self.run_watch(catalog)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(self.result.read_text())
        self.assertEqual(result["status"], "drift", result)
        return result, self.body.read_text()

    def assert_clean(self, catalog):
        proc = self.run_watch(catalog)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(self.result.read_text())
        self.assertEqual(result["status"], "clean", result)
        self.assertEqual(result["findings"], [])
        self.assertIsNone(result["fingerprint"])
        self.assertFalse(self.body.exists(), "a clean run must write no issue body")
        return result

    def finding(self, result, kind, entry):
        matches = [f for f in result["findings"] if f["kind"] == kind and f["entry"] == entry]
        self.assertEqual(len(matches), 1, result["findings"])
        return matches[0]


class ClassificationTest(WatchTestCase):
    def test_the_snapshot_yields_no_difference(self):
        self.assert_clean(snapshot())

    def test_missing_kimi_is_removed_with_its_roles(self):
        result, body = self.drift(without(snapshot(), KIMI))
        self.assertEqual(len(result["findings"]), 1, result["findings"])
        finding = self.finding(result, "removed", "kimi")
        self.assertEqual(finding["id"], KIMI)
        self.assertEqual(finding["uses"], ["reviewer", "visual-engineering-fallback"])
        first = body.splitlines()[0]
        for needle in (f"`{KIMI}`", "removed", "`reviewer`", "`visual-engineering-fallback`",
                       f"`{SOURCE_FILE}`", DETECTED):
            self.assertIn(needle, first)
        for needle in (f"`{KIMI}`", "removed", SOURCE_FILE):
            self.assertIn(needle, result["title"])
        self.assertIn("Before you edit the source, confirm on Synthetic that the ID names the model you expect.", body)

    def test_an_alias_row_does_not_keep_a_removed_model_present(self):
        catalog = without(snapshot(), KIMI)
        catalog = with_rows(catalog, row(KIMI, 1785110400, alias_of="Kimi K3"))
        result, _ = self.drift(catalog)
        self.finding(result, "removed", "kimi")

    def test_a_later_deepseek_build_is_a_new_version(self):
        catalog = snapshot()
        later = created_of(catalog, DEEPSEEK) + 86400
        candidate = "hf:deepseek-ai/DeepSeek-V4.1-Flash-1120"
        result, body = self.drift(with_rows(catalog, row(candidate, later)))
        self.assertEqual(len(result["findings"]), 1, result["findings"])
        finding = self.finding(result, "new-version", "deepseek")
        self.assertEqual(finding["id"], DEEPSEEK)
        self.assertEqual(finding["candidates"], [candidate])
        self.assertEqual(finding["uses"], ["quick", "scout", "text-generation", "unspecified-low", "small", "textGeneration"])
        first = body.splitlines()[0]
        for needle in (f"`{DEEPSEEK}`", f"`{candidate}`", "`quick`", "`unspecified-low`", DETECTED):
            self.assertIn(needle, first)
        self.assertIn(f"`{candidate}`", result["title"])

    def test_candidates_are_listed_newest_first(self):
        catalog = snapshot()
        base = created_of(catalog, DEEPSEEK)
        catalog = with_rows(
            catalog,
            row("hf:deepseek-ai/DeepSeek-V4.1-Flash-1120", base + 10),
            row("hf:deepseek-ai/DeepSeek-V4.2-Flash", base + 20),
        )
        result, _ = self.drift(catalog)
        finding = self.finding(result, "new-version", "deepseek")
        self.assertEqual(
            finding["candidates"],
            ["hf:deepseek-ai/DeepSeek-V4.2-Flash", "hf:deepseek-ai/DeepSeek-V4.1-Flash-1120"],
        )

    def test_suffixed_products_and_lower_versions_are_not_newer(self):
        catalog = snapshot()
        later = max(created_of(catalog, GLM), created_of(catalog, KIMI)) + 86400
        self.assert_clean(with_rows(
            catalog,
            row("hf:zai-org/GLM-5.3-Flash", later),
            row("hf:zai-org/GLM-5.3-Air", later),
            row("hf:moonshotai/Kimi-K2.7-Code", later),
            row("hf:zai-org/GLM-4.7", later),
            row("hf:moonshotai/Kimi-K2.9", later),
            row("hf:deepseek-ai/DeepSeek-V4.0-Flash-1201", later + created_of(catalog, DEEPSEEK)),
        ))

    def test_a_higher_version_on_the_same_created_is_newer(self):
        catalog = snapshot()
        same = created_of(catalog, GLM)
        result, _ = self.drift(with_rows(catalog, row("hf:zai-org/GLM-5.4", same)))
        self.assertEqual(self.finding(result, "new-version", "glm")["candidates"], ["hf:zai-org/GLM-5.4"])

    def test_a_higher_version_with_an_earlier_or_missing_created_is_newer(self):
        catalog = snapshot()
        earlier = created_of(catalog, GLM) - 86400
        no_created = row("hf:zai-org/GLM-6", None)
        del no_created["created"]
        result, _ = self.drift(with_rows(catalog, row("hf:zai-org/GLM-5.4", earlier), no_created))
        self.assertEqual(
            self.finding(result, "new-version", "glm")["candidates"],
            ["hf:zai-org/GLM-6", "hf:zai-org/GLM-5.4"],
        )

    def test_an_equal_version_is_newer_only_with_a_later_created(self):
        catalog = snapshot()
        base = created_of(catalog, DEEPSEEK)
        candidate = "hf:deepseek-ai/DeepSeek-V4.1-Flash-1120"
        no_created = row(candidate, None)
        del no_created["created"]
        for sibling in (row(candidate, base), row(candidate, "1793000000"), no_created):
            with self.subTest(created=sibling.get("created", "missing")):
                self.assert_clean(with_rows(catalog, sibling))
        result, _ = self.drift(with_rows(catalog, row(candidate, base + 1)))
        self.assertEqual(self.finding(result, "new-version", "deepseek")["candidates"], [candidate])

    def test_an_equal_version_is_not_newer_when_the_model_in_use_has_no_created(self):
        catalog = snapshot()
        for model in catalog["data"]:
            if model["id"] == DEEPSEEK:
                del model["created"]
        self.assert_clean(with_rows(catalog, row("hf:deepseek-ai/DeepSeek-V4.1-Flash-1120", 1793000000)))
        result, _ = self.drift(with_rows(catalog, row("hf:deepseek-ai/DeepSeek-V4.2-Flash", 1)))
        self.assertEqual(
            self.finding(result, "new-version", "deepseek")["candidates"], ["hf:deepseek-ai/DeepSeek-V4.2-Flash"]
        )

    def test_an_equal_version_with_a_later_created_is_newer(self):
        catalog = snapshot()
        result, _ = self.drift(with_rows(catalog, row("hf:moonshotai/Kimi-K3.0", created_of(catalog, KIMI) + 1)))
        self.assertEqual(self.finding(result, "new-version", "kimi")["candidates"], ["hf:moonshotai/Kimi-K3.0"])

    def test_syn_rows_are_ignored_and_an_hf_alias_row_is_a_candidate(self):
        catalog = snapshot()
        later = created_of(catalog, GLM) + 86400
        self.assert_clean(with_rows(
            catalog,
            row("syn:zai-org/GLM-6", later),
            row("syn:zai-org/GLM-6", later, alias_of="GLM 6"),
            row("hf:zai-org/GLM-6-Air", later, alias_of="GLM 6 Air"),
        ))
        result, _ = self.drift(with_rows(catalog, row("hf:zai-org/GLM-6", later, alias_of="GLM 6")))
        self.assertEqual([f["kind"] for f in result["findings"]], ["new-version"])
        self.assertEqual(self.finding(result, "new-version", "glm")["candidates"], ["hf:zai-org/GLM-6"])

    def test_a_removed_model_lists_its_lineage_candidates(self):
        catalog = with_rows(
            without(snapshot(), KIMI),
            row("hf:moonshotai/Kimi-K3.1", 1),
            row("hf:moonshotai/Kimi-K3.0", 2),
            row("hf:moonshotai/Kimi-K2.9", 3),
            row("hf:moonshotai/Kimi-K3.1-Code", 4),
        )
        result, body = self.drift(catalog)
        finding = self.finding(result, "removed", "kimi")
        self.assertEqual(finding["candidates"], ["hf:moonshotai/Kimi-K3.1", "hf:moonshotai/Kimi-K3.0"])
        self.assertIn("candidate `hf:moonshotai/Kimi-K3.1`", body.splitlines()[0])

    def test_a_row_can_be_both_a_new_version_and_changed(self):
        catalog = snapshot()
        for model in catalog["data"]:
            if model["id"] == GLM:
                model["reasoning_parameters"]["efforts"] = ["low", "high"]
        later = created_of(catalog, GLM) + 1
        result, body = self.drift(with_rows(catalog, row("hf:zai-org/GLM-5.4", later)))
        self.assertEqual(sorted(f["kind"] for f in result["findings"]), ["changed", "new-version"])
        self.assertEqual(self.finding(result, "new-version", "glm")["candidates"], ["hf:zai-org/GLM-5.4"])
        self.assertEqual(self.finding(result, "changed", "glm")["missingEfforts"], ["max"])
        first = body.splitlines()[0]
        self.assertIn("has a newer build `hf:zai-org/GLM-5.4`", first)
        self.assertIn("no longer offers effort `max`", first)

    def test_syn_rows_are_not_counted_as_rejected(self):
        baseline = self.assert_clean(snapshot())["rejectedCatalogEntries"]
        result = self.assert_clean(with_rows(snapshot(), row("syn:large:text", 1)))
        self.assertEqual(result["rejectedCatalogEntries"], baseline)

    def test_glm_without_max_is_changed_for_its_max_roles_only(self):
        catalog = snapshot()
        for model in catalog["data"]:
            if model["id"] == GLM:
                model["reasoning_parameters"]["efforts"] = ["low", "high"]
        result, body = self.drift(catalog)
        self.assertEqual(len(result["findings"]), 1, result["findings"])
        finding = self.finding(result, "changed", "glm")
        self.assertEqual(finding["missingEfforts"], ["max"])
        self.assertEqual(finding["uses"], ["deep-fallback", "reviewer", "opencodeEffort"])
        first = body.splitlines()[0]
        for needle in (f"`{GLM}`", "`max`", "`reviewer`", "`deep-fallback`", DETECTED):
            self.assertIn(needle, first)
        for role in ("writing-fallback", "unspecified-high-fallback"):
            self.assertNotIn(role, first)

    def test_a_model_with_no_reasoning_parameters_is_changed_for_every_effort(self):
        catalog = snapshot()
        for model in catalog["data"]:
            if model["id"] == KIMI:
                del model["reasoning_parameters"]
        result, _ = self.drift(catalog)
        self.assertEqual(self.finding(result, "changed", "kimi")["missingEfforts"], ["max"])

    def test_unsafe_catalog_ids_are_reported_only_as_a_count(self):
        catalog = without(snapshot(), KIMI)
        later = created_of(catalog, GLM) + 86400
        unsafe = [
            "hf:zai-org/GLM-6`](https://evil.invalid)",
            "hf:zai-org/GLM-6 [click](https://evil.invalid)",
            "hf:zai-org/GLM 6",
            "hf:zai-org/GLM-6@octocat",
            "@octocat ignore previous instructions",
        ]
        catalog = with_rows(catalog, *(row(model_id, later) for model_id in unsafe))
        baseline = self.assert_clean(snapshot())["rejectedCatalogEntries"]
        result, body = self.drift(catalog)
        self.assertEqual(result["rejectedCatalogEntries"], baseline + len(unsafe))
        self.assertEqual([f["kind"] for f in result["findings"]], ["removed"])
        text = body + self.result.read_text()
        for fragment in ("evil.invalid", "octocat", "GLM 6", "GLM-6", "click"):
            self.assertNotIn(fragment, text)
        self.assertIn(f"{baseline + len(unsafe)} catalog entries", body)

    def test_every_catalog_value_in_the_body_sits_in_a_code_span(self):
        catalog = without(snapshot(), KIMI)
        later = created_of(catalog, DEEPSEEK) + 1
        catalog = with_rows(catalog, row("hf:deepseek-ai/DeepSeek-V4.1-Flash-1120", later))
        _, body = self.drift(catalog)
        outside = "".join(part for index, part in enumerate(body.split("`")) if index % 2 == 0)
        for value in (KIMI, DEEPSEEK, "hf:deepseek-ai/DeepSeek-V4.1-Flash-1120", "hf:"):
            self.assertNotIn(value, outside)


class FingerprintTest(WatchTestCase):
    def test_same_findings_keep_the_fingerprint_and_new_ones_change_it(self):
        first, body = self.drift(without(snapshot(), KIMI))
        self.assertRegex(first["fingerprint"], r"^sha256:[0-9a-f]{64}$")
        self.assertIn(f"<!-- synthetic-models-watch fingerprint: {first['fingerprint']} -->", body)

        proc = self.run_watch(without(snapshot(), KIMI), extra=["--detected-at", "2026-10-22T09:00:00Z"])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        again = json.loads(self.result.read_text())
        self.assertEqual(again["fingerprint"], first["fingerprint"])

        other, _ = self.drift(without(without(snapshot(), KIMI), GLM))
        self.assertNotEqual(other["fingerprint"], first["fingerprint"])

        catalog = snapshot()
        for model in catalog["data"]:
            if model["id"] == GLM:
                model["reasoning_parameters"]["efforts"] = ["low", "high"]
        changed, _ = self.drift(catalog)
        catalog_low = snapshot()
        for model in catalog_low["data"]:
            if model["id"] == GLM:
                model["reasoning_parameters"]["efforts"] = ["max"]
        changed_low, _ = self.drift(catalog_low)
        self.assertNotEqual(changed["fingerprint"], changed_low["fingerprint"])

    def test_offered_efforts_alone_change_the_body_digest_but_not_the_fingerprint(self):
        results, bodies = [], []
        for efforts in (["low", "high"], ["high"]):
            catalog = snapshot()
            for model in catalog["data"]:
                if model["id"] == GLM:
                    model["reasoning_parameters"]["efforts"] = efforts
            result, body = self.drift(catalog)
            results.append(result)
            bodies.append(body)
        self.assertEqual(results[0]["fingerprint"], results[1]["fingerprint"])
        self.assertNotEqual(results[0]["bodyDigest"], results[1]["bodyDigest"])
        for result, body in zip(results, bodies):
            self.assertRegex(result["bodyDigest"], r"^sha256:[0-9a-f]{64}$")
            self.assertIn(f"<!-- synthetic-models-watch body: {result['bodyDigest']} -->", body)

    def test_the_detection_time_alone_keeps_the_body_digest(self):
        first, _ = self.drift(without(snapshot(), KIMI))
        proc = self.run_watch(without(snapshot(), KIMI), extra=["--detected-at", "2026-10-22T09:00:00Z"])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        again = json.loads(self.result.read_text())
        self.assertEqual(again["bodyDigest"], first["bodyDigest"])
        self.assertIn("2026-10-22T09:00:00Z", self.body.read_text())


class IssueStateTest(WatchTestCase):
    def state(self, issue):
        path = self.root / "issue.json"
        path.write_text(json.dumps(issue))
        proc = subprocess.run(
            [sys.executable, str(SCRIPT), "--issue-state", str(path)], capture_output=True, text=True
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return json.loads(proc.stdout)

    def notice(self, kind):
        proc = subprocess.run([sys.executable, str(SCRIPT), "--notice", kind], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return proc.stdout

    def test_it_reads_back_the_marks_the_body_carries(self):
        result, body = self.drift(without(snapshot(), KIMI))
        state = self.state({"body": body, "comments": []})
        self.assertEqual(state, {
            "fingerprint": result["fingerprint"],
            "bodyDigest": result["bodyDigest"],
            "notice": None,
        })

    def test_a_body_without_marks_has_none(self):
        self.assertEqual(
            self.state({"body": "Edit by hand.", "comments": []}),
            {"fingerprint": None, "bodyDigest": None, "notice": None},
        )

    def test_the_latest_notice_wins(self):
        comments = [
            {"body": self.notice("unreachable")},
            {"body": "a person's comment"},
            {"body": self.notice("reachable")},
            {"body": self.notice("unreachable")},
        ]
        self.assertEqual(self.state({"body": "", "comments": comments})["notice"], "unreachable")
        self.assertEqual(self.state({"body": "", "comments": comments[:3]})["notice"], "reachable")

    def test_the_unreachable_notice_names_the_catalog_and_the_secret(self):
        text = self.notice("unreachable")
        self.assertIn("cannot reach Synthetic's catalog", text)
        self.assertIn("SYNTHETIC_API_KEY", text)
        self.assertIn("<!-- synthetic-models-watch notice: unreachable -->", text)


class TitleTest(unittest.TestCase):
    def setUp(self):
        self.watch = load_watch()

    def removed(self, index, uses):
        return {"kind": "removed", "entry": f"e{index}", "id": f"hf:org/M-{index}", "uses": uses, "candidates": []}

    def test_a_short_title_keeps_the_uses(self):
        title = self.watch.title([self.removed(1, ["reviewer"])])
        self.assertIn("(uses `reviewer`)", title)

    def test_a_long_title_drops_the_uses_first(self):
        uses = [f"role-{n}-with-a-long-name" for n in range(8)]
        findings = [self.removed(1, uses)]
        full = self.watch.summary(findings[0])
        self.assertGreater(len(full), self.watch.TITLE_LIMIT)
        title = self.watch.title(findings)
        self.assertLessEqual(len(title), self.watch.TITLE_LIMIT)
        self.assertNotIn("uses", title)
        self.assertIn("`hf:org/M-1` removed; no candidate in its lineage", title)

    def test_the_source_evaluation_has_a_default_time_limit(self):
        self.assertEqual(self.watch.DEFAULT_EVAL_TIMEOUT, 300)

    def test_a_title_still_too_long_falls_back_to_a_count(self):
        findings = [self.removed(n, []) for n in range(12)]
        title = self.watch.title(findings)
        self.assertEqual(title, f"Reconcile {SOURCE_FILE}: 12 Synthetic model differences")
        self.assertLessEqual(len(title), self.watch.TITLE_LIMIT)


class FetchTest(WatchTestCase):
    def assert_no_issue_output(self, proc):
        self.assertNotEqual(proc.returncode, 0)
        self.assertFalse(self.result.exists(), "a failed run must write no result")
        self.assertFalse(self.body.exists(), "a failed run must write no issue body")

    def test_two_failures_exit_non_zero_with_no_issue_output(self):
        proc = self.run_fetch([7, 7])
        self.assert_no_issue_output(proc)
        self.assertEqual(len(self.calls()), 2)

    def test_two_429_responses_exit_non_zero_with_no_issue_output(self):
        proc = self.run_fetch([22, 22])
        self.assert_no_issue_output(proc)
        self.assertEqual(len(self.calls()), 2)

    def test_one_failure_is_retried(self):
        proc = self.run_fetch([22, json.dumps(without(snapshot(), KIMI))])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(len(self.calls()), 2)
        self.assertEqual(json.loads(self.result.read_text())["status"], "drift")

    def test_a_success_is_not_fetched_again(self):
        proc = self.run_fetch([json.dumps(snapshot())])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(len(self.calls()), 1)

    def test_an_empty_catalog_exits_non_zero(self):
        for body in ({"data": []}, {"data": [row("syn:large:text", 1, alias_of="x")]}, {}, []):
            with self.subTest(body=body):
                self.assert_no_issue_output(self.run_watch(body))

    def test_a_body_that_is_not_json_exits_non_zero(self):
        self.assert_no_issue_output(self.run_fetch(["<html>busy</html>", "<html>busy</html>"]))

    def test_no_key_sends_no_header(self):
        proc = self.run_fetch([json.dumps(snapshot())])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        (call,) = self.calls()
        self.assertEqual(call["argv"][-1], URL)
        self.assertNotIn("-H", call["argv"])
        self.assertEqual(call["stdin"], "")

    def test_an_empty_key_counts_as_unset(self):
        proc = self.run_fetch([json.dumps(snapshot())], key="")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        (call,) = self.calls()
        self.assertNotIn("-H", call["argv"])

    def test_the_key_travels_on_stdin_only(self):
        proc = self.run_fetch([22, json.dumps(without(snapshot(), KIMI))], key=KEY)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        calls = self.calls()
        self.assertEqual(len(calls), 2)
        for call in calls:
            self.assertEqual(call["argv"][-3:], ["-H", "@-", URL])
            self.assertFalse(any(KEY in arg for arg in call["argv"]))
            self.assertEqual(call["stdin"], f"Authorization: Bearer {KEY}\n")
            self.assertFalse(call["env_has_key"])
        for text in (proc.stdout, proc.stderr, self.result.read_text(), self.body.read_text()):
            self.assertNotIn(KEY, text)

    def test_a_failing_fetch_with_a_key_never_prints_it(self):
        proc = self.run_fetch([6, 6], key=KEY)
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(len(self.calls()), 2)
        self.assertNotIn(KEY, proc.stdout + proc.stderr)
        self.assertIn("attempt 2: status 6", proc.stderr)

    def test_a_failing_fetch_without_a_key_reports_curl_s_reason(self):
        proc = self.run_fetch([22, 22])
        self.assertIn("attempt 2: status 22 (curl: (22) The requested URL returned error: 429)", proc.stderr)

    def test_the_default_fetch_is_curl_with_a_time_limit(self):
        stubs = self.root / "bin"
        stubs.mkdir()
        curl = stubs / "curl"
        curl.write_text(FAKE_CURL.format(python=sys.executable))
        curl.chmod(0o755)
        catalog = self.root / "served.json"
        catalog.write_text(json.dumps(snapshot()))
        log = self.root / "curl-log.json"
        env = dict(os.environ)
        env.pop("SYNTHETIC_MODELS_FETCH", None)
        env.update({
            "PATH": f"{stubs}:{env.get('PATH', '')}",
            "SYNTHETIC_API_KEY": KEY,
            "FAKE_CURL_LOG": str(log),
            "FAKE_CATALOG": str(catalog),
        })
        proc = subprocess.run(
            [sys.executable, str(SCRIPT), "--source-json", str(SOURCE), "--result", str(self.result)],
            capture_output=True, text=True, env=env,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        call = json.loads(log.read_text())
        self.assertEqual(call["argv"], ["-sSfL", "--max-time", "60", "-H", "@-", URL])
        self.assertEqual(call["stdin"], f"Authorization: Bearer {KEY}\n")
        self.assertEqual(json.loads(self.result.read_text())["status"], "clean")


class SourceTest(WatchTestCase):
    def run_with_nix(self, stub_text, extra=()):
        stubs = self.root / "bin"
        stubs.mkdir()
        nix = stubs / "nix"
        nix.write_text(stub_text.format(python=sys.executable))
        nix.chmod(0o755)
        catalog = self.root / "catalog.json"
        catalog.write_text(json.dumps(without(snapshot(), KIMI)))
        env = dict(os.environ)
        env.pop("SYNTHETIC_MODELS_EVAL", None)
        env.update({
            "PATH": f"{stubs}:{env.get('PATH', '')}",
            "FAKE_NIX_LOG": str(self.root / "nix-log.json"),
            "FAKE_EVAL_SOURCE": str(SOURCE),
        })
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--catalog", str(catalog), "--result", str(self.result), *extra],
            capture_output=True, text=True, env=env,
        )

    def test_the_default_source_is_evaluated_with_nix(self):
        proc = self.run_with_nix(FAKE_NIX)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        argv = json.loads((self.root / "nix-log.json").read_text())
        self.assertEqual(argv, ["eval", "--json", "--file", SOURCE_FILE])
        self.assertEqual(json.loads(self.result.read_text())["status"], "drift")

    def test_a_hung_evaluation_times_out(self):
        started = time.monotonic()
        proc = self.run_with_nix(SLOW_NIX, extra=["--eval-timeout", "0.5"])
        self.assertLess(time.monotonic() - started, 20)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn(f"evaluating {SOURCE_FILE} timed out after 0.5 seconds", proc.stderr)
        self.assertFalse(self.result.exists())

    def test_a_lineage_that_misses_its_own_id_is_refused(self):
        source = json.loads(SOURCE.read_text())
        source["glm"]["lineage"] = "hf:zai-org/GLM-([0-9]+)-Air"
        path = self.root / "source.json"
        path.write_text(json.dumps(source))
        proc = self.run_watch(snapshot(), extra=["--source-json", str(path)])
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("glm", proc.stderr)
        self.assertFalse(self.result.exists())

    def test_the_result_goes_to_stdout_without_result(self):
        catalog = self.root / "catalog.json"
        catalog.write_text(json.dumps(snapshot()))
        proc = subprocess.run(
            [sys.executable, str(SCRIPT), "--source-json", str(SOURCE), "--catalog", str(catalog)],
            capture_output=True, text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["status"], "clean")


if __name__ == "__main__":
    unittest.main()
