import React, { useState } from "react";

const stations = [
  { id: 1, name: "Station 1", location: "Downtown", reports: 2 },
  { id: 2, name: "Station 2", location: "Riverside", reports: 1 },
  { id: 3, name: "Station 3", location: "Uptown", reports: 3 },
];

const incidentsByStation = {
  1: [
    { barangay: "Barangay A", type: "Theft", date: "2024-06-01", status: "Resolved", amount: 5000 },
    { barangay: "Barangay B", type: "Assault", date: "2024-06-03", status: "Ongoing", amount: 0 },
  ],
  2: [
    { barangay: "Barangay C", type: "Robbery", date: "2024-06-02", status: "Resolved", amount: 12000 },
  ],
  3: [
    { barangay: "Barangay D", type: "Vandalism", date: "2024-06-04", status: "Ongoing", amount: 2000 },
    { barangay: "Barangay E", type: "Burglary", date: "2024-06-05", status: "Resolved", amount: 8000 },
    { barangay: "Barangay F", type: "Theft", date: "2024-06-06", status: "Ongoing", amount: 3000 },
  ],
  4: [
    { barangay: "Barangay G", type: "Fraud", date: "2024-06-07", status: "Resolved" },
  ],
};

const maxReports = Math.max(...stations.map(s => s.reports));

export default function ReportStatus() {
  const [selectedStation, setSelectedStation] = useState(null);

  return (
    <div className="p-6">
      <div className="overflow-x-auto">
        <table className="min-w-full bg-white border rounded shadow">
          <thead>
            <tr>
              <th className="px-4 py-2 border-b">Station Name</th>
              <th className="px-4 py-2 border-b">Location</th>
              <th className="px-4 py-2 border-b">Incident Reports</th>
            </tr>
          </thead>
          <tbody>
            {stations.map(station => (
              <tr
                key={station.id}
                className={
                  (station.reports === maxReports ? "bg-red-100 font-bold " : "") +
                  "cursor-pointer hover:bg-blue-50"
                }
                onClick={() => setSelectedStation(station)}
              >
                <td className="px-4 py-2 border-b">{station.name}</td>
                <td className="px-4 py-2 border-b">{station.location}</td>
                <td className="px-4 py-2 border-b text-center">{station.reports}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {selectedStation && (
        <div className="mt-8 bg-white rounded shadow p-6 border">
          <div className="flex justify-between items-center mb-4">
            <h3 className="text-xl font-semibold">Incident Details for {selectedStation.name}</h3>
            <button className="text-red-500 hover:underline" onClick={() => setSelectedStation(null)}>Close</button>
          </div>
          <table className="min-w-full">
            <thead>
              <tr>
                <th className="px-4 py-2 border-b">Barangay</th>
                <th className="px-4 py-2 border-b">Type</th>
                <th className="px-4 py-2 border-b">Date</th>
                <th className="px-4 py-2 border-b">Status</th>
                <th className="px-4 py-2 border-b">Amount (₱)</th>
              </tr>
            </thead>
            <tbody>
              {(incidentsByStation[selectedStation.id] || []).map((incident, idx) => (
                <tr key={idx}>
                  <td className="px-4 py-2 border-b">{incident.barangay}</td>
                  <td className="px-4 py-2 border-b">{incident.type}</td>
                  <td className="px-4 py-2 border-b">{incident.date}</td>
                  <td className="px-4 py-2 border-b">{incident.status}</td>
                  <td className="px-4 py-2 border-b text-right">{incident.amount.toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
} 