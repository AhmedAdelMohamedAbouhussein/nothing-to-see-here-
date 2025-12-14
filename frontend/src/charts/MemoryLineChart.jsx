import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from "recharts";

export default function MemoryLineChart({ ram = [], virtual = [] }) {
  if (!ram.length && !virtual.length) return <p>No Memory Data</p>;

  // Combine RAM and Virtual Memory data by timestamp
  const data = ram.map((r, i) => ({
    time: r.time.split(" ")[1] || r.time,
    RAM: r.usagePercent,
    'Virtual Memory': virtual[i] ? virtual[i].usagePercent : null,
    ramUsedGB: r.used,
    virtualUsedGB: virtual[i] ? virtual[i].used : null,
  }));

  return (
    <ResponsiveContainer width="100%" height={300}>
      <LineChart data={data} margin={{ top: 20, right: 30, left: 0, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="time" tick={{ fontSize: 12 }} />
        <YAxis domain={[0, 100]} tick={{ fontSize: 12 }} />
        <Tooltip 
          formatter={(value, name, props) => [`${value}%`, name]} 
          labelFormatter={(label) => `Time: ${label}`} 
        />
        <Legend />
        <Line type="monotone" dataKey="RAM" stroke="#8884d8" dot={false} />
        <Line type="monotone" dataKey="Virtual Memory" stroke="#82ca9d" dot={false} />
      </LineChart>
    </ResponsiveContainer>
  );
}
