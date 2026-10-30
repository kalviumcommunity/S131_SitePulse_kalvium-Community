/**
 * seed.js - Firestore & Firebase Auth seed script for SitePulse
 *
 * Usage:
 *   node seed.js                      # Existing 3-site seed
 *   node seed.js --reset              # Clears seeded subcollections, then seeds
 *   node seed.js --reset --profile=full # Clears and seeds the 5-site demo profile
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
const DEFAULT_USER_DEFS = [
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

const DEFAULT_SITE_DEFS = [
  { id: 'site_metro', name: 'Metro Rail Station 4B' },
  { id: 'site_harbor', name: 'Harbor Terminal I' },
  { id: 'site_highway', name: 'Highway 101 Overpass' },
];

const FULL_SITE_DEFS = [
  { id: 'site_metro', name: 'Bengaluru Namma Metro Purple Line Extension' },
  { id: 'site_harbor', name: 'Kochi Vallarpadam Container Terminal' },
  { id: 'site_highway', name: 'Delhi-Mumbai Expressway Package 9' },
  { id: 'site_pune', name: 'Pune Hinjawadi IT Park Phase 3' },
  { id: 'site_jaipur', name: 'Jaipur Solar Park Expansion' },
];

const isFullProfile = process.argv.includes('--profile=full');
const USER_DEFS = isFullProfile
  ? [
      ...DEFAULT_USER_DEFS,
      {
        email: 'sup4@sitepulse.test',
        password: PASSWORD_ALL,
        displayName: 'Anjali Deshmukh',
        role: 'supervisor',
        siteId: 'site_pune',
      },
      {
        email: 'sup5@sitepulse.test',
        password: PASSWORD_ALL,
        displayName: 'Mohit Sharma',
        role: 'supervisor',
        siteId: 'site_jaipur',
      },
    ]
  : DEFAULT_USER_DEFS;
const SITE_DEFS = isFullProfile ? FULL_SITE_DEFS : DEFAULT_SITE_DEFS;

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

function getISTDateInfo(daysAgo) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const part = (type) => parts.find((value) => value.type === type).value;
  const today = new Date(
    Date.UTC(Number(part('year')), Number(part('month')) - 1, Number(part('day')))
  );
  const date = new Date(today);
  date.setUTCDate(date.getUTCDate() - daysAgo);
  const yyyy = date.getUTCFullYear();
  const mm = String(date.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(date.getUTCDate()).padStart(2, '0');

  return {
    daysAgo,
    year: yyyy,
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
    weekday: date.getUTCDay(),
    dateKey: `${yyyy}-${mm}-${dd}`,
    compact: `${yyyy}${mm}${dd}`,
  };
}

function getISTClientTimestamp(dayInfo, hour, minute) {
  const utcMillis =
    Date.UTC(dayInfo.year, dayInfo.month - 1, dayInfo.day, hour, minute) -
    330 * 60 * 1000;
  return admin.firestore.Timestamp.fromDate(new Date(utcMillis));
}

function seededRandom(seedText) {
  let state = 2166136261;
  for (const character of seedText) {
    state ^= character.charCodeAt(0);
    state = Math.imul(state, 16777619) >>> 0;
  }
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 0x100000000;
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

function getFullMaterialConfigs(siteId) {
  const materials = [
    {
      id: 'mat_cement',
      name: 'Portland Cement',
      unit: 'bags',
      lowStockThreshold: 20,
      dailyMin: 3,
      dailyMax: 8,
      finalStock: siteId === 'site_metro' ? 8 : 45,
    },
    {
      id: 'mat_rebar',
      name: '12mm Steel Rebar',
      unit: 'bundles',
      lowStockThreshold: 12,
      dailyMin: 1,
      dailyMax: 3,
      finalStock: siteId === 'site_harbor' ? 0 : 32,
    },
    {
      id: 'mat_sand',
      name: 'River Sand',
      unit: 'tonnes',
      lowStockThreshold: 10,
      dailyMin: 2,
      dailyMax: 6,
      finalStock: 38,
    },
    {
      id: 'mat_aggregate',
      name: 'Crushed Aggregate',
      unit: 'tonnes',
      lowStockThreshold: 12,
      dailyMin: 2,
      dailyMax: 6,
      finalStock: 42,
    },
    {
      id: 'mat_bricks',
      name: 'Red Clay Bricks',
      unit: 'pieces',
      lowStockThreshold: 1000,
      dailyMin: 120,
      dailyMax: 280,
      finalStock: 2600,
    },
  ];
  const siteSpecific = {
    site_metro: {
      id: 'mat_signal_cable',
      name: 'Signal Cable',
      unit: 'coils',
      lowStockThreshold: 4,
      dailyMin: 1,
      dailyMax: 2,
      finalStock: 16,
    },
    site_harbor: {
      id: 'mat_marine_paint',
      name: 'Marine Protective Paint',
      unit: 'drums',
      lowStockThreshold: 5,
      dailyMin: 1,
      dailyMax: 2,
      finalStock: 18,
    },
    site_highway: {
      id: 'mat_road_barrier',
      name: 'Concrete Road Barriers',
      unit: 'pieces',
      lowStockThreshold: 8,
      dailyMin: 1,
      dailyMax: 3,
      finalStock: 24,
    },
    site_pune: {
      id: 'mat_copper_wire',
      name: 'Copper Electrical Wire',
      unit: 'coils',
      lowStockThreshold: 5,
      dailyMin: 1,
      dailyMax: 2,
      finalStock: 19,
    },
    site_jaipur: {
      id: 'mat_solar_panels',
      name: 'Solar Panels',
      unit: 'panels',
      lowStockThreshold: 20,
      dailyMin: 2,
      dailyMax: 5,
      finalStock: 68,
    },
  };
  return [...materials, siteSpecific[siteId]];
}

async function seedFullProfile(supervisorBySite) {
  const workerNames = [
    'Aarav Sharma',
    'Meera Patel',
    'Kabir Khan',
    'Ananya Reddy',
    'Ishaan Gupta',
    'Kavya Nair',
    'Dev Malhotra',
    'Sana Shaikh',
    'Arjun Desai',
    'Pooja Verma',
    'Rohan Iyer',
    'Nisha Kulkarni',
    'Vivek Joshi',
    'Diya Menon',
  ];
  const trades = [
    'Mason',
    'Carpenter',
    'Electrician',
    'Welder',
    'Helper',
    'Plumber',
    'Painter',
    'Scaffolder',
    'Machine Operator',
  ];
  const activeWorkerCounts = [12, 10, 14, 11, 13];
  const inactiveSites = new Set(['site_harbor', 'site_pune', 'site_jaipur']);
  const sundaySkipSites = new Set(['site_harbor', 'site_pune']);
  const staleSiteId = 'site_jaipur';
  const days = Array.from({ length: 30 }, (_, index) =>
    getISTDateInfo(29 - index)
  );
  const batchManager = new BatchManager(db);
  const siteStats = [];

  const incidentPlans = {
    site_metro: [
      { daysAgo: 25, severity: 'minor', description: 'Loose cable cover was secured beside the concourse walkway.' },
      { daysAgo: 18, severity: 'moderate', description: 'A lifting sling showed wear and was removed from service.' },
      { daysAgo: 12, severity: 'high', description: 'A worker sustained a fall injury near the elevated platform.' },
      { daysAgo: 5, severity: 'critical', description: 'A temporary support shifted during the station slab pour.' },
    ],
    site_harbor: [],
    site_highway: [
      { daysAgo: 23, severity: 'moderate', description: 'A delivery vehicle blocked the marked pedestrian route.' },
      { daysAgo: 10, severity: 'high', description: 'Excavation edge protection failed beside the service road.' },
      { daysAgo: 6, severity: 'critical', description: 'A crane load swung close to an occupied work platform.' },
    ],
    site_pune: [
      { daysAgo: 17, severity: 'minor', description: 'A temporary light fitting was replaced in the stairwell.' },
      { daysAgo: 8, severity: 'high', description: 'Electrical isolation was missing at a live panel location.' },
    ],
    site_jaipur: [
      { daysAgo: 24, severity: 'minor', description: 'A damaged safety sign was replaced at the site entrance.' },
      { daysAgo: 9, severity: 'moderate', description: 'A toolbox was left unsecured beside the inverter shed.' },
    ],
  };

  for (let siteIndex = 0; siteIndex < SITE_DEFS.length; siteIndex++) {
    const site = SITE_DEFS[siteIndex];
    const siteId = site.id;
    const supervisor = supervisorBySite[siteId];
    const siteRef = db.collection('sites').doc(siteId);
    const stats = {
      site: site.name,
      workers: 0,
      attendance: 0,
      materialLogs: 0,
      incidents: 0,
      lowStockItems: 0,
    };
    const workers = [];
    let siteNewestTimestamp = null;
    const trackNewest = (timestamp) => {
      if (
        !siteNewestTimestamp ||
        timestamp.toMillis() > siteNewestTimestamp.toMillis()
      ) {
        siteNewestTimestamp = timestamp;
      }
    };

    const workerCount = activeWorkerCounts[siteIndex];
    for (let index = 0; index < workerCount; index++) {
      const workerNumber = index + 1;
      const workerId = `w_${siteId}_${String(workerNumber).padStart(2, '0')}`;
      const workerData = {
        name: workerNames[(index + siteIndex * 3) % workerNames.length],
        trade: trades[(index + siteIndex) % trades.length],
        workerCode: `${siteId.slice(5, 8).toUpperCase()}-${String(workerNumber).padStart(3, '0')}`,
        active: true,
      };
      await batchManager.set(siteRef.collection('workers').doc(workerId), workerData);
      workers.push({ id: workerId });
      stats.workers++;
    }

    if (inactiveSites.has(siteId)) {
      const workerId = `w_${siteId}_inactive_01`;
      await batchManager.set(siteRef.collection('workers').doc(workerId), {
        name: `Former Worker ${siteIndex + 1}`,
        trade: trades[(siteIndex + 2) % trades.length],
        workerCode: `${siteId.slice(5, 8).toUpperCase()}-I01`,
        active: false,
      });
      stats.workers++;
    }

    for (const dayInfo of days) {
      if (siteId === staleSiteId && dayInfo.daysAgo <= 2) continue;
      if (
        sundaySkipSites.has(siteId) &&
        dayInfo.weekday === 0
      ) {
        continue;
      }

      const random = seededRandom(`${siteId}:${dayInfo.dateKey}:attendance`);
      const badDay = random() < 0.08;
      for (let workerIndex = 0; workerIndex < workers.length; workerIndex++) {
        const roll = random();
        let status;
        if (badDay) {
          status = roll < 0.72 ? 'present' : roll < 0.84 ? 'half' : 'absent';
        } else {
          status = roll < 0.88 ? 'present' : roll < 0.95 ? 'half' : 'absent';
        }
        const hour = 8 + Math.floor(random() * 3);
        const minute = Math.floor(random() * 60);
        const updatedAt = getISTClientTimestamp(dayInfo, hour, minute);
        trackNewest(updatedAt);

        const attendanceId =
          `${siteId}_${workers[workerIndex].id}_${dayInfo.compact}`;
        await batchManager.set(
          siteRef.collection('attendance').doc(attendanceId),
          {
            workerId: workers[workerIndex].id,
            status,
            dateKey: dayInfo.dateKey,
            updatedAt,
            createdBy: supervisor.uid,
          }
        );
        stats.attendance++;
      }
    }

    for (const material of getFullMaterialConfigs(siteId)) {
      const logDays = days.filter(
        (dayInfo) => !(siteId === staleSiteId && dayInfo.daysAgo <= 2)
      );
      const random = seededRandom(`${siteId}:${material.id}:usage`);
      const usages = logDays.map(
        () =>
          material.dailyMin +
          Math.floor(random() * (material.dailyMax - material.dailyMin + 1))
      );
      const openingStock =
        material.finalStock + usages.reduce((total, quantity) => total + quantity, 0);
      let remaining = openingStock;

      await batchManager.set(siteRef.collection('materials').doc(material.id), {
        name: material.name,
        unit: material.unit,
        openingStock,
        currentStock: material.finalStock,
        lowStockThreshold: material.lowStockThreshold,
      });
      if (material.finalStock <= material.lowStockThreshold) {
        stats.lowStockItems++;
      }

      for (let index = 0; index < logDays.length; index++) {
        const dayInfo = logDays[index];
        const qtyUsed = usages[index];
        remaining -= qtyUsed;
        const createdAt = getISTClientTimestamp(
          dayInfo,
          14,
          (index * 7) % 60
        );
        trackNewest(createdAt);
        const logId = `log_${siteId}_${material.id}_${dayInfo.compact}`;
        await batchManager.set(
          siteRef.collection('materialLogs').doc(logId),
          {
            materialId: material.id,
            materialName: material.name,
            qtyUsed,
            remainingAfter: remaining,
            dateKey: dayInfo.dateKey,
            createdAt,
            createdBy: supervisor.uid,
          }
        );
        stats.materialLogs++;
      }
      if (remaining !== material.finalStock) {
        throw new Error(`Material balance mismatch for ${siteId}/${material.id}`);
      }
    }

    for (const incident of incidentPlans[siteId]) {
      const dayInfo = days.find((value) => value.daysAgo === incident.daysAgo);
      const occurredAt = getISTClientTimestamp(dayInfo, 10, 30);
      trackNewest(occurredAt);
      await batchManager.set(
        siteRef.collection('incidents').doc(`inc_${siteId}_${dayInfo.compact}`),
        {
          severity: incident.severity,
          description: incident.description,
          occurredAt,
          createdBy: supervisor.uid,
        }
      );
      stats.incidents++;
    }

    if (!siteNewestTimestamp) {
      throw new Error(`No activity generated for ${siteId}`);
    }
    await batchManager.set(siteRef, {
      name: site.name,
      lastEntryAt: siteNewestTimestamp,
    });
    siteStats.push(stats);
  }

  await batchManager.commit();
  console.log('\nFULL PROFILE SEED COMPLETED');
  console.log(`Users created/verified: ${USER_DEFS.length}`);
  console.log(`Sites seeded: ${SITE_DEFS.length}`);
  console.table(siteStats);
  console.log(`Test account password: ${PASSWORD_ALL}\n`);
}

// 6. Main seed routine
async function main() {
  const profileArguments = process.argv.filter((arg) =>
    arg.startsWith('--profile=')
  );
  if (
    profileArguments.some((arg) => arg !== '--profile=full') ||
    profileArguments.length > 1
  ) {
    throw new Error('The only supported profile is --profile=full.');
  }

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
    site_pune: users['sup4@sitepulse.test'],
    site_jaipur: users['sup5@sitepulse.test'],
  };

  // 2. Reset if requested
  if (isReset) {
    await resetSubcollections();
  }

  if (isFullProfile) {
    await seedFullProfile(supervisorBySite);
    return;
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
