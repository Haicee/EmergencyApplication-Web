import React, { useState } from "react";
import { LockClosedIcon } from '@heroicons/react/solid';

const backupHistoryData = [
  {
    date: "2024-01-20 14:30",
    size: "2.3 GB",
    type: "Full",
    status: "Completed",
  },
  {
    date: "2024-01-19 14:30",
    size: "1.8 GB",
    type: "Incremental",
    status: "Completed",
  },
  {
    date: "2024-01-18 14:30",
    size: "2.1 GB",
    type: "Full",
    status: "Completed",
  },
  {
    date: "2024-01-17 14:30",
    size: "1.5 GB",
    type: "Incremental",
    status: "Failed",
  },
];

const TypeBadge = ({ type }) => {
    const baseClasses = "px-2 py-1 text-xs font-medium rounded-full";
    switch (type) {
      case "Full":
        return <span className={`${baseClasses} bg-red-100 text-red-600`}>{type}</span>;
      case "Incremental":
        return <span className={`${baseClasses} bg-green-100 text-green-600`}>{type}</span>;
      default:
        return <span className={`${baseClasses} bg-gray-100 text-gray-600`}>{type}</span>;
    }
};

const StatusIndicator = ({ status }) => {
    const isCompleted = status === "Completed";
    return (
        <div className="flex items-center">
            <span className={`h-2 w-2 rounded-full mr-2 ${isCompleted ? 'bg-green-500' : 'bg-red-500'}`}></span>
            {status}
        </div>
    );
};


export default function SecurityBackups() {
  const [encryptionEnabled, setEncryptionEnabled] = useState(true);

  return (
    <div className="p-8 bg-gray-50 min-h-screen">
      {/* Encryption Settings */}
      <div className="bg-white p-6 rounded-lg shadow mb-8">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">Encryption Settings</h2>
        <div className="flex items-center justify-between">
          <div className="flex items-center">
            <div className="p-2 bg-red-100 rounded-full mr-4">
                <LockClosedIcon className="h-6 w-6 text-red-500"/>
            </div>
            <div>
              <div className="font-medium text-gray-700">Enable Encryption</div>
              <div className="text-sm text-gray-500">Secure all data with AES-256 encryption</div>
            </div>
          </div>
          <button 
            onClick={() => setEncryptionEnabled(!encryptionEnabled)}
            className={`relative inline-flex items-center h-6 rounded-full w-11 transition-colors duration-200 ease-in-out ${encryptionEnabled ? 'bg-green-500' : 'bg-gray-300'}`}
          >
            <span className={`inline-block w-4 h-4 transform bg-white rounded-full transition-transform duration-200 ease-in-out ${encryptionEnabled ? 'translate-x-6' : 'translate-x-1'}`}/>
          </button>
        </div>
      </div>

      {/* Backup Configuration */}
      <div className="bg-white p-6 rounded-lg shadow mb-8">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">Backup Configuration</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-4">
          <InputField label="Schedule Backup" type="select" options={["Daily", "Weekly", "Monthly"]} />
          <InputField label="Backup Time" type="time" defaultValue="22:00" />
          <InputField label="Backup Type" type="select" options={["Incremental", "Full"]} />
          <InputField label="Backup Destination" type="text" defaultValue="/backup/cloud/" />
        </div>
        <button className="px-5 py-2 bg-red-500 text-white font-semibold rounded-lg hover:bg-red-600">
          Run Backup Now
        </button>
      </div>

      {/* Backup History */}
      <div className="bg-white p-6 rounded-lg shadow">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">Backup History</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm text-left text-gray-500">
            <thead className="text-xs text-gray-700 uppercase bg-gray-50">
              <tr>
                <th scope="col" className="px-6 py-3">Date</th>
                <th scope="col" className="px-6 py-3">Size</th>
                <th scope="col" className="px-6 py-3">Type</th>
                <th scope="col" className="px-6 py-3">Status</th>
                <th scope="col" className="px-6 py-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {backupHistoryData.map((backup, index) => (
                <tr key={index} className="bg-white border-b hover:bg-gray-50">
                  <td className="px-6 py-4">{backup.date}</td>
                  <td className="px-6 py-4">{backup.size}</td>
                  <td className="px-6 py-4"><TypeBadge type={backup.type} /></td>
                  <td className="px-6 py-4"><StatusIndicator status={backup.status} /></td>
                  <td className="px-6 py-4">
                    <a href="#" className="font-medium text-red-600 hover:underline mr-4">Restore</a>
                    <a href="#" className="font-medium text-gray-600 hover:underline">Download</a>
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

const InputField = ({ label, type, options, defaultValue }) => (
  <div>
    <label className="block text-sm font-medium text-gray-500 mb-1">{label}</label>
    {type === 'select' ? (
      <select className="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500">
        {options.map(option => <option key={option}>{option}</option>)}
      </select>
    ) : (
      <input type={type} defaultValue={defaultValue} className="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" />
    )}
  </div>
);
