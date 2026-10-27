/**
 * seed.js - Firestore & Firebase Auth seed script for SitePulse
 *
 * Usage:
 *   node seed.js         # Idempotent seed
 *   node seed.js --reset # Clears seeded subcollections for the 3 sites, then seeds
 */

const admin = require('firebase-admin');

// 1. Initialize Firebase Admin SDK
// Uses Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS) or emulator env vars.
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.FIREBASE_PROJECT_ID ||
  'sitepulse-6245f';

if (!admin.apps.length) {
  admin.initializeApp({
    projectId,
  });
}

const db = admin.firestore();
const auth = admin.auth();

const PASSWORD_ALL = 'SitePulse#2026';

// 2. Target definitions
const USER_DEFS = [
  {
    email: 'pm@sitepulse.test',
    password: PASSWORD_ALL,
    displayName: 'Priya Nair',
    role: 'pm',
    siteId: null, // PM has no siteId
  },
  {
    email: 'sup1@sitepulse.test',
    password: PASSWORD_ALL,
    displayName: 'Ramesh Yadav',
    role: 'supervisor',
    siteId: 'site_metro',
  },
  {
    email: 'sup2@sitepulse.test',
    password: PASSWORD_ALL,
    displayName: 'Vikram Singh',
    role: 'supervisor',
    siteId: 'site_harbor',
  },
  {
    email: 'sup3@sitepulse.test',
    password: PASSWORD_ALL,
    displayName: 'Sunil Verma',
    role: 'supervisor',
    siteId: 'site_highway',
  },
];

const SITE_DEFS = [
  { id: 'site_metro', name: 'Metro Rail Station 4B' },
  { id: 'site_harbor', name: 'Harbor Terminal I' },
  { id: 'site_highway', name: 'Highway 101 Overpass' },
];

const TRADES = ['Mason', 'Carpenter', 'Electrician', 'Welder', 'Helper'];

const WORKER_NAMES = [
  'Aarav Sharma',
  'Deepak Patel',
  'Mohammad Ansari',
  'Rajesh Kumar',
  'Suresh Verma',
  'Amit Roy',
  'Manoj Paswan',
  'Santosh Gupta',
  'Vikash Bind',
  'Dinesh Yadav',
  'Arjun Mondal',
  'Kishan Lal',
];

// 3. Helper functions
function getDateInfo(daysAgo, hour = 9, minute = 0) {
  const d = new Date();
  d.setDate(d.getDate() - daysAgo);
  d.setHours(hour, minute, 0, 0);

  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');

  return {
    date: d,
    dateKey: `${yyyy}-${mm}-${dd}`,
    compact: `${yyyy}${mm}${dd}`,
    timestamp: admin.firestore.Timestamp.fromDate(d),
  };
}

class BatchManager {
  constructor(firestore) {
    this.firestore = firestore;
    this.currentBatch = firestore.batch();
    this.count = 0;
  }

  async set(ref, data, options) {
    if (options) {
      this.currentBatch.set(ref, data, options);
    } else {
      this.currentBatch.set(ref, data);
    }
    this.count++;
    if (this.count >= 400) {
      await this.commit();
    }
  }

  async delete(ref) {
    this.currentBatch.delete(ref);
    this.count++;
    if (this.count >= 400) {
      await this.commit();
    }
  }

  async commit() {
    if (this.count > 0) {
      await this.currentBatch.commit();
      this.currentBatch = this.firestore.batch();
      this.count = 0;
    }
  }
}

// 4. Create or update auth users & users collection
async function upsertUsers() {
  const userMap = {};

  for (const def of USER_DEFS) {
    let uid;
    try {
      const existing = await auth.getUserByEmail(def.email);
      uid = existing.uid;
      await auth.updateUser(uid, {
        displayName: def.displayName,
        password: def.password,
      });
    } catch (err) {
      if (err.code === 'auth/user-not-found') {
        const preferredUid = `uid_${def.email.split('@')[0]}`;
        const created = await auth.createUser({
          uid: preferredUid,
          email: def.email,
          password: def.password,
          displayName: def.displayName,
        });
        uid = created.uid;
      } else {
        throw err;
      }
    }

    const userData = {
      role: def.role,
      name: def.displayName,
      ...(def.siteId ? { siteId: def.siteId } : {}),
    };

    await db.collection('users').doc(uid).set(userData);
    userMap[def.email] = { uid, ...def };
  }

  return userMap;
}

// 5. Reset subcollections if --reset is passed
async function resetSubcollections() {
  console.log('Reset flag detected: deleting documents in site subcollections...');
  const subcollections = ['workers', 'attendance', 'materials', 'materialLogs', 'incidents'];
  const batchManager = new BatchManager(db);

  for (const site of SITE_DEFS) {
    const siteRef = db.collection('sites').doc(site.id);
    for (const sub of subcollections) {
      const snap = await siteRef.collection(sub).get();
      for (const doc of snap.docs) {
        await batchManager.delete(doc.ref);
      }
    }
  }
  await batchManager.commit();
  console.log('Reset complete.\n');
}

// 6. Main seed routine
async function main() {
  const isReset = process.argv.includes('--reset');
  console.log(`Starting SitePulse seed script (projectId: ${projectId})...`);

  if (process.env.FIRESTORE_EMULATOR_HOST) {
    console.log(`Using Firestore Emulator at ${process.env.FIRESTORE_EMULATOR_HOST}`);
  }
  if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    console.log(`Using Auth Emulator at ${process.env.FIREBASE_AUTH_EMULATOR_HOST}`);
  }

  // 1. Upsert users
  const users = await upsertUsers();
  const supervisorBySite = {
    site_metro: users['sup1@sitepulse.test'],
    site_harbor: users['sup2@sitepulse.test'],
    site_highway: users['sup3@sitepulse.test'],
  };

  // 2. Reset if requested
  if (isReset) {
    await resetSubcollections();
  }

  // 3. Prepare dates for last 3 days (relative to run date: day -2, day -1, today)
  const days = [
    getDateInfo(2, 8, 30),
    getDateInfo(1, 8, 30),
    getDateInfo(0, 8, 30),
  ];

  const batchManager = new BatchManager(db);

  // Statistics counters
  let totalWorkers = 0;
  let totalAttendance = 0;
  let totalMaterials = 0;
  let totalLogs = 0;
  let totalIncidents = 0;

  for (const site of SITE_DEFS) {
    const siteId = site.id;
    const supervisor = supervisorBySite[siteId];
    const siteRef = db.collection('sites').doc(siteId);

    let siteNewestTimestamp = days[0].timestamp;
    const trackNewest = (ts) => {
      if (!siteNewestTimestamp || ts.toMillis() > siteNewestTimestamp.toMillis()) {
        siteNewestTimestamp = ts;
      }
    };

    // A. 12 Workers per site
    const workers = [];
    for (let i = 1; i <= 12; i++) {
      const padNum = String(i).padStart(2, '0');
      const workerId = `w_${siteId}_${padNum}`;
      const workerCode = `W-${String(i).padStart(3, '0')}`;
      const name = WORKER_NAMES[(i - 1) % WORKER_NAMES.length];
      const trade = TRADES[(i - 1) % TRADES.length];

      const workerData = {
        name,
        trade,
        workerCode,
        active: true,
      };

      await batchManager.set(siteRef.collection('workers').doc(workerId), workerData);
      workers.push({ id: workerId, ...workerData });
      totalWorkers++;
    }

    // B. Attendance for last 3 days
    // Realistic mix (~90% present, some half, some absent)
    for (let dayIdx = 0; dayIdx < days.length; dayIdx++) {
      const dayInfo = days[dayIdx];
      for (let wIdx = 0; wIdx < workers.length; wIdx++) {
        const worker = workers[wIdx];
        const attendanceId = `${siteId}_${worker.id}_${dayInfo.compact}`;

        // Deterministic status pattern
        let status = 'present';
        if (dayIdx === 0 && wIdx === 3) {
          status = 'absent';
        } else if (dayIdx === 0 && wIdx === 8) {
          status = 'half';
        } else if (dayIdx === 1 && wIdx === 7) {
          status = 'half';
        } else if (dayIdx === 2 && wIdx === 11) {
          status = 'absent';
        }

        // Updated at client time
        const updateHour = 8 + Math.floor(wIdx / 4);
        const updateMin = (wIdx * 3) % 60;
        const entryTime = getDateInfo(2 - dayIdx, updateHour, updateMin).timestamp;
        trackNewest(entryTime);

        const attendanceData = {
          workerId: worker.id,
          status,
          dateKey: dayInfo.dateKey,
          updatedAt: entryTime,
          createdBy: supervisor.uid,
        };

        await batchManager.set(
          siteRef.collection('attendance').doc(attendanceId),
          attendanceData
        );
        totalAttendance++;
      }
    }

    // C. 4 Materials per site
    // Portland Cement (bags), 12mm Steel Rebar (bundles), Sand (tonnes), Bricks (pieces)
    // site_metro: Rebar BELOW threshold (8 vs 15)
    // site_harbor: all normal
    // site_highway: one low (Cement 18 vs 25)
    let materialConfigs;
    if (siteId === 'site_metro') {
      materialConfigs = [
        { id: 'mat_cement', name: 'Portland Cement', unit: 'bags', openingStock: 120, currentStock: 85, lowStockThreshold: 20 },
        { id: 'mat_rebar', name: '12mm Steel Rebar', unit: 'bundles', openingStock: 50, currentStock: 8, lowStockThreshold: 15 },
        { id: 'mat_sand', name: 'Sand', unit: 'tonnes', openingStock: 60, currentStock: 42, lowStockThreshold: 10 },
        { id: 'mat_bricks', name: 'Bricks', unit: 'pieces', openingStock: 6000, currentStock: 4500, lowStockThreshold: 1000 },
      ];
    } else if (siteId === 'site_harbor') {
      materialConfigs = [
        { id: 'mat_cement', name: 'Portland Cement', unit: 'bags', openingStock: 100, currentStock: 70, lowStockThreshold: 20 },
        { id: 'mat_rebar', name: '12mm Steel Rebar', unit: 'bundles', openingStock: 60, currentStock: 35, lowStockThreshold: 15 },
        { id: 'mat_sand', name: 'Sand', unit: 'tonnes', openingStock: 80, currentStock: 55, lowStockThreshold: 12 },
        { id: 'mat_bricks', name: 'Bricks', unit: 'pieces', openingStock: 8000, currentStock: 6200, lowStockThreshold: 1200 },
      ];
    } else {
      // site_highway (one low)
      materialConfigs = [
        { id: 'mat_cement', name: 'Portland Cement', unit: 'bags', openingStock: 100, currentStock: 18, lowStockThreshold: 25 },
        { id: 'mat_rebar', name: '12mm Steel Rebar', unit: 'bundles', openingStock: 45, currentStock: 28, lowStockThreshold: 12 },
        { id: 'mat_sand', name: 'Sand', unit: 'tonnes', openingStock: 50, currentStock: 32, lowStockThreshold: 10 },
        { id: 'mat_bricks', name: 'Bricks', unit: 'pieces', openingStock: 5000, currentStock: 3800, lowStockThreshold: 800 },
      ];
    }

    for (const mat of materialConfigs) {
      const matData = {
        name: mat.name,
        unit: mat.unit,
        openingStock: mat.openingStock,
        currentStock: mat.currentStock,
        lowStockThreshold: mat.lowStockThreshold,
      };
      await batchManager.set(siteRef.collection('materials').doc(mat.id), matData);
      totalMaterials++;
    }

    // D. Material logs (a few per site over the 3 days)
    const logsConfig = [
      {
        id: `log_${siteId}_${days[0].compact}_cement`,
        materialId: 'mat_cement',
        materialName: 'Portland Cement',
        qtyUsed: 15,
        remainingAfter: siteId === 'site_highway' ? 35 : 95,
        dayInfo: days[0],
        hour: 14,
        minute: 15,
      },
      {
        id: `log_${siteId}_${days[1].compact}_rebar`,
        materialId: 'mat_rebar',
        materialName: '12mm Steel Rebar',
        qtyUsed: siteId === 'site_metro' ? 12 : 5,
        remainingAfter: siteId === 'site_metro' ? 8 : 30,
        dayInfo: days[1],
        hour: 16,
        minute: 0,
      },
    ];

    if (siteId === 'site_metro') {
      logsConfig.push({
        id: `log_${siteId}_${days[2].compact}_sand`,
        materialId: 'mat_sand',
        materialName: 'Sand',
        qtyUsed: 8,
        remainingAfter: 42,
        dayInfo: days[2],
        hour: 15,
        minute: 30,
      });
    }

    for (const log of logsConfig) {
      const logTime = getDateInfo(
        2 - days.indexOf(log.dayInfo),
        log.hour,
        log.minute
      ).timestamp;
      trackNewest(logTime);

      const logData = {
        materialId: log.materialId,
        materialName: log.materialName,
        qtyUsed: log.qtyUsed,
        remainingAfter: log.remainingAfter,
        dateKey: log.dayInfo.dateKey,
        createdAt: logTime,
        createdBy: supervisor.uid,
      };

      await batchManager.set(siteRef.collection('materialLogs').doc(log.id), logData);
      totalLogs++;
    }

    // E. Incidents
    // site_metro: one critical (description >= 10 chars)
    // site_highway: one minor
    // site_harbor: none
    if (siteId === 'site_metro') {
      const incidentTime = getDateInfo(1, 10, 45).timestamp;
      trackNewest(incidentTime);
      const incData = {
        severity: 'critical',
        description: 'Scaffolding collapse near Platform 4B junction; area barricaded.',
        occurredAt: incidentTime,
        createdBy: supervisor.uid,
      };
      await batchManager.set(
        siteRef.collection('incidents').doc('inc_site_metro_01'),
        incData
      );
      totalIncidents++;
    } else if (siteId === 'site_highway') {
      const incidentTime = getDateInfo(0, 11, 20).timestamp;
      trackNewest(incidentTime);
      const incData = {
        severity: 'minor',
        description: 'Minor hydraulic hose leak from excavator; contained immediately.',
        occurredAt: incidentTime,
        createdBy: supervisor.uid,
      };
      await batchManager.set(
        siteRef.collection('incidents').doc('inc_site_highway_01'),
        incData
      );
      totalIncidents++;
    }

    // F. Site document with latest lastEntryAt
    await batchManager.set(siteRef, {
      name: site.name,
      lastEntryAt: siteNewestTimestamp,
    });
  }

  // Commit remaining writes
  await batchManager.commit();

  // Print Summary
  console.log('\n========================================');
  console.log('       SITEPULSE SEED COMPLETED        ');
  console.log('========================================');
  console.log(`Users created/verified : ${USER_DEFS.length}`);
  console.log(`Sites seeded           : ${SITE_DEFS.length}`);
  console.log(`Workers seeded         : ${totalWorkers} (12 per site)`);
  console.log(`Attendance entries     : ${totalAttendance} (36 per site across 3 days)`);
  console.log(`Materials seeded       : ${totalMaterials} (4 per site)`);
  console.log(`Material logs seeded   : ${totalLogs}`);
  console.log(`Incidents seeded       : ${totalIncidents} (1 critical, 1 minor)`);
  console.log('----------------------------------------');
  console.log('TEST ACCOUNTS (Password: ' + PASSWORD_ALL + ')');
  console.log('----------------------------------------');
  for (const u of USER_DEFS) {
    const siteTag = u.siteId ? ` [Site: ${u.siteId}]` : ' [All Sites]';
    console.log(`- ${u.email.padEnd(22)} | Role: ${u.role.padEnd(10)} | ${u.displayName}${siteTag}`);
  }
  console.log('========================================\n');
}

main().catch((err) => {
  console.error('\n[Seed Error]:', err);
  process.exit(1);
});
