# Site Pulse

Site Pulse is a construction-site tracking app for supervisors and project managers. It is built with Flutter for Android and Firebase Authentication and Cloud Firestore, and it continues to work offline.

## Features

- Sign in with a supervisor or project manager role.
- Supervisors can record attendance, log material usage with low-stock alerts, report safety incidents, and manage the worker roster by adding or soft-removing workers.
- The supervisor home screen shows recent attendance, material, and incident activity.
- Supervisor screens include a profile, Pending/Synced status, a sync-failure banner, and an offline banner.
- Project managers have a multi-site dashboard with site and date filters, attendance rates, low-stock counts, and incident counts.
- Site detail has Attendance, Materials, and Incidents tabs. Attendance includes week and month views, a chart, and a per-day list.
- Pull-to-refresh is available on the PM dashboard and site-detail views.
- Both roles have bottom navigation. Supervisors have Home, Roster, and Profile; project managers have Home and Profile.

## Tech stack

- Flutter for Android; the Flutter SDK version is not pinned in `pubspec.yaml`.
- Dart SDK constraint: `^3.13.5`.
- Riverpod: `flutter_riverpod ^3.4.3`.
- Routing: `go_router ^18.1.1`.
- Firebase: `firebase_core ^5.1.0`, `firebase_auth ^7.0.1`, and `cloud_firestore ^7.1.0`.
- Other Flutter packages: `connectivity_plus ^7.3.2`, `uuid ^4.6.0`, and `intl ^0.20.3`.
- Seed scripts use Node.js and `firebase-admin ^12.0.0`.
- Firestore security rules are tested with `@firebase/rules-unit-testing ^3.0.4` and `mocha ^10.7.3`.

## Architecture

```text
UI screens
    |
Riverpod providers
    |
Repository interfaces
    |
Firestore implementations
    |
Cloud Firestore (guarded by firestore.rules)
```

Folder map:

```text
lib/
  core/widgets/              Shared UI widgets
  data/models/               App and Firestore data models
  data/repositories/         Repository interfaces and Firestore implementations
  data/providers.dart        Riverpod providers
  features/auth/             Sign-in and authentication state
  features/supervisor/       Supervisor screens
  features/pm/               Project manager screens
  router.dart                Role-based routes and navigation
test/
  core/, data/, features/    Widget, model, and repository tests
  integration/               Acceptance test
  support/fakes/             In-memory test repositories
  support/test_overrides.dart Repository overrides for tests
rules-tests/                 Firestore security rules tests
scripts/                     Seed and read-only evidence scripts
```

## Key design decisions

- Firestore writes are not awaited by UI actions. The app reports that data is saved on the device while offline and reports write failures separately.
- Material usage writes use a `WriteBatch` with `FieldValue.increment`, not a transaction, to record the log and update stock together.
- Attendance document IDs are deterministic: `siteId_workerId_yyyymmdd`. This gives each worker at a site one attendance record per day.
- `dateKey` is a local calendar date stored as a sortable `yyyy-MM-dd` string, avoiding timezone shifts in date filtering.
- Event timestamps are client timestamps. Server timestamps can be null while a device is offline.
- Workers are soft-removed by setting `active` to false. Incidents are immutable after creation.
- Security rules scope supervisors to their assigned site and allow project managers to read across sites. Date filtering uses `dateKey`; the documented queries do not require composite indexes.

## Prerequisites and setup

Install Flutter, Android Studio with an Android emulator, Java for the Firestore emulator and rules tests, Node.js 18 or newer, and the Firebase CLI.

The Firebase configuration files are already in the repository: `firebase.json`, `android/app/google-services.json`, and `lib/firebase_options.dart`.

| Step | Command |
| --- | --- |
| Clone the repository | `git clone https://github.com/kalviumcommunity/S131_SitePulse_kalvium-Community.git` |
| Enter the project | `cd S131_SitePulse_kalvium-Community` |
| Get Flutter packages | `flutter pub get` |
| Install seed-script packages | `npm install --prefix scripts` |
| Install rules-test packages | `npm install --prefix rules-tests` |

## Running the app

For the real Firebase backend, connect an Android device or emulator and run:

| Purpose | Command |
| --- | --- |
| Run against Firebase | `flutter run` |
| Start the local Auth and Firestore emulators | `firebase emulators:start --only auth,firestore` |
| Run against emulators on the Android emulator | `flutter run --dart-define=USE_EMULATOR=true` |
| Build a release APK | `flutter build apk --release` |

Emulator mode is enabled only in debug builds. The Android emulator connects to Auth at `10.0.2.2:9099` and Firestore at `10.0.2.2:8080`. See `docs/DEV.md` for the emulator workflow. The production app uses Firebase repositories.

## Test accounts

These are demo accounts created by the seed scripts. All use the shared password `SitePulse#2026`. The default profile includes the PM and the first three supervisors; the full profile adds the last two supervisors.

| Role | Email | Assigned site/profile |
| --- | --- | --- |
| Project manager | `pm@sitepulse.test` | All sites |
| Supervisor | `sup1@sitepulse.test` | Metro Rail Station 4B (`site_metro`) |
| Supervisor | `sup2@sitepulse.test` | Harbor Terminal I (`site_harbor`) |
| Supervisor | `sup3@sitepulse.test` | Highway 101 Overpass (`site_highway`) |
| Supervisor | `sup4@sitepulse.test` | Pune Hinjawadi IT Park Phase 3 (`site_pune`), full profile only |
| Supervisor | `sup5@sitepulse.test` | Jaipur Solar Park Expansion (`site_jaipur`), full profile only |

The seed documentation does not list a separate special account.

## Seed data

The default seed creates or updates the PM, three supervisors, and three sites, with workers and recent attendance, material logs, and incidents. The full profile contains five sites, 30 days of attendance and material logs, low-stock examples, a stale site, and incidents across all severities.

Only the repository owner should run the seed script. Use a demo Firebase project or emulator. The `--reset` option deletes documents in the seeded site subcollections for the selected profile. Keep the service-account key outside the repository and never commit it.

For the full profile on a live demo project, set the credential path in PowerShell and run from the repository root:

| Purpose | PowerShell command |
| --- | --- |
| Seed the full demo profile | `$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account.json"`<br>`node scripts/seed.js --reset --profile=full` |

For emulator seeding, start the emulators first, set their host variables, and run the default seed:

| Purpose | PowerShell command |
| --- | --- |
| Seed Auth and Firestore emulators | `$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"`<br>`$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"`<br>`node scripts/seed.js` |

## Testing

Run all Flutter checks and the Firestore rules suite. All tests must pass. The acceptance test is `test/integration/acceptance_test.dart`. Widget and repository tests use in-memory repositories from `test/support/fakes`.

| Test or check | Command |
| --- | --- |
| Analyze Dart code | `flutter analyze` |
| Run Flutter tests | `flutter test` |
| Run the acceptance test | `flutter test test/integration/acceptance_test.dart` |
| Run Firestore rules tests | `firebase emulators:exec --only firestore "npm test --prefix rules-tests"` |
| Check incident completeness (from `scripts/`) | `node .\check-incidents.js` |
| Count site documents and check material stock (from `scripts/`) | `node .\count-docs.js` |
| Count attendance for a date (from `scripts/`) | `node .\count-docs.js --date 2026-10-28` |

The evidence scripts read Firebase data; configure credentials or emulator host variables as described in `scripts/README.md`.

## Security

- Supervisors can read data for their assigned site and can write only to the site records and fields permitted by the rules.
- Project managers can read across sites but cannot write site or subcollection data.
- Material stock updates must keep `currentStock` at zero or above.
- Attendance writes must use `present`, `absent`, or `half`.
- Incidents can be created with a valid severity and description, but cannot be updated or deleted.

The rules are covered by the tests in `rules-tests/test.js`.

## Known limitations

- Android only.
- The first sign-in requires a network connection. Firestore data can then be cached for offline use.
- Photo attachments and push notifications are not implemented.
- The PM site list is limited to 50 sites per query.
- The app does not offer edit-after-save flows for materials or incidents. Rules also reject incident updates; material updates are restricted to `currentStock`.
- Pending offline writes are stored on the device and can be lost if app data is cleared before synchronization.

## Project structure for contributors

- Create feature branches from `Dev`, open pull requests into `Dev`, and merge `Dev` into `main` only for a release.
- Data lane: work in `data/models/`, `data/repositories/`, and `data/providers.dart`; keep Firestore access in repositories.
- UI lane: work in `features/`, use Riverpod providers, and coordinate repository-interface changes with the data lane.

## Team and course context

Team members: [add team names]. Course: [add course name].
