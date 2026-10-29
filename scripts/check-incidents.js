const admin = require('firebase-admin');

const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.FIREBASE_PROJECT_ID ||
  'sitepulse-6245f';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();
const VALID_SEVERITIES = new Set(['minor', 'moderate', 'high', 'critical']);

async function main() {
  const sitesSnapshot = await db.collection('sites').get();
  const invalidIncidents = [];
  let total = 0;

  for (const site of sitesSnapshot.docs) {
    const incidentsSnapshot = await site.ref.collection('incidents').get();
    total += incidentsSnapshot.size;

    for (const incident of incidentsSnapshot.docs) {
      const data = incident.data();
      const issues = [];

      if (!VALID_SEVERITIES.has(data.severity)) {
        issues.push('invalid severity');
      }
      if (typeof data.description !== 'string' || data.description.trim().length < 10) {
        issues.push('description must be at least 10 characters');
      }
      if (!(data.occurredAt instanceof admin.firestore.Timestamp)) {
        issues.push('occurredAt must be a timestamp');
      }

      if (issues.length > 0) {
        invalidIncidents.push({
          siteId: site.id,
          incidentId: incident.id,
          issues: issues.join('; '),
        });
      }
    }
  }

  const invalid = invalidIncidents.length;
  console.table([{ total, valid: total - invalid, invalid }]);
  if (invalid > 0) {
    console.table(invalidIncidents);
    process.exitCode = 1;
  } else {
    console.log('All incidents are complete.');
  }
}

main().catch((error) => {
  console.error('Failed to check incidents:', error);
  process.exitCode = 1;
});
