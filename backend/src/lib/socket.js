import { Server } from "socket.io";
import http from "http";
import express from "express";
import { updateSocketMetrics } from "./metrics.js";

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: [
      "http://localhost:5173",
      "http://chat-app.com:8080",
      "http://chat-app.com",
      "http://localhost:8080",
    ],
  },
});

export function getReceiverSocketId(userId) {
  return userSocketMap[userId];
}

const userSocketMap = {}; // {userId: socketId}

function refreshSocketMetrics() {
  const activeUsers = Object.keys(userSocketMap).length;
  updateSocketMetrics(io.engine.clientsCount, activeUsers);
}

io.on("connection", (socket) => {
  console.log("A user connected", socket.id);

  const userId = socket.handshake.query.userId;
  if (userId) userSocketMap[userId] = socket.id;

  io.emit("getOnlineUsers", Object.keys(userSocketMap));
  refreshSocketMetrics();

  socket.on("disconnect", () => {
    console.log("A user disconnected", socket.id);
    delete userSocketMap[userId];
    io.emit("getOnlineUsers", Object.keys(userSocketMap));
    refreshSocketMetrics();
  });
});

refreshSocketMetrics();

export { io, app, server };
