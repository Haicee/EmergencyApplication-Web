import React, { useState } from "react";
import { NavLink, Outlet, useLocation } from "react-router-dom";

const PAGE_TITLES = {
  "/": "Dashboard",
  "/manage-users": "Manage Users",
  "/emergency-calls": "Emergency Calls",
  "/security-backups": "Security & Backups",
  "/system-logs": "System Performance & Activity Logs",
};

export default function Layout({ onLogout }) {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const location = useLocation();

  // Find the best matching title
  const title = PAGE_TITLES[location.pathname] || "Dashboard";

  return (
    <div className="min-h-screen bg-gray-100">
      
      <div className="flex">
        {/* Sidebar */}
        <aside
          className={`z-20 bg-white border-r min-h-screen flex flex-col fixed top-0 left-0 h-full transition-all duration-300 ${sidebarOpen ? "w-56" : "w-20"}`}
        >
          <div className="flex flex-col items-center gap-2 px-4 py-6">
            <span className="inline-flex items-center justify-center w-10 h-10 rounded-lg bg-gradient-to-br from-red-400 to-red-600 shadow-md">
              {/* Shield Icon */}
              <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="white">
                <rect width="24" height="24" rx="12" fill="none"/>
                <path d="M12 12a3 3 0 100-6 3 3 0 000 6z" stroke="white" strokeWidth="1.5"/>
                <path d="M19.5 19.5v-1.2a3.3 3.3 0 00-3.3-3.3h-8.4a3.3 3.3 0 00-3.3 3.3v1.2" stroke="white" strokeWidth="1.5" strokeLinecap="round"/>
              </svg>
            </span>
            {sidebarOpen && <span className="font-bold text-sm text-center">ResMe</span>}
          </div>
          {/* Nav links only show when sidebarOpen */}
          {sidebarOpen && (
            <nav className="mt-2 flex-1">
              <NavLink to="/" end className={({isActive}) => `flex items-center gap-2 px-4 py-2 rounded-r-full font-medium ${isActive ? 'bg-red-50 text-red-600' : 'text-gray-700 hover:bg-gray-100'}`}>Dashboard</NavLink>
              <NavLink to="/manage-users" className={({isActive}) => `flex items-center gap-2 px-4 py-2 rounded-r-full font-medium ${isActive ? 'bg-red-50 text-red-600' : 'text-gray-700 hover:bg-gray-100'}`}>Manage Users</NavLink>
              <NavLink to="/emergency-calls" className={({isActive}) => `flex items-center gap-2 px-4 py-2 rounded-r-full font-medium ${isActive ? 'bg-red-50 text-red-600' : 'text-gray-700 hover:bg-gray-100'}`}>Emergency Calls Logs</NavLink>
              <NavLink to="/security-backups" className={({isActive}) => `flex items-center gap-2 px-4 py-2 rounded-r-full font-medium ${isActive ? 'bg-red-50 text-red-600' : 'text-gray-700 hover:bg-gray-100'}`}>Security & Backups</NavLink>
              <NavLink to="/system-logs" className={({isActive}) => `flex items-center gap-2 px-4 py-2 rounded-r-full font-medium ${isActive ? 'bg-red-50 text-red-600' : 'text-gray-700 hover:bg-gray-100'}`}>System Performance & Activity Logs</NavLink>
              <NavLink to="/report-status" className={({isActive}) => `flex items-center gap-2 px-4 py-2 rounded-r-full font-medium ${isActive ? 'bg-red-50 text-red-600' : 'text-gray-700 hover:bg-gray-100'}`}>Report Status</NavLink>
            </nav>
          )}
        </aside>
        {/* Overlay for mobile when sidebar is open */}
        {sidebarOpen && (
          <div
            className="fixed inset-0 bg-black bg-opacity-30 z-10 md:hidden"
            onClick={() => setSidebarOpen(false)}
          />
        )}
        {/* Main Content */}
        <main className={`flex-1 transition-all duration-300 ${sidebarOpen ? "ml-56" : "ml-20"}`}>
          {/* Top Navigation */}
          <div className="flex items-center justify-between px-6 py-4 bg-white border-b sticky  z-20">
            <div className="flex items-center gap-0">
              {/* Hamburger */}
              <button
                className="text-gray-500 focus:outline-none"
                onClick={() => setSidebarOpen((v) => !v)}
              >
                <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeWidth="2" d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              </button>
              <span className="font-bold text-lg text-gray-700 ml-4">{title}</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-blue-100 text-blue-700 font-bold">
                A
              </span>
              <span className="text-sm text-gray-700 mr-2">Admin</span>
              <button 
                onClick={onLogout}
                className="bg-red-500 hover:bg-red-600 text-white text-xs px-3 py-1 rounded"
              >
                Logout
              </button>
            </div>
          </div>
          <Outlet />
        </main>
      </div>
    </div>
  );
} 