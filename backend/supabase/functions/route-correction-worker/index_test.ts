import { routeCorrectionReady, routeMatchingAvailable } from "./index.ts";

Deno.test("route correction requires completed deterministic job and published server metrics", () => {
  const finalized = {
    processing_status: "client_finalized",
    metrics_version: 2,
  };
  if (!routeCorrectionReady(finalized, "completed")) {
    throw new Error("Valid dependency rejected");
  }
  for (const status of ["queued", "running", "failed", undefined]) {
    if (routeCorrectionReady(finalized, status)) {
      throw new Error("Premature route correction");
    }
  }
  for (
    const row of [
      { ...finalized, processing_status: "client_finished_pending_processing" },
      { ...finalized, metrics_version: 1 },
    ]
  ) {
    if (routeCorrectionReady(row, "completed")) {
      throw new Error("Unpublished audit accepted");
    }
  }
});

Deno.test("stub and unsupported adapters cannot report map matching confidence", () => {
  for (const provider of ["stub", "osrm", "valhalla", ""]) {
    if (routeMatchingAvailable(provider)) {
      throw new Error("Unimplemented matching adapter selected");
    }
  }
});
