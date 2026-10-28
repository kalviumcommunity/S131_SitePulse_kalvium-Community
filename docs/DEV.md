# Development

## Run with the real Firebase backend

```powershell
flutter run --dart-define=USE_FAKES=false
```

## Run with the Firebase emulators

In the first PowerShell terminal, start Auth and Firestore:

```powershell
firebase emulators:start --only auth,firestore
```

In a second PowerShell terminal, seed the emulator data:

```powershell
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
node scripts/seed.js
```

Run the app in a third PowerShell terminal (Android emulator):

```powershell
flutter run --dart-define=USE_EMULATOR=true
```

## Run with in-memory fakes

```powershell
flutter run --dart-define=USE_FAKES=true
```

## Test accounts

| Account | Email | Password |
| --- | --- | --- |
| Supervisor 1 | `sup1@sitepulse.test` | `SitePulse#2026` |
| Supervisor 2 | `sup2@sitepulse.test` | `SitePulse#2026` |
| Supervisor 3 | `sup3@sitepulse.test` | `SitePulse#2026` |
| Project manager | `pm@sitepulse.test` | `SitePulse#2026` |
