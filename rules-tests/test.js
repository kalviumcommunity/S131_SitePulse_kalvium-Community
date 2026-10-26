const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

describe('Firestore Security Rules', () => {
  let testEnv;

  before(async () => {
    const rulesPath = path.resolve(__dirname, '../firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');

    testEnv = await initializeTestEnvironment({
      projectId: 'sitepulse-rules-test',
      firestore: {
        rules,
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();

    // Seed data with security rules disabled
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      // Seed users
      await db.doc('users/sup-1').set({
        role: 'supervisor',
        name: 'Supervisor One',
        siteId: 'site-1',
      });
      await db.doc('users/sup-2').set({
        role: 'supervisor',
        name: 'Supervisor Two',
        siteId: 'site-2',
      });
      await db.doc('users/pm-1').set({
        role: 'pm',
        name: 'Project Manager',
        siteId: null,
      });

      // Seed sites
      await db.doc('sites/site-1').set({
        name: 'Downtown Site',
        lastEntryAt: '2026-10-26T10:00:00.000Z',
      });
      await db.doc('sites/site-2').set({
        name: 'Uptown Site',
        lastEntryAt: '2026-10-26T10:00:00.000Z',
      });

      // Seed worker
      await db.doc('sites/site-1/workers/w-1').set({
        name: 'Worker 1',
        trade: 'Mason',
        workerCode: 'MAS-101',
        active: true,
      });

      // Seed attendance
      await db.doc('sites/site-1/attendance/att-1').set({
        workerId: 'w-1',
        date: '2026-10-26',
        status: 'present',
      });

      // Seed material
      await db.doc('sites/site-1/materials/mat-1').set({
        name: 'Cement',
        unit: 'bags',
        openingStock: 100,
        currentStock: 80,
        lowStockThreshold: 20,
      });

      // Seed materialLog
      await db.doc('sites/site-1/materialLogs/log-1').set({
        materialId: 'mat-1',
        qtyUsed: 20,
        remainingAfter: 80,
        date: '2026-10-26T10:00:00.000Z',
      });

      // Seed incident
      await db.doc('sites/site-1/incidents/inc-1').set({
        severity: 'high',
        description: 'Scaffolding snapped on 3rd floor',
        occurredAt: '2026-10-26T10:00:00.000Z',
      });
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  // 1. USERS
  describe('users collection', () => {
    it('signed-in user can read their own user document (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(db.doc('users/sup-1').get());
    });

    it('signed-in user cannot read another user document (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(db.doc('users/sup-2').get());
    });

    it('user cannot edit own role or document (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(db.doc('users/sup-1').update({ role: 'pm' }));
    });
  });

  // 2. SITES
  describe('sites collection', () => {
    it('assigned supervisor can read their own site (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(db.doc('sites/site-1').get());
    });

    it('PM can read any site (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('pm-1').firestore();
      await assertSucceeds(db.doc('sites/site-1').get());
      await assertSucceeds(db.doc('sites/site-2').get());
    });

    it('supervisor reads another site (fail) (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(db.doc('sites/site-2').get());
    });

    it('assigned supervisor can update ONLY lastEntryAt on their site (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(
        db.doc('sites/site-1').update({
          lastEntryAt: '2026-10-26T11:00:00.000Z',
        })
      );
    });

    it('assigned supervisor cannot update fields other than lastEntryAt on site (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-1').update({
          name: 'Hacked Site Name',
        })
      );
    });

    it('supervisor writes another site (fail) (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-2').update({
          lastEntryAt: '2026-10-26T12:00:00.000Z',
        })
      );
    });

    it('nobody can create or delete site documents (assertFails)', async () => {
      const dbSup = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(dbSup.doc('sites/site-3').set({ name: 'Site 3' }));
      await assertFails(dbSup.doc('sites/site-1').delete());
    });
  });

  // 3. WORKERS
  describe('workers subcollection', () => {
    it('assigned supervisor can read workers at own site (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(db.doc('sites/site-1/workers/w-1').get());
    });

    it('PM reads all workers across sites (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('pm-1').firestore();
      await assertSucceeds(db.doc('sites/site-1/workers/w-1').get());
    });

    it('assigned supervisor can create worker on own site (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(
        db.doc('sites/site-1/workers/w-2').set({
          name: 'Worker 2',
          trade: 'Electrician',
          workerCode: 'ELE-102',
          active: true,
        })
      );
    });

    it('assigned supervisor can update worker on own site (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(
        db.doc('sites/site-1/workers/w-1').update({ active: false })
      );
    });

    it('supervisor cannot create worker on another site (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-2/workers/w-foreign').set({
          name: 'Foreign Worker',
          trade: 'Mason',
          workerCode: 'MAS-999',
          active: true,
        })
      );
    });

    it('supervisor cannot delete worker (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(db.doc('sites/site-1/workers/w-1').delete());
    });
  });

  // 4. ATTENDANCE
  describe('attendance subcollection', () => {
    it('assigned supervisor and PM can read attendance (assertSucceeds)', async () => {
      const dbSup = testEnv.authenticatedContext('sup-1').firestore();
      const dbPm = testEnv.authenticatedContext('pm-1').firestore();
      await assertSucceeds(dbSup.doc('sites/site-1/attendance/att-1').get());
      await assertSucceeds(dbPm.doc('sites/site-1/attendance/att-1').get());
    });

    it('assigned supervisor can create and update attendance on own site (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(
        db.doc('sites/site-1/attendance/att-2').set({
          workerId: 'w-2',
          date: '2026-10-26',
          status: 'half',
        })
      );
      await assertSucceeds(
        db.doc('sites/site-1/attendance/att-1').update({ status: 'half' })
      );
    });

    it('supervisor cannot create attendance on another site (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-2/attendance/att-x').set({
          workerId: 'w-1',
          date: '2026-10-26',
          status: 'present',
        })
      );
    });

    it('supervisor cannot delete attendance (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(db.doc('sites/site-1/attendance/att-1').delete());
    });
  });

  // 5. MATERIALS
  describe('materials subcollection', () => {
    it('PM and assigned supervisor can read materials (assertSucceeds)', async () => {
      const dbSup = testEnv.authenticatedContext('sup-1').firestore();
      const dbPm = testEnv.authenticatedContext('pm-1').firestore();
      await assertSucceeds(dbSup.doc('sites/site-1/materials/mat-1').get());
      await assertSucceeds(dbPm.doc('sites/site-1/materials/mat-1').get());
    });

    it('assigned supervisor can update ONLY currentStock (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(
        db.doc('sites/site-1/materials/mat-1').update({ currentStock: 75 })
      );
    });

    it('material update touching a field other than currentStock (fail) (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-1/materials/mat-1').update({
          currentStock: 70,
          name: 'Premium Cement',
        })
      );
    });

    it('client cannot create or delete material (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-1/materials/mat-new').set({
          name: 'Steel',
          unit: 'kg',
          openingStock: 50,
          currentStock: 50,
          lowStockThreshold: 10,
        })
      );
      await assertFails(db.doc('sites/site-1/materials/mat-1').delete());
    });
  });

  // 6. MATERIAL LOGS
  describe('materialLogs subcollection', () => {
    it('assigned supervisor and PM can read material logs (assertSucceeds)', async () => {
      const dbSup = testEnv.authenticatedContext('sup-1').firestore();
      const dbPm = testEnv.authenticatedContext('pm-1').firestore();
      await assertSucceeds(dbSup.doc('sites/site-1/materialLogs/log-1').get());
      await assertSucceeds(dbPm.doc('sites/site-1/materialLogs/log-1').get());
    });

    it('assigned supervisor can create materialLog when qtyUsed > 0 (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(
        db.doc('sites/site-1/materialLogs/log-2').set({
          materialId: 'mat-1',
          qtyUsed: 5.5,
          remainingAfter: 74.5,
          date: '2026-10-26T12:00:00.000Z',
        })
      );
    });

    it('supervisor cannot create materialLog when qtyUsed <= 0 (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-1/materialLogs/log-3').set({
          materialId: 'mat-1',
          qtyUsed: 0,
          remainingAfter: 80,
          date: '2026-10-26T12:00:00.000Z',
        })
      );
    });

    it('materialLog cannot be updated or deleted (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-1/materialLogs/log-1').update({ qtyUsed: 15 })
      );
      await assertFails(db.doc('sites/site-1/materialLogs/log-1').delete());
    });
  });

  // 7. INCIDENTS
  describe('incidents subcollection', () => {
    it('assigned supervisor and PM can read incidents (assertSucceeds)', async () => {
      const dbSup = testEnv.authenticatedContext('sup-1').firestore();
      const dbPm = testEnv.authenticatedContext('pm-1').firestore();
      await assertSucceeds(dbSup.doc('sites/site-1/incidents/inc-1').get());
      await assertSucceeds(dbPm.doc('sites/site-1/incidents/inc-1').get());
    });

    it('assigned supervisor can create incident with valid severity and description >= 10 chars (assertSucceeds)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertSucceeds(
        db.doc('sites/site-1/incidents/inc-2').set({
          severity: 'moderate',
          description: 'Worker slipped on wet concrete path',
          occurredAt: '2026-10-26T14:00:00.000Z',
        })
      );
    });

    it('incident with bad severity (fail) (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-1/incidents/inc-bad-sev').set({
          severity: 'fatal',
          description: 'A serious incident with invalid severity',
          occurredAt: '2026-10-26T14:00:00.000Z',
        })
      );
    });

    it('incident with short description (fail) (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-1/incidents/inc-short').set({
          severity: 'minor',
          description: 'Too short',
          occurredAt: '2026-10-26T14:00:00.000Z',
        })
      );
    });

    it('incident update and delete (fail) (assertFails)', async () => {
      const db = testEnv.authenticatedContext('sup-1').firestore();
      await assertFails(
        db.doc('sites/site-1/incidents/inc-1').update({
          description: 'Updated incident description here',
        })
      );
      await assertFails(db.doc('sites/site-1/incidents/inc-1').delete());
    });
  });

  // 8. PM READ-ONLY EVERYWHERE
  describe('PM is read-only everywhere', () => {
    it('PM writes any entry (fail) (assertFails)', async () => {
      const db = testEnv.authenticatedContext('pm-1').firestore();

      // PM cannot write site
      await assertFails(
        db.doc('sites/site-1').update({ lastEntryAt: '2026-10-26T15:00:00.000Z' })
      );

      // PM cannot write worker
      await assertFails(
        db.doc('sites/site-1/workers/w-pm').set({
          name: 'PM Worker',
          trade: 'Mason',
          workerCode: 'MAS-999',
          active: true,
        })
      );

      // PM cannot write attendance
      await assertFails(
        db.doc('sites/site-1/attendance/att-pm').set({
          workerId: 'w-1',
          date: '2026-10-26',
          status: 'present',
        })
      );

      // PM cannot write material
      await assertFails(
        db.doc('sites/site-1/materials/mat-1').update({ currentStock: 50 })
      );

      // PM cannot write incident
      await assertFails(
        db.doc('sites/site-1/incidents/inc-pm').set({
          severity: 'minor',
          description: 'PM trying to file incident directly',
          occurredAt: '2026-10-26T15:00:00.000Z',
        })
      );
    });
  });

  // 9. SIGNED-OUT USERS DENIED
  describe('signed-out users denied', () => {
    it('signed-out read (fail) (assertFails)', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.doc('users/sup-1').get());
      await assertFails(db.doc('sites/site-1').get());
      await assertFails(db.doc('sites/site-1/workers/w-1').get());
      await assertFails(db.doc('sites/site-1/materials/mat-1').get());
      await assertFails(db.doc('sites/site-1/incidents/inc-1').get());
    });

    it('signed-out write (fail) (assertFails)', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        db.doc('sites/site-1').update({ lastEntryAt: '2026-10-26T16:00:00.000Z' })
      );
    });
  });
});
