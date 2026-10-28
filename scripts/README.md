# SitePulse Seed Scripts

Idempotent seed scripts for Firebase Authentication and Cloud Firestore for the SitePulse application.

## Prerequisites

- Node.js (v18+)
- Install dependencies:
  ```bash
  cd scripts
  npm install
  ```

## Authentication & Configuration

The script uses the Firebase Admin SDK for project `sitepulse-6245f`.

### Option 1: Firebase Emulators (Recommended for local dev)
Ensure the Firestore and Auth emulators are running, and set the environment variables:
```bash
# Windows PowerShell
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"

# Linux / macOS
export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
```

### Option 2: Live Firebase Project
Point `GOOGLE_APPLICATION_CREDENTIALS` to your service account key file:
```bash
# Windows PowerShell
$env:GOOGLE_APPLICATION_CREDENTIALS="path\to\service-account.json"

# Linux / macOS
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account.json"
```

## Running the Seed Script

### Standard Seed (Idempotent)
Creates or updates users, sites, workers, materials, attendance (for the last 3 days), material logs, and incidents. Safe to run multiple times without creating duplicates.
```bash
node seed.js
# or
npm run seed
```

### Reset & Re-Seed
Deletes all documents in seeded subcollections (`workers`, `attendance`, `materials`, `materialLogs`, `incidents`) of the 3 sites, then re-seeds fresh data. Useful for resetting before a demo:
```bash
node seed.js --reset
# or
npm run seed:reset
```

## Evidence Scripts

Run these read-only scripts from the `scripts` directory after configuring Firebase credentials or the Firestore emulator as described above.

### Check Incident Completeness
Reads incidents under every site, reports totals and any invalid incident IDs, and exits with code 1 if it finds an incident missing a valid severity, a description of at least 10 characters, or an `occurredAt` timestamp.
```powershell
node .\check-incidents.js
```

### Count Documents and Check Material Stock
Reports counts for workers, attendance, material logs, and incidents per site, plus each material's current stock. Optionally limit attendance counts by its `dateKey`:
```powershell
node .\count-docs.js
node .\count-docs.js --date 2026-10-28
```

## Seeded Test Accounts

All accounts share the default password: **`SitePulse#2026`**

| Email | Role | Name | Assigned Site | Site ID |
|---|---|---|---|---|
| `pm@sitepulse.test` | `pm` | Priya Nair | *All Sites (PM)* | - |
| `sup1@sitepulse.test` | `supervisor` | Ramesh Yadav | Metro Rail Station 4B | `site_metro` |
| `sup2@sitepulse.test` | `supervisor` | Vikram Singh | Harbor Terminal I | `site_harbor` |
| `sup3@sitepulse.test` | `supervisor` | Sunil Verma | Highway 101 Overpass | `site_highway` |

## Data Overview

- **Sites**:
  - `site_metro` ("Metro Rail Station 4B"): Rebar stock below threshold (8 vs 15), 1 critical incident.
  - `site_harbor` ("Harbor Terminal I"): All materials normal, 0 incidents.
  - `site_highway` ("Highway 101 Overpass"): Portland Cement below threshold (18 vs 25), 1 minor incident.
- **Workers**: 12 active workers per site across trades (Mason, Carpenter, Electrician, Welder, Helper).
- **Attendance**: 36 entries per site spanning the last 3 days with a realistic ~90% present rate.
- **Timestamps**: All entries use client timestamps and track the newest entry on `sites/{siteId}.lastEntryAt`.
