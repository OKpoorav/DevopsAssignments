const express = require("express");
const app = express();
const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.send("<h1>Hello World from Node.js (Express) in Docker!</h1><p>Session 06 - Poorav Kumar Gupta (24bcs10080)</p>");
});

app.listen(PORT, () => console.log(`Node.js app listening on port ${PORT}`));
