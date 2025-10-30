import React, { useEffect, useState } from "react";
import { ref, onValue, off, remove } from 'firebase/database';
import { database } from './firebase';
import { TrashIcon, EyeIcon } from '@heroicons/react/solid';

// Helper: title-case and special handling
const titleCase = (str) => (str || '')
  .toString()
  .split(/\s+/)
  .map(w => w ? w.charAt(0).toUpperCase() + w.slice(1) : '')
  .join(' ');

const isLikelyHttpUrl = (value) => {
  if (typeof value !== 'string') return false;
  const trimmed = value.trim();
  if (!trimmed || trimmed.startsWith('<')) return false;
  try {
    const parsed = new URL(trimmed);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
};

const parseDateValue = (value) => {
  if (!value && value !== 0) return null;
  if (typeof value === 'number') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;
    const maybeNumber = Number(trimmed);
    if (!Number.isNaN(maybeNumber) && trimmed.length >= 10) {
      const d = new Date(maybeNumber);
      if (!Number.isNaN(d.getTime())) return d;
    }
    const direct = new Date(trimmed);
    if (!Number.isNaN(direct.getTime())) return direct;
    const normalized = trimmed.includes('T') ? trimmed : trimmed.replace(' ', 'T');
    const shortened = normalized.replace(/\.(\d{3})\d+$/, '.$1');
    const d = new Date(shortened);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
};

const formatDateDisplay = (value) => {
  const date = parseDateValue(value);
  if (!date) return value || 'Not provided';
  return new Intl.DateTimeFormat('en-US', { month: 'long', day: 'numeric', year: 'numeric' }).format(date);
};

const formatTimeDisplay = (value) => {
  const date = parseDateValue(value);
  if (!date) return value || 'Not provided';
  return new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', second: '2-digit' }).format(date);
};

const formatDuration = (answeredAt, endedAt) => {
  const startMs = toNumber(answeredAt);
  if (!startMs || startMs === 0) return 'N/A';

  const endMs = endedAt && toNumber(endedAt) !== 0 ? toNumber(endedAt) : Date.now();

  const diffMs = endMs - startMs;
  if (diffMs < 0) return 'N/A';

  const totalSeconds = Math.floor(diffMs / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  if (hours > 0) {
    const hourStr = hours === 1 ? 'hour' : 'hours';
    const minuteStr = minutes === 1 ? 'minute' : 'minutes';
    const secondStr = seconds === 1 ? 'second' : 'seconds';
    return `${hours} ${hourStr} ${minutes} ${minuteStr} ${seconds} ${secondStr}`;
  }
  if (minutes > 0) {
    const minuteStr = minutes === 1 ? 'minute' : 'minutes';
    const secondStr = seconds === 1 ? 'second' : 'seconds';
    return `${minutes} ${minuteStr} ${seconds} ${secondStr}`;
  }
  const secondStr = seconds === 1 ? 'second' : 'seconds';
  return `${seconds} ${secondStr}`;
};

const ensureValue = (value) => {
  if (value === null || value === undefined) return 'Not provided';
  const str = String(value).trim();
  return str ? str : 'Not provided';
};

const getInitials = (name) => {
  const parts = (name || '').toString().trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  const first = parts[0]?.[0] || '';
  const last = parts.length > 1 ? parts[parts.length - 1]?.[0] : '';
  return (first + last).toUpperCase();
};

const toNumber = (value) => {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string') {
    const parsed = parseFloat(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
};

const buildMapsLink = (lat, lng) => {
  const latitude = toNumber(lat);
  const longitude = toNumber(lng);
  if (latitude === null || longitude === null) return null;
  return `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`;
};

const composeAddressFromComponents = (address, fallbackDisplayName = '') => {
  if (!address) return fallbackDisplayName || '';

  const normalize = (value) => (value || '').toString().trim();

  const streetCore = normalize(address.road
    || address.residential
    || address.street
    || address.pedestrian
    || address.footway
    || address.highway
    || address.path);

  const houseNumber = normalize(address.house_number || address.unit || address.building);
  const streetLine = [houseNumber, streetCore].filter(Boolean).join(' ').trim();

  const barangay = normalize(address.barangay
    || address.suburb
    || address.village
    || address.neighbourhood
    || address.hamlet
    || address.quarter);

  const city = normalize(address.city
    || address.town
    || address.municipality
    || address.city_district
    || address.county);

  const region = normalize(address.region
    || address.state
    || address.province
    || address.state_district);

  const postcode = normalize(address.postcode);

  const parts = [streetLine, barangay, city, region, postcode]
    .filter(Boolean)
    .map((part) => part.replace(/\s+/g, ' '))
    .filter((value, index, self) => self.findIndex(item => item.toLowerCase() === value.toLowerCase()) === index);

  if (parts.length) return parts.join(', ');
  if (fallbackDisplayName) return fallbackDisplayName;
  if (address.country) return normalize(address.country);
  return '';
};

const TimelineCard = ({ label, value, time }) => (
  <div className="bg-gradient-to-br from-blue-50 to-blue-100 border border-blue-100 rounded-xl p-3 sm:p-4 flex flex-col gap-1 shadow-sm">
    <p className="text-xs uppercase text-blue-600 tracking-wide">{label}</p>
    <p className="text-sm sm:text-base font-semibold text-slate-900">{value || 'Not provided'}</p>
    {time && (
      <p className="text-xs text-blue-500">{time}</p>
    )}
  </div>
);

export default function ReportStatus() {
  const [stations, setStations] = useState([]); // ["Police Station 1", ...]
  const [selectedStation, setSelectedStation] = useState('');
  const [reportsByStation, setReportsByStation] = useState({}); // { stationName: [reports] }

  const [viewReport, setViewReport] = useState(null);
  const [deleteConfirm, setDeleteConfirm] = useState({ callId: null, stationName: null });
  const [resolvedLocation, setResolvedLocation] = useState({ status: 'idle', address: '' });
  const [imageError, setImageError] = useState(false);
  const [attachmentError, setAttachmentError] = useState(false);
  const [attachmentPreviewUrl, setAttachmentPreviewUrl] = useState(null);

  const stationReports = reportsByStation[selectedStation] || [];
  const mapsLink = viewReport ? buildMapsLink(viewReport.citizenLatitude, viewReport.citizenLongitude) : null;

  const resolvedLocationText = (() => {
    if (!viewReport) return '';
    switch (resolvedLocation.status) {
      case 'loading':
        return 'Resolving location…';
      case 'error':
        return 'Unable to resolve location from coordinates';
      case 'success':
        return resolvedLocation.address;
      case 'empty':
      case 'idle':
      default:
        return ensureValue(viewReport.location);
    }
  })();

  useEffect(() => {
    // Reset image error when switching reports
    setImageError(false);
    setAttachmentError(false);
    setAttachmentPreviewUrl(null);

    let active = true;
    const controller = new AbortController();

    const resolveAddress = async () => {
      if (!viewReport) {
        setResolvedLocation({ status: 'idle', address: '' });
        return;
      }

      const lat = toNumber(viewReport.citizenLatitude);
      const lng = toNumber(viewReport.citizenLongitude);

      if (lat === null || lng === null) {
        setResolvedLocation({ status: 'idle', address: '' });
        return;
      }

      setResolvedLocation((prev) => ({ ...prev, status: 'loading' }));

      try {
        const params = new URLSearchParams({
          format: 'jsonv2',
          lat: lat.toString(),
          lon: lng.toString(),
          addressdetails: '1'
        });

        const response = await fetch(`https://nominatim.openstreetmap.org/reverse?${params.toString()}`, {
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'EmergencyApplication-Web-Admin/1.0'
          },
          signal: controller.signal
        });

        if (!response.ok) throw new Error('Failed to reverse geocode');

        const data = await response.json();
        const formatted = composeAddressFromComponents(data.address, data.display_name);

        if (!active) return;

        if (formatted) {
          setResolvedLocation({ status: 'success', address: formatted });
        } else {
          setResolvedLocation({ status: 'empty', address: '' });
        }
      } catch (error) {
        if (!active || error.name === 'AbortError') return;
        setResolvedLocation({ status: 'error', address: '' });
      }
    };

    resolveAddress();

    return () => {
      active = false;
      controller.abort();
    };
  }, [viewReport]);

  useEffect(() => {
    const respondersRef = ref(database, 'Responders');

    const normalize = (call, callId, fallbackStation) => {
      const obj = (call && typeof call === 'object') ? call : {};
      const station = fallbackStation || obj.station || '';

      const tableDate = () => {
        const raw = obj.completedAt || obj.answeredAt || obj.endedAt || obj.timestamp || obj.dateTime || obj.createdAt;
        if (!raw) return obj.date || '';
        const parsed = parseDateValue(raw);
        if (!parsed) return obj.date || '';
        return `${parsed.getFullYear()}-${String(parsed.getMonth() + 1).padStart(2, '0')}-${String(parsed.getDate()).padStart(2, '0')}`;
      };

      const rawImage = obj.callerImage || obj.imageUrl || '';
      const trimmedImage = (rawImage || '').toString().trim();
      const imageStrLower = trimmedImage.toLowerCase();
      const isPlaceholder = imageStrLower === 'not provided' || imageStrLower === 'n/a' || imageStrLower === 'none' || imageStrLower === 'null' || trimmedImage === '';

      const rawAttachment = obj.imageAttached || obj.attachment || obj.attachmentUrl || '';
      const trimmedAttachment = (rawAttachment || '').toString().trim();
      const attachmentLower = trimmedAttachment.toLowerCase();
      const hasAttachment = trimmedAttachment && !['not provided', 'n/a', 'none', 'null'].includes(attachmentLower);
      const attachmentUrl = hasAttachment && isLikelyHttpUrl(trimmedAttachment) ? trimmedAttachment : '';

      const attachmentUrls = (() => {
        const urls = [];
        const addUrl = (u) => {
          const s = (u || '').toString().trim();
          if (isLikelyHttpUrl(s) && !urls.includes(s)) urls.push(s);
        };
        const fromAny = (v) => {
          if (typeof v === 'string') {
            // Split on common separators in case multiple URLs are packed into one string
            const parts = v.split(/[\s,;|]+/).filter(Boolean);
            parts.forEach(addUrl);
          } else if (v && typeof v === 'object') {
            // Common possible fields written by different clients
            const candidates = [v.url, v.downloadURL, v.imageUrl, v.link, v.href, v.src];
            candidates.forEach(addUrl);
          }
        };
        const traverse = (node, depth = 0) => {
          if (!node || depth > 5) return; // avoid pathological cycles
          if (typeof node === 'string') {
            fromAny(node);
            return;
          }
          if (Array.isArray(node)) {
            node.forEach((item) => traverse(item, depth + 1));
            return;
          }
          if (typeof node === 'object') {
            fromAny(node);
            Object.values(node).forEach((val) => traverse(val, depth + 1));
          }
        };

        const src = obj.attachments;
        traverse(src);

        // Also merge legacy single field if present (string may also contain multiple)
        if (trimmedAttachment) fromAny(trimmedAttachment);
        if (attachmentUrl) addUrl(attachmentUrl);

        return urls;
      })();

      return {
        callId,
        callerName: ensureValue(obj.callerName || obj.caller || obj.name),
        callerImage: isPlaceholder ? '' : trimmedImage,
        callerNumber: ensureValue(obj.callerNumber || obj.mobile || obj.contactNumber || obj.phone || obj.citizenContactNumber),
        birthDate: ensureValue(obj.birthDate || obj.callerBirthdate),
        gender: ensureValue(obj.gender),
        disabilityStatus: ensureValue(obj.disabilityStatus),
        medicalConditions: ensureValue(obj.medicalConditions),
        description: ensureValue(obj.description),
        location: ensureValue(obj.location),
        citizenLatitude: obj.citizenLatitude ?? obj.latitude ?? '',
        citizenLongitude: obj.citizenLongitude ?? obj.longitude ?? '',
        imageAttached: hasAttachment ? trimmedAttachment : 'Not provided',
        imageAttachmentUrl: attachmentUrl,
        attachmentUrls,
        callDuration: formatDuration(obj.answeredAt, obj.endedAt) || ensureValue(obj.callDuration || obj.duration),
        status: titleCase(obj.status || 'completed'),
        station,
        officerId: ensureValue(obj.officerId || obj.respondedBy),
        date: tableDate(),
        answeredAt: obj.answeredAt || null,
        inProgressAt: obj.inProgressAt || obj.inprogressAt || null,
        completedAt: obj.completedAt || null,
        endedAt: obj.endedAt || null,
        timestamp: obj.timestamp || obj.createdAt || null,
      };
    };

    const unsubscribe = onValue(respondersRef, (snapshot) => {
      const respondersData = snapshot.val() || {};
      const stationNames = Object.keys(respondersData || {});
      const grouped = {};

      stationNames.forEach((stationName) => {
        const completed = respondersData?.[stationName]?.ReceivedCallDetails?.Completed;
        if (completed && typeof completed === 'object') {
          grouped[stationName] = Object.entries(completed).map(([callId, call]) => normalize(call, callId, stationName));
        } else {
          grouped[stationName] = [];
        }
      });

      Object.keys(grouped).forEach((stationName) => {
        grouped[stationName].sort((a, b) => (b.date || '').localeCompare(a.date || ''));
      });

      setReportsByStation(grouped);
      setStations(stationNames);
      setSelectedStation((current) => {
        if (!stationNames.length) return '';
        if (current && stationNames.includes(current)) return current;
        return stationNames[0];
      });
    });

    return () => {
      try { off(respondersRef); } catch {}
      if (typeof unsubscribe === 'function') unsubscribe();
    };
  }, []);

  // Handle delete from database
  const handleDelete = async (callId, stationName) => {
    try {
      const deleteRef = ref(database, `Responders/${stationName}/ReceivedCallDetails/Completed/${callId}`);
      await remove(deleteRef);
      // onValue listener will update the UI automatically
    } catch (error) {
      console.error('Failed to delete report:', error);
    }
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
                      <button onClick={() => setDeleteConfirm({ callId: r.callId, stationName: selectedStation })} className="text-red-500 hover:text-red-700" title="Delete"><TrashIcon className="h-5 w-5"/></button>
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
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-slate-900/70 px-3 sm:px-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl sm:max-w-4xl overflow-hidden">
            <div className="flex items-center justify-between px-5 py-4 sm:px-7 sm:py-5 border-b border-blue-100 bg-gradient-to-r from-blue-500 via-blue-600 to-blue-700 text-white">
              <div className="space-y-1">
                <h3 className="text-2xl sm:text-3xl font-semibold">Call Details</h3>
                <p className="text-xs sm:text-sm text-blue-100">Incident summary and responder timeline</p>
              </div>
              <button
                onClick={() => setViewReport(null)}
                className="h-9 w-9 sm:h-10 sm:w-10 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 transition"
                aria-label="Close details"
              >
                <span className="text-xl">✕</span>
              </button>
            </div>

            <div className="px-5 py-6 sm:px-7 sm:py-7 space-y-6 sm:space-y-7 max-h-[80vh] overflow-y-auto bg-slate-50">
              <section className="bg-white border border-blue-100 rounded-2xl p-5 sm:p-6 grid grid-cols-1 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] lg:grid-cols-[minmax(0,1.1fr)_minmax(0,1.9fr)] gap-4 sm:gap-6 items-center shadow-sm">
                <div className="flex flex-col items-center justify-center text-center gap-4 sm:gap-5">
                  <div className="h-24 w-24 sm:h-28 sm:w-28 rounded-full bg-gradient-to-br from-blue-600 to-blue-700 border-4 border-white shadow-md overflow-hidden flex items-center justify-center">
                    {viewReport.callerImage && !imageError ? (
                      <img
                        src={viewReport.callerImage}
                        alt={viewReport.callerName}
                        className="h-full w-full object-cover"
                        onError={() => setImageError(true)}
                      />
                    ) : (
                      <span className="text-white text-2xl sm:text-3xl font-semibold select-none" aria-label="Avatar initials">
                        {getInitials(viewReport.callerName)}
                      </span>
                    )}
                  </div>
                  <div>
                    <p className="text-xl sm:text-2xl font-semibold text-slate-900">{viewReport.callerName}</p>
                  </div>
                </div>

                <div className="w-full grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4 self-stretch">
                  <div className="bg-slate-50 rounded-xl shadow-sm p-4 sm:p-5 border border-blue-100">
                    <p className="text-xs font-semibold text-blue-600 uppercase tracking-wide">Contact Number</p>
                    <p className="text-sm sm:text-base text-slate-900 mt-1">{ensureValue(viewReport.callerNumber)}</p>
                  </div>
                  <div className="bg-slate-50 rounded-xl shadow-sm p-4 sm:p-5 border border-blue-100">
                    <p className="text-xs font-semibold text-blue-600 uppercase tracking-wide">Birth Date</p>
                    <p className="text-sm sm:text-base text-slate-900 mt-1">{ensureValue(viewReport.birthDate)}</p>
                  </div>
                  <div className="bg-slate-50 rounded-xl shadow-sm p-4 sm:p-5 border border-blue-100">
                    <p className="text-xs font-semibold text-blue-600 uppercase tracking-wide">Gender</p>
                    <p className="text-sm sm:text-base text-slate-900 mt-1">{ensureValue(viewReport.gender)}</p>
                  </div>
                  <div className="bg-slate-50 rounded-xl shadow-sm p-4 sm:p-5 border border-blue-100">
                    <p className="text-xs font-semibold text-blue-600 uppercase tracking-wide">Disability Status</p>
                    <p className="text-sm sm:text-base text-slate-900 mt-1">{ensureValue(viewReport.disabilityStatus)}</p>
                  </div>
                  <div className="bg-slate-50 rounded-xl shadow-sm p-4 sm:p-5 border border-blue-100">
                    <p className="text-xs font-semibold text-blue-600 uppercase tracking-wide">Medical Conditions</p>
                    <p className="text-sm sm:text-base text-slate-900 mt-1">{ensureValue(viewReport.medicalConditions)}</p>
                  </div>
                  <div className="bg-slate-50 rounded-xl shadow-sm p-4 sm:p-5 border border-blue-100">
                    <p className="text-xs font-semibold text-blue-600 uppercase tracking-wide">Call Received By</p>
                    <p className="text-sm sm:text-base text-slate-900 mt-1">{ensureValue(viewReport.officerId)}</p>
                  </div>
                </div>
              </section>

              <section className="space-y-6">
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-5 sm:gap-6">
                  <div className="bg-white border border-blue-100 rounded-2xl p-5 sm:p-6 shadow-sm space-y-4">
                    <div>
                      <h4 className="text-xs sm:text-sm font-semibold text-blue-600 uppercase tracking-wide">Incident Description</h4>
                      <p className="mt-2 sm:mt-3 text-slate-900 leading-relaxed whitespace-pre-line">{ensureValue(viewReport.description)}</p>
                    </div>
                    <div>
                      <h4 className="text-xs sm:text-sm font-semibold text-blue-600 uppercase tracking-wide">Attachment</h4>
                      {Array.isArray(viewReport.attachmentUrls) && viewReport.attachmentUrls.length > 0 ? (
                        <div className="mt-2 sm:mt-3">
                          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                            {viewReport.attachmentUrls.map((url, idx) => (
                              <div key={idx} className="bg-slate-100 border border-blue-100 rounded-xl overflow-hidden">
                                <button
                                  type="button"
                                  onClick={() => setAttachmentPreviewUrl(url)}
                                  className="w-full h-40 flex items-center justify-center focus:outline-none focus:ring-2 focus:ring-blue-400"
                                  aria-label={`Open attachment ${idx + 1}`}
                                >
                                  <img
                                    src={url}
                                    alt={`Attachment ${idx + 1}`}
                                    className="w-full h-full object-contain bg-white"
                                    loading="lazy"
                                  />
                                </button>
                                
                              </div>
                            ))}
                          </div>
                        </div>
                      ) : viewReport.imageAttachmentUrl && !attachmentError ? (
                        <div className="mt-2 sm:mt-3 space-y-3">
                          <button
                            type="button"
                            onClick={() => setAttachmentPreviewUrl(viewReport.imageAttachmentUrl)}
                            className="w-full bg-slate-100 border border-blue-100 rounded-xl overflow-hidden focus:outline-none focus:ring-2 focus:ring-blue-400"
                            aria-label="Open attachment preview"
                          >
                            <img
                              src={viewReport.imageAttachmentUrl}
                              alt={`${viewReport.callerName} attachment`}
                              className="w-full h-48 object-contain bg-white"
                              loading="lazy"
                              onError={() => setAttachmentError(true)}
                            />
                          </button>
                          <div className="flex flex-wrap gap-3 text-sm">
                            <a
                              href={viewReport.imageAttachmentUrl}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="inline-flex items-center gap-1 font-medium text-blue-600 hover:text-blue-700"
                            >
                              Download Image
                            </a>
                          </div>
                        </div>
                      ) : (
                        <p className="mt-2 sm:mt-3 text-slate-900">{ensureValue(viewReport.imageAttached)}</p>
                      )}
                    </div>
                  </div>

                  <div className="bg-white border border-blue-100 rounded-2xl p-5 sm:p-6 shadow-sm space-y-4">
                    <div className="flex items-center justify-between">
                      <h4 className="text-xs sm:text-sm font-semibold text-blue-600 uppercase tracking-wide">Location Details</h4>
                      {mapsLink && (
                        <a
                          href={mapsLink}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-2 text-xs font-semibold text-blue-600 hover:text-blue-700"
                        >
                          <span>View on Map</span>
                        </a>
                      )}
                    </div>
                    <p className="text-sm sm:text-base text-slate-900 leading-relaxed whitespace-pre-line">{resolvedLocationText}</p>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm text-slate-600">
                      <div className="bg-slate-100 border border-blue-100 rounded-xl p-3">
                        <p className="text-xs uppercase text-blue-600 tracking-wide">Latitude</p>
                        <p className="mt-1 text-slate-900">{ensureValue(viewReport.citizenLatitude)}</p>
                      </div>
                      <div className="bg-slate-100 border border-blue-100 rounded-xl p-3">
                        <p className="text-xs uppercase text-blue-600 tracking-wide">Longitude</p>
                        <p className="mt-1 text-slate-900">{ensureValue(viewReport.citizenLongitude)}</p>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="bg-white border border-blue-100 rounded-2xl p-5 sm:p-6 shadow-sm">
                  <div className="flex items-center justify-between mb-4 sm:mb-5">
                    <h4 className="text-xs sm:text-sm font-semibold text-blue-600 uppercase tracking-wide">Call Timeline</h4>
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 text-sm">
                    <TimelineCard label="Answered At" value={formatDateDisplay(viewReport.answeredAt)} time={formatTimeDisplay(viewReport.answeredAt)} />
                    <TimelineCard label="Ended At" value={formatDateDisplay(viewReport.endedAt)} time={formatTimeDisplay(viewReport.endedAt)} />
                    <TimelineCard label="In Progress At" value={formatDateDisplay(viewReport.inProgressAt)} time={formatTimeDisplay(viewReport.inProgressAt)} />
                    <TimelineCard label="Completed At" value={formatDateDisplay(viewReport.completedAt)} time={formatTimeDisplay(viewReport.completedAt)} />
                  </div>
                  <div className="mt-5 sm:mt-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 text-sm">
                    <div className="bg-slate-100 border border-blue-100 rounded-xl p-4">
                      <p className="text-xs uppercase text-blue-600 tracking-wide">Call Duration</p>
                      <p className="mt-2 text-slate-900">{ensureValue(viewReport.callDuration)}</p>
                    </div>
                    <div className="bg-slate-100 border border-blue-100 rounded-xl p-4">
                      <p className="text-xs uppercase text-blue-600 tracking-wide">Status</p>
                      <p className="mt-2 text-slate-900">{titleCase(viewReport.status)}</p>
                    </div>
                    <div className="bg-slate-100 border border-blue-100 rounded-xl p-4">
                      <p className="text-xs uppercase text-blue-600 tracking-wide">Call ID</p>
                      <p className="mt-2 text-slate-900">{ensureValue(viewReport.callId)}</p>
                    </div>
                  </div>
                </div>
              </section>
            </div>

            <div className="flex justify-end gap-3 px-5 py-4 sm:px-7 sm:py-5 border-t border-blue-100 bg-white">
              <button
                onClick={() => setViewReport(null)}
                className="px-4 py-2 text-sm font-medium text-blue-600 bg-white border border-blue-200 rounded-lg hover:bg-blue-50 transition"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deleteConfirm.callId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
          <div className="bg-white p-6 rounded-lg shadow-lg max-w-sm w-full">
            <h3 className="text-lg font-semibold mb-4">Confirm Delete</h3>
            <p className="mb-4">Are you sure you want to delete this report?</p>
            <div className="flex justify-end gap-2">
            <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={() => setDeleteConfirm({ callId: null, stationName: null })}>Cancel</button>
              <button
                onClick={() => {
                  handleDelete(deleteConfirm.callId, deleteConfirm.stationName);
                  setDeleteConfirm({ callId: null, stationName: null });
                }}
                className="px-3 py-2 bg-red-500 text-white rounded hover:bg-red-600"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}

      {attachmentPreviewUrl && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/80 px-4" role="dialog" aria-modal="true">
          <div className="relative bg-white rounded-2xl shadow-2xl max-w-3xl w-full overflow-hidden">
            <button
              type="button"
              onClick={() => setAttachmentPreviewUrl(null)}
              className="absolute top-3 right-3 h-9 w-9 flex items-center justify-center rounded-full bg-white/80 hover:bg-white text-slate-700 shadow"
              aria-label="Close attachment preview"
            >
              ✕
            </button>
            <div className="bg-slate-900 p-4 text-white text-sm font-medium">Attachment Preview</div>
            <div className="bg-slate-50 p-4 flex items-center justify-center">
              <img
                src={attachmentPreviewUrl}
                alt="Attachment preview"
                className="max-h-[70vh] w-full object-contain bg-white"
              />
            </div>
            <div className="flex justify-end gap-3 px-4 py-3 bg-white border-t">
              <a
                href={attachmentPreviewUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="px-4 py-2 text-sm font-medium text-blue-600 hover:text-blue-700"
              >
                Download Image
              </a>
              <button
                type="button"
                onClick={() => setAttachmentPreviewUrl(null)}
                className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
