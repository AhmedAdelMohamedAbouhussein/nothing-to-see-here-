import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";

export default function DiskBarChart({ diskSnapshots = [] }) {
  if (!diskSnapshots.length) return <p>No Disk Data Available</p>;

  // Use the latest snapshot
  const latest = diskSnapshots[diskSnapshots.length - 1];
  if (!latest.disks || !latest.disks.length) return <p>No Disks Found</p>;

  // Flatten partitions into chart data
  const data = latest.disks.flatMap(disk => 
    disk.partitions.map(part => ({
      name: part.name,
      used: part.used ? parseFloat(part.used) : 0,
    }))
  );

  if (!data.length) return <p>No Partition Usage Data</p>;

  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data} margin={{ top: 20, right: 30, left: 0, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="name" tick={{ fontSize: 12 }} />
        <YAxis tick={{ fontSize: 12 }} />
        <Tooltip />
        <Bar dataKey="used" fill="#8884d8" />
      </BarChart>
    </ResponsiveContainer>
  );
}
