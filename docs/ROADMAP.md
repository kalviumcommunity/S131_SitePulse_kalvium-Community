# Site Pulse — 1-Day Full Roadmap & Architecture Guide 🚀

> **Target Goal:** Complete the entire Frontend scope of **Site Pulse** in 1 day (10 PRs).  
> **Role:** Frontend Engineer (Mobile UI, Flutter, Riverpod, GoRouter, Offline-first UI).  
> **Backend Integration:** Runs against Fake in-memory repositories right now, with automated 100% plug-and-play parity when real Firebase Firestore is connected.

---

## 📚 Table of Contents
1. [Absolute Beginner Theory: The 0-to-1 Fundamentals](#1-absolute-beginner-theory-the-0-to-1-fundamentals)
2. [The Architecture & Data Flow (How It All Connects)](#2-the-architecture--data-flow-how-it-all-connects)
3. [File Tree & Ownership Map](#3-file-tree--ownership-map)
4. [The 1-Day 10-PR Roadmap (Step-by-Step Execution Plan)](#4-the-1-day-10-pr-roadmap-step-by-step-execution-plan)
5. [Deep Dive & Learnings for Each PR](#5-deep-dive--learnings-for-each-pr)
6. [Hard Rules & Golden Habits](#6-hard-rules--golden-habits)
7. [Git Workflow & PR Checklist](#7-git-workflow--pr-checklist)

---

## 1. Absolute Beginner Theory: The 0-to-1 Fundamentals

If you have never built a frontend or mobile app before, here is the plain-English breakdown of every concept used in this project:

### 🧩 A. What is Flutter and Dart?
- **Dart** is the programming language (similar to TypeScript, Java, or Python). It is strongly typed (e.g., `String`, `int`, `double`, `bool`) and supports async programming (`Future`, `Stream`).
- **Flutter** is Google's UI framework written in Dart. In Flutter:
  - **Everything is a Widget**: A button is a widget, text is a widget, layout padding is a widget, and an entire screen is a widget.
  - **StatelessWidget**: A widget that just displays information and never changes on its own (like an icon, a static label, or a simple card).
  - **StatefulWidget / ConsumerWidget**: A widget that holds dynamic data (e.g. text entered in an input field, a switch toggled on/off, or live data streamed from a database).

### 🖥️ B. Frontend vs. Backend vs. Database
In a standard app, you usually have:
1. **Frontend (You!)**: What runs on the user's phone screen. Buttons, text fields, lists, colors, cards, and snackbars.
2. **Backend**: The business logic and server. In Site Pulse, **there is NO custom Node.js/Python server**. Site Pulse uses **Serverless Firebase Authentication & Cloud Firestore**.
3. **Database (Cloud Firestore)**: A cloud database storing JSON-like documents organized into collections (`users`, `sites`, `workers`, `attendance`, `materials`, `materialLogs`, `incidents`).
4. **Offline Persistence (The Magic Key)**:
   - Construction sites often have **zero network / poor connectivity** (airplane mode or basement tunnels).
   - Normal apps crash or freeze with spinning loaders when there's no internet.
   - **Site Pulse is Offline-First**: Firestore caches data locally in SQLite/internal disk storage.
   - When a supervisor saves attendance offline, it writes **instantly to local disk**.
   - As soon as the phone catches 4G or Wi-Fi, Firestore **automatically synchronizes** the changes to the cloud in the background.

### ⚡ C. State Management: Riverpod
- **Why do we need it?** If user logs attendance on Screen A, how does the Supervisor Home Screen or Project Manager Dashboard know that the data changed without refreshing the whole app?
- **Riverpod** is the state management tool for Flutter:
  - It creates **Providers** (global access points to data and business logic).
  - When data updates, Riverpod tells only the widgets watching that data to redraw themselves efficiently.
  - In Site Pulse, all data is accessed via **StreamProviders** or repository providers defined in `lib/data/providers.dart`.

### 🔄 D. Streams & Reactive Programming
- A `Future` is a value that will arrive once (like an HTTP fetch).
- A `Stream` is an open pipe that sends values whenever something changes (like live chat messages or real-time database updates).
- In Site Pulse, all repositories return `Stream<List<Worker>>`, `Stream<List<Incident>>`, etc. This means your UI will automatically update on screen without you needing to press "refresh" or write manual polling timers!

---

## 2. The Architecture & Data Flow (How It All Connects)

Here is the mental model of how data moves from user finger-tap to database:

```
[ User Taps Button ] (e.g. Save Attendance)
        │
        ▼
[ Flutter UI Screen ] (lib/features/supervisor/attendance/...)
        │
        ▼ (Calls repository method via Riverpod provider)
[ AttendanceRepository ] (lib/data/repositories/attendance_repository.dart)
        │
        ├─► [ Local Device Storage / Memory Cache ]
        │     - Returns Document ID IMMEDIATELY (< 5ms)
        │     - Shows "Saved on this device" snackbar immediately
        │     - Sets `hasPendingWrites = true` (shows amber Pending SyncChip)
        │
        ▼ (Whenever online)
[ Cloud Firestore ] (Syncs in background)
        │
        ▼
[ hasPendingWrites becomes false ] (SyncChip automatically flips to green "Synced")
        │
        ▼
[ PM Dashboard updates in real time ]
```

### 🚫 The Most Critical Rule: NEVER `await` Firestore writes in the UI!
```dart
// ❌ BAD (App freezes forever if user is offline in a basement!)
await attendanceRepo.recordAttendance(entry);
showSuccessMessage();

// ✅ GOOD (Instant local save, works offline, catches errors asynchronously)
final docId = attendanceRepo.recordAttendance(entry);
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Saved on this device')),
);
```

---

## 3. File Tree & Ownership Map

```
lib/
├── main.dart                  # App bootstrap (Firebase init, Riverpod ProviderScope)
├── app.dart                   # MaterialApp.router configuration
├── router.dart                # [SHARED] GoRouter route paths & redirect rules
├── core/
│   ├── theme/
│   │   └── app_theme.dart     # [SHARED] Brown/amber primary, surface colors, Material 3
│   ├── constants/
│   │   └── thresholds.dart    # Pure business rules: isLowStock(), isHighSeverity()
│   ├── utils/                 # Formatters (dates, numbers)
│   └── widgets/               # [YOU OWN] Shared reusable UI components
│       ├── sync_chip.dart
│       ├── offline_banner.dart
│       ├── status_views.dart  # LoadingView, EmptyView, ErrorView
│       ├── quantity_stepper.dart
│       ├── severity_selector.dart
│       └── attendance_toggle.dart
├── data/                      # [PARTNER OWNS - DO NOT EDIT]
│   ├── models/                # AppUser, Site, Worker, AttendanceEntry, Material, etc.
│   ├── repositories/          # Interfaces (WorkerRepository, AttendanceRepository, etc.)
│   │   └── fakes/             # In-memory fake implementations seeded with sample data
│   └── providers.dart         # Riverpod providers for all repositories
└── features/                  # [YOU OWN] All screens and feature widgets
    ├── auth/                  # Login screen, role-based redirection
    ├── supervisor/
    │   ├── home/              # Supervisor home dashboard & recent activity feed
    │   ├── roster/            # Worker list, add worker, remove worker (soft-delete)
    │   ├── attendance/        # Daily attendance grid, toggles, save
    │   ├── material/          # Log material usage, stock calculation, threshold alert
    │   └── incident/          # Incident form, severity picker, escalation banner
    └── pm/
        ├── dashboard/         # Project manager cross-site overview, site cards, flags
        └── site_detail/       # Single site drill-down (Attendance, Materials, Incidents)
```

---

## 4. The 1-Day 10-PR Roadmap (Step-by-Step Execution Plan)

Target timeline for completing in 1 day (estimated 12-16 hours of active coding with AI assistance):

| PR # | Branch Name | Focus Area | Depends On | Est. Time |
|---|---|---|---|---|
| **PR 1** | `feat/shared-widgets` | 6 Reusable core widgets & widget tests | Nothing | 1.5 hrs |
| **PR 2** | `feat/login-role-routing` | Login screen & GoRouter role redirection | Nothing | 1.5 hrs |
| **PR 3** | `feat/supervisor-roster` | Site worker roster & add/remove actions | PR 1 | 1.5 hrs |
| **PR 4** | `feat/supervisor-attendance` | Daily attendance entry & instant offline save | PR 1 & 3 | 2.0 hrs |
| **PR 5** | `feat/supervisor-material` | Material usage logging & low-stock warning | PR 1 | 1.5 hrs |
| **PR 6** | `feat/supervisor-incident` | Incident reporting & high-severity warning | PR 1 | 1.5 hrs |
| **PR 7** | `feat/supervisor-home` | Supervisor Home screen & combined activity feed | PR 3-6 | 2.0 hrs |
| **PR 8** | `feat/pm-dashboard` | PM multi-site dashboard with filters & flags | PR 1 | 2.5 hrs |
| **PR 9** | `feat/pm-site-detail` | PM single site 3-tab deep drill-down | PR 8 | 1.5 hrs |
| **PR 10** | `feat/ui-polish-tests` | Small screen polish, 48dp targets, integration tests | All | 1.5 hrs |

---

## 5. Deep Dive & Learnings for Each PR

### 🟢 PR 1: Shared Widgets (`feat/shared-widgets`)
- **What is built:**
  1. `SyncChip`: Amber clock pill ("Pending") or green checkmark pill ("Synced").
  2. `OfflineBanner`: Yellow banner at top of screen listening to `connectivity_plus`.
  3. `LoadingView`, `EmptyView`, `ErrorView`: The 3 universal states every screen needs.
  4. `QuantityStepper`: Big `[-]` and `[+]` buttons with number in the middle (48dp+ tap targets).
  5. `SeveritySelector`: 4 buttons (Minor, Moderate, High, Critical) with icons and color coding.
  6. `AttendanceToggle`: 3-way toggle (Present / Half-day / Absent) mapped to `AttendanceStatus`.
- **Key Theory Learned:**
  - Component reusability: building small, isolated UI pieces first makes later screens take 10 minutes instead of hours.
  - Widget testing with `WidgetTester`, `find.byType`, and `pumpWidget`.

### 🟢 PR 2: Login Screen & Role Routing (`feat/login-role-routing`)
- **What is built:**
  1. Login UI with email and password fields, show/hide password toggle, validation, loading spinner.
  2. `lib/router.dart` redirection:
     - Not logged in $\rightarrow$ `/login`
     - Role == `supervisor` $\rightarrow$ `/supervisor/home`
     - Role == `pm` $\rightarrow$ `/pm/dashboard`
     - Guard rails: supervisor attempting to visit `/pm/*` gets automatically bounced to `/supervisor/home`.
- **Key Theory Learned:**
  - GoRouter's `redirect` callback: reads the auth state and ensures users only see their authorized role.

### 🟢 PR 3: Supervisor Worker Roster (`feat/supervisor-roster`)
- **What is built:**
  1. List of active workers for the supervisor's site (`watchWorkers(siteId)`).
  2. Top search bar filtering by worker name or code.
  3. Floating "Add Worker" dialog/form (Name, unique code, trade).
  4. Remove worker dialog (soft delete: sets `active = false`).
- **Key Theory Learned:**
  - Soft delete: why construction apps never hard-delete workers (past attendance records must still reference them!).
  - Form validation with `GlobalKey<FormState>`.

### 🟢 PR 4: Supervisor Attendance Entry (`feat/supervisor-attendance`)
- **What is built:**
  1. Date picker (default today).
  2. Present / Half-day / Absent live counters updating in real-time as toggles flip.
  3. List of active workers with `AttendanceToggle` and `SyncChip`.
  4. "Save Attendance" bottom bar button: calls `recordBulkAttendance`, shows instant snackbar, never awaits.
  5. Pre-populating existing marks if reopening an already-marked date.
- **Key Theory Learned:**
  - Deterministic document IDs: `siteId_workerId_yyyymmdd` guarantees no duplicate records even if saved multiple times offline!
  - Bulk optimistic writes.

### 🟢 PR 5: Supervisor Material Usage (`feat/supervisor-material`)
- **What is built:**
  1. Dropdown of site materials.
  2. Live stock preview: "Current: 100 bags | Projected Remaining: 85 bags".
  3. `QuantityStepper` capped at `currentStock` (cannot select $> currentStock$ or $\le 0$).
  4. Low-stock alert banner at top using `isLowStock(material)`.
  5. Recent material logs history list with `SyncChip`.
- **Key Theory Learned:**
  - Pure functions for business logic: never hardcode numbers; import `isLowStock()` from `thresholds.dart`.

### 🟢 PR 6: Supervisor Safety Incident (`feat/supervisor-incident`)
- **What is built:**
  1. `SeveritySelector` (Minor, Moderate, High, Critical).
  2. Description box with min 10 characters counter.
  3. High/Critical escalation warning banner using `isHighSeverity(severity)`.
  4. Submit confirmation dialog: "This record cannot be edited after submitting".
  5. Recent incidents feed (read-only, immutable).
- **Key Theory Learned:**
  - Immutability in compliance/safety: why incidents can never be edited or deleted once recorded.

### 🟢 PR 7: Supervisor Home (`feat/supervisor-home`)
- **What is built:**
  1. Header with site name, `OfflineBanner`, and user profile info.
  2. 3 Big touch action cards: Attendance, Material Usage, Incident Report.
  3. "Manage Site Worker Roster" button.
  4. Recent Activity Feed: combines the latest 10 items across attendance, material logs, and incidents sorted by date.
- **Key Theory Learned:**
  - Stream merging / combining with Rx or Riverpod to unify 3 different collections into 1 consolidated feed.

### 🟢 PR 8: Project Manager Dashboard (`feat/pm-dashboard`)
- **What is built:**
  1. Top filters: Site selector (All Sites or specific site) and Date Range picker.
  2. Summary Metric Cards: Total workers present %, Sites with low stock count, High-severity incident count.
  3. Site Cards List: Each card displays site name, last synced time ("X min ago", amber if >24 hrs), crew count, material status badge, incident badge.
  4. Tapping a site card navigates to `/pm/site/:siteId`.
- **Key Theory Learned:**
  - Cross-site data aggregation and real-time dashboard calculations.

### 🟢 PR 9: PM Site Detail Drill-Down (`feat/pm-site-detail`)
- **What is built:**
  1. Top app bar with site name and date range filter.
  2. 3 Tabs:
     - Tab 1: Attendance History (dates list, tap date to view worker breakdown).
     - Tab 2: Materials (current stock vs threshold, usage history logs).
     - Tab 3: Incidents (severity badges, description, timestamp).
  3. Read-only design (no edit/delete buttons for PM).
- **Key Theory Learned:**
  - TabBar & TabBarView in Flutter with cached offline queries.

### 🟢 PR 10: UI Polish & Acceptance Tests (`feat/ui-polish-tests`)
- **What is built:**
  1. Large font & small screen layout audit (preventing yellow/black overflow bars).
  2. Touch target audit (ensuring all buttons are at least 48x48 dp).
  3. Complete end-to-end integration test: Login as supervisor $\rightarrow$ Mark attendance $\rightarrow$ Verify instant pending chip $\rightarrow$ Offline toggle test.
- **Key Theory Learned:**
  - Accessibility & field durability: construction workers wear gloves and work under direct sunlight; touch targets and high-contrast labels are mandatory.

---

## 6. Hard Rules & Golden Habits

1. **Every screen must handle 4 states**:
   - `loading`: Show `LoadingView()` or `CircularProgressIndicator`.
   - `empty`: Show `EmptyView(message, ctaLabel, onCta)` with an action to add the first item.
   - `error`: Show `ErrorView(message, onRetry)` with a retry button.
   - `offline`: Show `OfflineBanner()` at the top.
2. **Every list item displays a `SyncChip`**:
   - Reads `entry.hasPendingWrites`. If `true` $\rightarrow$ Amber "Pending"; if `false` $\rightarrow$ Green "Synced".
3. **Never write raw Firestore calls in UI**:
   - Always call the repository method provided by Riverpod (`ref.read(attendanceRepositoryProvider)`).
4. **Always clean up stream controllers & subscriptions**:
   - When using `StreamSubscription` in a `StatefulWidget`, always call `.cancel()` in `dispose()`.
5. **Run the quality check before committing**:
   ```bash
   flutter analyze
   flutter test
   ```

---

## 7. Git Workflow & PR Checklist

For every single task:
```bash
# 1. Ensure dev is clean and updated
git checkout dev
git pull origin dev

# 2. Branch for the specific task
git checkout -b feat/<task-name>

# 3. Work, make atomic commits (3 to 6 commits per PR)
git add <modified-files>
git commit -m "feat(<scope>): description"

# 4. Verify quality
flutter analyze
flutter test

# 5. Push and open PR
git push -u origin feat/<task-name>
```
