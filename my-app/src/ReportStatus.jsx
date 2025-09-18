import React, { useEffect, useState } from "react";
import { ref, onValue, off } from 'firebase/database';
import { database } from './firebase';
import { PencilIcon, TrashIcon, EyeIcon } from '@heroicons/react/solid';

// Helper: title-case and special handling
const titleCase = (str) => (str || '')
  .toString()
  .split(/\s+/)
  .map(w => w ? w.charAt(0).toUpperCase() + w.slice(1) : '')
  .join(' ');

export default function ReportStatus() {
  const [stations, setStations] = useState([]); // ["Police Station 1", ...]
  const [selectedStation, setSelectedStation] = useState('');
  const [reportsByStation, setReportsByStation] = useState({}); // { stationName: [reports] }

  const [viewReport, setViewReport] = useState(null);
  const [editReport, setEditReport] = useState(null);

  const stationReports = reportsByStation[selectedStation] || [];

  useEffect(() => {
    const deskRef = ref(database, 'Desk Officer');
    const centralAnsweredRef = ref(database, 'StationsCallLogs/AnsweredCalls');

    const normalize = (call, callId, fallbackStation) => {
      const obj = (call && typeof call === 'object') ? call : {};
      const station = obj.station || fallbackStation || '';
      const toDate = () => {
        const t = obj.answeredAt || obj.endedAt || obj.timestamp || obj.dateTime || obj.createdAt;
        if (typeof t === 'number') {
          try { const d = new Date(t); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; } catch { return ''; }
        }
        return obj.date || '';
      };
      return {
        callId,
        callerName: obj.caller || obj.callerName || obj.name || 'Unknown',
        description: 'Please provide a description',
        date: toDate(),
        status: titleCase(obj.status || 'ended'),
        callerNumber: obj.mobile || obj.contactNumber || obj.phone || '',
        station,
      };
    };

    let deskData = {};              // snapshot of 'Desk Officer'
    let centralAnswered = {};       // snapshot of 'StationsCallLogs/AnsweredCalls'

    const buildGrouped = () => {
      const deskStations = Object.keys(deskData || {});
      const centralStations = Array.from(new Set(
        Object.values(centralAnswered || {})
          .map(c => (c && c.station) || '')
          .filter(st => st && st !== 'Unknown Station')
      ));
      const stationNames = Array.from(new Set([...(deskStations || []), ...centralStations]));

      // group using central first
      const grouped = {};
      Object.entries(centralAnswered || {}).forEach(([cid, call]) => {
        const stRaw = (call && call.station) || '';
        if (!stRaw || stRaw === 'Unknown Station') return; // skip unknowns from central
        const st = stRaw;
        if (!grouped[st]) grouped[st] = [];
        grouped[st].push(normalize(call, cid, st));
      });
      // augment with desk received calls (often booleans/short entries)
      stationNames.forEach((stationName) => {
        const stationNode = deskData[stationName];
        if (stationNode && typeof stationNode === 'object') {
          // Case A: station-level ReceivedCalls (no officer layer)
          const stationLevelAnswered = stationNode?.ReceivedCalls?.AnsweredCalls;
          if (stationLevelAnswered && typeof stationLevelAnswered === 'object') {
            Object.entries(stationLevelAnswered).forEach(([callId, call]) => {
              const chosen = centralAnswered[callId] || call;
              const row = normalize(chosen, callId, stationName);
              const st = row.station || stationName;
              if (!grouped[st]) grouped[st] = [];
              if (!grouped[st].some(r => r.callId === callId)) {
                grouped[st].push(row);
              }
            });
          }

          // Case B: officer-level ReceivedCalls
          Object.entries(stationNode).forEach(([key, val]) => {
            if (val && typeof val === 'object') {
              const answered = val?.ReceivedCalls?.AnsweredCalls;
              if (answered && typeof answered === 'object') {
                Object.entries(answered).forEach(([callId, call]) => {
                  const chosen = centralAnswered[callId] || call;
                  const row = normalize(chosen, callId, stationName);
                  const st = row.station || stationName;
                  if (!grouped[st]) grouped[st] = [];
                  // avoid duplicates if same call already from central
                  if (!grouped[st].some(r => r.callId === callId)) {
                    grouped[st].push(row);
                  }
                });
              }
            }
          });
        }
      });
      // sort by date desc (string compare adequate for YYYY-MM-DD)
      Object.keys(grouped).forEach(st => {
        grouped[st].sort((a,b) => (b.date || '').localeCompare(a.date || ''));
      });

      // Ensure Unknown Station is not shown if somehow present
      if (grouped['Unknown Station']) delete grouped['Unknown Station'];

      setReportsByStation(grouped);
      setStations(stationNames);
      if (!selectedStation && stationNames.length > 0) setSelectedStation(stationNames[0]);
      else if (selectedStation && !stationNames.includes(selectedStation)) setSelectedStation(stationNames[0] || '');
    };

    const unsubDesk = onValue(deskRef, (snap) => { deskData = snap.val() || {}; buildGrouped(); });
    const unsubCentral = onValue(centralAnsweredRef, (snap) => { centralAnswered = snap.val() || {}; buildGrouped(); });

    return () => {
      try { off(deskRef); } catch {}
      try { off(centralAnsweredRef); } catch {}
      if (typeof unsubDesk === 'function') unsubDesk();
      if (typeof unsubCentral === 'function') unsubCentral();
    };
  }, [selectedStation]);

  // Handle edit save with validation (still local only)
  const handleSaveEdit = () => {
    setReportsByStation((prev) => {
      const next = { ...prev };
      const list = next[selectedStation] ? [...next[selectedStation]] : [];
      list[editReport.index] = editReport.data;
      next[selectedStation] = list;
      return next;
    });
    setEditReport(null);
  };

  return (
    <div className="p-6">
      <label className="block mb-2 font-semibold">Select Station:</label>
      <div className="flex gap-4 mb-6">
        {stations.length === 0 ? (
          <div className="text-gray-500">No stations found.</div>
        ) : stations.map((station) => (
          <div
            key={station}
            onClick={() => setSelectedStation(station)}
            className={`cursor-pointer border rounded-lg p-4 flex-1 text-center shadow-md transition ${
              selectedStation === station ? "bg-blue-600 text-white" : "bg-white hover:bg-gray-100"
            }`}
          >
            {station}
          </div>
        ))}
      </div>

      <div className="bg-white p-4 rounded-lg shadow">
        {stationReports.length === 0 ? (
          <p className="text-gray-600">No reports for this station.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left text-gray-500">
              <thead className="text-xs text-gray-700 uppercase bg-gray-50">
                <tr>
                  <th className="px-6 py-3">Caller Name</th>
                  <th className="px-6 py-3">Description</th>
                  <th className="px-6 py-3">Date</th>
                  <th className="px-6 py-3">Status</th>
                  <th className="px-6 py-3">Caller Number</th>
                  <th className="px-6 py-3">Actions</th>
                </tr>
              </thead>
              <tbody>
                {stationReports.map((r, index) => (
                  <tr key={index} className="bg-white border-b hover:bg-gray-50">
                    <td className="px-6 py-4 font-medium text-gray-900">{r.callerName}</td>
                    <td className="px-6 py-4">{r.description}</td>
                    <td className="px-6 py-4">{r.date}</td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium inline-block ${
                        (r.status || '').toLowerCase().includes('resolv') ? 'bg-green-100 text-green-600'
                          : (r.status || '').toLowerCase().includes('ongo') || (r.status || '').toLowerCase().includes('end') ? 'bg-red-100 text-red-600' : 'bg-gray-100 text-gray-600'
                      }`}>
                        {titleCase(r.status)}
                      </span>
                    </td>
                    <td className="px-6 py-4">{r.callerNumber}</td>
                    <td className="px-6 py-4 flex items-center space-x-2">
                      <button onClick={() => setViewReport(r)} className="text-blue-500 hover:text-blue-700" title="View"><EyeIcon className="h-5 w-5"/></button>
                      <button onClick={() => setEditReport({ index, data: { ...r } })} className="text-gray-500 hover:text-gray-700" title="Edit"><PencilIcon className="h-5 w-5"/></button>
                      <button disabled className="text-gray-300 cursor-not-allowed" title="Delete disabled"><TrashIcon className="h-5 w-5"/></button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* View Modal */}
      {viewReport && (
        <div className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50">
          <div className="bg-white p-6 rounded-lg w-96">
            <h3 className="text-lg font-bold mb-4">Call Details</h3>
            <p><strong>Caller Name:</strong> {viewReport.callerName}</p>
            <p><strong>Description:</strong> {viewReport.description}</p>
            <p><strong>Date:</strong> {viewReport.date}</p>
            <p><strong>Status:</strong> {titleCase(viewReport.status)}</p>
            <p><strong>Caller Number:</strong> {viewReport.callerNumber}</p>

            <div className="flex justify-end mt-4">
              <button onClick={() => setViewReport(null)} className="bg-gray-500 text-white px-3 py-1 rounded hover:bg-gray-600">Close</button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {editReport && (
        <div className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50">
          <div className="bg-white p-6 rounded-lg w-96">
            <h3 className="text-lg font-bold mb-4">Edit Report</h3>
            <label className="block mb-2">Caller Name:</label>
            <input type="text" value={editReport.data.callerName} onChange={(e) => setEditReport({ ...editReport, data: { ...editReport.data, callerName: e.target.value } })} className="w-full border p-2 mb-4" />
            <label className="block mb-2">Description:</label>
            <input type="text" value={editReport.data.description} onChange={(e) => setEditReport({ ...editReport, data: { ...editReport.data, description: e.target.value } })} className="w-full border p-2 mb-4" />
            <label className="block mb-2">Status:</label>
            <select value={editReport.data.status} onChange={(e) => setEditReport({ ...editReport, data: { ...editReport.data, status: e.target.value } })} className="w-full border p-2 mb-4">
              <option>Ongoing</option>
              <option>Resolved</option>
            </select>
            <label className="block mb-2">Caller Number:</label>
            <input type="text" value={editReport.data.callerNumber} onChange={(e) => setEditReport({ ...editReport, data: { ...editReport.data, callerNumber: e.target.value } })} className="w-full border p-2 mb-4" />
            <div className="flex justify-end gap-2">
              <button onClick={() => setEditReport(null)} className="bg-gray-500 text-white px-3 py-1 rounded hover:bg-gray-600">Cancel</button>
              <button onClick={handleSaveEdit} className="bg-green-500 text-white px-3 py-1 rounded hover:bg-green-600">Save</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
