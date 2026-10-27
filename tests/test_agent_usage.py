"""Offline command-boundary proofs for provider usage and shared cache behavior."""

import concurrent.futures
import http.server
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/agent-usage"
TOKEN = "fake-private-token-never-publish"


class UsageTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = dict(os.environ, HOME=str(self.root),
                        XDG_CACHE_HOME=str(self.root / "cache"),
                        CODEX_HOME=str(self.root / ".codex"),
                        GROK_HOME=str(self.root / ".grok"),
                        CLAUDE_CONFIG_DIR=str(self.root / ".claude"),
                        PI_CODING_AGENT_DIR=str(self.root / ".omp/agent"),
                        PATH=str(self.root) + os.pathsep + os.environ.get("PATH", ""))
        for key in ("XAI_API_KEY", "XAI_BASE_URL", "GROK_BASE_URL", "ANTHROPIC_API_KEY"):
            self.env.pop(key, None)
        self.write(".codex/auth.json", {"tokens": {"account_id": "codex-account"}})
        self.write(".claude.json", {"oauthAccount": {"accountUuid": "claude-account"}})
        self.write(".grok/auth.json", {"https://auth.x.ai::b1a00492-073a-47ea-816f-4c329264a828": {
            "key": TOKEN, "email": "example@example.invalid"}})
        reset = int(time.time()) + 7200
        self.data = {
            "codex": {"accountId": "codex-account", "rateLimits": {
                "primary": {"usedPercent": 50, "windowDurationMins": 300, "resetsAt": reset},
                "secondary": {"usedPercent": 80, "windowDurationMins": 10080, "resetsAt": reset}}},
            "claude": {"rate_limits": {"five_hour": {"utilization": 30, "resets_at": reset},
                "seven_day": {"utilization": 40, "resets_at": reset}},
                "model_scoped": [{"display_name": "Fable", "utilization": 90, "resets_at": reset}]},
            "omp": [{"provider": "openai-codex", "limits": [{"amount": {"usedFraction": 1}}]},
                    {"provider": "google-antigravity", "scope": "gemini-account", "limits": [{
                        "label": "Gemini", "scope": "provider", "window": {
                            "id": "weekly", "durationMs": 604800000, "resetsAt": reset * 1000},
                        "amount": {"usedFraction": .2, "remainingFraction": .8}}]}],
            "grok": {"config": {"creditUsagePercent": 10, "currentPeriod": {
                "type": "USAGE_PERIOD_TYPE_WEEKLY", "start": reset - 604800, "end": reset}}},
            "synthetic": {"subscription": {"limit": 100, "requests": 30, "renewsAt": reset},
                "search": {"hourly": {"limit": 10, "requests": 2, "renewsAt": reset}},
                "planWeeklyLimit": {"percentRemaining": 20, "nextRegenAt": reset, "nextRegenPercent": 5}},
        }
        self.save()
        self.stub("codex", '''
import json,sys,time
assert sys.argv[1:] == ['app-server','--listen','stdio://']
for line in sys.stdin:
 r=json.loads(line)
 if r['method']=='initialize':
  assert r['params']=={'clientInfo':{'name':'agent-usage','version':'1'}}
  print(json.dumps({'id':r['id'],'result':{}}),flush=True)
 elif r['method']=='initialized': initialized=True
 elif r['method']=='account/rateLimits/read':
  assert initialized and r['params']=={}
  time.sleep(data.get('delay',0))
  if data.get('fail'): sys.exit(1)
  print(json.dumps({'id':r['id'],'result':data['codex']}),flush=True)
''')
        self.stub("node", "import json,sys\nif data.get('fail_claude'):\n print(" + repr(TOKEN) + ",file=sys.stderr)\n sys.exit(1)\nprint(json.dumps(data['claude']))")
        self.stub("omp", "import json,sys\nassert sys.argv[1:]==['usage','--json','--provider','google-antigravity']\nprint(json.dumps(data['omp']))")
        self.stub("grok", "import sys\nassert sys.argv[1:]==['models']")
        self.stub("omp-synthetic-key", "print('" + TOKEN + "')")
        outer = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                outer.assertEqual(self.headers['Authorization'], 'Bearer ' + TOKEN)
                provider = 'grok' if self.path.startswith('/v1/billing') else 'synthetic'
                statuses = outer.data.get('grok_statuses', []) if provider == 'grok' else []
                status = statuses.pop(0) if statuses else 200
                self.send_response(status)
                self.end_headers()
                self.wfile.write(json.dumps(outer.data[provider]).encode())

            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.stub("curl", f'''
import sys,urllib.request,urllib.error
assert sys.argv[1:3]==['--config','-']
config=sys.stdin.read()
assert 'Bearer {TOKEN}' in config
url=sys.argv[-1]
assert url in ['https://cli-chat-proxy.grok.com/v1/billing?format=credits','https://api.synthetic.new/v2/quotas']
req=urllib.request.Request('http://127.0.0.1:{server.server_port}/'+url.split('/',3)[3],headers={{'Authorization':'Bearer {TOKEN}'}})
try: response=urllib.request.urlopen(req)
except urllib.error.HTTPError as exc: response=exc
sys.stdout.buffer.write(response.read()+b'\\n'+str(response.code).encode())
''')

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))

    def save(self):
        self.write('data.json', self.data)

    def stub(self, name, body):
        path = self.root / name
        path.write_text(f'#!{sys.executable}\nimport json,pathlib\nroot=pathlib.Path(__file__).parent\ndata=json.loads((root/"data.json").read_text())\nwith (root/"calls").open("a") as f: f.write({name!r}+"\\n")\n' + body + '\n')
        path.chmod(0o755)

    def invoke(self, *args):
        proc = subprocess.run([sys.executable, str(SCRIPT), '--json', *args],
                              env=self.env, capture_output=True, text=True, timeout=40)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertNotIn(TOKEN, proc.stdout + proc.stderr)
        for path in (self.root / 'cache').rglob('*'):
            if path.is_file():
                self.assertNotIn(TOKEN, path.read_text())
        return json.loads(proc.stdout)['providers']

    def calls(self, name):
        return (self.root / 'calls').read_text().splitlines().count(name)

    def test_readers_preserve_provider_and_model_windows(self):
        result = self.invoke()
        self.assertEqual(result['codex']['windows'][1]['remainingPercent'], 20)
        self.assertEqual(result['gemini']['windows'][0]['remainingPercent'], 80)
        self.assertEqual(result['claude']['windows'][-1]['model'], 'Fable')
        weekly = result['synthetic']['windows'][-1]
        self.assertEqual(weekly['remainingPercent'], 20)
        self.assertEqual(weekly['nextRegenPercent'], 5)
        self.assertNotIn('resetsAt', weekly)
        self.assertEqual(result['grok']['windows'][0]['usedPercent'], 10)

    def test_default_output_is_readable_usage_and_regeneration(self):
        result = subprocess.run([sys.executable, str(SCRIPT)], env=self.env,
                                capture_output=True, text=True, timeout=40)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('codex: ok', result.stdout)
        self.assertIn('% used', result.stdout)
        self.assertIn('regenerates 5%', result.stdout)
        self.assertNotIn(TOKEN, result.stdout + result.stderr)

    def test_grok_refresh_and_provider_failure_isolation(self):
        self.data['grok_statuses'] = [401, 200]
        self.data['fail_claude'] = True
        self.save()
        result = self.invoke()
        self.assertEqual(result['grok']['status'], 'ok')
        self.assertEqual(self.calls('grok'), 1)
        self.assertEqual(result['claude']['status'], 'unknown')
        self.assertEqual(result['codex']['status'], 'ok')

    def test_grok_second_401_and_402(self):
        for statuses, exhausted in [([401, 401], False), ([402], True)]:
            with self.subTest(statuses=statuses):
                self.data['grok_statuses'] = statuses
                result = self.invoke('--refresh')['grok']
                self.assertEqual(result['status'], 'unknown')
                self.assertEqual(result.get('exhausted', False), exhausted)

    def test_grok_api_key_and_custom_endpoint_are_unknown(self):
        for key in ('XAI_API_KEY', 'XAI_BASE_URL'):
            self.env[key] = 'custom'
            self.assertEqual(self.invoke('--refresh')['grok']['status'], 'unknown')
            del self.env[key]
        (self.root / '.grok/config.toml').write_text('[api]\nbase_url = "https://custom.invalid"\n')
        self.assertEqual(self.invoke('--refresh')['grok']['status'], 'unknown')

    def test_grok_legacy_auth_missing_percentage_and_api_key_mode(self):
        auth = self.root / '.grok/auth.json'
        self.write('.grok/auth.json', {'https://accounts.x.ai/sign-in': {
            'key': TOKEN, 'email': 'legacy@example.invalid'}})
        del self.data['grok']['config']['creditUsagePercent']
        self.save()
        self.assertEqual(self.invoke()['grok']['windows'][0]['remainingPercent'], 100)
        entry = json.loads(auth.read_text())
        entry['https://accounts.x.ai/sign-in']['auth_mode'] = 'api_key'
        auth.write_text(json.dumps(entry))
        self.assertEqual(self.invoke()['grok']['status'], 'unknown')

    def test_omp_reports_envelope_and_nested_claude_model_windows(self):
        self.data['omp'] = {'reports': self.data['omp']}
        self.data['claude']['rate_limits']['model_scoped'] = self.data['claude'].pop('model_scoped')
        self.save()
        result = self.invoke()
        self.assertEqual(result['gemini']['status'], 'ok')
        self.assertEqual(result['claude']['belowThresholdModels'], ['Fable'])

    def test_fresh_and_concurrent_calls_share_fetch(self):
        self.data['delay'] = .4
        self.save()
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: self.invoke(), range(2)))
        self.assertEqual(results[0]['codex']['windows'], results[1]['codex']['windows'])
        self.invoke()
        self.assertEqual(self.calls('codex'), 1)
        self.assertEqual(self.calls('omp'), 1)

    def test_failure_cache_refresh_and_stale_success(self):
        self.data['fail'] = True
        self.save()
        failed = self.invoke()['codex']
        self.assertEqual(failed['status'], 'unknown')
        self.assertIn('accountHash', failed)
        self.assertEqual(self.invoke()['codex']['status'], 'unknown')
        self.assertEqual(self.calls('codex'), 1)
        self.data['fail'] = False
        self.save()
        success = self.invoke('--refresh')['codex']
        self.assertEqual(success['status'], 'ok')
        self.assertEqual(failed['accountHash'], success['accountHash'])
        self.data['fail'] = True
        self.save()
        result = self.invoke('--refresh')['codex']
        self.assertEqual(result['status'], 'stale')
        self.assertEqual(result['windows'][1]['remainingPercent'], 20)
        self.invoke()
        self.assertEqual(self.calls('codex'), 3)

    def test_stale_expired_windows_do_not_skip_provider(self):
        self.data['codex']['rateLimits']['secondary']['resetsAt'] = time.time() - 1
        self.save()
        self.invoke()
        self.data['fail'] = True
        self.save()
        result = self.invoke('--refresh')['codex']
        self.assertEqual(result['status'], 'stale')
        self.assertFalse(result['belowThreshold'])
        self.assertIsNone(result['windows'][1]['remainingPercent'])

    def test_threshold_is_strict_and_model_scoped(self):
        result = self.invoke()
        self.assertTrue(result['codex']['belowThreshold'])
        self.assertFalse(result['claude']['belowThreshold'])
        self.assertEqual(result['claude']['belowThresholdModels'], ['Fable'])
        self.assertTrue(result['synthetic']['belowThreshold'])
        self.data['codex']['rateLimits']['secondary']['usedPercent'] = 75
        self.save()
        self.assertFalse(self.invoke('--refresh')['codex']['belowThreshold'])

    def test_account_change_does_not_reuse_previous_windows(self):
        self.invoke()
        self.data['codex']['accountId'] = 'another-account'
        self.data['codex']['rateLimits']['secondary']['usedPercent'] = 5
        self.save()
        self.write('.codex/auth.json', {'tokens': {'account_id': 'another-account'}})
        result = self.invoke()['codex']
        self.assertEqual(result['windows'][1]['remainingPercent'], 95)
        self.assertEqual(self.calls('codex'), 2)

    def test_omp_database_account_switch_invalidates_cache(self):
        database = self.root / '.omp/agent/agent.db'
        database.parent.mkdir(parents=True)
        with sqlite3.connect(database) as connection:
            connection.execute('CREATE TABLE auth_credentials (id INTEGER, provider TEXT, updated_at INTEGER)')
            connection.execute("INSERT INTO auth_credentials VALUES (1, 'google-antigravity', 1)")
        self.invoke()
        with sqlite3.connect(database) as connection:
            connection.execute("UPDATE auth_credentials SET id=2, updated_at=2")
        self.data['omp'][1]['limits'][0]['amount']['usedFraction'] = .9
        self.save()
        self.assertAlmostEqual(self.invoke()['gemini']['windows'][0]['remainingPercent'], 10)
        self.assertEqual(self.calls('omp'), 2)

    def age_cache(self, seconds):
        for path in (self.root / 'cache/agent-usage').glob('*.json'):
            record = json.loads(path.read_text())
            record['result']['fetchedAt'] -= seconds
            if record.get('lastSuccess'):
                record['lastSuccess']['fetchedAt'] -= seconds
            path.write_text(json.dumps(record))

    def test_freshness_expiry_and_last_success_retention(self):
        self.invoke()
        self.age_cache(61)
        self.invoke()
        self.assertEqual(self.calls('codex'), 2)
        self.data['fail'] = True
        self.save()
        self.assertEqual(self.invoke('--refresh')['codex']['status'], 'stale')
        self.age_cache(301)
        self.invoke()
        self.assertEqual(self.calls('codex'), 4)
        self.age_cache(86401)
        self.assertEqual(self.invoke()['codex']['status'], 'unknown')

    def test_killed_fetcher_releases_lock(self):
        self.data['delay'] = 10
        self.save()
        proc = subprocess.Popen([sys.executable, str(SCRIPT), '--json'], env=self.env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 5
            while not (self.root / 'calls').exists():
                self.assertLess(time.monotonic(), deadline)
                time.sleep(.01)
            proc.kill()
            proc.wait()
            self.data['delay'] = 0
            self.save()
            self.assertEqual(self.invoke()['codex']['status'], 'ok')
        finally:
            if proc.poll() is None:
                proc.kill()
            proc.communicate(timeout=15)


if __name__ == '__main__':
    unittest.main()
