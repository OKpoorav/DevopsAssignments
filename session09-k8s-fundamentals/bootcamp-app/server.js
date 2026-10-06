// Same behaviour as the official Kubernetes Basics "kubernetes-bootcamp" app.
const http = require('http');
const os = require('os');
const VERSION = process.env.APP_VERSION || '1';
const startTime = new Date().toISOString();
let requests = 0;
http.createServer((req, res) => {
  requests++;
  res.writeHead(200);
  res.end(`Hello Kubernetes bootcamp! | Running on: ${os.hostname()} | v=${VERSION}\n`);
  console.log(`Request #${requests} ${req.method} ${req.url} from ${req.socket.remoteAddress}`);
}).listen(8080, () => console.log(`Kubernetes Bootcamp App Started At: ${startTime} | Running On: ${os.hostname()} | v=${VERSION}`));
