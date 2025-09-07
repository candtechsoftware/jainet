// server.js
import express from "express";

const app = express();
app.use(express.json());

// In-memory "database"
const users = new Map();

// POST /users
app.post("/users", (req, res) => {
  const id = users.size + 1;
  const user = { id, ...req.body };
  users.set(id, user);
  res.status(201).json(user);
});

// GET /users/:id
app.get("/users/:id", (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (users.has(id)) {
    res.json(users.get(id));
  } else {
    res.status(404).json({ error: "User not found" });
  }
});

app.get("/users", (req, res) => {
  res.json(Array.from(users.values()));
});

// DELETE /users/:id
app.delete("/users/:id", (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (users.has(id)) {
    users.delete(id);
    res.json({ message: `User ${id} deleted` });
  } else {
    res.status(404).json({ error: "User not found" });
  }
});

// Start server
const PORT = 8080;
app.listen(PORT, () => {
  console.log(`Express server running on http://localhost:${PORT}`);
});
