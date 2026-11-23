"""Start a clean, disposable localhost-only Supabase QA service.

Run from backend: python3 tests/prepare_http_qa.py .aetron-e2e-ci
The target must not already exist. No project link or remote DB operations.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
qa = Path(sys.argv[1]).resolve()
if qa.parent != root or not re.fullmatch(r"\.aetron-e2e-[a-z0-9-]+", qa.name):
    raise SystemExit("Expected a new backend/.aetron-e2e-* directory")
cli = ["supabase"] if shutil.which("supabase") else ["npx", "--yes", "supabase@2.120.0"]
qa.mkdir()
subprocess.run(cli + ["init", "--workdir", str(qa)], check=True, stdout=subprocess.DEVNULL)
config = qa / "supabase/config.toml"
project_id = qa.name.lstrip(".")
data = config.read_text()
data = re.sub(r"^project_id = .*?$", f'project_id = "{project_id}"', data, flags=re.M)
data = re.sub(r"\b543(\d\d)\b", r"563\1", data)
data = data.replace("inspector_port = 8083", "inspector_port = 8383")
data = re.sub(r"(\[db.seed\]\s*\n(?:#[^\n]*\n)*)enabled = true",
              r"\1enabled = false", data)
config.write_text(data)
shutil.copytree(root / "supabase/migrations", qa / "supabase/migrations")
# CLI start prints disposable JWTs and service credentials. Do not emit them.
with (qa / "start.log").open("w") as log:
    result = subprocess.run(cli + ["start", "--workdir", str(qa), "-x",
        "studio,edge-runtime,realtime,logflare,vector,mailpit,postgres-meta,supavisor,imgproxy"],
        stdout=log, stderr=log)
if result.returncode != 0:
    raise SystemExit(f"Local QA startup failed (exit {result.returncode}); see private start.log")
print(f"Started isolated {project_id} at http://127.0.0.1:56321")
