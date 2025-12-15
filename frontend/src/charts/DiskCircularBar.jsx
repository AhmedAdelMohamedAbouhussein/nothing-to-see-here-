import { CircularProgressbar, buildStyles } from "react-circular-progressbar";
import 'react-circular-progressbar/dist/styles.css';
import styles from "./DiskProgressChart.module.css";

export default function DiskProgressChart({ diskSnapshots = [] }) {
    if (!diskSnapshots.length) return <p>No Disk Data Available</p>;

    // Use the latest snapshot
    const latest = diskSnapshots[diskSnapshots.length - 1];
    if (!latest.disks || !latest.disks.length) return <p>No Disks Found</p>;

    const parseSize = (size) => {
        if (!size) return 0;
        const unit = size.slice(-1).toUpperCase();
        const num = parseFloat(size);
        switch (unit) {
            case "K": return num / 1024 / 1024;
            case "M": return num / 1024;
            case "G": return num;
            case "T": return num * 1024;
            default: return num;
        }
    };

    return (
        <div className={styles.diskContainer}>
            {latest.disks.map((disk, idx) => {
                const totalSize = parseSize(disk.size);
                const usedSize = disk.partitions.reduce((acc, p) => acc + parseSize(p.used || "0"), 0);
                const usedPercent = totalSize ? (usedSize / totalSize) * 100 : 0;

                return (
                    <div key={idx} className={styles.disk}>
                        <h4>{disk.name} (Total: {disk.size})</h4>
                        <p>Used: {usedSize.toFixed(2)}G / {totalSize}G</p>
                        <div className={styles.diskCircle}>
                            <CircularProgressbar
                                value={usedPercent}
                                text={`${usedPercent.toFixed(1)}%`}
                                styles={buildStyles({
                                    textSize: '16px',
                                    pathColor: '#8884d8',
                                    trailColor: '#eee'
                                })}
                            />
                        </div>

                        {disk.partitions.length > 0 && (
                            <div className={styles.partitions}>
                                {disk.partitions.map((p, pIdx) => {
                                    const partTotal = parseSize(p.size || "0");
                                    const partUsed = parseSize(p.used || "0");
                                    const partitionUsedPercent = partTotal ? (partUsed / partTotal) * 100 : 0;

                                    return (
                                        <div key={pIdx} className={styles.partition}>
                                            <h5>{p.name} ({p.size || "Unknown"})</h5>
                                            {p.mount && <p>Mount: {p.mount}</p>}
                                            <p>Used: {partUsed.toFixed(2)}G / {partTotal}G</p>
                                            <CircularProgressbar
                                                value={partitionUsedPercent}
                                                text={`${partitionUsedPercent.toFixed(1)}%`}
                                                styles={buildStyles({
                                                    textSize: '12px',
                                                    pathColor: '#82ca9d',
                                                    trailColor: '#eee'
                                                })}
                                            />
                                        </div>
                                    );
                                })}
                            </div>
                        )}
                    </div>
                );
            })}
        </div>
    );
}
