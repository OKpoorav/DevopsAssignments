const express = require("express");
const os = require("os");
const app = express();
const PORT = process.env.PORT || 3000;

app.get("/", (req, res) =>
  res.send(`<h1>Hello from Node.js (multi-stage) - Session 07</h1><p>Container hostname: ${os.hostname()}</p>`)
);
app.get("/health", (req, res) => res.json({ status: "ok", runtime: "node", version: process.version }));

app.listen(PORT, () => console.log(`Node app on ${PORT}`));
