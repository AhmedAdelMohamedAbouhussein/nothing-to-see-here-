import fs from "fs";
import path from "path";

import {
    parseCpuLog,
    parseGpuLog,
    parseMemoryLog,
    parseDiskLog,
    parseNetworkLog,
    smartstatusLog,
    parseUptimeLog
} from "../utils/parseLogs.js";

const REPORTS_DIR = path.join(process.cwd(), "system_reports");

export const getFolderLogs = (req, res) => {
    const { folderName } = req.params;

    const validName =
        /^\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec$/;

    if (!validName.test(folderName)) {
        return res.status(400).json({
            error: "Invalid folder name"
        });
    }

    const folderPath = path.join(REPORTS_DIR, folderName);

    if (!fs.existsSync(folderPath)) {
        return res.status(404).json({
            error: "Folder not found"
        });
    }

    try {
        const files = fs.readdirSync(folderPath);

        const response = {
            folder: folderName,
            cpu: [],
            gpu: [],
            memory: { ram: [], virtual: [] },
            disk: [],
            network: [],
            smart: []

        };

        for (const file of files) {
            const filePath = path.join(folderPath, file);
            if (!fs.statSync(filePath).isFile()) continue;
        
            switch (file) {
                case "cpu.log":
                    response.cpu = parseCpuLog(filePath);
                    break;
                case "gpu.log":
                    response.gpu = parseGpuLog(filePath);
                    break;
                case "memory.log":
                    response.memory = parseMemoryLog(filePath);
                    break;
                case "disk.log":
                    response.disk = parseDiskLog(filePath);
                    break;
                case "network.log":
                    response.network = parseNetworkLog(filePath);
                    break;
                case "smart.log":
                    response.smart = smartstatusLog(filePath);
                    break;
                case "load.log":
                    response.uptimeData = parseUptimeLog(filePath)
                    break;
            }
        }

        res.json(response);

    } catch (err) {
        console.error(err);

        return res.status(500).json({
            error: "Failed to read logs"
        });
    }
};
