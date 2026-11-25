# Physical iPhone recording integration test — 2026-11-21

Device: iPhone 15 Pro Max, iOS 26.6; Aetron 1.0.1+2, profile build, USB.
Diagnostic run 20261121-physical-01 used the production recording notifier,
real device sensors, Isar and authenticated Supabase. No injected GPS or steps.
The run tested recording behavior, not a measured walking course or step ground truth.

## Observed outcome

- Start, manual pause, checkpoint, frozen pause timer, resume and stop: passed.
- Recorded 45 active seconds, 100 detected steps, 7 moving seconds and 7.600094 m client distance.
- Local workout saved and synced; zero unsynced GPS/step rows for this session.
- Local GPS 19 rows, 18 distinct normalized sample keys; server GPS 18 rows.
- After normalization to millisecond timestamps and seven decimal coordinate places,
  no local-only or cloud-only GPS keys remained (18 matching keys).
- Local and cloud raw step interval counts: 100 each. Counts alone do not establish interval-by-interval equality.
- Deterministic finalization completed on attempt one; client_finalized, metrics version 2.
- Server canonical distance 2 m, client claim 7.600094 m preserved in research archive.
  Reconciliation rejected segmented GPS+step claim with reason
  mixed_or_step_claim_not_corroborated_archive_preserved. Raw validation was unverified.
- Automatic pause did not activate in sampled states. Its correctness under known
  movement/stop transitions remains unverified. No controlled background test was run.

## Reproduction

The one-shot diagnostic is enabled only in non-release physical iOS builds by an
explicit fresh AETRON_RECORDING_TEST_ID. It creates a genuine diagnostic workout
in the signed-in account. Do not run during an active workout. Keep the phone
unlocked, foregrounded, and connected while recording and polling the result.

Build using `./run.sh --build-ios-only --profile --no-pub --dart-define=AETRON_RECORDING_TEST_ID=FRESH_ID`.
Install the built app with devicectl without uninstalling. Launch once and read
Documents/aetron-recording-FRESH_ID.json. Marker prevents duplicate starts.
The raw GPS audit test uses an exported Isar snapshot and GPS keys from the same
cloud session, with private temporary files; emits aggregate comparison only.

This test verifies integration and persistence, not algorithmic accuracy.
Do not interpret detected steps as manually counted reference steps.
