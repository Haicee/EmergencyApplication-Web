import React from "react";

export default function SystemLogs() {
  return (
    <div className="p-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div className="bg-white rounded-lg shadow p-6 flex flex-col items-center">
          <div className="bg-red-100 text-red-600 rounded-full p-2 mb-2">
            <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path d="M12 12a3 3 0 100-6 3 3 0 000 6z" strokeWidth="1.5"/><path d="M19.5 19.5v-1.2a3.3 3.3 0 00-3.3-3.3h-8.4a3.3 3.3 0 00-3.3 3.3v1.2" strokeWidth="1.5" strokeLinecap="round"/></svg>
          </div>
          <div className="text-sm text-gray-500">Total Registered Users</div>
          <div className="text-xs text-gray-400 mb-2">Active users in the system</div>
          <div className="text-3xl font-bold text-red-600">245</div>
        </div>
        <div className="bg-white rounded-lg shadow p-6 flex flex-col items-center">
          <div className="bg-red-100 text-red-600 rounded-full p-2 mb-2">
            <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path d="M12 8v4l3 3" strokeWidth="1.5" strokeLinecap="round"/></svg>
          </div>
          <div className="text-sm text-gray-500">Total Emergency Calls</div>
          <div className="text-xs text-gray-400 mb-2">Currently in progress</div>
          <div className="text-3xl font-bold text-red-600">3</div>
        </div>
        <div className="bg-white rounded-lg shadow p-6 flex flex-col items-center">
          <div className="bg-red-100 text-red-600 rounded-full p-2 mb-2">
            <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path d="M12 8v4l3 3" strokeWidth="1.5" strokeLinecap="round"/></svg>
          </div>
          <div className="text-sm text-gray-500">Total Incident Reports</div>
          <div className="text-xs text-gray-400 mb-2">Documented cases</div>
          <div className="text-3xl font-bold text-red-600">112</div>
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
        <div className="bg-white rounded-lg shadow p-6 flex flex-col items-center">
          <div className="bg-red-100 text-red-600 rounded-full p-2 mb-2">
            <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor"><circle cx="12" cy="12" r="10" strokeWidth="1.5"/><path d="M12 8v4l3 3" strokeWidth="1.5" strokeLinecap="round"/></svg>
          </div>
          <div className="text-sm text-gray-500">System Status</div>
          <div className="text-xs text-gray-400 mb-2">Overall system health</div>
          <div className="flex items-center gap-2 mt-2">
            <span className="h-3 w-3 bg-green-500 rounded-full inline-block"></span>
            <span className="text-green-600 text-sm font-medium">All Systems Operational</span>
          </div>
        </div>
        <div className="bg-white rounded-lg shadow p-6 flex flex-col items-center">
          <div className="bg-red-100 text-red-600 rounded-full p-2 mb-2">
            <svg width="28" height="28" fill="none" viewBox="0 0 24 24" stroke="currentColor"><rect x="6" y="6" width="12" height="12" rx="2" strokeWidth="1.5"/></svg>
          </div>
          <div className="text-sm text-gray-500">Backup Status</div>
          <div className="text-xs text-gray-400 mb-2">&nbsp;</div>
          <div className="flex items-center gap-2 mt-2">
            <span className="h-3 w-3 bg-green-500 rounded-full inline-block"></span>
            <span className="text-green-600 text-sm font-medium">Successful</span>
          </div>
        </div>
      </div>
      {/* Admin Activity Log */}
      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <div className="font-semibold text-gray-700 mb-2">Admin Activity Log</div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="bg-gray-50 text-gray-500">
                <th className="px-4 py-2 text-left">Date & Time</th>
                <th className="px-4 py-2 text-left">Admin</th>
                <th className="px-4 py-2 text-left">Action</th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-b">
                <td className="px-4 py-2">April 18, 10:21 AM</td>
                <td className="px-4 py-2">Admin</td>
                <td className="px-4 py-2">Updated user record: Citizen-032</td>
              </tr>
              <tr className="border-b">
                <td className="px-4 py-2">April 18, 09:12 AM</td>
                <td className="px-4 py-2">Admin</td>
                <td className="px-4 py-2">Modified backup schedule</td>
              </tr>
              <tr className="border-b">
                <td className="px-4 py-2">April 17, 03:45 PM</td>
                <td className="px-4 py-2">Admin</td>
                <td className="px-4 py-2">Logged in</td>
              </tr>
              <tr>
                <td className="px-4 py-2">April 17, 03:47 PM</td>
                <td className="px-4 py-2">Admin</td>
                <td className="px-4 py-2">Restored backup (Apr 15)</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      {/* Desk Officer Activity Log */}
      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <div className="font-semibold text-gray-700 mb-2">Desk Officer Activity Log</div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="bg-gray-50 text-gray-500">
                <th className="px-4 py-2 text-left">Time</th>
                <th className="px-4 py-2 text-left">Station</th>
                <th className="px-4 py-2 text-left">Action</th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-b">
                <td className="px-4 py-2">08:45 AM</td>
                <td className="px-4 py-2">Police Station 1</td>
                <td className="px-4 py-2">Accepted emergency call from Citizen-009</td>
              </tr>
              <tr className="border-b">
                <td className="px-4 py-2">08:50 AM</td>
                <td className="px-4 py-2">Police Station 1</td>
                <td className="px-4 py-2">Created Incident Report #IR-2025-018</td>
              </tr>
              <tr>
                <td className="px-4 py-2">09:15 AM</td>
                <td className="px-4 py-2">Police Station 1</td>
                <td className="px-4 py-2">Ended call with Citizen-011</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
} 