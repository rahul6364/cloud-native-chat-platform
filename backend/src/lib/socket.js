import "dotenv/config";
import { Server } from "socket.io";
import http from "http";
import express from "express";
import { createAdapter } from "@socket.io/redis-adapter";
import Redis from "ioredis";
import { updateSocketMetrics } from "./metrics.js";

const app = express();
const server = http.createServer(app);

const redisUrl = process.env.REDIS_URL || "redis://localhost:6379";

const redisOptions = {
  lazyConnect: true,
  maxRetriesPerRequest: null,
  retryStrategy(times) {
    return Math.min(times * 1000, 10000);
  },
};

const pubClient = new Redis(redisUrl, redisOptions);
const subClient = pubClient.duplicate();

for (const [name, client] of [
  ["publisher", pubClient],
  ["subscriber", subClient],
]) {
  client.on("error", (error) => {
    console.error(`Redis ${name} error:`, error.message);
  });

  client.on("ready", () => {
    console.log(`Redis ${name} connected`);
  });
}

await Promise.all([pubClient.connect(), subClient.connect()]);

const io = new Server(server, {
  cors: {
    origin: [
      "http://localhost:5173",
      "http://chat-app.com:8080",
      "http://chat-app.com",
      "http://localhost:8080",
    ],
    credentials: true,
  },
  pingInterval: 25000,
  pingTimeout: 60000,
  transports: ["websocket"],
});

io.adapter(createAdapter(pubClient, subClient));


async function refreshSocketMetrics() {
  try {
    const sockets = await io.fetchSockets();

    const onlineUsers = new Set(
      sockets
        .map((socket) => socket.data.userId)
        .filter(Boolean)
    );

    updateSocketMetrics(sockets.length, onlineUsers.size);

    return [...onlineUsers];
  } catch (error) {
    console.error("Failed to refresh socket metrics:", error.message);
    return [];
  }
}

io.on("connection", async (socket) => {
  const userId = socket.handshake.query.userId;

  if (!userId) {
    socket.disconnect(true);
    return;
  }

  socket.data.userId = String(userId);
  await socket.join(String(userId));

  console.log(`User ${userId} connected: ${socket.id}`);

  io.emit("getOnlineUsers", await refreshSocketMetrics());

  socket.on("disconnect", async () => {
    console.log(`User ${userId} disconnected: ${socket.id}`);

    io.emit("getOnlineUsers", await refreshSocketMetrics());
  });
});

export { io, app, server };
