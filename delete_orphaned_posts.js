const https = require('https');
const { execSync } = require('child_process');

const keepUsers = [
  'ViTjeDwWxifu5svbSV9e80b4jar2',
  'LYR0BAsSJqYm5uOkBWvZeyTbXo03',
  'eHU38pSMaANRoAbGrJTQgjfXGtA3'
];

https.get('https://firestore.googleapis.com/v1/projects/knockpost-84b21/databases/(default)/documents/posts?pageSize=300', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    const json = JSON.parse(data);
    const docs = json.documents || [];
    const postsToDelete = [];
    
    for (const doc of docs) {
      const nameParts = doc.name.split('/');
      const postId = nameParts[nameParts.length - 1];
      
      // Find authorId field
      const fields = doc.fields || {};
      const authorIdField = fields.authorId;
      let authorId = null;
      if (authorIdField && authorIdField.stringValue) {
          authorId = authorIdField.stringValue;
      }
      
      // If authorId is not in our kept users list, mark for deletion
      if (authorId && !keepUsers.includes(authorId)) {
        postsToDelete.push(postId);
      }
    }
    
    console.log(`Found ${docs.length} total posts. Deleting ${postsToDelete.length} orphaned posts.`);
    
    for (const id of postsToDelete) {
      console.log(`Deleting post ${id}...`);
      try {
        execSync(`firebase firestore:delete --project knockpost-84b21 --recursive posts/${id} -f`);
        console.log(`Successfully deleted post ${id}`);
      } catch (err) {
        console.error(`Error deleting post ${id}:`, err.message);
      }
    }
    
    console.log('Post cleanup complete!');
  });
}).on('error', err => {
  console.error('Error fetching posts:', err.message);
});
