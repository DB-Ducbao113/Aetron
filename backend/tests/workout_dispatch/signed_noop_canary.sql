-- Hosted smoke test: signs two nonexistent jobs, without changing workout
-- rows or exporting the Vault secret. Check both response IDs separately.
with key_config as materialized (
  select (select regexp_replace(decrypted_secret, '/+$', '')
            from vault.decrypted_secrets where name='project_url'
            order by updated_at desc limit 1) as project_url,
         (select decrypted_secret from vault.decrypted_secrets
            where name='workout_dispatch_secret'
            order by updated_at desc limit 1) as signing_key
),
payloads as materialized (
  select worker, gen_random_uuid() as job_id,
         gen_random_uuid() as workout_id, gen_random_uuid() as nonce,
         floor(extract(epoch from clock_timestamp()))::bigint::text as signed_at
  from (values ('deterministic-finalize-worker'), ('route-correction-worker')) w(worker)
)
select p.worker, net.http_post(
  url := k.project_url || '/functions/v1/' || p.worker,
  body := jsonb_build_object('job_id', p.job_id, 'workout_id', p.workout_id,
                             'dispatch_nonce', p.nonce),
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'X-Aetron-Worker-Timestamp', p.signed_at,
    'X-Aetron-Worker-Signature', encode(extensions.hmac(
      convert_to(p.worker || chr(10) || p.job_id::text || chr(10) ||
        p.workout_id::text || chr(10) || p.nonce::text || chr(10) || p.signed_at, 'UTF8'),
      convert_to(k.signing_key, 'UTF8'), 'sha256'), 'hex')),
  timeout_milliseconds := 10000
) as request_id
from payloads p cross join key_config k
where length(k.signing_key) >= 32 and k.project_url is not null;
