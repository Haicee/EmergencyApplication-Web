import React, { useState, useEffect } from "react";
import { PhoneIncomingIcon, PhoneMissedCallIcon, PhoneOutgoingIcon, DownloadIcon, SearchIcon, TrashIcon, PencilIcon } from '@heroicons/react/solid';
import ExcelJS from 'exceljs';
import { ref, onValue, off } from 'firebase/database';
import { database } from './firebase';

// Helper to pretty-print status labels for display
const formatStatusLabel = (status) => {
  const raw = (status || '').toString().trim();
  const s = raw.toLowerCase();
  if (s === 'missed') return 'Missed Calls';
  // Title-case words (handles single words or phrases)
  return raw
    .split(/\s+/)
    .map(w => w ? w.charAt(0).toUpperCase() + w.slice(1) : '')
    .join(' ');
};

const StatusBadge = ({ status }) => {
  const baseClasses = "px-2 py-1 text-xs font-medium rounded-full";
  const s = (status || '').toString().toLowerCase();
  // Map common raw statuses to colors
  if (s.includes('ring')) return <span className={`${baseClasses} bg-orange-100 text-orange-600`}>{formatStatusLabel(status)}</span>;
  if (s.includes('end')) return <span className={`${baseClasses} bg-green-100 text-green-600`}>{formatStatusLabel(status)}</span>;
  if (s.includes('declin')) return <span className={`${baseClasses} bg-red-100 text-red-600`}>{formatStatusLabel(status)}</span>;
  if (s.includes('cancel')) return <span className={`${baseClasses} bg-gray-100 text-gray-600`}>{formatStatusLabel(status)}</span>;
  if (s.includes('time')) return <span className={`${baseClasses} bg-red-100 text-red-600`}>{formatStatusLabel(status)}</span>;
  if (s.includes('miss')) return <span className={`${baseClasses} bg-red-100 text-red-600`}>{formatStatusLabel(status)}</span>;
  if (s.includes('ongoing')) return <span className={`${baseClasses} bg-orange-100 text-orange-600`}>{formatStatusLabel(status)}</span>;
  if (s.includes('answered')) return <span className={`${baseClasses} bg-green-100 text-green-600`}>{formatStatusLabel(status)}</span>;
  return <span className={`${baseClasses} bg-gray-100 text-gray-600`}>{formatStatusLabel(status)}</span>;
};

const StatCard = ({ title, value, icon, iconBg = "bg-gray-100 text-gray-600" }) => (
  <div className="bg-white p-6 rounded-2xl border border-gray-100 flex justify-between items-center shadow-sm hover:shadow-md transition-shadow duration-200">
    <div>
      <p className="text-sm font-medium text-gray-500">{title}</p>
      <p className="mt-2 text-3xl font-semibold text-gray-900">{value}</p>
    </div>
    <div className={`p-3 rounded-xl ${iconBg}`}>
      {icon}
    </div>
  </div>
);

export default function EmergencyCalls() {
  const [activeFilter, setActiveFilter] = useState("All Calls");
  const [activeCalls, setActiveCalls] = useState([]); // Ongoing
  const [answeredCalls, setAnsweredCalls] = useState([]);
  const [missedCalls, setMissedCalls] = useState([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [officersIndex, setOfficersIndex] = useState({}); // username/code -> { name, station }

  // Helper: format timestamp if numeric
  const formatTime = (t) => {
    if (!t && t !== 0) return '';
    if (typeof t === 'number') {
      try {
        const d = new Date(t);
        const yyyy = d.getFullYear();
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        const hh = String(d.getHours()).padStart(2, '0');
        const mi = String(d.getMinutes()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd} ${hh}:${mi}`;
      } catch {
        return String(t);
      }
    }
    return String(t);
  };

  // Resolve officer code/username to display name
  const resolveOfficerName = (code) => {
    if (!code) return '';
    const entry = officersIndex[code];
    if (entry?.name) return entry.name;
    // Fallback: code as name
    return code;
  };

  // Helper: map snapshot object to UI rows
  const mapCalls = (obj, category) => {
    const entries = Object.entries(obj || {});
    return entries.map(([key, value]) => {
      const callerName = value?.caller || value?.callerName || value?.name || value?.userName || value?.username || 'Unknown';
      const callerType = value?.callerType || value?.type || 'Citizen';
      const time = formatTime(value?.time || value?.timestamp || value?.dateTime || value?.createdAt);
      const location = value?.location || [value?.streetAddress, value?.barangay, value?.city].filter(Boolean).join(', ') || value?.address || '';
      const station = value?.station || '';

      // Receiver logic by category and raw status
      const rawStatus = (value?.status || '').toString().toLowerCase();
      let receiverName = '';
      let receiverType = '';
      if (category === 'Answered') {
        const officerCode = value?.officer || value?.answeredBy || value?.handledBy;
        receiverName = resolveOfficerName(officerCode);
        receiverType = receiverName ? 'Officer' : '';
      } else if (category === 'Missed') {
        if (rawStatus === 'declined') {
          const officerCode = value?.declinedBy || value?.missedBy;
          receiverName = resolveOfficerName(officerCode);
          receiverType = receiverName ? 'Officer' : '';
        } else if (rawStatus === 'cancelled' || rawStatus === 'timeout') {
          receiverName = 'Not Connected';
          receiverType = '';
        } else {
          // fallback
          receiverName = 'Not Connected';
          receiverType = '';
        }
      } else if (category === 'Ongoing') {
        receiverName = 'Waiting...';
        receiverType = '';
      }

      const displayStatus = value?.status || (category === 'Ongoing' ? 'ringing' : category);

      return {
        id: value?.id || key,
        caller: callerName,
        callerType: callerType,
        time: time,
        location: location,
        station: station,
        receiver: receiverName,
        receiverType: receiverType,
        status: displayStatus,
      };
    });
  };

  // Subscribe to Firebase paths
  useEffect(() => {
    const activeRef = ref(database, 'StationsCallLogs/ActiveCalls');
    const ansRef = ref(database, 'StationsCallLogs/AnsweredCalls');
    const missRef = ref(database, 'StationsCallLogs/MissedCalls');

    const unsubActive = onValue(activeRef, (snapshot) => {
      setActiveCalls(mapCalls(snapshot.val(), 'Ongoing'));
    });

    const unsubAnswered = onValue(ansRef, (snapshot) => {
      setAnsweredCalls(mapCalls(snapshot.val(), 'Answered'));
    });

    const unsubMissed = onValue(missRef, (snapshot) => {
      setMissedCalls(mapCalls(snapshot.val(), 'Missed'));
    });

    // Also build officers index
    const officersRef = ref(database, 'Desk Officer');
    const unsubOfficers = onValue(officersRef, (snapshot) => {
      const data = snapshot.val() || {};
      // Flatten as username/code -> { name, station }
      const index = {};
      Object.entries(data).forEach(([stationName, stationData]) => {
        if (!stationData || typeof stationData !== 'object') return;
        Object.entries(stationData).forEach(([key, val]) => {
          // Skip metadata keys; assume officer objects contain a username
          if (val && typeof val === 'object' && (val.username || val.name)) {
            const code = (val.username || val.name);
            index[code] = { name: val.username || val.name, station: stationName };
          }
        });
      });
      setOfficersIndex(index);
    });

    // Cleanup
    return () => {
      try { off(activeRef); } catch {}
      try { off(ansRef); } catch {}
      try { off(missRef); } catch {}
      try { off(officersRef); } catch {}
      if (typeof unsubActive === 'function') unsubActive();
      if (typeof unsubAnswered === 'function') unsubAnswered();
      if (typeof unsubMissed === 'function') unsubMissed();
      if (typeof unsubOfficers === 'function') unsubOfficers();
    };
  }, []);

  const allCalls = [...activeCalls, ...answeredCalls, ...missedCalls];

  const handleFilterClick = (filter) => {
    setActiveFilter(filter);
  };

  const baseFiltered = (() => {
    if (activeFilter === 'Active Calls') return activeCalls;
    if (activeFilter === 'Missed Calls') return missedCalls;
    if (activeFilter === 'Answered Calls') return answeredCalls;
    return allCalls;
  })();

  const filteredCalls = baseFiltered.filter((call) => {
    if (!searchQuery) return true;
    const q = searchQuery.toLowerCase();
    return (
      String(call.id).toLowerCase().includes(q) ||
      String(call.caller).toLowerCase().includes(q) ||
      String(call.station || '').toLowerCase().includes(q) ||
      String(call.receiver || '').toLowerCase().includes(q) ||
      String(call.time).toLowerCase().includes(q)
    );
  });
  // Export the calls to XLSX with separate sheets and bold headers (mirrors ManageUsers export styling)
  const handleExportCalls = async () => {
    const headers = ['Call ID', 'Caller', 'Receiver', 'Station', 'Date and Time', 'Status'];
    const personCell = (name, type) => {
      const n = name || '';
      if (!type) return n;
      return n ? `${n} (${type})` : type;
    };
    const toRows = (calls = []) => (calls || []).map((c) => ([
      c.id ?? '',
      personCell(c.caller, c.callerType),
      personCell(c.receiver, c.receiverType),
      c.station || '',
      c.time || '',
      c.status || '',
    ]));

    const workbook = new ExcelJS.Workbook();

    const addSheet = (sheetName, rows) => {
      const ws = workbook.addWorksheet(sheetName);
      ws.addRow(headers);
      rows.forEach(row => ws.addRow(row));
      const headerRow = ws.getRow(1);
      headerRow.font = { bold: true };
      headerRow.commit && headerRow.commit();
      headers.forEach((header, idx) => {
        let max = String(header).length;
        rows.forEach(row => {
          const cellValue = String(row[idx] ?? '');
          const segments = cellValue.split(/\r?\n/);
          segments.forEach(seg => {
            max = Math.max(max, seg.length);
          });
        });
        ws.getColumn(idx + 1).width = Math.min(Math.max(10, max + 2), 60);
      });
    };

    const sheets = [
      ['All Calls', toRows(allCalls)],
      ['Active Calls', toRows(activeCalls)],
      ['Missed Calls', toRows(missedCalls)],
      ['Answered Calls', toRows(answeredCalls)],
    ];
    sheets.forEach(([name, rows]) => addSheet(name, rows));

    const ts = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const filename = `emergency_calls_${ts.getFullYear()}-${pad(ts.getMonth() + 1)}-${pad(ts.getDate())}_${pad(ts.getHours())}${pad(ts.getMinutes())}${pad(ts.getSeconds())}.xlsx`;

    const buffer = await workbook.xlsx.writeBuffer();
    const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

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
        <StatCard
          title="Ongoing Calls"
          value={String(activeCalls.length)}
          icon={<PhoneIncomingIcon className="h-6 w-6" />}
          iconBg="bg-blue-100 text-blue-600"
        />
        <StatCard
          title="Missed Calls"
          value={String(missedCalls.length)}
          icon={<PhoneMissedCallIcon className="h-6 w-6" />}
          iconBg="bg-rose-100 text-rose-600"
        />
        <StatCard
          title="Answered Calls"
          value={String(answeredCalls.length)}
          icon={<PhoneOutgoingIcon className="h-6 w-6" />}
          iconBg="bg-emerald-100 text-emerald-600"
        />
      </div>

      <div className="bg-white p-4 rounded-lg shadow">
        <div className="flex flex-col md:flex-row justify-between items-center mb-4">
            {/* Filter Tabs */}
            <div className="flex space-x-2 mb-4 md:mb-0">
                <button className={getButtonClasses("All Calls")} onClick={() => handleFilterClick("All Calls")}>All Calls</button>
                <button className={getButtonClasses("Active Calls")} onClick={() => handleFilterClick("Active Calls")}>Active Calls</button>
                <button className={getButtonClasses("Missed Calls")} onClick={() => handleFilterClick("Missed Calls")}>Missed Calls</button>
                <button className={getButtonClasses("Answered Calls")} onClick={() => handleFilterClick("Answered Calls")}>Answered Calls</button>
            </div>
          <div className="flex items-center space-x-2">
            <button onClick={handleExportCalls} className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
                <DownloadIcon className="h-4 w-4"/>
                Export
            </button>
            <div className="relative">
                <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400"/>
                <input type="text" placeholder="Search here..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} className="pl-10 pr-4 py-2 text-sm border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"/>
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
                <th scope="col" className="px-6 py-3">Receiver</th>
                <th scope="col" className="px-6 py-3">Station</th>
                <th scope="col" className="px-6 py-3">Date and Time</th>
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
                  <td className="px-6 py-4">
                    <div>{call.receiver || ''}</div>
                    <div className="text-xs text-gray-500">{call.receiverType}</div>
                  </td>
                  <td className="px-6 py-4">{call.station || ''}</td>
                  <td className="px-6 py-4">{call.time}</td>
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
