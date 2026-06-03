import express from "express";
import { register } from "../lib/metrics.js";

const router = express.Router();

router.get("/", async (req, res) => {
  try {
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    res.status(500).json({ message: "Failed to collect metrics" });
  }
});

export default router;
