#!/usr/bin/env python3
"""Temporary U9 Linux evidence venue; remove after recording CI evidence.

Every row drives the real owner, not a replay of an extracted assertion.
Only scratch archives have an index. Structured records and full command
transcripts are retained together in the uploaded CI evidence artifact.
"""
import argparse
from dataclasses import asdict, dataclass
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import selectors
import sys
from types import SimpleNamespace
import subprocess
import tarfile
import tempfile
import time


@dataclass(frozen=True)
class Mutation:
    id: str
    finding: str
    owner: str
    path: str
    before: str
    after: str
    diagnostic: str


def mutation(id, finding, owner, path, before, after, diagnostic):
    return Mutation(id, finding, owner, path, before, after, diagnostic)


AGENTS = 'home/h82/agents/'
CASES = []
for id, owner, module, label in [
    ('claude-settings', 'claude', 'claude', 'Claude Code'),
    ('claude-global', 'claude', 'claude', 'Claude Code'),
    ('codex-settings', 'codex-settings', 'codex', 'Codex'),
    ('antigravity-settings', 'gemini', 'gemini', 'Antigravity CLI'),
    ('tokscale-settings', 'tokscale', 'tokscale', 'Tokscale'),
]:
    before = '${merger} \\\n        --label ' + ("'" + label + "'" if ' ' in label else label)
    if module == 'claude':
        before += ' ' + chr(92) + '\n        --settings ${config.home.homeDirectory}/' + ('.claude.json' if id == 'claude-global' else '.claude/settings.json')
    if module == 'codex':
        before = '${merger} ' + chr(92) + '\n        --format toml'
    CASES.append(mutation(id, 'F1', owner, AGENTS + module + '.nix', before,
                          'echo ' + before, 'activation did not execute exactly one merger'))
CASES += [
    mutation('plugins-echo', 'F1', 'agent-plugins', AGENTS + 'agent-plugins.nix',
             'env ${harness.env} ${syncTool} \\', 'env ${harness.env} echo ${syncTool} \\',
             'activation skipped plugin harness rows'),
    mutation('gemini-disabled', 'F2', 'gemini', AGENTS + 'gemini.nix',
             '  home.file.".gemini/settings.json".text',
             '  home.file.".gemini/settings.json".enable = false;\n  home.file.".gemini/settings.json".text',
             'missing or incorrect delivered Gemini settings'),
    mutation('gemini-retargeted', 'F2', 'gemini', AGENTS + 'gemini.nix',
             '  home.file.".gemini/settings.json".text',
             '  home.file.".gemini/settings.json".target = ".gemini/audit-misplaced.json";\n  home.file.".gemini/settings.json".text',
             'missing or incorrect delivered Gemini settings'),
]
for id, owner, module, before, diagnostic in [
    ('standalone-codex', 'codex-settings', 'codex', '${merger} \\', 'activation did not execute exactly one merger'),
    ('standalone-antigravity', 'gemini', 'gemini', '${merger} \\', 'activation did not execute exactly one merger'),
    ('standalone-plugins', 'agent-plugins', 'agent-plugins', 'env ${harness.env} ${syncTool} \\', 'activation skipped plugin harness rows'),
]:
    CASES.append(mutation(id, 'F3', owner, AGENTS + module + '.nix', before,
                          '${lib.optionalString (config.my.kind == "linux") "echo "}' + before,
                          diagnostic))
CASES += [
    mutation('bootstrap-rule', 'F8', 'bootstrap-recipients', '.sops.yaml',
             '  - path_regex: secrets/tokens\\.yaml$\n    age: ',
             '  - path_regex: secrets/audit-nonmatching\\.yaml$\n    age: ',
             'invalid or absent from the first applicable secrets/tokens.yaml rule'),
    mutation('pinentry-wrong-delegate', 'F11', 'pinentry-card', 'packages/gpg-tools.nix',
             "--replace-fail '@PINENTRY_QT@' '${pkgs.pinentry-qt}/bin/pinentry-qt'",
             "--replace-fail '@PINENTRY_QT@' '${pkgs.pinentry-curses}/bin/pinentry-curses'",
             r'selected \[\[.*expected'),
    mutation('pinentry-unresolved', 'F11', 'pinentry-card', 'packages/gpg-tools.nix',
             "        --replace-fail '@PINENTRY_QT@' '${pkgs.pinentry-qt}/bin/pinentry-qt' " + chr(92) + "\n",
             '', 'unresolved package substitution:'),
    mutation('pinentry-missing-alias', 'F11', 'pinentry-card', 'packages/gpg-tools.nix',
             'ln -s pinentry-card $out/bin/pinentry\n      substituteInPlace $out/bin/pinentry-card',
             'substituteInPlace $out/bin/pinentry-card',
             'missing executable entry point:'),
    mutation('ndk-no-metadata', 'F12', 'android-sdk', 'packages/android-sdk.nix',
             '  sdkRoot = "${composition.androidsdk}/libexec/android-sdk";',
             '''  sdkRoot = pkgs.runCommand "audit-sdk-without-ndk-metadata" { } ''
    mkdir -p $out
    cp -rsL ${composition.androidsdk}/libexec/android-sdk/. $out/
    chmod -R u+w $out
    rm $out/ndk/*/source.properties
  '';''',
             r': missing /nix/store/[^\n]+/ndk/[^/]+/source\.properties'),
    mutation('registry-disabled', 'F13', 'podman-containers', 'home/h82/dev/containers.nix',
             '    xdg.configFile."containers/registries.conf.d/10-unqualified-search.conf".text',
             '    xdg.configFile."containers/registries.conf.d/10-unqualified-search.conf".enable = false;\n    xdg.configFile."containers/registries.conf.d/10-unqualified-search.conf".text',
             'missing materialized registry search drop-in'),
    mutation('registry-commented', 'F13', 'podman-containers', 'home/h82/dev/containers.nix',
             '      unqualified-search-registries = ["docker.io"]',
             '      # unqualified-search-registries = ["docker.io"]',
             'incorrect materialized registry search policy'),
    mutation('containers-auth-no-write', 'F14', 'podman-containers', 'home/h82/dev/containers.nix',
             'if [ ! -e "$AUTH_FILE" ] && [ ! -L "$AUTH_FILE" ]; then',
             'if false && [ ! -e "$AUTH_FILE" ] && [ ! -L "$AUTH_FILE" ]; then',
             'containersAuth did not create auth.json'),
]
for id, owner, path, anchor, field, diagnostic in [
    ('gpg', 'gpg-agent-no-cache', 'home/h82/security/gpg.nix', '  programs.gpg = {',
     'home.file."${config.programs.gpg.homedir}/gpg-agent.conf"', 'gpg-agent.conf no longer sets default-cache-ttl 0'),
    ('zsh', 'zsh-prezto', 'home/h82/shell/shell.nix', '  programs.zsh = {',
     'home.file.".config/zsh/.zshrc"', '.config/zsh/.zshrc does not contain runcoms/zshrc'),
    ('ghostty', 'ghostty-font', 'home/h82/desktop/terminal.nix', '  programs.ghostty = {',
     'xdg.configFile."ghostty/config"', 'ghostty config does not set font-family'),
]:
    for suffix, assignment in [('disabled', 'enable = false'),
                                ('retargeted', 'target = ".audit-misplaced-' + id + '"')]:
        CASES.append(mutation(id + '-' + suffix, 'F16', owner, path, anchor,
                              '  ' + field + '.' + assignment + ';\n' + anchor, diagnostic))
CASES += [
    mutation('zsh-startup', 'F16', 'zsh-prezto', 'home/h82/shell/shell.nix',
             '  programs.zsh = {', '  home.file.".zshenv".enable = false;\n  programs.zsh = {',
             '.zshenv does not source'),
    mutation('gpg-nonzero-ttl', 'F16', 'gpg-agent-no-cache', 'home/h82/security/gpg.nix',
             '      default-cache-ttl 0', '      default-cache-ttl 0\n      default-cache-ttl-ssh 60',
             'gpg-agent.conf sets a non-zero cache lifetime'),
]
for package, before in [('python3', '        python3\n'), ('uv', '      ++ [ uv ]')]:
    empty = '(pkgs.runCommand "audit-empty-' + package + '" { pname = "' + package + '"; } "mkdir -p $out")'
    after = '        ' + empty + '\n' if package == 'python3' else '      ++ [ ' + empty + ' ]'
    CASES.append(mutation('empty-' + package, 'F17', 'python3-runtime', 'home/h82/default.nix',
                          before, after, 'installed ' + package + ' runtime failed on'))
CASES += [
    mutation('printer-unconditional', 'F18', 'printing', 'modules/nixos/services/printing.nix',
             'if [ "$(lpstat -v ${label} 2>/dev/null)" != "device for ${label}: $uri" ]; then',
             'if true; then', r"AssertionError: \('printer queue lifecycle', 'correct',"),
    mutation('taskbar-no-discovery', 'F19', 'plasma-taskbar', 'home/h82/desktop/kde/plasma.nix',
             'org.kde.plasma.icontasks|org.kde.plasma.taskmanager)',
             'org.audit.missing.icontasks|org.audit.missing.taskmanager)',
             'taskbar activation did not reconcile'),
    mutation('vscodium-echo', 'F20', 'vscodium', 'home/h82/dev/vscodium.nix',
             '      ${merger} \\', '      echo ${merger} \\',
             'merging the seeded settings file lost a declared value or a key VSCodium wrote'),
    mutation('tailscale-existing-contact', 'F21', 'vmChecks.tailscale-provisioning', 'scripts/tailscale-dedup-device',
             'if [ -e "$TAILSCALE_STATE_FILE" ]; then',
             'if [ -e "$TAILSCALE_STATE_FILE" ]; then\n  curl -sS --fail "$TAILSCALE_API_BASE/api/v2/tailnet/-/devices" >/dev/null',
             'existing state contacted API:'),
    mutation('udev-retargeted', 'F22', 'logitech-wakeup', 'modules/nixos/system/base.nix',
             '  boot.kernel.sysctl = {',
             '  environment.etc."udev/rules.d".target = "audit-misplaced-rules";\n  boot.kernel.sysctl = {',
             'Logitech wakeup-disable rule is missing from the installed udev rules'),
    mutation('sysctl-retargeted', 'F23', 'kernel-sysctl', 'modules/nixos/system/base.nix',
             '  boot.kernel.sysctl = {',
             '  environment.etc."sysctl.d/60-nixos.conf".target = "audit-misplaced-sysctl";\n  boot.kernel.sysctl = {',
             'sysctl.d/60-nixos.conf is missing from the built /etc'),
    mutation('sysctl-numeric', 'F23', 'kernel-sysctl', 'modules/nixos/system/base.nix',
             '"fs.inotify.max_user_watches" = 524288;', '"fs.inotify.max_user_watches" = 524289;',
             "missing the line 'fs.inotify.max_user_watches=524288'"),
]
CASES += [
    mutation('settings-dry-run', 'review-dry-run', 'gemini', AGENTS + 'gemini.nix',
             '    if [[ ! -v DRY_RUN ]]; then', '    if true; then',
             'settings dry-run invoked a writing helper'),
    mutation('vscodium-dry-run', 'review-dry-run', 'vscodium', 'home/h82/dev/vscodium.nix',
             '    if [[ ! -v DRY_RUN ]]; then', '    if true; then',
             'settings dry-run changed protected bytes'),
    mutation('plugin-unset-variable', 'review-shell', 'agent-plugins', AGENTS + 'agent-plugins.nix',
             'if [[ -v DRY_RUN ]]; then', 'if [ -n "$DRY_RUN" ]; then',
             r'block[.]sh:.*DRY_RUN:'),
    mutation('auth-embedded-credential', 'review-credentials', 'podman-containers', 'home/h82/dev/containers.nix',
             '          AUTH_DIR="$HOME/.config/containers"',
             '          AUDIT_PASSWORD="fake-embedded-credential"\n          AUTH_DIR="$HOME/.config/containers"',
             'containersAuth activation embeds credential material'),
]
GROUPS = sorted({case.owner for case in CASES})
NIX = ['nix', '--extra-experimental-features', 'nix-command flakes']


def emit(**record):
    encoded = json.dumps(record, sort_keys=True)
    if LOG_DIR is not None:
        LOG_DIR.mkdir(exist_ok=True, parents=True)
        with (LOG_DIR / 'evidence.jsonl').open('a') as stream:
            stream.write(encoded + '\n')
    print('AUDIT_PROOF_JSON ' + encoded, flush=True)


LOG_DIR = None


def command(args, cwd, timeout=5400, capture=False):
    start = time.monotonic()
    directory = LOG_DIR or Path(tempfile.mkdtemp(prefix='audit-transcripts-'))
    directory.mkdir(exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix='command-', dir=directory)
    os.close(descriptor)
    transcript = Path(name)
    captured = {"stdout": bytearray(), "stderr": bytearray()}
    process = subprocess.Popen(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        with transcript.open('wb') as log, selectors.DefaultSelector() as ready:
            for name, pipe in (("stdout", process.stdout), ("stderr", process.stderr)):
                ready.register(pipe, selectors.EVENT_READ, name)
            while ready.get_map():
                remaining = timeout - (time.monotonic() - start)
                if remaining <= 0:
                    raise subprocess.TimeoutExpired(args, timeout)
                for event, _ in ready.select(min(remaining, 1)):
                    chunk = os.read(event.fd, 65536)
                    if not chunk:
                        ready.unregister(event.fileobj)
                        continue
                    log.write(chunk)
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.buffer.flush()
                    if capture:
                        data = captured[event.data]
                        if len(data) + len(chunk) > 65536:
                            raise RuntimeError('bounded command capture exceeded 64 KiB')
                        data.extend(chunk)
            process.wait(timeout=max(0.001, timeout - (time.monotonic() - start)))
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        process.stdout.close()
        process.stderr.close()
    emit(command=args, exit=process.returncode, seconds=round(time.monotonic() - start, 2),
         transcript=transcript.name)
    return SimpleNamespace(returncode=process.returncode, transcript=transcript,
                           stdout=captured['stdout'].decode(), stderr=captured['stderr'].decode())


def diagnostic_evidence(path, pattern):
    digest = hashlib.sha256()
    tail = ''
    excerpt = None
    with path.open('rb') as stream:
        while chunk := stream.read(65536):
            digest.update(chunk)
            text = tail + chunk.decode(errors='replace')
            # Keep the raw tail so CSI sequences split across reads reassemble.
            tail = text[-8192:]
            text = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)
            match = re.search(pattern, text)
            if match and excerpt is None:
                excerpt = text[max(0, match.start() - 256):match.end() + 256]
    return excerpt, digest.hexdigest()


def evaluate(root, owner):
    attr = 'legacyPackages.x86_64-linux.' + owner if owner.startswith('vmChecks.') else 'checks.x86_64-linux.' + owner
    result = command(NIX + ['eval', '--raw', 'path:' + str(root) + '#' + attr + '.drvPath'], root, 600, capture=True)
    if result.returncode:
        raise RuntimeError('owner evaluation failed; no caught evidence')
    drv = result.stdout.strip()
    if not drv.startswith('/nix/store/') or not drv.endswith('.drv') or '\n' in drv:
        raise RuntimeError('unexpected derivation path: ' + drv)
    return drv


def build(root, drv):
    return command(NIX + ['build', '--no-link', '--print-build-logs', drv + '^*'], root)


def run(root, group, revision):
    selected = [case for case in CASES if case.owner == group]
    baseline = evaluate(root, group)
    if build(root, baseline).returncode:
        raise RuntimeError('unmutated owner failed; mutations not attempted')
    failures = []
    for case in selected:
        path = root / case.path
        original = path.read_bytes()
        before = original.decode()
        if before.count(case.before) != 1:
            raise RuntimeError(case.id + ': exact mutation anchor count is ' + str(before.count(case.before)))
        after = before.replace(case.before, case.after)
        if after == before:
            raise RuntimeError(case.id + ': mutation changed no bytes')
        record = dict(case=asdict(case), revision=revision, platform=platform.platform(),
                      runner=os.environ.get('RUNNER_ARCH'),
                      ci_run=os.environ.get('GITHUB_SERVER_URL', '') + '/' + os.environ.get('GITHUB_REPOSITORY', '') +
                      '/actions/runs/' + os.environ.get('GITHUB_RUN_ID', ''),
                      before_sha256=hashlib.sha256(original).hexdigest(),
                      after_sha256=hashlib.sha256(after.encode()).hexdigest(), baseline_drv=baseline, baseline_exit=0)
        problem = None
        try:
            path.write_text(after)
            assert path.read_text() == after
            emit(event='mutation-applied', **record)
            drv = evaluate(root, group)
            record['mutant_drv'] = drv
            if drv == baseline:
                raise RuntimeError('mutation did not change owner derivation')
            result = build(root, drv)
            log = command(NIX + ['log', drv], root, 120)
            excerpt, digest = diagnostic_evidence(log.transcript, case.diagnostic)
            record.update(mutant_exit=result.returncode, owner_log_exit=log.returncode,
                          owner_log_excerpt=excerpt, owner_log_sha256=digest,
                          owner_log_transcript=log.transcript.name)
            if result.returncode == 0 or log.returncode != 0 or excerpt is None:
                raise RuntimeError('mutation not caught by intended owner builder diagnostic')
            record['caught'] = True
        except (RuntimeError, subprocess.TimeoutExpired) as error:
            problem = str(error)
            record.update(caught=False, error=problem)
        finally:
            path.write_bytes(original)
            assert path.read_bytes() == original
            restored = evaluate(root, group)
            if restored != baseline or build(root, restored).returncode:
                record['restored_control'] = False
                emit(event='result', **record)
                raise RuntimeError('restored owner control failed')
            record['restored_drv'] = restored
            record['restored_control'] = True
            emit(event='result', **record)
        if problem:
            failures.append(case.id + ': ' + problem)
    if failures:
        raise RuntimeError('; '.join(failures))
    emit(event='venue-complete', owner=group, mutation_count=len(selected), revision=revision)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument('--list', action='store_true', help='JSON matrix group IDs')
    choice.add_argument('--case', choices=GROUPS, help='run all mutations for one real owner')
    args = parser.parse_args()
    if args.list:
        print(json.dumps(GROUPS))
        return
    if platform.system() != 'Linux' or platform.machine() != 'x86_64':
        parser.error('matching x86_64 Linux builder required; native replay is not evidence')
    source = Path(__file__).resolve().parents[1]
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip()
    archive = subprocess.check_output(['git', 'archive', revision], cwd=source)
    with tempfile.TemporaryDirectory(prefix='audit-proof-') as directory:
        global LOG_DIR
        base = Path(directory).resolve()
        LOG_DIR = Path(os.environ['AUDIT_PROOF_LOG_DIR']).resolve() if 'AUDIT_PROOF_LOG_DIR' in os.environ else base / 'transcripts'
        root = base / 'source'
        root.mkdir()
        with tarfile.open(fileobj=io.BytesIO(archive)) as stream:
            stream.extractall(root, filter='data')
        if (root / '.git').exists():
            raise RuntimeError('archive unexpectedly has .git')
        for git_args in (['git', 'init', '--initial-branch=audit-proof'], ['git', 'add', '--all']):
            if command(git_args, root, 30).returncode:
                raise RuntimeError('scratch index initialization failed')
        run(root, args.case, revision)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        emit(event='venue-failed', error=str(error))
        raise
