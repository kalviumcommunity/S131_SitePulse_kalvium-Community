# Sync status

- Read `syncStatusRepositoryProvider` from `lib/data/providers.dart` with Riverpod.
- Its `SyncStatusRepository` exposes `writeFailures`, `pendingCount`, and `allSynced`.
- `writeFailures` emits the current list of `WriteFailure` values and each update.
- Each `WriteFailure` has `collection`, `documentId`, `message`, and `time`.
- Call `clearWriteFailures()` after the user acknowledges or clears the failure list.
- `pendingCount` counts this supervisor's pending attendance, material logs, and incidents from the last seven calendar days.
- `allSynced` updates on Firestore snapshots-in-sync and is true when the pending count is zero.
- Use stream builders/providers to render loading, error, offline, and current sync states.
