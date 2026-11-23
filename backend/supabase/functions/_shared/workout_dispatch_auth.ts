import { readJsonBody } from "./security.ts";

type WorkerName = "deterministic-finalize-worker" | "route-correction-worker";
type DispatchPayload = { job_id: string; workout_id: string; dispatch_nonce: string };
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const encoder = new TextEncoder();

// pg_net's queue can be read by database roles. Authenticate a short-lived
// signature bound to the worker, both IDs and single-use dispatch nonce.
export async function authorizedWorkoutDispatcher(
  request: Request,
  worker: WorkerName,
  expected: string | undefined,
  nowSeconds = Math.floor(Date.now() / 1000),
): Promise<DispatchPayload | null> {
  const timestamp = request.headers.get("X-Aetron-Worker-Timestamp") ?? "";
  const signature = request.headers.get("X-Aetron-Worker-Signature") ?? "";
  if (!expected || expected.length < 32 || !/^\d{10}$/.test(timestamp) ||
    !/^[0-9a-f]{64}$/.test(signature)) return null;
  const age = nowSeconds - Number(timestamp);
  if (age > 120 || age < -30) return null;
  try {
    const body = await readJsonBody(request, 2048) as Partial<DispatchPayload> | null;
    if (!body || typeof body.job_id !== "string" ||
      typeof body.workout_id !== "string" || typeof body.dispatch_nonce !== "string" ||
      !uuid.test(body.job_id) || !uuid.test(body.workout_id) || !uuid.test(body.dispatch_nonce)) return null;
    const key = await crypto.subtle.importKey("raw", encoder.encode(expected),
      { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
    const bytes = Uint8Array.from(signature.match(/../g)!, (pair) => parseInt(pair, 16));
    const message = encoder.encode([worker, body.job_id, body.workout_id, body.dispatch_nonce, timestamp].join("\n"));
    return await crypto.subtle.verify("HMAC", key, bytes, message)
      ? { job_id: body.job_id, workout_id: body.workout_id, dispatch_nonce: body.dispatch_nonce } : null;
  } catch {
    return null;
  }
}
