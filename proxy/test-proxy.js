const http = require('http');

const server = http.createServer((req, res) => {
  console.log(`[PROXY REQUEST] ${req.method} ${req.url}`);
  console.log('Headers:', JSON.stringify(req.headers, null, 2));
  
  res.writeHead(500);
  res.end('Intercepted by test proxy');
});

server.listen(9999, () => {
  console.log('Test proxy listening on 9999');
});
