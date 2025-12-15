import React from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  LabelList
} from "recharts";

export default function DiskBarChart({ diskSnapshots = [] }) {
  if (!diskSnapshots.length) return <p style={{ color: "#fff" }}>No Disk Data Available</p>;

  const latest = diskSnapshots[diskSnapshots.length - 1];
  if (!latest.disks || !latest.disks.length) return <p style={{ color: "#fff" }}>No Disks Found</p>;

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

  const chartData = latest.disks.map((disk) => {
    const total = parseSize(disk.size);
    const used = disk.partitions.reduce((acc, p) => acc + parseSize(p.used || "0"), 0);
    return {
      name: disk.name,
      used,
      free: Math.max(total - used, 0)
    };
  });

  return (
    <div style={{ backgroundColor: "#0a1f3c", padding: "15px", borderRadius: "12px" }}>
      <ResponsiveContainer width="100%" height={350}>
        <BarChart
          data={chartData}
          margin={{ top: 20, right: 30, left: 20, bottom: 20 }}
        >
          <CartesianGrid strokeDasharray="3 3" stroke="#2a3b5f" />
          <XAxis dataKey="name" stroke="#fff" />
          <YAxis stroke="#fff" unit=" GB" />
          <Tooltip
            contentStyle={{ backgroundColor: "#1a2a4f", border: "none", color: "#fff" }}
            formatter={(value) => `${value.toFixed(2)} GB`}
          />
          <Legend wrapperStyle={{ color: "#fff" }} />
          <Bar dataKey="used" stackId="a" fill="#ff6b6b">
            <LabelList dataKey="used" position="insideTop" fill="#fff" formatter={(val) => val.toFixed(1)} />
          </Bar>
          <Bar dataKey="free" stackId="a" fill="#4ecdc4">
            <LabelList dataKey="free" position="insideTop" fill="#fff" formatter={(val) => val.toFixed(1)} />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
