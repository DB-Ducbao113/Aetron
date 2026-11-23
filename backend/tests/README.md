# Backend HTTP and deployment regression checks

Run from `backend/` with Docker, Supabase CLI (or Node/npx), Python 3 and Deno.
The disposable QA project uses ports 56321/56322, a separate project ID and
local test accounts. Do not link it to a hosted project.

```sh
python3 tests/prepare_http_qa.py .aetron-e2e-ci
supabase db lint --local --workdir .aetron-e2e-ci --fail-on error
for test_file in supabase/tests/*.sql; do
  docker exec -i supabase_db_aetron-e2e-ci psql -X -v ON_ERROR_STOP=1 -U postgres < "$test_file" || exit 1
done
deno cache supabase/functions/workouts-start/index.ts supabase/functions/gps-track/index.ts supabase/functions/workouts-end/index.ts supabase/functions/deterministic-finalize-worker/index.ts supabase/functions/generate-workout-insight/index.ts supabase/functions/recovery-email-start/index.ts supabase/functions/recovery-email-verify/index.ts
python3 tests/backend_http_e2e.py .aetron-e2e-ci
supabase stop --workdir .aetron-e2e-ci --no-backup
```

Remove only the disposable QA directory after stopping its containers.
`start.log` contains local CLI status credentials; never commit it.

The HTTP test uses actual local Auth, PostgREST and Edge Function source
running under Deno, with a synthetic signed worker request and nonce.
It verifies owner isolation, workout creation/upload/finalization, duplicate
worker request rejection, AI rule fallback/cache and recovery-code validation.
The verification challenge is seeded locally; neither real email delivery
nor an external AI provider is contacted. The local HTTP run does not prove
the hosted gateway or actual device behavior.

The production deployment workflow now checks the linked target and worker
configuration before applying migrations, pauses and drains the dispatcher,
and verifies both signed no-op requests before restoring a previously active
dispatcher. It accepts manual releases from `main` and `ekf`; the production
environment's branch/reviewer protection must also be configured in GitHub.
A failed deployment leaves the dispatcher paused for investigation.
The signed no-op SQL only uses synthetic job IDs and does not create or
modify workout rows. The live production smoke in the November 20, 2026
incident recovery returned HTTP 200 / noop / job_not_found for both workers.

See `workout_dispatch/README.md` for the original incident and retry fixture.
