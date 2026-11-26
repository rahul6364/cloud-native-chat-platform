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

// Business / activity counters.
// Counters are per-process: Prometheus should sum() them across replicas.
export const userLoginsTotal = new client.Counter({
  name: "chatapp_user_logins_total",
  help: "Total number of successful logins",
  registers: [register],
});

export const userRegistrationsTotal = new client.Counter({
  name: "chatapp_user_registrations_total",
  help: "Total number of successful user registrations",
  registers: [register],
});

export const messagesSentTotal = new client.Counter({
  name: "chatapp_messages_sent_total",
  help: "Total number of chat messages successfully saved and delivered",
  registers: [register],
});

// Current number of user documents in MongoDB (not the same as online users).
// A gauge refreshed periodically; not unique per process, so use max() in PromQL.
export const registeredUsersGauge = new client.Gauge({
  name: "chatapp_registered_users_total",
  help: "Current number of registered users in the database (gauge, not a counter)",
  registers: [register],
});

export function updateSocketMetrics(connectionCount, userCount) {
  socketConnectionsActive.set(connectionCount);
  activeUsersGauge.set(userCount);
}

export function incrementUserLogins() {
  userLoginsTotal.inc();
}

export function incrementUserRegistrations() {
  userRegistrationsTotal.inc();
}

export function incrementMessagesSent() {
  messagesSentTotal.inc();
}

export function updateRegisteredUsers(count) {
  registeredUsersGauge.set(count);
}
