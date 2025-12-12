// controllers/execBash.js
import { spawn } from "child_process";

let monitorProcess = null; // global reference

export const startMonitoring = (req, res, next) => 
{
    if (monitorProcess) {
        return res.status(400).json({ message: "Monitoring already running" });
    }

    monitorProcess = spawn("bash", ["../../test.sh"]);

    monitorProcess.stdout.on("data", data => 
    {
        console.log("OUTPUT:", data.toString());
    });

    monitorProcess.stderr.on("data", data => 
    {
        console.error("SCRIPT ERROR:", data.toString());
    });

    monitorProcess.on("close", code => {
        console.log("Monitoring stopped with code", code);
        monitorProcess = null; // reset reference
    });

    res.json({ message: "Monitoring started" });
};


export const stopMonitoring = (req, res, next) => {
    if (!monitorProcess) 
    {
        return res.status(400).json({ message: "Monitoring is not running" });
    }

    monitorProcess.kill("SIGTERM"); // send signal to stop the script
    res.json({ message: "Monitoring stopped" });
};