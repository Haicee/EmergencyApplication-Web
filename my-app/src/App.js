import React, { useState } from "react";
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import Dashboard from "./Dashboard";
import './index.css';
import './App.css';
// Import placeholder pages
import ManageUsers from "./ManageUsers";
import EmergencyCalls from "./EmergencyCalls";
import Layout from "./Layout";
import Login from "./Login";
import ReportStatus from "./ReportStatus";

function App() {
  // Persist login across refresh using localStorage set in Login.jsx
  const initialSession = (() => {
    try {
      const raw = localStorage.getItem('resme_admin');
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  })();
  const isInactive = !!(initialSession && (initialSession.status || 'Active') === 'Inactive');
  if (isInactive) {
    // Clear invalid session if account is inactive
    try { localStorage.removeItem('resme_admin'); } catch {}
  }
  const [isLoggedIn, setIsLoggedIn] = useState(!!(initialSession && initialSession.role === 'Admin' && !isInactive));
  const [loginBanner, setLoginBanner] = useState(isInactive ? 'Account is Inactivated. Please activate it to access the Admin.' : '');

  const handleLogout = () => {
    try { localStorage.removeItem('resme_admin'); } catch {}
    setIsLoggedIn(false);
  };

  if (!isLoggedIn) {
    return <Login onLogin={() => setIsLoggedIn(true)} initialError={loginBanner} />;
  }

  return (
    <Router>
      <Routes>
        <Route path="/" element={<Layout onLogout={handleLogout} />}>
          <Route index element={<Dashboard />} />
          <Route path="manage-users" element={<ManageUsers />} />
          <Route path="emergency-calls" element={<EmergencyCalls />} />
          <Route path="report-status" element={<ReportStatus />} />
          <Route path="*" element={<Navigate to="/" />} />
        </Route>
      </Routes>
    </Router>
  );
}

export default App;
