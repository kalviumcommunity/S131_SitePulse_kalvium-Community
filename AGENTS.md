# Site Pulse - rules for AI agents

Stack: Flutter (Android only), Firebase Auth, Cloud Firestore (offline persistence), Riverpod, go_router. No custom backend.
Scope: the PRD only. Do not add features, screens or fields that are not in the PRD. Decisions are in DECISIONS.md.

## Layout
lib/core (theme, widgets, utils, constants) | lib/data (models, repositories) |
lib/features/{auth, supervisor/{home,attendance,material,incident,roster}, pm/{dashboard,site_detail}}
UI never calls Firestore directly; always go through a repository in lib/data/repositories.
snake_case files, one feature per folder.

## Data model
users/{uid} (role, name, siteId) | sites/{siteId} (name, lastEntryAt)
sites/{siteId}/workers | attendance (id: siteId_workerId_yyyymmdd) | materials | materialLogs | incidents

## Hard rules
- Never await Firestore writes in the UI (offline they never complete). Show "Saved on this device", attach catchError.
- Never use transactions. Use WriteBatch + FieldValue.increment.
- Never use a hardcoded or fallback site, worker or user id in lib/features or in the real repositories; ids come only from the signed-in user.
- Every document gets a client UUID or a deterministic ID, generated once when the form opens.
- Show sync state with snapshots(includeMetadataChanges: true) and metadata.hasPendingWrites.
- Cancel every stream subscription on dispose. Dashboard queries always filter by date and have a limit.
- Every screen needs loading, empty, error and offline states.
- Thresholds: low stock = currentStock <= lowStockThreshold; high severity = high or critical.
- Before finishing a task run: flutter analyze, flutter test. Report in 5 lines or fewer.