#!/usr/bin/env python3
"""Real CLI processes; all state is isolated. Injected receipts simulate a future human adapter."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import uuid

cli = str(Path(sys.argv[1]).resolve())
passed = 0


def env(root):
    return dict(os.environ, REPRISE_GATE_PATH=str(root))


def command(*extra):
    return [cli, 'ask', '--requester', 'Codex', '--action', 'Publier la branche',
            '--target', 'ridhafandi-dev/reprise', '--scope', 'feature/aegis-gate-v0 uniquement',
            '--effect', 'difficult', '--evidence', 'Tests locaux réussis', '--ttl', '30', *extra]


def wait_request(root, proc):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        files = list(root.glob('*.request.json'))
        if files:
            return json.loads(files[0].read_bytes())
        if proc.poll() is not None:
            raise AssertionError(proc.communicate())
        time.sleep(.01)
    raise AssertionError('CLI did not publish request')


def receipt(request, outcome='approve_once'):
    return dict(version=1, requestID=request['id'], requestDigest=request['requestDigest'],
                outcome=outcome, decidedAt=int(time.time() * 1000), expiresAt=request['expiresAt'])


def publish(root, request, value):
    file = root / (request['id'].lower() + '.decision.json')
    tmp = root / (str(uuid.uuid4()) + '.testtmp')
    with open(tmp, 'xb') as out:
        os.chmod(tmp, 0o600)
        out.write(value if isinstance(value, bytes) else json.dumps(value).encode())
        out.flush()
        os.fsync(out.fileno())
    os.link(tmp, file)  # Exclusive, atomic publication for this simulated peer.
    tmp.unlink()
    return file


def check(name, body):
    global passed
    with tempfile.TemporaryDirectory(prefix='reprise-gate-cli-') as path:
        body(Path(path))
    passed += 1
    print(f'PASS Gate CLI: {name}', flush=True)


def no_wait(root):
    result = subprocess.run(command('--no-wait'), env=env(root), capture_output=True)
    assert result.returncode == 4, result.stderr
    request = json.loads(result.stdout)
    assert set(request) == {'version', 'id', 'requester', 'action', 'target', 'scope', 'effect',
                            'evidence', 'createdAt', 'expiresAt', 'requestDigest'}
    unsigned = {k: v for k, v in request.items() if k != 'requestDigest'}
    unsigned['id'] = unsigned['id'].lower()
    canonical = json.dumps(unsigned, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
    assert hashlib.sha256(canonical).hexdigest() == request['requestDigest']
    assert len(list(root.glob('*.request.json'))) == 1
    assert not list(root.glob('*.decision.json'))
    assert not result.stderr


check('no-wait is pending (4), canonical digest independently verified with Python', no_wait)


def decision_flow(root, outcome, expected):
    proc = subprocess.Popen(command(), env=env(root), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        request = wait_request(root, proc)
        original = receipt(request, outcome)
        file = publish(root, request, original)
        stdout, stderr = proc.communicate(timeout=5)
        assert proc.returncode == expected, (proc.returncode, stderr)
        assert json.loads(stdout) == original
        assert not stderr
        assert not list(root.glob('*.request.json'))
        assert file.exists() and len(list(root.glob('*.entry.json'))) == 1
    finally:
        if proc.poll() is None:
            proc.kill(); proc.communicate()


check('approval JSON, exit 0, verified cleanup and retained anti-replay receipt', lambda r: decision_flow(r, 'approve_once', 0))
check('denial JSON, exit 2, verified cleanup', lambda r: decision_flow(r, 'deny', 2))


def invalid_receipt(root, mutation):
    proc = subprocess.Popen(command(), env=env(root), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        request = wait_request(root, proc)
        bad = mutation(receipt(request))
        file = publish(root, request, bad)
        before = file.read_bytes()
        stdout, stderr = proc.communicate(timeout=5)
        assert proc.returncode == 1 and not stdout and stderr, (proc.returncode, stdout, stderr)
        assert file.read_bytes() == before
        assert len(list(root.glob('*.request.json'))) == 1
    finally:
        if proc.poll() is None:
            proc.kill(); proc.communicate()


check('wrong digest receipt rejected and preserved', lambda r: invalid_receipt(r, lambda d: dict(d, requestDigest='0' * 64)))
check('another request receipt rejected and preserved', lambda r: invalid_receipt(r, lambda d: dict(d, requestID=str(uuid.uuid4()))))
check('wrong expiration receipt rejected and preserved', lambda r: invalid_receipt(r, lambda d: dict(d, expiresAt=d['expiresAt'] + 1)))
check('corrupt receipt rejected and preserved', lambda r: invalid_receipt(r, lambda d: b'{broken'))


def concurrent(root):
    procs = [subprocess.Popen(command('--no-wait'), env=env(root), stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(12)]
    try:
        deadline = time.monotonic() + 10
        observations = 0
        while any(p.poll() is None for p in procs):
            assert time.monotonic() < deadline
            # Published files must always contain full JSON, even during concurrent writes.
            for file in [*root.glob('*.entry.json'), *root.glob('*.request.json')]:
                json.loads(file.read_bytes())
                observations += 1
            time.sleep(.001)
        results = [(p.returncode, *p.communicate()) for p in procs]
        assert sum(code == 4 for code, _, _ in results) == 8, results
        assert sum(code == 1 for code, _, _ in results) == 4, results
        entries = [json.loads(f.read_bytes()) for f in root.glob('*.entry.json')]
        assert sorted(e['sequence'] for e in entries) == list(range(1, 9))
        assert len({e['request']['id'] for e in entries}) == 8
        assert len(list(root.glob('*.request.json'))) == 8
        assert observations > 0
        assert not list(root.glob('*.tmp'))
    finally:
        for p in procs:
            if p.poll() is None:
                p.kill(); p.communicate()


check('12 concurrent writers: 8 FIFO admissions, 4 errors, no partial published JSON', concurrent)


def interrupted(root):
    proc = subprocess.Popen(command(), env=env(root), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        wait_request(root, proc)
        proc.send_signal(signal.SIGTERM)
        stdout, _ = proc.communicate(timeout=5)
        assert not stdout and len(list(root.glob('*.request.json'))) == 1
        assert not list(root.glob('*.decision.json'))
    finally:
        if proc.poll() is None:
            proc.kill(); proc.communicate()


check('interrupted requester leaves pending request, no authorization', interrupted)


def malicious_action(root):
    marker = root / 'MUST-NOT-EXIST'
    args = command('--no-wait')
    args[args.index('--action') + 1] = f'touch {marker}; $(touch {marker})'
    result = subprocess.run(args, env=env(root), capture_output=True)
    assert result.returncode == 4, result.stderr
    assert not marker.exists()
    assert json.loads(result.stdout)['action'] == args[args.index('--action') + 1]


check('shell syntax remains inert data in real CLI', malicious_action)


def invalid_options(root):
    for extra in [('--execute', 'yes'), ('--ttl', '900'), ('--no-wait', '--no-wait')]:
        result = subprocess.run(command(*extra), env=env(root), capture_output=True)
        assert result.returncode == 1 and not result.stdout
    assert not list(root.iterdir())


check('unknown and duplicate CLI flags rejected before storage', invalid_options)


def expiration(root):
    start = time.monotonic()
    result = subprocess.run(command(), env=env(root), capture_output=True, timeout=36)
    assert result.returncode == 3, (result.returncode, result.stderr)
    decision = json.loads(result.stdout)
    assert decision['outcome'] == 'expired' and decision['decidedAt'] >= decision['expiresAt']
    assert 29 <= time.monotonic() - start < 36
    assert not list(root.glob('*.request.json'))
    assert len(list(root.glob('*.decision.json'))) == 1


check('real 30-second timeout writes expired receipt, JSON exit 3, verified cleanup', expiration)
print(f'Gate CLI tests: {passed} passed, 0 failed', flush=True)
