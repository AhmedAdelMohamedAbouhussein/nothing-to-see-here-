import {Routes, Route} from 'react-router-dom'
import Monitor from "./pages/monitor/Monitor.jsx";
import Report from "./pages/reports/Reports.jsx";


function App() {
  return (
    <Routes>
      <Route path="/" element={<Monitor />} />
      <Route path="/report" element={<Report />} />
    </Routes>
  )
}

export default App
