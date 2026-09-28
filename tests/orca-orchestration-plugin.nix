/*
  Check interface:

    import ./tests/orca-orchestration-plugin.nix { inherit pkgs; }

  Asserts what the built Claude Code plugin tree actually contains, read from
  its materialized files rather than from the Nix values that produced them:

  - hooks/hooks.json declares SessionStart and PreToolUse only. SessionStart
    sits under the single matcher `startup`, so resume, clear, compact, and
    fork never re-inject.
  - PreToolUse has one entry whose matcher fully matches Agent and Task and
    nothing else tried here, Workflow included, and whose command, run
    against an Agent payload, denies with an /orchestration reason inside Orca
    and prints nothing outside it.
  - Its handlers request parts 1..N exactly once each, N equals the part
    count the packaged script appends its overflow line to, and each command
    runs and prints its labeled part against a stub Orca CLI.
  - plugin.json's version is recomputed here from the hook file's bytes, so a
    hook change that left the version (and so Claude Code's cache) behind
    turns this red, and it satisfies agent-plugin-sync's segment pattern.
  - agent-plugin-sync's own read_manifests() accepts the tree.

  The builder collects every failure instead of exiting at the first.
*/
{ pkgs }:
let
  plugin = import ../packages/orca-orchestration-plugin.nix { inherit pkgs; };
in
pkgs.runCommand "orca-orchestration-plugin-tests"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    pluginTree = plugin;
    expectedVersion = plugin.version or "";
    syncScript = ../scripts/agent-plugin-sync;
  }
  ''
    export HOME=$TMPDIR
    python3 - <<'PY'
    import hashlib
    import importlib.machinery
    import importlib.util
    import json
    import os
    import re
    import shlex
    import subprocess
    import sys
    from pathlib import Path

    tree = Path(os.environ['pluginTree'])
    failures = []

    def check(condition, message):
        if not condition:
            failures.append(message)

    hooks_path = tree / 'hooks' / 'hooks.json'
    hooks_bytes = hooks_path.read_bytes()
    hooks = json.loads(hooks_bytes).get('hooks', {})
    check(sorted(hooks) == ['PreToolUse', 'SessionStart'], 'hooks.json declares {}, not PreToolUse and SessionStart'.format(sorted(hooks)))
    entries = hooks.get('SessionStart', [])
    check(len(entries) == 1, 'SessionStart has {} entries, not one'.format(len(entries)))
    entry = entries[0] if entries else {}
    check(entry.get('matcher') == 'startup', 'SessionStart matcher is {!r}, not "startup"'.format(entry.get('matcher')))

    handlers = entry.get('hooks', [])
    parts = []
    commands = []
    for handler in handlers:
        check(handler.get('type') == 'command', 'a handler is not a command hook: {}'.format(handler))
        timeout = handler.get('timeout')
        check(isinstance(timeout, int) and 0 < timeout <= 10, 'handler timeout {!r} is not 1-10 seconds'.format(timeout))
        argv = shlex.split(handler.get('command', ""))
        commands.append(argv)
        try:
            parts.append(int(argv[argv.index('--part') + 1]))
        except (ValueError, IndexError):
            failures.append('handler does not request a part: {}'.format(argv))
    check(parts == list(range(1, len(parts) + 1)) and parts, 'handlers request parts {}, not 1..N once each'.format(parts))

    script = Path(commands[0][0]) if commands else None
    declared = None
    if script and script.is_file():
        match = re.search(r"^CLAUDE_PARTS='?(\d+)'?$", script.read_text(), re.M)
        declared = int(match.group(1)) if match else None
    check(declared == len(parts), 'script declares {} Claude parts, hooks.json runs {}'.format(declared, len(parts)))

    # Every handler runs against a stub CLI printing a two-part guide; part
    # indexes past the guide print nothing.
    stub = Path(os.environ['TMPDIR']) / 'orca-stub'
    guide = Path(os.environ['TMPDIR']) / 'guide'
    guide.write_text("".join('guide line {:05d}\n'.format(i) for i in range(800)))
    stub.write_text('#!{}\nimport sys\nsys.stdout.write(open({!r}).read())\n'.format(sys.executable, str(guide)))
    stub.chmod(0o755)
    env = {'PATH': '/var/empty', 'ORCA_PANE_KEY': 'pane-1', 'ORCA_CLI_COMMAND': str(stub)}
    for part, argv in zip(parts, commands):
        result = subprocess.run(argv, env=env, capture_output=True, text=True)
        check(result.returncode == 0, 'part {} exited {}'.format(part, result.returncode))
        first = result.stdout.splitlines()[:1]
        if part <= 2:
            check(first == ['Orca orchestration guide (injected at session start), part {} of 2'.format(part)],
                  'part {} printed {!r}'.format(part, first))
        else:
            check(result.stdout == "", 'part {} printed text for a two-part guide'.format(part))

    guards = hooks.get('PreToolUse', [])
    check(len(guards) == 1, 'PreToolUse has {} entries, not one'.format(len(guards)))
    guard = guards[0] if guards else {}
    try:
        matcher = re.compile(guard.get('matcher', ""))
        for tool in ['Agent', 'Task']:
            check(matcher.fullmatch(tool) is not None, 'PreToolUse matcher {!r} does not match {}'.format(matcher.pattern, tool))
        for tool in ['Workflow', 'AgentOutput', 'SubAgent', 'Bash', 'Read']:
            check(matcher.search(tool) is None, 'PreToolUse matcher {!r} also matches {}'.format(matcher.pattern, tool))
    except re.error as exc:
        failures.append('PreToolUse matcher is not a regular expression: {}'.format(exc))
    guard_handlers = guard.get('hooks', [])
    check(len(guard_handlers) == 1, 'PreToolUse has {} handlers, not one'.format(len(guard_handlers)))
    for handler in guard_handlers:
        check(handler.get('type') == 'command', 'the PreToolUse handler is not a command hook: {}'.format(handler))
        timeout = handler.get('timeout')
        check(isinstance(timeout, int) and 0 < timeout <= 10, 'PreToolUse timeout {!r} is not 1-10 seconds'.format(timeout))
        argv = shlex.split(handler.get('command', ""))
        payload = json.dumps({'hook_event_name': 'PreToolUse', 'tool_name': 'Agent', 'tool_input': {}})
        inside = subprocess.run(argv, env={'PATH': '/var/empty', 'ORCA_PANE_KEY': 'pane-1'}, input=payload, capture_output=True, text=True)
        check(inside.returncode == 0, 'PreToolUse command exited {} inside Orca'.format(inside.returncode))
        try:
            decision = json.loads(inside.stdout).get('hookSpecificOutput', {})
        except ValueError:
            decision = {}
        check(decision.get('permissionDecision') == 'deny' and '/orchestration' in decision.get('permissionDecisionReason', ""),
              'PreToolUse command did not deny Agent with an /orchestration reason inside Orca: {!r}'.format(inside.stdout))
        outside = subprocess.run(argv, env={'PATH': '/var/empty'}, input=payload, capture_output=True, text=True)
        check(outside.returncode == 0 and outside.stdout == "", 'PreToolUse command printed {!r} outside Orca'.format(outside.stdout))

    manifest = json.loads((tree / '.claude-plugin' / 'plugin.json').read_text())
    version = manifest.get('version')
    recomputed = '0.0.0-' + hashlib.sha256(hooks_bytes).hexdigest()[:12]
    check(version == recomputed, 'plugin.json version {!r} is not the hook file hash {!r}'.format(version, recomputed))
    check(version == os.environ['expectedVersion'], 'plugin.json version {!r} differs from the package version {!r}'.format(version, os.environ['expectedVersion']))

    loader = importlib.machinery.SourceFileLoader('agent_plugin_sync', os.environ['syncScript'])
    spec = importlib.util.spec_from_loader('agent_plugin_sync', loader)
    sync = importlib.util.module_from_spec(spec)
    loader.exec_module(sync)
    check(bool(sync.SEGMENT.match(version or "")), 'version {!r} fails agent-plugin-sync SEGMENT'.format(version))
    try:
        marketplace = sync.read_manifests(tree)
        check([p.get('name') for p in marketplace.get('plugins', [])] == [manifest.get('name')],
              'marketplace does not list exactly the plugin {!r}'.format(manifest.get('name')))
    except sync.Failure as exc:
        failures.append('read_manifests refused the tree: {}'.format(exc))

    for failure in failures:
        print('orca-orchestration-plugin: FAIL: ' + failure, file=sys.stderr)
    if failures:
        sys.exit(1)
    print('orca-orchestration-plugin: ok')
    PY
    touch $out
  ''
