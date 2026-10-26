"""Real pinned ACP and rendered T3 launch contracts; no live app proof implied."""

import json
import http.server
import os
from pathlib import Path
import queue
import ssl
import subprocess
import sys
import tempfile
import threading
import time


class Acp:
    def __init__(self, config, home, work, extra_env):
        self.events = []
        self.replies = {}
        self.frames = queue.Queue()
        self.serial = 0
        self.stderr = tempfile.TemporaryFile(mode="w+")
        env = {"HOME": str(home), "PATH": os.environ["PATH"],
               "SYNTHETIC_API_KEY": "sk-fake-synthetic", "OPENROUTER_API_KEY": "sk-fake-openrouter",
               **extra_env}
        self.process = subprocess.Popen([config["commandPath"], *config["commandArgs"]],
                                        cwd=work, env=env, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=self.stderr, text=True)
        def read():
            for line in self.process.stdout:
                self.frames.put(json.loads(line))
            self.frames.put(None)
        self.reader = threading.Thread(target=read, daemon=True)
        self.reader.start()

    def send(self, method, params, request=True):
        frame = {"jsonrpc": "2.0", "method": method, "params": params}
        if request:
            self.serial += 1
            frame["id"] = self.serial
        self.process.stdin.write(json.dumps(frame) + "\n")
        self.process.stdin.flush()
        return frame.get("id")

    def receive(self, number, timeout=30, allow_error=False):
        deadline = time.monotonic() + timeout
        while number not in self.replies:
            frame = self.frames.get(timeout=max(0.01, deadline - time.monotonic()))
            assert frame is not None, "ACP exited before replying"
            if "method" in frame:
                if "id" in frame:
                    assert frame["method"] == "session/request_permission", frame
                    option = next(o for o in frame["params"]["options"] if o["kind"] == "allow_once")
                    self.process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": frame["id"],
                                                        "result": {"outcome": {"outcome": "selected",
                                                                               "optionId": option["optionId"]}}}) + "\n")
                    self.process.stdin.flush()
                else:
                    self.events.append(frame)
            else:
                self.replies[frame["id"]] = frame
        frame = self.replies.pop(number)
        if allow_error:
            return frame
        assert "error" not in frame, frame
        return frame["result"]

    def call(self, method, **params):
        return self.receive(self.send(method, params))

    def initialize(self):
        response = self.call("initialize", protocolVersion=1, clientCapabilities={})
        assert response["agentInfo"]["name"] == "omp"
        assert response["agentCapabilities"]["loadSession"] is True
        return response

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=5)
        self.reader.join(timeout=2)
        self.process.stdin.close()
        self.process.stdout.close()
        self.stderr.close()


def option(state, name):
    return next(row for row in state["configOptions"] if row["id"] == name)


def values(state, name):
    return {row["value"] for row in option(state, name)["options"]}


def prepare(entry, home):
    agent = home / ".omp/agent"
    agent.mkdir(parents=True)
    for name, path in entry["documents"].items():
        (agent / name).write_bytes(Path(path).read_bytes())
    # Protected production helper commands remain the consumer; only fake
    # credentials enter this process, and the sandbox has no user auth files.
    providers = json.loads((agent / "models.yml").read_text())["providers"]
    assert set(providers) == {"synthetic", "openrouter"}, "local Codex definitions are forbidden"
    skill = agent / "skills/u5-proof"
    skill.mkdir(parents=True)
    (skill / "SKILL.md").write_text("---\nname: u5-proof\ndescription: ACP_SKILL_PROOF\n---\nACP skill fixture.\n")
    work = home / "project"
    work.mkdir()
    (work / "AGENTS.md").write_text("ACP_REPOSITORY_PROOF\n")
    return work


class Fixture(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def json_response(self, data, status=200):
        raw = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_CONNECT(self):
        assert self.path in ("api.synthetic.new:443", "openrouter.ai:443"), self.path
        self.send_response(200)
        self.end_headers()
        try:
            self.connection = self.server.tls.wrap_socket(self.connection, server_side=True)
        except (ConnectionResetError, ssl.SSLEOFError):
            # OMP cancels background discovery connections on process exit.
            return
        self.rfile = self.connection.makefile("rb")
        self.wfile = self.connection.makefile("wb")
        self.close_connection = False
        self.handle_one_request()

    def do_GET(self):
        self.send_error(404)

    def do_POST(self):
        try:
            self.respond()
        except (AssertionError, StopIteration) as error:
            self.server.errors.append(str(error))
            self.json_response({"error": {"message": str(error)}}, 400)

    def respond(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if self.path == "/mcp":
            self.server.mcp_frames.append(body)
            if "id" not in body:
                self.json_response({}, 202)
                return
            method = body["method"]
            if method == "initialize":
                result = {"protocolVersion": body["params"]["protocolVersion"], "capabilities": {"tools": {}},
                          "serverInfo": {"name": "u5-fixture", "version": "1"}}
            elif method == "tools/list":
                result = {"tools": [{"name": "proof", "description": "Return a protocol fixture nonce",
                                     "inputSchema": {"type": "object", "properties": {}}}]}
            elif method == "tools/call":
                assert body["params"]["name"] == "proof", body
                self.server.mcp_calls.append(body)
                result = {"content": [{"type": "text", "text": self.server.nonce}]}
            else:
                self.json_response({"jsonrpc": "2.0", "id": body["id"],
                                    "error": {"code": -32601, "message": "unknown method"}})
                return
            self.json_response({"jsonrpc": "2.0", "id": body["id"], "result": result})
            return
        self.server.requests.append(body)
        assert self.path == "/openai/v1/chat/completions", self.path
        messages = str(body["messages"])
        last_user = str(next(m for m in reversed(body["messages"]) if m["role"] == "user"))
        if "ACP_CANCEL" in last_user:
            self.server.cancel_started.set()
            self.server.cancel_release.wait(20)
            return
        assert "ACP_REPOSITORY_PROOF" in messages, "ACP omitted repository instructions"
        assert "ACP_SKILL_PROOF" in messages, "ACP omitted native skill discovery"
        results = str([m for m in body["messages"] if m["role"] == "tool"])
        if "ACP_RESUME" in last_user:
            assert self.server.nonce in results, "resume lost prior MCP result"
            delta, reason = {"content": "ACP_RESUMED"}, "stop"
        elif not any(m["role"] == "tool" for m in body["messages"]):
            delta, reason = self.tool("write", {"i": "Writing ACP proof", "path": "acp-proof.txt",
                                                "content": "ACP_NATIVE_TOOL_RESULT\n"}), "tool_calls"
        elif self.server.nonce not in results:
            # OMP natively mounts MCP tools under xd:// rather than sending
            # each full schema as a top-level provider tool.
            assert "mcp__fixture_proof" in messages, "MCP mount absent from provider context"
            delta, reason = self.tool("write", {"i": "Calling injected MCP tool", "path": "xd://mcp__fixture_proof",
                                                "content": "{}"}), "tool_calls"
        else:
            delta, reason = {"content": "ACP_COMPLETED " + self.server.nonce}, "stop"
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for payload in ({"choices": [{"index": 0, "delta": delta, "finish_reason": None}]},
                        {"choices": [{"index": 0, "delta": {}, "finish_reason": reason}]}):
            self.wfile.write(("data: " + json.dumps(payload) + "\n\n").encode())
        self.wfile.write(b"data: [DONE]\n\n")

    @staticmethod
    def tool(name, arguments):
        return {"tool_calls": [{"index": 0, "id": "call_" + name, "type": "function",
                                "function": {"name": name, "arguments": json.dumps(arguments)}}]}


def endpoint(home):
    cert, key = home / "cert.pem", home / "key.pem"
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                    "-keyout", str(key), "-out", str(cert), "-subj", "/CN=ACP fixture",
                    "-addext", "subjectAltName=DNS:api.synthetic.new"], check=True, capture_output=True)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Fixture)
    server.daemon_threads = True
    server.tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    server.tls.load_cert_chain(cert, key)
    server.requests, server.mcp_calls, server.mcp_frames, server.errors = [], [], [], []
    server.nonce = "MCP_RESULT_" + os.urandom(8).hex()
    server.cancel_started, server.cancel_release = threading.Event(), threading.Event()
    threading.Thread(target=server.serve_forever, daemon=True).start()
    proxy = f"http://127.0.0.1:{server.server_port}"
    env = {"NODE_EXTRA_CA_CERTS": str(cert), "PI_PROXY_SYNTHETIC": proxy, "PI_PROXY_OPENROUTER": proxy}
    mcp = [{"type": "http", "name": "fixture", "url": proxy + "/mcp", "headers": []}]
    return server, env, mcp


def exchange(config, home, work):
    server, env, mcp = endpoint(home)
    client = Acp(config, home, work, env)
    try:
        client.initialize()
        state = client.call("session/new", cwd=str(work), mcpServers=mcp)
        session = state["sessionId"]
        assert option(state, "model")["currentValue"] == "openai-codex/gpt-6-astra", state
        assert option(state, "thinking")["currentValue"] == "low", option(state, "thinking")
        reply = client.receive(client.send("session/prompt", {"sessionId": session,
                               "prompt": [{"type": "text", "text": "ACP_EXCHANGE"}]}), allow_error=True)
        assert not server.requests, "Codex startup fell back to a paid API provider"
        assert "No API key found for openai-codex." in reply.get("error", {}).get("data", {}).get("details", ""), reply
        print("Unified ACP startup stays on Codex low without auth and sends no API request")
        state = client.call("session/set_config_option", sessionId=session, configId="model",
                            value="synthetic/hf:zai-org/GLM-5.3")
        state = client.call("session/set_config_option", sessionId=session, configId="thinking", value="max")
        reply = client.call("session/prompt", sessionId=session,
                            prompt=[{"type": "text", "text": "ACP_EXCHANGE: write a file and call the MCP fixture."}])
        assert reply["stopReason"] == "end_turn", (reply, server.errors)
        assert not server.errors, server.errors
        assert (work / "acp-proof.txt").read_text() == "ACP_NATIVE_TOOL_RESULT\n"
        assert len(server.mcp_calls) == 1, server.mcp_calls
        assert len(server.requests) == 3, len(server.requests)
        assert all(body["model"] == "hf:zai-org/GLM-5.3" and body.get("reasoning_effort") == "max"
                   for body in server.requests), "ACP effective default differs from actual requests"
        updates = [e["params"]["update"] for e in client.events if e["method"] == "session/update"]
        assert any(u["sessionUpdate"] == "tool_call_update" and u.get("status") == "completed" for u in updates)
        assert any(server.nonce in str(u) and u["sessionUpdate"] == "agent_message_chunk" for u in updates)
        pending = client.send("session/prompt", {"sessionId": session,
                              "prompt": [{"type": "text", "text": "ACP_CANCEL"}]})
        assert server.cancel_started.wait(10), "cancel test never reached the provider request"
        client.send("session/cancel", {"sessionId": session}, request=False)
        assert client.receive(pending, timeout=10)["stopReason"] == "cancelled"
        server.cancel_release.set()
        client.close()
        client = Acp(config, home, work, env)
        client.initialize()
        resumed = client.call("session/load", sessionId=session, cwd=str(work), mcpServers=mcp)
        assert option(resumed, "model")["currentValue"] == "synthetic/hf:zai-org/GLM-5.3"
        assert option(resumed, "thinking")["currentValue"] == "max"
        reply = client.call("session/prompt", sessionId=session, prompt=[{"type": "text", "text": "ACP_RESUME"}])
        assert reply["stopReason"] == "end_turn"
        assert any("ACP_RESUMED" in str(e) for e in client.events), "resumed prompt returned no result"
    finally:
        if sys.exc_info()[0]:
            client.stderr.seek(0)
            print("ACP fixture diagnostics:", server.errors, client.stderr.read(), file=sys.stderr)
        server.cancel_release.set()
        client.close()
        server.shutdown()
        server.server_close()


def catalog(config, home, work, expected):
    client = Acp(config, home, work, {})
    try:
        client.initialize()
        state = client.call("session/new", cwd=str(work), mcpServers=[])
        assert expected == values(state, "model"), ("Unified scope changed selected selectors",
                                                   len(values(state, "model")), sorted(values(state, "model"))[:8],
                                                   sorted(expected - values(state, "model"))[:8])
        session = state["sessionId"]
        # T3's custom selectors must all be selectable by the real ACP runtime.
        for selector in sorted(expected):
            state = client.call("session/set_config_option", sessionId=session, configId="model", value=selector)
            assert option(state, "model")["currentValue"] == selector, selector
        state = client.call("session/set_config_option", sessionId=session, configId="model", value="synthetic/hf:zai-org/GLM-5.3")
        assert values(state, "thinking") == {"off", "auto", "low", "high", "max"}, option(state, "thinking")
        state = client.call("session/set_config_option", sessionId=session, configId="thinking", value="max")
        assert option(state, "thinking")["currentValue"] == "max"
        print(f"ACP advertised and selected all {len(expected)} API snapshot selectors; active thinking refreshed")
    finally:
        client.close()


def applied(entry, home):
    target = home / ".t3/userdata/settings.json"
    target.parent.mkdir(parents=True)
    seed = {"providerInstances": {"pi": {"enabled": True, "config": {"preserved": "Pi state"}},
                                   "omp": {"environment": {"variables": {"KEEP": "yes"}},
                                           "config": {"authMethodId": "agent", "customModels": ["stale-selector"]}},
                                   "omp-codex": {"driver": "acpRegistry", "enabled": True,
                                                 "config": {"authMethodId": "agent"}}},
            "projectSettingsOverrides": {"example": {"keep": True}}}
    target.write_text(json.dumps(seed))
    script = entry["activation"].replace(entry["home"], str(home))
    assert script != entry["activation"], "T3 settings activation has no expected destination"
    result = subprocess.run(["bash", "-euo", "pipefail", "-c", 'run() { "$@"; }\n' + script],
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    settings = json.loads(target.read_text())
    assert settings["projectSettingsOverrides"] == seed["projectSettingsOverrides"]
    instances = settings["providerInstances"]
    assert instances["pi"]["enabled"] is False, "T3 still enables retired Pi"
    assert instances["pi"]["config"] == seed["providerInstances"]["pi"]["config"]
    assert instances["omp"]["environment"] == seed["providerInstances"]["omp"]["environment"]
    assert instances["omp"]["config"]["authMethodId"] == "agent"
    assert "omp-codex" not in instances, "T3 retained the retired OMP Codex entry"
    assert instances["omp"]["driver"] == "acpRegistry" and instances["omp"]["enabled"] is True
    assert instances["omp"]["config"]["source"] == "local"
    result = subprocess.run(["bash", "-euo", "pipefail", "-c", 'run() { "$@"; }\n' + script],
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert json.loads(target.read_text()) == settings, "repeated activation changed consolidated settings"
    return instances


if __name__ == "__main__":
    deliveries, synthetic, openrouter = sys.argv[1:]
    entries = json.loads(Path(deliveries).read_text())
    assert entries, "no T3-enabled host tested"
    expected = {f"{provider}/{row['id']}" for provider, path in (("synthetic", synthetic), ("openrouter", openrouter))
                for row in json.loads(Path(path).read_text())["data"]
                if provider == "synthetic" or (row["id"].startswith("openrouter/")
                                               and row["id"] != "openrouter/bodybuilder")}
    for entry in entries:
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            instances = applied(entry, home)
            api = instances["omp"]["config"]
            assert set(api["customModels"]) == expected and len(api["customModels"]) == len(expected), "T3 API selectors capped or changed"
            patterns = {"synthetic/**", "google-antigravity/**", "openai-codex/*"} | {s for s in expected if s.startswith("openrouter/")}
            args = api["commandArgs"]
            assert set(args[args.index("--models") + 1].split(",")) == patterns, "CLI scope differs from unified selection"
            overlay = json.loads(Path(args[args.index("--config") + 1]).read_text())
            assert set(overlay["enabledModels"]) == patterns, "overlay scope differs from unified selection"
            assert overlay["modelRoles"]["default"] == "openai-codex/gpt-6-astra"
            assert overlay["defaultThinkingLevel"] == "low"
            work = prepare(entry, home)
            common = (home / ".omp/agent/config.yml").read_bytes()
            catalog(api, home, work, expected)
            exchange(api, home, work)
            print("ACP prompt/native tool/MCP result/cancel/persistent resume passed")
            assert (home / ".omp/agent/config.yml").read_bytes() == common, "ACP scope changed common CLI settings"
