import { authorizedWorkoutDispatcher } from "./workout_dispatch_auth.ts";

const secret = "local-test-fixture-" + "x".repeat(32);
const worker = "deterministic-finalize-worker";
const jobId = "63000000-0000-4000-8000-000000000011";
const workoutId = "63000000-0000-4000-8000-000000000001";
const nonce = "63000000-0000-4000-8000-000000000021";
const now = 1795136400;
function request(headers: Record<string, string> = {}, workout = workoutId, dispatchNonce = nonce): Request {
  return new Request("https://fixture.invalid", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify({ job_id: jobId, workout_id: workout, dispatch_nonce: dispatchNonce }),
  });
}
function check(value: boolean, expected: boolean) {
  if (value !== expected) throw new Error("Unexpected dispatcher authorization");
}
Deno.test("HMAC binds the worker, job and workout; expires and fails closed", async () => {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const digest = new Uint8Array(await crypto.subtle.sign("HMAC", key,
    new TextEncoder().encode([worker, jobId, workoutId, nonce, now].join("\n"))));
  const headers = {
    "X-Aetron-Worker-Timestamp": String(now),
    "X-Aetron-Worker-Signature": Array.from(digest, (b) => b.toString(16).padStart(2, "0")).join(""),
  };
  const valid = await authorizedWorkoutDispatcher(request(headers), worker, secret, now);
  check(valid?.job_id === jobId && valid.workout_id === workoutId && valid.dispatch_nonce === nonce, true);
  check(!!await authorizedWorkoutDispatcher(request(), worker, secret, now), false);
  check(!!await authorizedWorkoutDispatcher(request({ Authorization: "Bearer " + secret, apikey: secret }), worker, secret, now), false);
  check(!!await authorizedWorkoutDispatcher(request(headers), worker, undefined, now), false);
  check(!!await authorizedWorkoutDispatcher(request(headers), worker, secret, now + 121), false);
  check(!!await authorizedWorkoutDispatcher(request(headers), worker, secret, now - 31), false);
  check(!!await authorizedWorkoutDispatcher(request(headers), "route-correction-worker", secret, now), false);
  check(!!await authorizedWorkoutDispatcher(request(headers, jobId), worker, secret, now), false);
  check(!!await authorizedWorkoutDispatcher(request(headers, workoutId, jobId), worker, secret, now), false);
  check(!!await authorizedWorkoutDispatcher(request({ ...headers, "X-Aetron-Worker-Timestamp": String(now - 1) }), worker, secret, now), false);
  check(!!await authorizedWorkoutDispatcher(request(headers), worker, secret + "x", now), false);
});
