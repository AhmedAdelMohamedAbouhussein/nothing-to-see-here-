import fs from "fs";

export const parseCpuLog = (filePath) => {
    const lines = fs.readFileSync(filePath, "utf-8")
        .split("\n")
        .map(line => line.trim())
        .filter(line => line);

    const cpuData = [];

    for (const line of lines) {
        const match = line.match(/(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec): CPU Usage: ([\d.]+)% CPU Temperature: ([\d.]+)°C/);
        if (match) {
            cpuData.push({
                time: match[1],
                usage: Number(match[2]),
                temperature: Number(match[3])
            });
        }
    }

    return cpuData;
};

export const parseGpuLog = (filePath) => {
    const lines = fs.readFileSync(filePath, "utf-8").split("\n").filter(Boolean);
    const gpuData = [];

    for (const line of lines) {
        const match = line.match(/(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec): GPU Usage=([\d.]+) GPU Temp=([\d.]+)/);
        if (match) {
            gpuData.push({
                time: match[1],
                usage: Number(match[2]),
                temperature: Number(match[3])
            });
        }
    }

    return gpuData;
};


export const parseMemoryLog = (filePath) => {
    const lines = fs.readFileSync(filePath, "utf-8")
        .split("\n")
        .map(line => line.trim())
        .filter(line => line);

    const memoryData = [];
    const virtualData = [];

    for (const line of lines) {
        // RAM line
        const ramMatch = line.match( /(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec): Memory Utilization: ([\d.]+) Memory Used: ([\d.]+) GB Memory Total: ([\d.]+) GB/);
        if (ramMatch) {
            memoryData.push({
                time: ramMatch[1],
                usagePercent: Number(ramMatch[2]),
                used: Number(ramMatch[3]),
                total: Number(ramMatch[4])
            });
        }

        // Virtual Memory line
        const vmMatch = line.match( /(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec): Virtual Memory Utilization: ([\d.]+) Virtual Memory Used: ([\d.]+) GB Virtual Memory Total: ([\d.]+) GB/);
        if (vmMatch) {
            virtualData.push({
                time: vmMatch[1],
                usagePercent: Number(vmMatch[2]),
                used: Number(vmMatch[3]),
                total: Number(vmMatch[4])
            });
        }
    }

    return { ram: memoryData, virtual: virtualData };
};




export const parseDiskLog = (filePath) => {
    const content = fs.readFileSync(filePath, "utf-8");
    const lines = content.split("\n").filter(Boolean);

    const snapshots = [];
    let currentSnapshot = null;
    let currentDisk = null;

    for (const line of lines) {
        // New snapshot (timestamp)
        const timestampMatch = line.match(/^(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec):/);
        if (timestampMatch) {
            const timestamp = timestampMatch[1];
            if (!currentSnapshot || currentSnapshot.timestamp !== timestamp) {
                currentSnapshot = { timestamp, disks: [] };
                snapshots.push(currentSnapshot);
                currentDisk = null;
            }

            // Disk line
            const diskMatch = line.match(/disk: (\S+)\s+(\S+)/);
            if (diskMatch) {
                const [name, size] = diskMatch;
                currentDisk = { name, size, partitions: [] };
                currentSnapshot.disks.push(currentDisk);
                continue;
            }

            // Partition line
            const partitionMatch = line.match(
                /partition: (\S+)\s+(\S+)\s+(\S+)(?:\s+(\S+))?(?:\s+([\d.]+[KMGT]?) used)?(?:\s+(\d+%)?)?/
            );
            if (partitionMatch && currentDisk) {
                const [, name, size, type, mount, used, usePercent] = partitionMatch;
                const partition = { name, size, type };
                if (mount) partition.mount = mount;
                if (used) partition.used = used;
                if (usePercent) partition.usePercent = usePercent;
                currentDisk.partitions.push(partition);
            }
        }
    }

    return snapshots;
};


export const parseNetworkLog = (filePath) => {
    const content = fs.readFileSync(filePath, "utf-8");
    
    const received = content.match(/Network Received:\s*(\d+)/)?.[1];
    const transmitted = content.match(/Network Transmitted:\s*(\d+)/)?.[1];
    return {
        received: received ? Number(received) : null,
        transmitted: transmitted ? Number(transmitted) : null
    };
};

export const smartstatusLog = (filePath) => {
    const content = fs.readFileSync(filePath, "utf-8");

    const status = content.match(/SMART overall-health self-assessment test result:\s*(\w+)/)?.[1];

    return {
        status: status || null
    };
};