import { useEffect, useRef, useState } from "react";
import styles from "./Monitor.module.css";
import Navbar from "../../components/navbar/Navbar";

import CpuGpuChart from "../../charts/CpuGpuChart";
import DiskBarChart from "../../charts/DiskCircularBar";
import MemoryCircular from "../../charts/MemoryCircular";
import MemoryLineChart from "../../charts/MemoryLineChart";

function Monitor() {
    const socketRef = useRef(null);

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

        let currentSnapshot = null;

        socket.onopen = () => {
            console.log("Connected to WebSocket");
        };

        socket.onmessage = (event) => {
            let line = event.data.trim();
            //console.log(line);

            const time = getBackendStyleTime();

            /* ================= CPU ================= */
            if (line.startsWith("CPU Usage:")) {
                const usage = parseFloat(line.split(":")[1]);
                setCpuData(prev => [
                    ...prev,
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
                    ...prev,
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
                    ...prev,
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
            // Extract timestamp if present and Check if line has timestamp
            const timestampMatch = line.match(/^(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec):\s*(.*)/);
            let timestamp = null;
            if (timestampMatch) {
                timestamp = timestampMatch[1];
                line = timestampMatch[2]; // remove timestamp from the line
            }

            // Save previous snapshot if timestamp changed
            if (timestamp && (!currentSnapshot || currentSnapshot.time !== timestamp)) {
                if (currentSnapshot) {
                    // Replace the state entirely with the current snapshot
                    setDiskSnapshots([structuredClone(currentSnapshot)]);
                    console.log('Saved snapshot:', structuredClone(currentSnapshot));
                }
                currentSnapshot = { time: timestamp, disks: [] };
            }

            // Now line may literally start with "disk:" or "partition:"
            if (line.startsWith("disk:")) {
                const parts = line.split(" ");
                const name = parts[1];
                const size = parts[2];
                currentSnapshot.disks.push({ name, size, partitions: [] });
            }


            if (line.startsWith("partition:")) {
                const parts = line.split(" ");
                const partition = {
                    name: parts[1],
                    size: parts[2],
                    type: parts[3],
                };
                if (parts[4]) partition.mount = parts[4];
                if (parts[5]) partition.used = parts[5];
                if (parts[7]) partition.usePercent = parts[7];
            
                currentSnapshot.disks.at(-1)?.partitions.push(partition);
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

            </div>
        </div>
    );
}

export default Monitor;
