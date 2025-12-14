import { useEffect, useRef, useState } from "react";
import styles from "./Monitor.module.css";
import Navbar from "../../components/navbar/Navbar";

import CpuGpuChart from "../../charts/CpuGpuChart";
import DiskBarChart from "../../charts/DiskBarChart";
import MemoryCircular from "../../charts/MemoryCircular";
import MemoryLineChart from "../../charts/MemoryLineChart";

function Monitor() {
    const socketRef = useRef(null);

    const [logs, setLogs] = useState([]);

    const [cpuData, setCpuData] = useState([]);
    const [gpuData, setGpuData] = useState([]);

    const [ramData, setRamData] = useState([]);
    const [virtualData, setVirtualData] = useState([]);

    const [diskSnapshots, setDiskSnapshots] = useState([]);

    // Function to generate backend-style timestamp
    const getBackendStyleTime = () => {
        const d = new Date();
        const yyyy = d.getFullYear();
        const mm = String(d.getMonth() + 1).padStart(2, "0");
        const dd = String(d.getDate()).padStart(2, "0");
        const hh = String(d.getHours()).padStart(2, "0");
        const min = String(d.getMinutes()).padStart(2, "0");
        const ss = String(d.getSeconds()).padStart(2, "0");
        return `${yyyy}-${mm}-${dd}-${hh}h-${min}min-${ss}sec`;
    };

    useEffect(() => {
        const socket = new WebSocket("ws://localhost:8000");
        socketRef.current = socket;

        const diskState = { disks: [] };

        socket.onopen = () => {
            console.log("Connected to WebSocket");
        };

        socket.onmessage = (event) => {
            const line = event.data.trim();
            setLogs(prev => [...prev, line]);

            const time = getBackendStyleTime();

            /* ================= CPU ================= */
            if (line.startsWith("CPU Usage:")) {
                const usage = parseFloat(line.split(":")[1]);
                setCpuData(prev => [
                    ...prev.slice(-19),
                    { time, usage, temperature: prev.at(-1)?.temperature ?? 0 }
                ]);
            }

            if (line.startsWith("CPU Temperature:")) {
                const temperature = parseFloat(line.split(":")[1]);
                setCpuData(prev => [
                    ...prev.slice(0, -1),
                    { ...prev.at(-1), temperature }
                ]);
            }

            /* ================= MEMORY ================= */
            if (line.startsWith("Memory Utilization:")) {
                const usagePercent = parseFloat(line.split(":")[1]);
                setRamData(prev => [
                    ...prev.slice(-19),
                    { time, usagePercent }
                ]);
            }

            if (line.startsWith("Memory Used:")) {
                const used = parseFloat(line.split(":")[1]);
                setRamData(prev => [
                    ...prev.slice(0, -1),
                    { ...prev.at(-1), used }
                ]);
            }

            if (line.startsWith("Memory Total:")) {
                const total = parseFloat(line.split(":")[1]);
                setRamData(prev => [
                    ...prev.slice(0, -1),
                    { ...prev.at(-1), total }
                ]);
            }

            /* ============ VIRTUAL MEMORY ============ */
            if (line.startsWith("Virtual Memory Utilization:")) {
                const usagePercent = parseFloat(line.split(":")[1]);
                setVirtualData(prev => [
                    ...prev.slice(-19),
                    { time, usagePercent }
                ]);
            }

            if (line.startsWith("Virtual Memory Used:")) {
                const used = parseFloat(line.split(":")[1]);
                setVirtualData(prev => [
                    ...prev.slice(0, -1),
                    { ...prev.at(-1), used }
                ]);
            }

            if (line.startsWith("Virtual Memory Total:")) {
                const total = parseFloat(line.split(":")[1]);
                setVirtualData(prev => [
                    ...prev.slice(0, -1),
                    { ...prev.at(-1), total }
                ]);
            }

            /* ================= DISKS ================= */
            if (line.startsWith("disk :")) {
                diskState.disks.push({
                    name: line.split(":")[1].trim().split(" ")[0],
                    partitions: []
                });
            }

            if (line.startsWith("partition :")) {
                const parts = line.split(" ");
                const name = parts[2];
                const usedIndex = parts.findIndex(p => p === "used");
                const used = usedIndex !== -1 ? parseFloat(parts[usedIndex - 1]) : 0;

                diskState.disks.at(-1)?.partitions.push({ name, used });
            }

            /* snapshot separator (blank line or end marker) */
            if (line === "") {
                if (diskState.disks.length) {
                    setDiskSnapshots(prev => [
                        ...prev.slice(-9),
                        { time, disks: structuredClone(diskState.disks) }
                    ]);
                    diskState.disks = [];
                }
            }
        };

        socket.onerror = (err) => console.error("WebSocket error", err);

        return () => socket.close();
    }, []);

    /* ================= BUTTONS ================= */
    const handleStart = () => {
        if (socketRef.current?.readyState === WebSocket.OPEN) {
            socketRef.current.send("START");
        }
    };

    const handleStop = () => {
        if (socketRef.current?.readyState === WebSocket.OPEN) {
            socketRef.current.send("STOP");
        }
    };

    return (
        <div className={styles.main}>
            <Navbar />

            <div className={styles.container}>
                <div className={styles.top}>
                    <h2 className={styles.title}>Live Monitor</h2>
                </div>

                {/* ===== Buttons ===== */}
                <div className={styles.body}>
                    <div className={styles.buttons}>
                        <button onClick={handleStart}>Start</button>
                        <button onClick={handleStop}>Stop</button>
                    </div>
                </div>

                {/* ===== Charts ===== */}
                <div className={styles.chartGrid}>
                    <CpuGpuChart cpuData={cpuData} gpuData={gpuData} />
                    <MemoryCircular ram={ramData} virtual={virtualData} />
                    <MemoryLineChart ram={ramData} virtual={virtualData} />
                    <DiskBarChart diskSnapshots={diskSnapshots} />
                </div>

                {/* ===== Logs ===== */}
                <div className={styles.body}>
                    <pre className={styles.output}>
                        {logs.join("\n")}
                    </pre>
                </div>
            </div>
        </div>
    );
}

export default Monitor;
