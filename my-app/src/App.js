import React, { useState } from "react";
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import Dashboard from "./Dashboard";
import './index.css';
import './App.css';
// Import placeholder pages
import ManageUsers from "./ManageUsers";
import EmergencyCalls from "./EmergencyCalls";
import SecurityBackups from "./SecurityBackups";
import SystemLogs from "./SystemLogs";
import Layout from "./Layout";
import Login from "./Login";
import ReportStatus from "./ReportStatus";

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);

  const handleLogout = () => {
    setIsLoggedIn(false);
  };

  if (!isLoggedIn) {
    return <Login onLogin={() => setIsLoggedIn(true)} />;
  }

  return (
    <Router>
      <Routes>
        <Route path="/" element={<Layout onLogout={handleLogout} />}>
          <Route index element={<Dashboard />} />
          <Route path="manage-users" element={<ManageUsers />} />
          <Route path="emergency-calls" element={<EmergencyCalls />} />
          <Route path="security-backups" element={<SecurityBackups />} />
          <Route path="system-logs" element={<SystemLogs />} />
          <Route path="report-status" element={<ReportStatus />} />
          <Route path="*" element={<Navigate to="/" />} />
        </Route>
      </Routes>
    </Router>
  );
}

export default App;
