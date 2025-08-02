const express = require('express');
const app = express();
app.use(express.json());

app.get('/repos/:owner/:repo', (req, res) => {
  console.log('Mock intercepted: GET /repos/' + req.params.owner + '/' + req.params.repo);
  
  if (req.params.owner && req.params.repo) {
    res.status(200).json({ default_branch: 'main' });
  } else {
    res.status(404).json({ message: 'Repository not found' });
  }
});

app.get('/repos/:owner/:repo/branches/:branch', (req, res) => {
  console.log('Mock intercepted: GET /repos/' + req.params.owner + '/' + req.params.repo + '/branches/' + req.params.branch);
  
  if (req.params.owner && req.params.repo && req.params.branch === 'main') {
    res.status(200).json({ commit: { sha: 'abc123' } });
  } else {
    res.status(404).json({ message: 'Branch not found' });
  }
});

app.post('/repos/:owner/:repo/git/refs', (req, res) => {
  console.log('Mock intercepted: POST /repos/' + req.params.owner + '/' + req.params.repo + '/git/refs');
  console.log('Request body:', JSON.stringify(req.body));
  
  if (req.body.ref && req.body.sha && req.body.ref.startsWith('refs/heads/')) {
    res.status(201).json({ ref: req.body.ref });
  } else {
    res.status(422).json({ message: 'Reference already exists or invalid request' });
  }
});

app.listen(3000, () => {
  console.log('Mock server listening on http://127.0.0.1:3000...');
});
