import express from "express";
import cookieParser from "cookie-parser";
import cors from "cors";
import mongoose from "mongoose";

import path from "path";

import { connectDB } from "./lib/db.js";

import authRoutes from "./routes/auth.route.js";
import messageRoutes from "./routes/message.route.js";
import healthRoutes from "./routes/health.route.js";
import metricsRoutes from "./routes/metrics.route.js";
import { metricsMiddleware } from "./middleware/metrics.middleware.js";
import { updateRegisteredUsers } from "./lib/metrics.js";
import User from "./models/user.model.js";
import { app, server, io, pubClient, subClient } from "./lib/socket.js";
import { allowedOrigins } from "./lib/origins.js";

// Load environment variables from .env file

const PORT = process.env.PORT;
const __dirname = path.resolve();
let shuttingDown = false;

app.use(express.json({ limit: "10mb" }));
app.use(cookieParser());
app.use(
  cors({
    origin: allowedOrigins,
    credentials: true,
  })
);

app.use(metricsMiddleware);

app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

app.use("/metrics", metricsRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/messages", messageRoutes);
app.use(
  "/health",
  (req, res, next) => {
    if (shuttingDown) {
      return res.status(503).json({
        status: "shutting_down",
        timestamp: new Date().toISOString(),
      });
    }
    next();
  },
  healthRoutes
);

// Global Error Handler
app.use((err, req, res, next) => {
  console.error("GLOBAL ERROR HANDLER:", err.stack);
  res.status(500).json({ message: "Internal Server Error", error: err.message });
});

if (process.env.NODE_ENV === "production") {
  app.use(express.static(path.join(__dirname, "../frontend/dist")));

  app.get("*", (req, res) => {
    res.sendFile(path.join(__dirname, "../frontend", "dist", "index.html"));
  });
}

async function refreshRegisteredUsers() {
  try {
    updateRegisteredUsers(await User.countDocuments({}));
  } catch (error) {
    console.error("Failed to refresh registered users metric:", error.message);
  }
}

server.listen(PORT, async () => {
  console.log("server is running on PORT:" + PORT);
  await connectDB();
  refreshRegisteredUsers();
  setInterval(refreshRegisteredUsers, 60_000).unref();
});

async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`Received ${signal}, starting graceful shutdown...`);

  const forceTimer = setTimeout(() => {
    console.error("Graceful shutdown timed out, forcing exit");
    process.exit(1);
  }, 20000);
  forceTimer.unref();

  try {
    await new Promise((resolve) => io.close(() => resolve()));
    if (server.listening) {
      await new Promise((resolve) => server.close(() => resolve()));
    }
    await mongoose.connection.close();
    await Promise.allSettled([pubClient.quit(), subClient.quit()]);
  } catch (err) {
    console.error("Error during graceful shutdown:", err.message);
  } finally {
    process.exit(0);
  }
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
