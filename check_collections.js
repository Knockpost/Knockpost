const https = require('https');

https.get('https://firestore.googleapis.com/v1/projects/knockpost-84b21/databases/(default)/documents', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log(data);
  });
});
