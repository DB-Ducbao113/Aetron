# Aetron physical iPhone smoke test

## Reproduction

Use the current source, existing app bundle, and a physical iPhone connected
by USB. Do not restart or reinstall the app during an active workout.
Build using the repository launch script with the existing Dart defines:

```sh
./run.sh -d DEVICE_UDID --profile --no-pub --device-connection attached --no-resident --dart-define=AETRON_DEVICE_SMOKE=true
```

If Flutter cannot attach after the build succeeds, stop that run and install
the freshly built app without uninstalling its data container:

```sh
xcrun devicectl device install app --device DEVICE_UDID build/ios/iphoneos/Runner.app
python3 tool/iphone_profile_smoke.py --udid DEVICE_UDID --restart
```

The helper requires a fresh report, checks all seven probes, and distinguishes
PASS, BLOCKED and FAIL. Diagnostics are opt-in and disabled in release builds.
The scratch Isar database is separate from the actual workout cache. Only
aggregate data is reported, without coordinates, credentials or user IDs.

## Observed result — 2026-11-21

Physical iPhone 15 Pro Max, iOS 26.6, Aetron 1.0.1+2, AOT profile.
Report started 2026-11-21T08:25:03.868357Z.

| Probe | Result |
| --- | --- |
| Live Isar reads | PASS; 12 cached workouts |
| Isar scratch write/close/reopen/read | PASS |
| Native CMPedometer channel | PASS; permission, cadence, history available |
| Native historical interval | PASS; valid interval |
| Location permission | PASS; always |
| Fresh location fix | PASS; OS-reported horizontal accuracy 7 m |
| Authenticated Supabase bounded workout read | PASS |

Seven of seven passed, no blocked probes. Production read-only aggregate:
40 completed processing jobs, 0 active or failed jobs, dispatcher active,
28 workouts and 17,777 raw GPS points.

The location accuracy value is an OS estimate, not measured error against
ground truth. The historical step probe verifies API response, not step
accuracy. The scratch data is synthetic and never uploaded.
No new outdoor workout, counted-step comparison, auto-pause transition,
background recording, or device-to-server write path was exercised by this
smoke test. These require a real recording and corresponding ground truth.
