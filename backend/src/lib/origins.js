const defaultOrigins = [
  "http://chat-app.com:8080",
  "http://chat-app.com",
  "http://localhost:8080",
  "http://localhost:5173",
];

const envOrigins = (process.env.ALLOWED_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

export const allowedOrigins = [...new Set([...defaultOrigins, ...envOrigins])];
