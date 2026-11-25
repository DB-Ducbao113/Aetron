# Aetron — Local storage reliability and data integrity

Scope: Isar workout storage and synchronization; no change to GNSS, IOD, stride, or calorie algorithms. Isar 3.1.0+1 and existing collections/schema IDs are retained.

## Changes

- Sign-out/account switching no longer deletes offline workouts. Explicit account/workout deletion remains a distinct action. Repository detail, cache, delete, upload and raw tracking operations check the owner and active account, and the route provider rejects raw fallback when detail access is denied. This is app-level account isolation, not per-account encryption at rest.
- Mobile recording completion requires successful persistence of pending raw GPS/step writes and the finalized local workout. Failed writes retain the frozen session/UUID and retry; no false finished status. Raw writes are tracked independently of cloud upload buffers. The in-memory retry queue is not a durable journal across process death.
- Summary checkpoints run every five seconds after meaningful progress, also on pause, with serialized writes and a sealed final-write ordering. Checkpoints carry `recording_checkpoint:true`, do not upload as finalized workouts, and remain available for explicit recovery or discard after interruption. The five-second interval is an engineering policy, not a guaranteed maximum crash-loss bound or scientific threshold.
- All production Isar opens use `relaxedDurability:false`. Recovery preserves the original backup, attempts to read a scratch copy, and restores all three collections in one destination transaction only if empty. A genuinely unreadable backup cannot be automatically recovered; historical backups are not replayed indiscriminately.
- Remote history uses stable ID-based pagination, owner checks, and non-destructive reconciliation. An absent row in filtered/paginated history alone does not authorize deletion. Unsynced local snapshots survive a conflicting remote row. Pending raw uploads require an owned workout. Sync acknowledgement compares stored values (including UTC instants and serialized GPS/lap payloads), not reconstructed object identity. UUID collisions across accounts and stale checkpoint overwrites are rejected in the Isar transaction.

## Validation

- `flutter analyze --no-pub`: zero issues.
- Targeted storage/recording/account/sync/Isar/IOD regression run: **53 passed, 1 optional CIOD replay skipped, 0 failures**. Actual temporary macOS Isar databases and mocked Supabase transport; no live cloud mutation. Readable-backup test verifies all three collections, unchanged source bytes, and rejection of recovery into a nonempty destination. Injected disk/network failures, pagination, account switch during upload, partial history and checkpoint retry covered.
- Full suite after final changes: **707 passed, 13 failed, 3 skipped**. Nonzero exit; all 13 reported failures are missing-fixture assertions in earlier GPS benchmarks (10) or device/backup inspections (3). The tests were not disabled or rewritten to hide those failures.
- Missing inputs confirmed: `exports/research_7_sessions/aetron_7_new_sessions_raw.csv`, `exports/aetron_raw_gps_combined.csv`, `exports/research_7_sessions/ios_device_backup_20261105`, `/tmp/iphone_live_check/Documents/default.isar`, `/tmp/iphone_post_launch/Documents/default.isar`.
- `git diff --check`: clean. No commit, push, deploy, device database modification, or destructive migration.

## Remaining validation and limitations

Native iOS/Android force-kill/restart, disk-full handling, real cloud end-to-end synchronization, old database migration, unrecoverable corruption, and long-session write latency/storage-size benchmarks have not been established by this run. Process death may lose uncommitted sensor samples and the latest checkpoint; a corrupt file may require manual recovery. Remote deletions on another device need an explicit authoritative deletion protocol before safe cache eviction; absent synced entries can remain in offline cache. Logout retains account data on disk, so application ownership checks are required; encryption and backup-retention policy remain separate tasks. The result is a verified software-level reliability improvement, not a guarantee of zero data loss or production release readiness.
