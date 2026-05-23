const https = require('https');
const { execSync } = require('child_process');

const keepUsers = [
  'ViTjeDwWxifu5svbSV9e80b4jar2',
  'LYR0BAsSJqYm5uOkBWvZeyTbXo03',
  'eHU38pSMaANRoAbGrJTQgjfXGtA3'
];

https.get('https://firestore.googleapis.com/v1/projects/knockpost-84b21/databases/(default)/documents/users?pageSize=300', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    const json = JSON.parse(data);
    const docs = json.documents || [];
    const idsToDelete = [];
    
    for (const doc of docs) {
      const nameParts = doc.name.split('/');
      const id = nameParts[nameParts.length - 1];
      
      if (!keepUsers.includes(id)) {
        idsToDelete.push(id);
      }
    }
    
    console.log(`Found ${docs.length} total users. Keeping ${keepUsers.length}. Deleting ${idsToDelete.length} users.`);
    
    for (const id of idsToDelete) {
      console.log(`Deleting ${id}...`);
      try {
        execSync(`firebase firestore:delete --project knockpost-84b21 --recursive users/${id} -f`);
        console.log(`Successfully deleted ${id}`);
      } catch (err) {
        console.error(`Error deleting ${id}:`, err.message);
      }
    }
    
    console.log('Cleanup complete!');
  });
}).on('error', err => {
  console.error('Error fetching users:', err.message);
});
