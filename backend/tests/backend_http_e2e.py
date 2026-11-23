"""HTTP regression on an isolated LOCAL Supabase only.

Usage: python3 tests/backend_http_e2e.py .aetron-e2e-20261120
Requires migrated, disposable Supabase stack and cached Deno dependencies.
No external AI or email requests; no production credentials are read.
"""
import contextlib
import datetime as dt
import hashlib
import hmac
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid


ROOT = Path(__file__).resolve().parents[1]
QA = Path(sys.argv[1]).resolve()
if not QA.is_relative_to(ROOT) or not QA.name.startswith(".aetron-e2e-"):
    raise SystemExit("Use a disposable .aetron-e2e-* workspace under backend")
if not (QA / "supabase/config.toml").is_file():
    raise SystemExit("Missing isolated local Supabase configuration")
status = subprocess.run(
    (["supabase"] if shutil.which("supabase") else ["npx", "--yes", "supabase@2.120.0"])
    + ["status", "--workdir", str(QA), "-o", "json"],
    capture_output=True, check=True, text=True,
)
local = json.loads(status.stdout)
base = local["API_URL"]
if base != "http://127.0.0.1:56321":
    raise SystemExit("Unexpected local QA endpoint")
anon, service = local["ANON_KEY"], local["SERVICE_ROLE_KEY"]
deno = shutil.which("deno") or str(Path.home() / ".deno/bin/deno")
fixture_key = "aetron-local-e2e-fixture-only-" + "x" * 32
env = {
    k: v for k, v in os.environ.items()
    if k in ("PATH", "HOME", "TMPDIR", "DENO_DIR", "LANG")
}
env.update(SUPABASE_URL=base, SUPABASE_ANON_KEY=anon,
           SUPABASE_SERVICE_ROLE_KEY=service,
           AETRON_WORKER_DISPATCH_SECRET=fixture_key)


def request(url, expected, body=None, token=None, method=None, extra=None):
    headers = {"Content-Type": "application/json", "apikey": anon}
    if token:
        headers["Authorization"] = "Bearer " + token
    headers.update(extra or {})
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(),
                                 headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            code, raw = r.status, r.read()
    except urllib.error.HTTPError as e:
        code, raw = e.code, e.read()
    if code != expected:
        raise AssertionError(f"{method or req.get_method()} {url.split('?')[0]}: HTTP {code}, expected {expected}")
    return json.loads(raw) if raw else None


@contextlib.contextmanager
def function(name):
    # Only local HTTP is permitted even if a real provider key exists on host.
    with socket.socket() as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        probe.bind(("127.0.0.1", 8000))
    with tempfile.TemporaryFile() as logs:
        process = subprocess.Popen(
            [deno, "run", "--cached-only", "--allow-env",
             "--allow-net=0.0.0.0:8000,127.0.0.1:56321",
             str(ROOT / "supabase/functions" / name / "index.ts")],
            cwd=ROOT, env=env, stdout=logs, stderr=logs,
        )
        try:
            for _ in range(100):
                if process.poll() is not None:
                    raise RuntimeError(f"{name}: Deno exited {process.returncode}")
                try:
                    with socket.create_connection(("127.0.0.1", 8000), timeout=.2):
                        break
                except OSError:
                    time.sleep(.1)
            else:
                raise RuntimeError(f"{name}: HTTP startup timeout")
            yield "http://127.0.0.1:8000"
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def rest(table, expected, token, body=None, method=None, extra=None):
    return request(base + "/rest/v1/" + table, expected, body, token, method, extra)


def signup():
    email = "qa-" + uuid.uuid4().hex + "@aetron.local"
    password = "LocalQaOnly!" + uuid.uuid4().hex
    request(base + "/auth/v1/signup", 200, {"email": email, "password": password})
    auth = request(base + "/auth/v1/token?grant_type=password", 200,
                   {"email": email, "password": password})
    return auth["user"]["id"], auth["access_token"]


owner, token = signup()
other, other_token = signup()
print("PASS: two local signups and password logins", flush=True)
with function("workouts-start") as url:
    request(url, 401, {"activity_type": "walking"})
    workout = request(url, 200, {"activity_type": "walking", "mode": "outdoor"}, token)
wid = workout["workout_id"]
assert rest("workout_sessions?id=eq." + wid, 200, other_token) == []
assert rest("v_user_stats?user_id=eq." + owner, 200, other_token) == []
print("PASS: workout creation and cross-account RLS", flush=True)

points = [{"workout_id": wid, "timestamp": (dt.datetime.now(dt.timezone.utc)
           + dt.timedelta(seconds=i)).isoformat(), "latitude": 0.0,
           "longitude": i * .00001, "accuracy": 5, "speed": 1.1}
          for i in range(3)]
with function("gps-track") as url:
    request(url, 404, points, other_token)
    assert request(url, 200, points, token)["count"] == 3
assert len(rest("raw_gps_points?workout_id=eq." + wid, 200, token)) == 3
print("PASS: GPS upload and ownership enforcement", flush=True)

with function("workouts-end") as url:
    finish = {"workout_id": wid, "duration_sec": 3, "moving_time_sec": 3,
              "distance_km": .002, "avg_speed_kmh": 2.4, "calories_kcal": 1, "steps": 3}
    request(url, 404, finish, other_token)
    request(url, 200, finish, token)
jobs = rest("workout_processing_jobs?workout_id=eq." + wid, 200, service)
assert len(jobs) == 1 and jobs[0]["status"] == "queued"
job = jobs[0]["id"]
nonce = str(uuid.uuid4())
rest("workout_processing_jobs?id=eq." + job, 204, service,
     {"dispatch_nonce": nonce, "dispatch_attempt_count": 1}, "PATCH")
ts = str(int(time.time()))
signature = hmac.new(fixture_key.encode(),
                     "\n".join(["deterministic-finalize-worker", job, wid, nonce, ts]).encode(),
                     hashlib.sha256).hexdigest()
payload = {"job_id": job, "workout_id": wid, "dispatch_nonce": nonce}
headers = {"X-Aetron-Worker-Timestamp": ts, "X-Aetron-Worker-Signature": signature}
with function("deterministic-finalize-worker") as url:
    request(url, 401, payload)
    request(url, 200, payload, extra=headers)
    assert request(url, 200, payload, extra=headers)["status"] == "noop"
job_after = rest("workout_processing_jobs?id=eq." + job, 200, service)[0]
session = rest("workout_sessions?id=eq." + wid, 200, token)[0]
assert job_after["status"] == "completed" and job_after["attempt_count"] == 1
assert job_after["dispatch_nonce"] is None and session["metrics_version"] == 2
assert session["processing_status"] == "client_finalized"
print("PASS: workout finish, signed worker, replay rejection and finalized metrics", flush=True)

with function("generate-workout-insight") as url:
    data = {"workout_id": wid, "language": "vi"}
    request(url, 404, data, other_token)
    first = request(url, 200, data, token)
    second = request(url, 200, data, token)
    assert first["source"] == "fallback_rule" and first["id"] == second["id"]
print("PASS: AI fallback, persistent cache and ownership", flush=True)

# Seed a local-only verification challenge. No external email is sent.
email = "qa-" + uuid.uuid4().hex + "@gmail.com"
code = "123456"
hash_value = hashlib.sha256(f"{owner}:{email}:{code}".encode()).hexdigest()
rest("user_recovery_emails", 201, service, {"user_id": owner, "recovery_email": email})
rest("recovery_email_verifications", 201, service, {
    "user_id": owner, "recovery_email": email, "code_hash": hash_value,
    "expires_at": (dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=10)).isoformat(),
})
with function("recovery-email-start") as url:
    request(url, 401, {"recovery_email": email})
    request(url, 400, {"recovery_email": "invalid"}, token)
with function("recovery-email-verify") as url:
    request(url, 400, {"recovery_email": email, "code": code}, other_token)
    request(url, 400, {"recovery_email": email, "code": "000000"}, token)
    assert request(url, 200, {"recovery_email": email, "code": code}, token)["verified_at"]
    request(url, 400, {"recovery_email": email, "code": code}, token)
print("PASS: recovery validation, wrong code, correct code and replay rejection", flush=True)
print("LOCAL HTTP E2E PASS (no live email or LLM provider calls)")
