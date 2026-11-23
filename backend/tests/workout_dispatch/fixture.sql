-- Only for an isolated, disposable PostgreSQL database. No outbound HTTP.
create schema if not exists vault;
create schema if not exists net;
create schema if not exists cron;
create schema if not exists auth;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create table vault.decrypted_secrets(name text, decrypted_secret text, updated_at timestamptz);
create sequence net.mock_requests;
create table net.mock_http_requests(id bigint primary key, url text, body jsonb, headers jsonb);
create function net.http_post(url text, body jsonb, headers jsonb, timeout_milliseconds int)
returns bigint language sql as $$
  insert into net.mock_http_requests values (nextval('net.mock_requests'), url, body, headers)
  returning id
$$;
create function cron.schedule(text,text,text) returns bigint language sql as $$ select 1::bigint $$;
create function auth.role() returns text language sql as $$ select null::text $$;
create table public.workout_sessions(id uuid primary key, ended_at timestamptz, processing_status text, metrics_version int);
create table public.workout_processing_jobs(
 id uuid primary key, workout_id uuid not null references public.workout_sessions(id),
 job_type text not null, status text not null, attempt_count int not null default 0,
 started_at timestamptz, finished_at timestamptz, error_message text, created_at timestamptz not null default now()
);
