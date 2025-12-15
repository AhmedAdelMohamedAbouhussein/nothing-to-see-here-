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
        const match = line.match(/(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec): GPU Usage: ([\d.]+)% GPU Temperature:([\d.]+)°C/);
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
        // Extract timestamp and rest of line
        const timestampMatch = line.match(/^(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec):\s*(.*)/);
        if (!timestampMatch) continue;

        const timestamp = timestampMatch[1];
        const contentLine = timestampMatch[2];

        // Start new snapshot if needed
        if (!currentSnapshot || currentSnapshot.timestamp !== timestamp) {
            currentSnapshot = { timestamp, disks: [] };
            snapshots.push(currentSnapshot);
            currentDisk = null;
        }

        // Disk line
        const diskMatch = contentLine.match(/^disk:\s*(\S+)\s+(\S+)/);
        if (diskMatch) {
            const [, name, size] = diskMatch;
            currentDisk = { name, size, partitions: [] };
            currentSnapshot.disks.push(currentDisk);
            continue;
        }

        // Partition line
        const partitionMatch = contentLine.match(
            /^partition\s*:\s*(\S+)\s+(\S+)\s+(\S+)(?:\s+(\S+))?(?:\s+([\d.]+[KMGT]?)\s*used)?(?:\s+(\d+%)?)?/
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

    return snapshots;
};


export const parseNetworkLog = (filePath) => {
  const lines = fs
    .readFileSync(filePath, "utf-8")
    .split("\n")
    .filter(line => line.includes("Network Traffic"));

  const networkData = [];

  // Helper: parse custom timestamp into milliseconds
  const parseTime = (timeStr) => {
    const match = timeStr.match(
      /(\d{4})-(\d{2})-(\d{2})-(\d{2})h-(\d{2})min-(\d{2})sec/
    );
    if (!match) return null;
    const [_, Y, M, D, h, m, s] = match;
    return new Date(`${Y}-${M}-${D}T${h}:${m}:${s}`).getTime();
  };

  for (const line of lines) {
    const timeMatch = line.match(/^(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec)/);
    const ifaceMatch = line.match(/Interface:\s*([^|]+)/);
    const incomingMatch = line.match(/Incoming_Bytes_Total:\s*(\d+)/);
    const outgoingMatch = line.match(/Outgoing_Bytes_Total:\s*(\d+)/);

    if (!timeMatch || !ifaceMatch || !incomingMatch || !outgoingMatch) continue;

    const time = timeMatch[1];
    const timestamp = parseTime(time);
    if (timestamp === null) continue;

    const iface = ifaceMatch[1].trim();
    const incomingTotal = Number(incomingMatch[1]);
    const outgoingTotal = Number(outgoingMatch[1]);

    let incomingBps = 0;
    let outgoingBps = 0;

    const last = networkData.at(-1);

    if (last && last.interface === iface) {
      const deltaTimeSec = (timestamp - last.timestamp) / 1000;
      if (deltaTimeSec > 0) {
        incomingBps = Math.max((incomingTotal - last.incomingTotal) / deltaTimeSec, 0);
        outgoingBps = Math.max((outgoingTotal - last.outgoingTotal) / deltaTimeSec, 0);
      }
    }

    networkData.push({
      time,
      timestamp,
      interface: iface,
      incomingTotal,
      outgoingTotal,
      incomingBps: Math.round(incomingBps),
      outgoingBps: Math.round(outgoingBps),
    });
  }

  return networkData;
};


export const smartstatusLog = (filePath) => {
    const content = fs.readFileSync(filePath, "utf-8");

    const status = content.match(/SMART overall-health self-assessment test result:\s*(\w+)/)?.[1];

    return {
        status: status || null
    };
};


export const parseUptimeLog = (filePath) => {
    const lines = fs
        .readFileSync(filePath, "utf-8")
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line && !line.startsWith("="));

    const uptimeData = [];

    const regex = /^(\d{4}-\d{2}-\d{2}-\d{2}h-\d{2}min-\d{2}sec):\s+\d{2}:\d{2}:\d{2}\s+up\s+(.+?),\s+(\d+)\s+user[s]?,\s+load average:\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)\s*$/;

    for (const line of lines) {
        const match = line.match(regex);

        if (!match) {
            continue;
        }

        const [
            ,
            time,
            uptime,
            users,
            loadOne,
            loadFive,
            loadFifteen,
        ] = match;

        uptimeData.push({
            time,
            uptime: uptime.replace(/\s+/g, " ").trim(),
            users: Number(users),
            loadOne: Number(loadOne),
            loadFive: Number(loadFive),
            loadFifteen: Number(loadFifteen),
        });
    }

    return uptimeData;
};
