import client from "prom-client";

export const register = new client.Registry();

client.collectDefaultMetrics({ register, prefix: "chatapp_" });

export const httpRequestsTotal = new client.Counter({
  name: "chatapp_http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

export const httpRequestDurationSeconds = new client.Histogram({
  name: "chatapp_http_request_duration_seconds",
  help: "HTTP request latency in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [register],
});

export const socketConnectionsActive = new client.Gauge({
  name: "chatapp_socket_connections_active",
  help: "Number of active Socket.io connections",
  registers: [register],
});

export const activeUsersGauge = new client.Gauge({
  name: "chatapp_active_users",
  help: "Number of users with an active socket session",
  registers: [register],
});

export function updateSocketMetrics(connectionCount, userCount) {
  socketConnectionsActive.set(connectionCount);
  activeUsersGauge.set(userCount);
}
