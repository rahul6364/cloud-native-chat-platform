import { httpRequestDurationSeconds, httpRequestsTotal } from "../lib/metrics.js";

function resolveRoute(req) {
  if (req.route?.path) {
    const base = req.baseUrl && req.baseUrl !== "/" ? req.baseUrl : "";
    return `${base}${req.route.path}`;
  }
  if (req.path === "/metrics") return "/metrics";
  if (req.path.startsWith("/api/")) {
    const parts = req.path.split("/").filter(Boolean);
    if (parts.length >= 2) return `/api/${parts[1]}`;
  }
  return req.path || "unknown";
}

export function metricsMiddleware(req, res, next) {
  if (req.path === "/metrics") {
    return next();
  }

  const start = process.hrtime.bigint();

  res.on("finish", () => {
    const route = resolveRoute(req);
    const labels = {
      method: req.method,
      route,
      status_code: String(res.statusCode),
    };
    httpRequestsTotal.inc(labels);
    const durationSeconds = Number(process.hrtime.bigint() - start) / 1e9;
    httpRequestDurationSeconds.observe(labels, durationSeconds);
  });

  next();
}
