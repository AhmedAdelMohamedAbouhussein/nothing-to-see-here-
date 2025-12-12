// routes/monitor.js
import express from "express";

import { startMonitoring, stopMonitoring } from "../controllers/execBash.js";

const router = express.Router();

router.post("/start", startMonitoring);
router.post("/stop", stopMonitoring);

export default router;
