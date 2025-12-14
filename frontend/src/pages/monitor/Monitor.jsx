import { useEffect, useRef, useState } from "react";
import styles from "./Monitor.module.css";
import Navbar from "../../components/navbar/Navbar";

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from "recharts";


function Monitor() {
    const [logs, setLogs] = useState([]);
    const socketRef = useRef(null);

        // Data state for charts
    const [cpuData, setCpuData] = useState([]);
    const [memoryData, setMemoryData] = useState([]);
    const [gpuData, setGpuData] = useState([]);
    const [diskData, setDiskData] = useState([]);
    const [networkData, setNetworkData] = useState([]);

    useEffect(() => {
        // Open WebSocket connection
        const socket = new WebSocket("ws://localhost:8000");
        socketRef.current = socket;

        socket.onopen = () => {
            console.log("Connected to WebSocket");
            // Do NOT send START automatically
        };

        socket.onmessage = (event) => {
            const line = event.data;
            
            setLogs(prev => [...prev, line]);

            const timestamp = new Date().toLocaleTimeString();

            // CPU
            if (line.startsWith("CPU Usage:")) {
                const usage = parseFloat(line.split("CPU Usage:")[1]);
                setCpuData(prev => [...prev, { time: timestamp, usage }].slice(-20));
            }

            // Memory
            if (line.startsWith("Memory Utilization:")) {
                const memUtil = parseFloat(line.split("Memory Utilization:")[1]);
                setMemoryData(prev => [...prev, { time: timestamp, memUtil }].slice(-20));
            }

            // GPU
            if (line.startsWith("GPU Utilization:")) {
                const gpuUtil = parseFloat(line.split("GPU Utilization:")[1]);
                setGpuData(prev => [...prev, { time: timestamp, gpuUtil }].slice(-20));
            }

            // Disk (simplified: just count of used disks)
            if (line.includes("used")) {
                setDiskData(prev => [...prev, { time: timestamp, usage: 1 }].slice(-20));
            }

            // Network (simplified example: skip detailed parsing)
            if (line.startsWith("Iface")) {
                setNetworkData(prev => [...prev, { time: timestamp, rx: Math.random() * 100, tx: Math.random() * 100 }].slice(-20));
            }
        };

        socket.onerror = (err) => {
            console.error("WebSocket error", err);
        };

        return () => {
            // Send STOP if the socket is still open
            if (socketRef.current.readyState === WebSocket.OPEN) {
                socketRef.current.send("STOP");
            }
            socket.close();
        };
    }, []);

    // Functions to start/stop monitoring
    const handleStart = () => {
        if (socketRef.current && socketRef.current.readyState === WebSocket.OPEN) {
            socketRef.current.send("START");
        }
    };

    const handleStop = () => {
        if (socketRef.current && socketRef.current.readyState === WebSocket.OPEN) {
            socketRef.current.send("STOP");
        }
    };


    const renderChart = (data, dataKey, title, color) => (
        <div className={styles.chartContainer}>
            <h3>{title}</h3>
            <ResponsiveContainer width="100%" height={200}>
                <LineChart data={data}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="time" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey={dataKey} stroke={color} strokeWidth={2} />
                </LineChart>
            </ResponsiveContainer>
        </div>
    );




    return (
        <div className={styles.main}>
            <Navbar />
            <div className={styles.container}>
                <div className={styles.top}>
                    <h2 className={styles.title}>Live Monitor</h2>
                </div>
                <div className={styles.body}>
                    <div className={styles.buttons}>
                        <button onClick={handleStart}>Start</button>
                        <button onClick={handleStop}>Stop</button>
                    </div>

                </div>
                <div className={styles.body}>
                    <pre className={styles.output}>
                        {logs.join("\n")}
                    </pre>

                </div>
                <div className={styles.chartGrid}>
                    {renderChart(cpuData, "usage", "CPU Usage (%)", "#ff4d4f")}
                    {renderChart(memoryData, "memUtil", "Memory Usage (%)", "#40a9ff")}
                    {renderChart(gpuData, "gpuUtil", "GPU Usage (%)", "#73d13d")}
                    {renderChart(diskData, "usage", "Disk Usage (simplified)", "#ffc53d")}
                    {renderChart(networkData, "rx", "Network RX (mock)", "#9254de")}
                    {/* Add SMART chart if numeric */}
                </div>
            </div>
        </div>
    );
}

export default Monitor;
