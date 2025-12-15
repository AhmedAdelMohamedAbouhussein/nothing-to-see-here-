import React from "react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer
} from "recharts";

export default function LoadAverageChart({ uptimeData = [] }) {
  if (!uptimeData.length) return <p style={{ color: "#fff" }}>No Load Data</p>;

  const chartContainerStyle = {
    backgroundColor: "#0a1f3c", // same blue background
    padding: "20px",
    borderRadius: "12px"
  };

  const cartesianGridColor = "#2a3b5f";
  const axisProps = { stroke: "#fff", tick: { fill: "#fff" } };
  const tooltipStyle = { backgroundColor: "#1a2a4f", border: "none", color: "#fff" };
  const legendStyle = { color: "#fff" };

  return (
    <div style={chartContainerStyle}>
      <h3 style={{ color: "#fff" }}>Load Average (1, 5, 15 min)</h3>
      <ResponsiveContainer width="100%" height={250}>
        <LineChart data={uptimeData} margin={{ top: 20, right: 30, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke={cartesianGridColor} />
          <XAxis dataKey="time" {...axisProps} />
          <YAxis {...axisProps} />
          <Tooltip contentStyle={tooltipStyle} />
          <Legend wrapperStyle={legendStyle} verticalAlign="top" height={36} />
          <Line type="monotone" dataKey="loadOne" stroke="#8884d8" name="1 min" dot={false} />
          <Line type="monotone" dataKey="loadFive" stroke="#82ca9d" name="5 min" dot={false} />
          <Line type="monotone" dataKey="loadFifteen" stroke="#ffc658" name="15 min" dot={false} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
