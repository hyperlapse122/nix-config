"""Capture real OMP requests and complete a deterministic tool exchange, offline.

The pinned Synthetic shim replaces baseUrl with its official URL. A local TLS
proxy exercises that transport without changing provider identities or metadata.
"""

import http.server
import json
import os
from pathlib import Path
import subprocess
import ssl
import sys
import tempfile
import threading


OMP, MANIFEST, MISSING_KEY = sys.argv[1:]
documents = json.loads(Path(MANIFEST).read_text())
assert documents, "no managed OMP documents were tested"
requests = []
certificate_dir = tempfile.TemporaryDirectory()
cert = Path(certificate_dir.name) / "cert.pem"
key = Path(certificate_dir.name) / "key.pem"
subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                "-keyout", str(key), "-out", str(cert), "-subj", "/CN=OMP test provider",
                "-addext", "subjectAltName=DNS:api.synthetic.new,DNS:openrouter.ai"],
               check=True, capture_output=True)
tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
tls.load_cert_chain(cert, key)


class Provider(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_CONNECT(self):
        assert self.path in ("api.synthetic.new:443", "openrouter.ai:443"), self.path
        self.send_response(200)
        self.end_headers()
        self.connection = tls.wrap_socket(self.connection, server_side=True)
        self.rfile = self.connection.makefile("rb")
        self.wfile = self.connection.makefile("wb")
        self.close_connection = False
        self.handle_one_request()

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        requests.append((self.path, body, self.headers.get("Authorization")))
        if self.path.endswith("/responses"):
            self.respond_responses(body)
            return
        has_result = any(m.get("role") == "tool" for m in body["messages"])
        if has_result:
            delta = {"content": "OMP_PROVIDER_OK"}
            reason = "stop"
        else:
            delta = {"tool_calls": [{"index": 0, "id": "call_write", "type": "function",
                                    "function": {"name": "write", "arguments": json.dumps({
                                        "i": "Writing provider proof", "path": "provider-proof.txt",
                                        "content": "tool exchange completed\n"})}}]}
            reason = "tool_calls"
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for payload in ({"choices": [{"index": 0, "delta": delta, "finish_reason": None}]},
                        {"choices": [{"index": 0, "delta": {}, "finish_reason": reason}]}):
            self.wfile.write(("data: " + json.dumps(payload) + "\n\n").encode())
        self.wfile.write(b"data: [DONE]\n\n")

    def respond_responses(self, body):
        has_result = any(m.get("type") == "function_call_output" for m in body["input"])
        arguments = json.dumps({"i": "Writing provider proof", "path": "provider-proof.txt",
                                "content": "tool exchange completed\n"})
        item = ({"type": "message", "id": "msg_test", "role": "assistant", "status": "completed",
                 "content": [{"type": "output_text", "text": "OMP_PROVIDER_OK", "annotations": []}]}
                if has_result else {"type": "function_call", "id": "fc_test", "call_id": "call_write",
                                    "name": "write", "arguments": arguments, "status": "completed"})
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        response = {"id": "resp_test", "object": "response", "model": body["model"], "status": "in_progress", "output": []}
        initial_item = {**item, **({"content": []} if has_result else {"arguments": ""})}
        events = [("response.created", {"response": response}),
                  ("response.output_item.added", {"output_index": 0, "item": initial_item})]
        if has_result:
            events += [("response.content_part.added", {"item_id": item["id"], "output_index": 0, "content_index": 0,
                                                        "part": {"type": "output_text", "text": "", "annotations": []}}),
                       ("response.output_text.delta", {"item_id": item["id"], "output_index": 0, "content_index": 0,
                                                        "delta": "OMP_PROVIDER_OK"})]
        else:
            events += [("response.function_call_arguments.delta", {"item_id": item["id"], "output_index": 0, "delta": arguments})]
        events += [("response.output_item.done", {"output_index": 0, "item": item}),
                   ("response.completed", {"response": {**response, "status": "completed", "output": [item],
                                                         "usage": {"input_tokens": 1, "output_tokens": 1, "total_tokens": 2}}})]
        for kind, payload in events:
            self.wfile.write(("event: " + kind + "\ndata: " + json.dumps({"type": kind, **payload}) + "\n\n").encode())


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Provider)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    for declared in documents:
        for selector, model, effort in ((None, "hf:zai-org/GLM-5.3", "max"),
                                        ("synthetic/hf:zai-org/GLM-5.3:low", "hf:zai-org/GLM-5.3", "low"),
                                        ("openrouter/openai/gpt-4o", "openai/gpt-4o", None),
                                        ("missing", "hf:zai-org/GLM-5.3", None)):
            with tempfile.TemporaryDirectory() as temporary:
                home = Path(temporary)
                agent = home / ".omp/agent"
                agent.mkdir(parents=True)
                work = home / "project"
                work.mkdir()
                models = json.loads(Path(declared["models.yml"]).read_text())
                for name, provider in models["providers"].items():
                    # Give only the protected command a fake credential, not OMP or its tools.
                    variable = "SYNTHETIC_API_KEY" if name == "synthetic" else "OPENROUTER_API_KEY"
                    provider["apiKey"] = ("!" + MISSING_KEY if selector == "missing" else
                                          f"!{variable}=sk-fake-{name} " + provider["apiKey"][1:])
                (agent / "models.yml").write_text(json.dumps(models))
                (agent / "config.yml").write_bytes(Path(declared["config.yml"]).read_bytes())
                env = {"HOME": str(home), "PATH": os.environ["PATH"],
                       "PI_CODING_AGENT_DIR": str(agent), "NODE_EXTRA_CA_CERTS": str(cert),
                       "PI_PROXY_SYNTHETIC": f"http://127.0.0.1:{server.server_port}",
                       "PI_PROXY_OPENROUTER": f"http://127.0.0.1:{server.server_port}"}
                args = [OMP, "--print", "--mode", "json", "--no-session", "--no-title", "--no-lsp",
                        "--no-extensions", "--no-skills", "--no-rules", "--tools", "write", "--auto-approve"]
                if selector and selector != "missing":
                    args += ["--model", selector]
                requests.clear()
                try:
                    result = subprocess.run([*args, "Write provider-proof.txt, then finish."],
                                            cwd=work, env=env, stdin=subprocess.DEVNULL,
                                            capture_output=True, text=True, timeout=30)
                except subprocess.TimeoutExpired as error:
                    raise AssertionError(([(path, body.get("model")) for path, body, _ in requests],
                                          error.stdout, error.stderr)) from error
                if selector == "missing":
                    assert result.returncode != 0, "OMP accepted absent provider credentials"
                    assert not requests, "OMP sent a request without its provider key"
                    assert "sk-fake-" not in result.stdout + result.stderr, "credential leaked in failure"
                    continue
                assert result.returncode == 0, (result.returncode, result.stdout, result.stderr)
                assert len(requests) == 2, (len(requests), result.stdout, result.stderr)
                for path, body, auth in requests:
                    expected_path = "/api/v1/responses" if selector and selector.startswith("openrouter/") else "/openai/v1/chat/completions"
                    assert path == expected_path, path
                    assert body["model"] == model, body["model"]
                    if effort:
                        assert body.get("reasoning_effort") == effort, body.get("reasoning_effort")
                    expected_key = "sk-fake-openrouter" if selector and selector.startswith("openrouter/") else "sk-fake-synthetic"
                    assert auth == f"Bearer {expected_key}", "protected key command did not supply the request"
                assert (work / "provider-proof.txt").read_text() == "tool exchange completed\n"
                assert "OMP_PROVIDER_OK" in result.stdout, result.stdout
        print("OMP default max, explicit low, and OpenRouter tool exchanges passed")
finally:
    server.shutdown()
    server.server_close()
    thread.join()
    certificate_dir.cleanup()
