"""Compare the pinned runtime's catalog with the independent provider snapshots."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def environment(home):
    return {"HOME": str(home), "PATH": os.environ["PATH"],
            "SYNTHETIC_API_KEY": "sk-fake-synthetic",
            "OPENROUTER_API_KEY": "sk-fake-openrouter"}


def run(omp, documents, snapshots):
    providers = json.loads(Path(documents["models.yml"]).read_text())["providers"]
    assert set(providers) == {"synthetic", "openrouter"}, "only API providers belong in models.yml"
    with tempfile.TemporaryDirectory() as temporary:
        home = Path(temporary)
        agent = home / ".omp/agent"
        agent.mkdir(parents=True)
        for name in ("models.yml", "config.yml"):
            (agent / name).write_bytes(Path(documents[name]).read_bytes())
        result = subprocess.run([omp, "models", "--json"], cwd=home,
                                env=environment(home), capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, result.stderr
        assert not result.stderr.strip(), result.stderr
        listed = {row["selector"]: row for row in json.loads(result.stdout)["models"]}
        for provider, path in snapshots.items():
            rows = json.loads(Path(path).read_text())["data"]
            assert rows, f"empty {provider} snapshot"
            missing = {f"{provider}/{row['id']}" for row in rows} - listed.keys()
            assert not missing, f"snapshot selectors missing: {sorted(missing)}"
            for row in rows:
                actual = listed[f"{provider}/{row['id']}"]
                modalities = row.get("input_modalities", (row.get("architecture") or {}).get("input_modalities", []))
                assert actual["input"] == [m for m in ("text", "image") if m in modalities], row["id"]
                context = row.get("context_length")
                if provider == "openrouter":
                    context = (row.get("top_provider") or {}).get("context_length") or context
                if isinstance(context, int) and context > 0:
                    assert actual["contextWindow"] == context, row["id"]
                limit = row.get("max_output_length") if provider == "synthetic" else (row.get("top_provider") or {}).get("max_completion_tokens")
                if isinstance(limit, int) and limit > 0:
                    assert actual["maxTokens"] == limit, row["id"]
                reasoning = row.get("reasoning_parameters" if provider == "synthetic" else "reasoning")
                if reasoning:
                    efforts = reasoning.get("efforts" if provider == "synthetic" else "supported_efforts")
                    if efforts:
                        expected = [e for e in ("minimal", "low", "medium", "high", "xhigh", "max") if e in efforts]
                        assert actual["thinking"] == expected, row["id"]
        glm = listed["synthetic/hf:zai-org/GLM-5.3"]
        assert glm["thinking"] == ["low", "high", "max"], glm
        print(f"OMP loaded all {sum(len(json.loads(Path(p).read_text())['data']) for p in snapshots.values())} snapshot selectors")


if __name__ == "__main__":
    omp, manifest, synthetic, openrouter, helpers = sys.argv[1:]
    for helper, env, expected in (
        ("omp-synthetic-key", {}, "sk-fake-file"),
        ("omp-synthetic-key", {"SYNTHETIC_API_KEY": "sk-fake-override"}, "sk-fake-override"),
        ("omp-openrouter-key", {}, None),
        ("omp-synthetic-key", {"SYNTHETIC_API_KEY": "invalid fake credential"}, None),
    ):
        result = subprocess.run([str(Path(helpers) / helper)], env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == (expected is not None), "provider helper status"
        assert result.stdout == (expected or ""), "provider helper output"
        assert "fake" not in result.stderr, "provider helper leaked a credential"
    for documents in json.loads(Path(manifest).read_text()):
        run(omp, documents, {"synthetic": synthetic, "openrouter": openrouter})
