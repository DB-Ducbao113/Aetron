# Workout dispatcher incident and rollout

## Incident: 2026-11-20

Production cron job `dispatch-workout-processing-jobs` was paused because
the dispatcher sent up to five requests per minute while HTTP 401 responses
never reached the worker attempt counter. The queue contained 38 queued jobs.

The production `VACUUM (FULL, ANALYZE) net._http_response` completed.
PostgreSQL database size fell from 417,262,739 to 75,025,555 bytes; the response
table fell from 344,760,320 to 2,506,752 bytes, with 1,800 response rows retained.
The follow-up count was 28 workouts, 17,777 raw GPS rows and 38 queued jobs.
The API rate-limit cleanup cron was left active.

## Local regression test (isolated, no outbound HTTP)

Run from `backend/`. Use a new disposable container; never run the fixture
against a linked project or another project's database.

```sh
docker run --rm -d --name aetron-dispatch-test --network none \
  -e POSTGRES_PASSWORD=local-test-only \
  public.ecr.aws/supabase/postgres:17.11.0.004
docker exec aetron-dispatch-test pg_isready -U postgres
docker exec aetron-dispatch-test createdb -U postgres aetron_dispatch_fixture
docker exec -i aetron-dispatch-test psql -X -v ON_ERROR_STOP=1 -U postgres \
  -d aetron_dispatch_fixture < tests/workout_dispatch/fixture.sql
docker exec -i aetron-dispatch-test psql -X -v ON_ERROR_STOP=1 -U postgres \
  -d aetron_dispatch_fixture < supabase/migrations/202607040003_stabilize_workout_processing_jobs.sql
# RED: the historical dispatcher fails the new test.
docker exec -i aetron-dispatch-test psql -X -v ON_ERROR_STOP=1 -U postgres \
  -d aetron_dispatch_fixture < tests/workout_dispatch/retry_test.sql
# GREEN:
docker exec -i aetron-dispatch-test psql -X -v ON_ERROR_STOP=1 -U postgres \
  -d aetron_dispatch_fixture < supabase/migrations/202611200001_bound_workout_dispatch_and_cron_history.sql
docker exec -i aetron-dispatch-test psql -X -v ON_ERROR_STOP=1 -U postgres \
  -d aetron_dispatch_fixture < tests/workout_dispatch/retry_test.sql
docker stop aetron-dispatch-test
deno test --allow-env --allow-net \
  supabase/functions/_shared/workout_dispatch_auth_test.ts \
  supabase/functions/deterministic-finalize-worker/index_test.ts \
  supabase/functions/route-correction-worker/index_test.ts
```

## Production rollout gate

1. Keep the dispatcher cron inactive. Check linked project and migration
   history. The observed latest remote migration was `202610130006`;
   the current local workers also depend on the pending scientific-client
   migration `202611180001`. Review the deployment scope before applying it.
2. Confirm a backup/recovery plan and deploy the required migrations through
   the normal linked migration workflow; do not bypass migration history.
3. Provision the same randomly generated secret (at least 32 characters) as
   Vault secret `workout_dispatch_secret` and Edge Functions secret
   `AETRON_WORKER_DISPATCH_SECRET`. Do not commit or print the value.
   The existing Vault SDK service-role key is not used by the new dispatcher.
4. Deploy only the intended worker functions with their config. Both set
   `verify_jwt = false` because the application checks a short-lived HMAC
   signature itself. Verify missing/invalid signatures return 401, with no
   job modification. A single-use nonce is consumed on worker claim.
5. With cron still paused, manually dispatch one eligible job using
   `select * from public.dispatch_workout_processing_jobs(1);`.
   Observe the HTTP status, job status, worker attempt counter and request
   ID. Do not enable cron until the signed worker call is confirmed healthy.
6. Re-enable only the dispatcher cron and monitor the backlog. The new
   transport budget is three sends with 2/5/15 minute delays; worker attempts
   remain independently counted. Preserve failed/completed job records.
7. After confirming the retention decision, allow the new daily cleanup
   scheduler to remove finished cron history older than seven days.
   Check the count first; 188,564 old rows were observed during the audit.
   Run `VACUUM (FULL, ANALYZE) cron.job_run_details` separately during a
   maintenance window if disk reclamation is still needed.

Useful aggregate verification:

```sql
select jobname, active, schedule from cron.job order by jobid;
select status, count(*) from public.workout_processing_jobs group by status;
select status_code, count(*) from net._http_response
where created >= now() - interval '10 minutes' group by status_code;
select pg_database_size(current_database()) as db_bytes,
       pg_total_relation_size('net._http_response') as net_bytes,
       pg_total_relation_size('cron.job_run_details') as cron_bytes;
```

To contain an unexpected production regression, disable only the dispatcher
again: `select cron.alter_job(jobid, active := false) from cron.job where jobname
= 'dispatch-workout-processing-jobs';`. Do not delete workout records or reset
the historical worker attempts as part of storage maintenance.

The SQL test mocks pg_net and cron, so it cannot establish hosted gateway
compatibility or live worker completion. The production rollout gate remains
mandatory.
