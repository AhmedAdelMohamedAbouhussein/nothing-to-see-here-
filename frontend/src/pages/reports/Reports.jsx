import { useEffect, useState } from "react";
import axios from "axios";
import { Link } from 'react-router-dom';
import {FaArrowLeft} from "react-icons/fa";

import CpuGpuChart from "../../charts/CpuGpuChart";
import DiskBarChart from "../../charts/DiskCircularBar";
import MemoryLineChart from "../../charts/MemoryLineChart";
import DiskChart from "../../charts/DiskChart"
import NetworkChart from "../../charts/NetworkChart";
import LoadAverageChart from "../../charts/LoadAverageChart.jsx"

import styles from "./Reports.module.css";

function Reports() {
    const [folders, setFolders] = useState([]);
    const [selectedFolder, setSelectedFolder] = useState(null);
    const [folderData, setFolderData] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    // Fetch folders on mount
    useEffect(() => {
        axios
            .post("http://localhost:8000/reports/folders")
            .then((res) => {
                setFolders(res.data);
            })
            .catch(() => {
                setError("Failed to load folders");
            });
    }, []);

    // Open a folder
    const openFolder = async (folderName) => {
        setSelectedFolder(folderName);
        setLoading(true);
        setError(null);

        try 
        {
            const res = await axios.get(
                `http://localhost:8000/reports/folders/${folderName}`
            );
            setFolderData(res.data); // save the folder logs
            console.log(folderData);
        } 
        catch 
        {
            setError("Failed to load folder content");
        } 
        finally 
        {
            setLoading(false);
        }
    };

    const renderMetrics = () => {
        if (!folderData) return null;

        const { cpu, gpu, memory, disk: disks, network, uptimeData} = folderData;

        return (
            <div style={{ display: "flex", flexDirection: "column", gap: "2rem" }}>
                <CpuGpuChart cpuData={cpu} gpuData={gpu} />
                {/* RAM + Virtual Memory Line Chart */}
                <MemoryLineChart ram={memory.ram} virtual={memory.virtual} />
                <NetworkChart data={network} />
                <DiskBarChart diskSnapshots={disks} />
                <DiskChart diskSnapshots={disks} />
                <LoadAverageChart uptimeData={uptimeData} />
            </div>
        );
    };

    return (
        <div className={styles.main}>
            <div className={styles.sidebar}>
                    <div className={styles.listitems}>
                        < FaArrowLeft className={styles.icons} />
                        <Link Link className={styles.links} to="/">Back to monitoring</Link>
                    </div>
                <div className={styles.asideTop}>
                    <h3>Folders</h3>
                </div>
                {folders.map((f) => (
                    <div
                        key={f}
                        className={`${styles.folder} ${selectedFolder === f ? styles.active : ""}`}
                        onClick={() => openFolder(f)}
                    >
                        {f}
                    </div>
                ))}
            </div>

            <div className={styles.container}>
                <div className={styles.top}>
                    <h2 className={styles.title}>Reports</h2>
                </div>

                <div className={styles.body}>
                    {error && <p className={styles.error}>{error}</p>}
                    {loading && <p>Loading...</p>}
                    {!loading && !selectedFolder && <p>Select a report folder</p>}
                    {!loading && selectedFolder && renderMetrics()}
                </div>
            </div>
        </div>
    );
}

export default Reports;
