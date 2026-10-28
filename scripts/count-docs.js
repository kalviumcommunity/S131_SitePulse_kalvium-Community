const admin = require('firebase-admin');

const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.FIREBASE_PROJECT_ID ||
  'sitepulse-6245f';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();
const COUNTED_COLLECTIONS = ['workers', 'attendance', 'materialLogs', 'incidents'];

function parseDateArgument(args) {
  let date;

  for (let index = 0; index < args.length; index += 1) {
    if (args[index] !== '--date') {
      throw new Error(`Unknown argument: ${args[index]}`);
    }
    if (date !== undefined) {
      throw new Error('The --date option may only be provided once.');
    }

    date = args[index + 1];
    if (!date || date.startsWith('--')) {
      throw new Error('Usage: node count-docs.js [--date yyyy-MM-dd]');
    }
    index += 1;

    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
      Number.isNaN(Date.parse(`${date}T00:00:00.000Z`)) ||
      new Date(`${date}T00:00:00.000Z`).toISOString().slice(0, 10) !== date
    ) {
      throw new Error(`Invalid date "${date}". Expected yyyy-MM-dd.`);
    }
  }

  return date;
}

async function main() {
  const date = parseDateArgument(process.argv.slice(2));
  const sitesSnapshot = await db.collection('sites').get();
  const counts = [];
  const materials = [];

  for (const site of sitesSnapshot.docs) {
    const results = await Promise.all(
      COUNTED_COLLECTIONS.map((collectionName) => {
        let query = site.ref.collection(collectionName);
        if (collectionName === 'attendance' && date) {
          query = query.where('dateKey', '==', date);
        }
        return query.get();
      }),
    );

    for (let index = 0; index < COUNTED_COLLECTIONS.length; index += 1) {
      counts.push({
        siteId: site.id,
        collection: COUNTED_COLLECTIONS[index],
        count: results[index].size,
      });
    }

    const materialSnapshot = await site.ref.collection('materials').get();
    for (const material of materialSnapshot.docs) {
      materials.push({
        siteId: site.id,
        materialId: material.id,
        name: material.get('name'),
        currentStock: material.get('currentStock'),
      });
    }
  }

  console.log(`Document counts${date ? ` (attendance dateKey: ${date})` : ''}`);
  console.table(counts);
  console.log('Material current stock');
  console.table(materials);
}

main().catch((error) => {
  console.error('Failed to count site documents:', error);
  process.exitCode = 1;
});
