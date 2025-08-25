import React, { useState } from "react";
import { ClockIcon, CheckCircleIcon, XCircleIcon, DownloadIcon, SearchIcon, TrashIcon, PencilIcon } from '@heroicons/react/solid';


const callsData = [
  {
    id: "EC-001",
    caller: "Juan Dela Cruz",
    callerType: "Citizen",
    time: "2024-01-20 13:45",
    location: "Lagao, General Santos City",
    status: "Ongoing",
  },
  {
    id: "EC-002",
    caller: "Maria Garcia",
    callerType: "Citizen",
    time: "2024-01-20 10:30",
    location: "City Heights, General Santos City",
    status: "Answered",
  },
  {
    id: "EC-003",
    caller: "Mark Miller",
    callerType: "Citizen",
    time: "2024-01-19 18:20",
    location: "Calumpang, General Santos City",
    status: "Missed",
  },
];

const StatusBadge = ({ status }) => {
  const baseClasses = "px-2 py-1 text-xs font-medium rounded-full";
  switch (status) {
    case "Ongoing":
      return <span className={`${baseClasses} bg-orange-100 text-orange-600`}>{status}</span>;
    case "Answered":
      return <span className={`${baseClasses} bg-green-100 text-green-600`}>{status}</span>;
    case "Missed":
      return <span className={`${baseClasses} bg-red-100 text-red-600`}>{status}</span>;
    default:
      return <span className={`${baseClasses} bg-gray-100 text-gray-600`}>{status}</span>;
  }
};


export default function EmergencyCalls() {
  const [activeFilter, setActiveFilter] = useState("All Calls");

  const handleFilterClick = (filter) => {
    setActiveFilter(filter);
  };

  const filteredCalls = callsData.filter(call => {
    if (activeFilter === 'All Calls') return true;
    if (activeFilter === 'Active') return call.status === 'Ongoing';
    if (activeFilter === 'Missed Calls') return call.status === 'Missed';
    if (activeFilter === 'Answered Calls') return call.status === 'Answered';
    return true;
  });

  const getButtonClasses = (filter) => {
    const baseClasses = "px-4 py-2 text-sm font-medium rounded-lg";
    if (activeFilter === filter) {
      return `${baseClasses} text-white bg-blue-600`;
    }
    return `${baseClasses} text-gray-600 hover:bg-gray-100`;
  }

  return (
    <div className="p-6 bg-gray-50 min-h-full">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        {/* Stat Cards */}
        <StatCard title="Ongoing Calls" value="12" icon={<ClockIcon className="h-6 w-6 text-orange-500" />} />
        <StatCard title="Answered Calls" value="45" icon={<CheckCircleIcon className="h-6 w-6 text-green-500" />} />
        <StatCard title="Missed Calls" value="3" icon={<XCircleIcon className="h-6 w-6 text-red-500" />} />
      </div>

      <div className="bg-white p-4 rounded-lg shadow">
        <div className="flex flex-col md:flex-row justify-between items-center mb-4">
            {/* Filter Tabs */}
            <div className="flex space-x-2 mb-4 md:mb-0">
                <button className={getButtonClasses("All Calls")} onClick={() => handleFilterClick("All Calls")}>All Calls</button>
                <button className={getButtonClasses("Active")} onClick={() => handleFilterClick("Active")}>Active</button>
                <button className={getButtonClasses("Missed Calls")} onClick={() => handleFilterClick("Missed Calls")}>Missed Calls</button>
                <button className={getButtonClasses("Answered Calls")} onClick={() => handleFilterClick("Answered Calls")}>Answered Calls</button>
            </div>
          <div className="flex items-center space-x-2">
            <button className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
                <DownloadIcon className="h-4 w-4"/>
                Export
            </button>
            <div className="relative">
                <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400"/>
                <input type="text" placeholder="Search here..." className="pl-10 pr-4 py-2 text-sm border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"/>
            </div>
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-sm text-left text-gray-500">
            <thead className="text-xs text-gray-700 uppercase bg-gray-50">
              <tr>
                <th scope="col" className="px-6 py-3">Call ID</th>
                <th scope="col" className="px-6 py-3">Caller</th>
                <th scope="col" className="px-6 py-3">Time</th>
                <th scope="col" className="px-6 py-3">Location</th>
                <th scope="col" className="px-6 py-3">Status</th>
                <th scope="col" className="px-6 py-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredCalls.map((call) => (
                <tr key={call.id} className="bg-white border-b hover:bg-gray-50">
                  <td className="px-6 py-4 font-medium text-gray-900">{call.id}</td>
                  <td className="px-6 py-4">
                    <div>{call.caller}</div>
                    <div className="text-xs text-gray-500">{call.callerType}</div>
                  </td>
                  <td className="px-6 py-4">{call.time}</td>
                  <td className="px-6 py-4">{call.location}</td>
                  <td className="px-6 py-4">
                    <StatusBadge status={call.status} />
                  </td>
                  <td className="px-6 py-4 flex items-center space-x-2">
                    <button className="text-gray-400 hover:text-gray-600"><PencilIcon className="h-5 w-5"/></button>
                    <button className="text-gray-400 hover:text-gray-600"><TrashIcon className="h-5 w-5"/></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

const StatCard = ({ title, value, icon }) => (
    <div className="bg-white p-5 rounded-lg shadow flex justify-between items-center">
        <div>
            <div className="text-sm text-gray-500">{title}</div>
            <div className="text-2xl font-bold text-gray-800">{value}</div>
        </div>
        <div className="bg-gray-100 p-3 rounded-full">
            {icon}
        </div>
    </div>
); 