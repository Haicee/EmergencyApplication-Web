import React, { useState, useEffect } from "react";
import apiService from "./services/api";
import { EyeIcon, EyeOffIcon } from '@heroicons/react/solid';

export default function ManageUsers() {
  const [activeTab, setActiveTab] = useState("Citizens");
  const [search, setSearch] = useState("");
  const [stationSearch, setStationSearch] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  // Citizens state
  const [citizens, setCitizens] = useState([]);
  const [editUser, setEditUser] = useState(null);
  const [editForm, setEditForm] = useState({});
  const [deleteUserIdx, setDeleteUserIdx] = useState(null);
  
  // Stations state
  const [stations, setStations] = useState([]);
  const [editStationIdx, setEditStationIdx] = useState(null);
  const [editStation, setEditStation] = useState({ name: '', address: '' });
  const [deleteStationIdx, setDeleteStationIdx] = useState(null);
  const [addOfficerIdx, setAddOfficerIdx] = useState(null);
  const [newOfficer, setNewOfficer] = useState({ initials: '', name: '', role: '' });
  const [editOfficerIdx, setEditOfficerIdx] = useState({ stationIdx: null, officerIdx: null });
  const [editOfficer, setEditOfficer] = useState({ initials: '', name: '', role: '', status: 'Active' });
  const [deleteOfficerIdx, setDeleteOfficerIdx] = useState({ stationIdx: null, officerIdx: null });
  const [showPassword, setShowPassword] = useState(false);

  // Add Desk Officer state
  const [deskOfficerStations, setDeskOfficerStations] = useState([]);
  const [selectedDeskOfficerStation, setSelectedDeskOfficerStation] = useState('');
  const [deskOfficers, setDeskOfficers] = useState([]);

  // Add state to hold officers for each station
  const [deskOfficerStationData, setDeskOfficerStationData] = useState({});

  // Add state for editing a desk officer
  const [editDeskOfficer, setEditDeskOfficer] = useState(null); // {station, officer}
  const [editDeskOfficerForm, setEditDeskOfficerForm] = useState({});
  const [editDeskOfficerLoading, setEditDeskOfficerLoading] = useState(false);
  const [editDeskOfficerError, setEditDeskOfficerError] = useState(null);
  const [showEditDeskOfficerPassword, setShowEditDeskOfficerPassword] = useState(false);

  // Add state for deleting a desk officer
  const [deleteDeskOfficer, setDeleteDeskOfficer] = useState(null); // {station, username}
  const [deleteDeskOfficerLoading, setDeleteDeskOfficerLoading] = useState(false);
  const [deleteDeskOfficerError, setDeleteDeskOfficerError] = useState(null);

  // Add state for adding a desk officer
  const [addDeskOfficerStation, setAddDeskOfficerStation] = useState(null); // station name
  const [addDeskOfficerForm, setAddDeskOfficerForm] = useState({ name: '', status: 'Active', password: '' });
  const [addDeskOfficerLoading, setAddDeskOfficerLoading] = useState(false);
  const [addDeskOfficerError, setAddDeskOfficerError] = useState(null);
  const [showAddDeskOfficerPassword, setShowAddDeskOfficerPassword] = useState(false);

  // Load data on component mount
  useEffect(() => {
    loadData();
  }, []);

  // Fetch Desk Officer stations when tab changes to Desk Officers
  useEffect(() => {
    if (activeTab === 'Desk Officers') {
      setLoading(true);
      setError(null);
      apiService.getDeskOfficerStations()
        .then(stations => {
          setDeskOfficerStations(stations);
          if (stations.length > 0) {
            setSelectedDeskOfficerStation(stations[0]);
          } else {
            setSelectedDeskOfficerStation('');
            setDeskOfficers([]);
          }
        })
        .catch(err => setError(err.message))
        .finally(() => setLoading(false));
    }
  }, [activeTab]);

  // Fetch officers when selected station changes
  useEffect(() => {
    if (activeTab === 'Desk Officers' && selectedDeskOfficerStation) {
      setLoading(true);
      setError(null);
      apiService.getDeskOfficersByStation(selectedDeskOfficerStation)
        .then(officersObj => {
          // officersObj is an object keyed by username
          const officers = Object.values(officersObj || {});
          setDeskOfficers(officers);
        })
        .catch(err => setError('Failed to fetch desk officers: ' + err.message))
        .finally(() => setLoading(false));
    } else if (activeTab === 'Desk Officers') {
      setDeskOfficers([]);
    }
  }, [activeTab, selectedDeskOfficerStation]);

  // Fetch officers for all stations when deskOfficerStations changes
  useEffect(() => {
    if (activeTab === 'Desk Officers' && deskOfficerStations.length > 0) {
      setLoading(true);
      setError(null);
      Promise.all(
        deskOfficerStations.map(station =>
          apiService.getDeskOfficersByStation(station)
            .then(stationObj => ({
              station,
              stationData: stationObj || {}
            }))
            .catch(() => ({ station, stationData: {} })) // If fetch fails, just return empty list
        )
      )
        .then(results => {
          const data = {};
          results.forEach(({ station, stationData }) => {
            data[station] = stationData;
          });
          setDeskOfficerStationData(data);
        })
        .finally(() => setLoading(false));
    } else if (activeTab === 'Desk Officers') {
      setDeskOfficerStationData({});
    }
  }, [activeTab, deskOfficerStations]);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      if (activeTab === "Citizens") {
        const usersObj = await apiService.getCitizens();
        // Convert object to array
        const citizensData = Object.values(usersObj || {});
        setCitizens(citizensData);
      }
    } catch (err) {
      setError(err.message);
      console.error('Error loading data:', err);
    } finally {
      setLoading(false);
    }
  };

  // Reload data when tab changes
  useEffect(() => {
    loadData();
  }, [activeTab]);

  const filteredUsers = citizens.filter(
    (u) =>
      (u.username && u.username.toLowerCase().includes(search.toLowerCase())) ||
      (u.name && u.name.toLowerCase().includes(search.toLowerCase())) ||
      (u.firstName && u.firstName.toLowerCase().includes(search.toLowerCase())) ||
      (u.surname && u.surname.toLowerCase().includes(search.toLowerCase()))
  );

  const openEdit = (user) => {
    setEditUser(user);
    setEditForm({
      name: user.username || user.name || `${user.firstName || ''} ${user.middleInitial || ''} ${user.surname || ''}`.trim(),
      password: user.password || '',
      contact: user.contactNumber || '',
      gender: user.gender || '',
      pwd: user.pwdCondition && user.pwdCondition !== 'None' ? true : false,
      pwdCondition: user.pwdCondition || '',
      medical: user.medicalCondition && user.medicalCondition !== 'None' ? true : false,
      medicalCondition: user.medicalCondition || '',
      address: [user.streetAddress, user.barangay, user.city].filter(Boolean).join(', '),
    });
  };

  const closeEdit = () => {
    setEditUser(null);
  };

  const handleEditChange = (e) => {
    const { name, value, type, checked } = e.target;
    setEditForm((prev) => ({
      ...prev,
      [name]: type === "checkbox" ? checked : value,
    }));
  };

  const handleEditSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      // Build the updated user object
      const updatedUser = {
        ...editUser,
        username: editForm.name,
        password: editForm.password,
        contactNumber: editForm.contact,
        gender: editForm.gender,
        pwdCondition: editForm.pwd ? editForm.pwdCondition : 'None',
        medicalCondition: editForm.medical ? editForm.medicalCondition : 'None',
        // Optionally, split address back into fields if needed
        // streetAddress, barangay, city
      };
      await apiService.updateCitizen(editUser.username, updatedUser);
      await loadData();
      closeEdit();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteUser = async () => {
    if (deleteUserIdx === null) return;
    setLoading(true);
    try {
      const userToDelete = filteredUsers[deleteUserIdx];
      const userId = userToDelete.username || userToDelete.id || userToDelete.name;
      await apiService.deleteCitizen(userId);
      await loadData();
      setDeleteUserIdx(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Open edit modal
  const openEditDeskOfficer = (station, officer) => {
    setEditDeskOfficer({ station, oldUsername: officer.username });
    setEditDeskOfficerForm({
      name: officer.username || '', // Name field is the username
      status: officer.status || 'Active',
      password: officer.password || '',
    });
    setEditDeskOfficerError(null);
  };

  // Close edit modal
  const closeEditDeskOfficer = () => {
    setEditDeskOfficer(null);
    setEditDeskOfficerForm({});
    setEditDeskOfficerError(null);
  };

  // Handle form change
  const handleEditDeskOfficerChange = e => {
    const { name, value } = e.target;
    setEditDeskOfficerForm(prev => ({ ...prev, [name]: value }));
  };

  // Handle form submit
  const handleEditDeskOfficerSubmit = async e => {
    e.preventDefault();
    setEditDeskOfficerLoading(true);
    setEditDeskOfficerError(null);
    try {
      await apiService.updateDeskOfficer(
        editDeskOfficer.station,
        editDeskOfficer.oldUsername, // old username as key
        {
          username: editDeskOfficerForm.name, // new username
          ...editDeskOfficerForm
        }
      );
      // If the username changed, delete the old key and create the new one
      if (editDeskOfficer.oldUsername !== editDeskOfficerForm.name) {
        await apiService.deleteDeskOfficer(editDeskOfficer.station, editDeskOfficer.oldUsername);
      }
      // Refresh officers for all stations
      if (deskOfficerStations.length > 0) {
        Promise.all(
          deskOfficerStations.map(station =>
            apiService.getDeskOfficersByStation(station).then(officersObj => ({
              station,
              officers: Object.values(officersObj || {})
            }))
          )
        ).then(results => {
          const data = {};
          results.forEach(({ station, officers }) => {
            data[station] = officers;
          });
          setDeskOfficerStationData(data);
        });
      }
      closeEditDeskOfficer();
    } catch (err) {
      setEditDeskOfficerError('Failed to update desk officer: ' + err.message);
    } finally {
      setEditDeskOfficerLoading(false);
    }
  };

  // Open delete modal
  const openDeleteDeskOfficer = (station, officer) => {
    setDeleteDeskOfficer({ station, username: officer.username });
    setDeleteDeskOfficerError(null);
  };

  // Close delete modal
  const closeDeleteDeskOfficer = () => {
    setDeleteDeskOfficer(null);
    setDeleteDeskOfficerError(null);
  };

  // Handle delete confirm
  const handleDeleteDeskOfficer = async () => {
    setDeleteDeskOfficerLoading(true);
    setDeleteDeskOfficerError(null);
    try {
      await apiService.deleteDeskOfficer(deleteDeskOfficer.station, deleteDeskOfficer.username);
      // Refresh officers for all stations
      if (deskOfficerStations.length > 0) {
        Promise.all(
          deskOfficerStations.map(station =>
            apiService.getDeskOfficersByStation(station).then(officersObj => ({
              station,
              officers: Object.values(officersObj || {})
            }))
          )
        ).then(results => {
          const data = {};
          results.forEach(({ station, officers }) => {
            data[station] = officers;
          });
          setDeskOfficerStationData(data);
        });
      }
      closeDeleteDeskOfficer();
    } catch (err) {
      setDeleteDeskOfficerError('Failed to delete desk officer: ' + err.message);
    } finally {
      setDeleteDeskOfficerLoading(false);
    }
  };

  // Open add modal
  const openAddDeskOfficer = (station) => {
    setAddDeskOfficerStation(station);
    setAddDeskOfficerForm({ name: '', status: 'Active', password: '' });
    setAddDeskOfficerError(null);
  };

  // Close add modal
  const closeAddDeskOfficer = () => {
    setAddDeskOfficerStation(null);
    setAddDeskOfficerForm({ name: '', status: 'Active', password: '' });
    setAddDeskOfficerError(null);
  };

  // Handle form change
  const handleAddDeskOfficerChange = e => {
    const { name, value } = e.target;
    setAddDeskOfficerForm(prev => ({ ...prev, [name]: value }));
  };

  // Handle form submit
  const handleAddDeskOfficerSubmit = async e => {
    e.preventDefault();
    setAddDeskOfficerLoading(true);
    setAddDeskOfficerError(null);
    try {
      // Username is the name field
      const officerData = {
        username: addDeskOfficerForm.name,
        ...addDeskOfficerForm
      };
      await apiService.addDeskOfficer(addDeskOfficerStation, officerData);
      // Refresh officers for all stations
      if (deskOfficerStations.length > 0) {
        Promise.all(
          deskOfficerStations.map(station =>
            apiService.getDeskOfficersByStation(station).then(officersObj => ({
              station,
              officers: Object.values(officersObj || {})
            }))
          )
        ).then(results => {
          const data = {};
          results.forEach(({ station, officers }) => {
            data[station] = officers;
          });
          setDeskOfficerStationData(data);
        });
      }
      closeAddDeskOfficer();
    } catch (err) {
      setAddDeskOfficerError('Failed to add desk officer: ' + err.message);
    } finally {
      setAddDeskOfficerLoading(false);
    }
  };

  // Update the Edit handler for stations to pre-fill the modal fields
  const openEditStation = (idx) => {
    const stationName = deskOfficerStations[idx];
    const stationData = deskOfficerStationData[stationName] || {};
    setEditStation({
      name: stationName,
      streetAddress: stationData.streetAddress || '',
      city: stationData.city || '',
      region: stationData.region || '',
    });
    setEditStationIdx(idx);
  };

  const handleDeleteStation = async () => {
    if (deleteStationIdx === null) return;
    setLoading(true);
    try {
      const stationToDelete = deskOfficerStations[deleteStationIdx];
      await apiService.deleteDeskOfficerStation(stationToDelete);
      await loadData();
      setDeleteStationIdx(null); // <-- Make sure to reset the index
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="p-6">
      
      <div className="bg-white rounded-xl shadow p-4 mb-8">
        {/* Tabs, Export, Search */}
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
          <div className="flex gap-2 border-b">
            <button
              className={`px-4 py-2 font-medium border-b-2 transition text-sm ${activeTab === "Citizens" ? "border-red-500 text-red-600" : "border-transparent text-gray-500"}`}
              onClick={() => setActiveTab("Citizens")}
            >
              Citizens
            </button>
            <button
              className={`px-4 py-2 font-medium border-b-2 transition text-sm ${activeTab === "Desk Officers" ? "border-red-500 text-red-600" : "border-transparent text-gray-500"}`}
              onClick={() => setActiveTab("Desk Officers")}
            >
              Desk Officers
            </button>
          </div>
          {activeTab === "Desk Officers" && (
            <div className="flex gap-2 items-center">
              <input
                type="text"
                className="rounded border border-gray-200 px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                placeholder="Search here..."
                value={search}
                onChange={e => setSearch(e.target.value)}
              />
            </div>
          )}
          {activeTab === "Citizens" && (
            <div className="flex gap-2 items-center">
              <button className="flex items-center gap-1 bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-1.5 rounded text-sm font-medium border border-gray-200">
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path d="M4 4v2a2 2 0 002 2h12a2 2 0 002-2V4"/><path d="M7 10v10a2 2 0 002 2h6a2 2 0 002-2V10"/><path d="M10 14h4"/></svg>
                Export
              </button>
              <input
                type="text"
                className="rounded border border-gray-200 px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                placeholder="Search here..."
                value={search}
                onChange={e => setSearch(e.target.value)}
              />
            </div>
          )}
        </div>
        {/* Citizens Table */}
        {activeTab === "Citizens" && (
          <div className="overflow-x-auto">
            {loading && (
              <div className="text-center py-4">
                <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-red-500"></div>
                <p className="mt-2 text-gray-600">Loading...</p>
              </div>
            )}
            {error && (
              <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
                <strong>Error:</strong> {error}
              </div>
            )}
            {!loading && (
              <table className="min-w-full text-sm text-left">
                <thead>
                  <tr className="bg-gray-50 text-gray-600 uppercase text-xs">
                    <th className="px-4 py-2 font-medium">Name</th>
                    <th className="px-4 py-2 font-medium">Contact</th>
                    <th className="px-4 py-2 font-medium">Gender</th>
                    <th className="px-4 py-2 font-medium">Medical Condition</th>
                    <th className="px-4 py-2 font-medium">PWD</th>
                    <th className="px-4 py-2 font-medium">Address</th>
                    <th className="px-4 py-2 font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {citizens.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="px-4 py-6 text-center text-gray-400">
                        No citizens found.
                      </td>
                    </tr>
                  ) : citizens.map((user, idx) => (
                    <tr key={user.username || idx} className="border-b hover:bg-gray-50">
                      <td className="px-4 py-2 font-medium">{user.username || user.name || user.firstName + ' ' + (user.middleInitial || '') + ' ' + (user.surname || '')}</td>
                      <td className="px-4 py-2">{user.contactNumber}</td>
                      <td className="px-4 py-2">{user.gender}</td>
                      <td className="px-4 py-2">{user.medicalCondition || 'None'}</td>
                      <td className="px-4 py-2">{user.pwdCondition || 'None'}</td>
                      <td className="px-4 py-2">{[user.streetAddress, user.barangay, user.city].filter(Boolean).join(', ')}</td>
                      <td className="px-4 py-2 flex gap-2">
                        <button className="text-blue-600 hover:underline text-xs font-medium" onClick={() => openEdit(user)}>Update</button>
                        <span className="text-gray-400">|</span>
                        <button className="text-red-500 hover:underline text-xs font-medium" onClick={() => setDeleteUserIdx(idx)}>Delete</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}
        {/* Desk Officers Tab */}
        {activeTab === "Desk Officers" && (
          <div className="flex flex-col gap-4">
            {loading ? (
              <div className="text-center py-4">
                <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-red-500"></div>
                <p className="mt-2 text-gray-600">Loading stations...</p>
              </div>
            ) : deskOfficerStations.length === 0 ? (
              <div className="text-center text-gray-400 py-8">No stations found.</div>
            ) : (
              deskOfficerStations.map((station, idx) => {
                // Get station metadata and officers
                const stationData = deskOfficerStationData[station] || {};
                const { streetAddress, city, region, ...officersObj } = stationData;
                // Officers: filter out metadata keys
                const officers = Object.entries(officersObj)
                  .filter(([key, value]) => value && typeof value === 'object' && value.username)
                  .map(([key, value]) => value);
                // Compose address string
                const addressString = [streetAddress, city, region].filter(Boolean).join(', ');
                return (
                  <div key={station} className="bg-gray-50 rounded-xl shadow p-4 mb-4">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-4">
                        <span className="inline-flex items-center justify-center w-9 h-9 rounded-full font-bold text-white text-lg bg-green-600">{station.split(' ').map(w => w[0]).join('').toUpperCase()}</span>
                        <div className="font-semibold text-gray-800 text-lg">{station}</div>
                      </div>
                      <div className="flex items-center gap-4 text-gray-500 text-sm">
                        {addressString && <span>{addressString}</span>}
                        <button className="ml-2 text-blue-600 hover:underline text-sm font-medium" onClick={() => openEditStation(idx)}>Edit</button>
                        <button className="ml-2 text-red-500 hover:underline text-sm font-medium" onClick={() => setDeleteStationIdx(idx)}>Delete</button>
                      </div>
                    </div>
                    <div className="overflow-x-auto">
                      <table className="min-w-full text-sm text-left">
                        <thead>
                          <tr className="bg-white text-gray-600 uppercase text-xs">
                            <th className="px-4 py-2 font-medium">Desk Officer</th>
                            <th className="px-4 py-2 font-medium">Status</th>
                            <th className="px-4 py-2 font-medium">Action</th>
                          </tr>
                        </thead>
                        <tbody>
                          {officers.length === 0 ? (
                            <tr>
                              <td colSpan={3} className="px-4 py-6 text-center text-gray-400">No officers found.</td>
                            </tr>
                          ) : (
                            officers.map((officer, oIdx) => (
                              <tr key={officer.username || oIdx} className="border-b hover:bg-gray-50">
                                <td className="px-4 py-2">{officer.username}</td>
                                <td className="px-4 py-2">
                                  <span className={
                                    officer.status === 'Inactive'
                                      ? 'inline-block px-3 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-600'
                                      : 'inline-block px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-600'
                                  }>
                                    {officer.status || 'Active'}
                                  </span>
                                </td>
                                <td className="px-4 py-2">
                                  <button className="text-blue-600 hover:underline text-xs font-medium mr-2" onClick={() => openEditDeskOfficer(station, officer)}>Update</button>
                                  <span className="text-gray-400">|</span>
                                  <button className="text-red-500 hover:underline text-xs font-medium ml-2" onClick={() => openDeleteDeskOfficer(station, officer)}>Delete</button>
                                </td>
                              </tr>
                            ))
                          )}
                        </tbody>
                      </table>
                    </div>
                    <div className="flex justify-end mt-2">
                      <button className="flex items-center gap-1 bg-red-500 hover:bg-red-600 text-white px-3 py-1.5 rounded text-sm font-medium" onClick={() => openAddDeskOfficer(station)}>
                        + Add Officer
                      </button>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        )}
      </div>
      {/* Edit User Modal */}
      {editUser && (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-md relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Edit User</h2>
            <form className="flex flex-col gap-4" onSubmit={handleEditSubmit}>
              <div>
                <label className="block text-xs font-medium mb-1">Name</label>
                <input name="name" value={editForm.name} onChange={handleEditChange} className="w-full border rounded px-3 py-2 text-sm" required />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Password</label>
                <div className="relative">
                  <input
                    name="password"
                    type={showPassword ? "text" : "password"}
                    value={editForm.password}
                    onChange={handleEditChange}
                    className="w-full border rounded px-3 py-2 text-sm pr-16"
                  />
                  <button
                    type="button"
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500"
                    onClick={() => setShowPassword(v => !v)}
                    tabIndex={-1}
                  >
                    {showPassword ? (
                      <EyeOffIcon className="h-5 w-5" />
                    ) : (
                      <EyeIcon className="h-5 w-5" />
                    )}
                  </button>
                </div>
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Contact Number</label>
                <input name="contact" value={editForm.contact} onChange={handleEditChange} className="w-full border rounded px-3 py-2 text-sm" required />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Gender</label>
                <select name="gender" value={editForm.gender} onChange={handleEditChange} className="w-full border rounded px-3 py-2 text-sm" required>
                  <option value="Male">Male</option>
                  <option value="Female">Female</option>
                </select>
              </div>
              <div className="space-y-3">
                <label className="flex items-center gap-2 text-xs">
                  <input type="checkbox" name="pwd" checked={editForm.pwd} onChange={handleEditChange} />
                  Person with Disability (PWD)
                </label>
                {editForm.pwd && (
                  <div>
                    <label className="block text-xs font-medium mb-1">PWD Condition</label>
                    <input 
                      name="pwdCondition" 
                      value={editForm.pwdCondition} 
                      onChange={handleEditChange} 
                      className="w-full border rounded px-3 py-2 text-sm" 
                      placeholder="e.g., No leg, Visual impairment, etc."
                      required={editForm.pwd}
                    />
                  </div>
                )}
                
                <label className="flex items-center gap-2 text-xs">
                  <input type="checkbox" name="medical" checked={editForm.medical} onChange={handleEditChange} />
                  Medical condition
                </label>
                {editForm.medical && (
                  <div>
                    <label className="block text-xs font-medium mb-1">Medical Condition</label>
                    <input 
                      name="medicalCondition" 
                      value={editForm.medicalCondition} 
                      onChange={handleEditChange} 
                      className="w-full border rounded px-3 py-2 text-sm" 
                      placeholder="e.g., Diabetes, Hypertension, etc."
                      required={editForm.medical}
                    />
                  </div>
                )}
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Address</label>
                <input name="address" value={editForm.address} onChange={handleEditChange} className="w-full border rounded px-3 py-2 text-sm" required />
              </div>
              <div className="flex justify-end gap-2 mt-2">
                <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={closeEdit} disabled={loading}>Cancel</button>
                <button type="submit" className="px-4 py-2 rounded bg-red-500 text-white font-semibold" disabled={loading}>
                  {loading ? 'Updating...' : 'Update'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
      
      {editStationIdx !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-md relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Edit Station</h2>
            <form
              className="flex flex-col gap-4"
              onSubmit={async (e) => {
                e.preventDefault();
                setLoading(true);
                try {
                  const stationToUpdate = deskOfficerStations[editStationIdx];
                  // Format region
                  const formattedRegion = editStation.region && editStation.region.trim().toLowerCase().startsWith('region ')
                    ? editStation.region.trim()
                    : `Region ${editStation.region.trim()}`;
                  await apiService.updateDeskOfficerStation(stationToUpdate, {
                    streetAddress: editStation.streetAddress,
                    city: editStation.city,
                    region: formattedRegion
                  });
                  await loadData();
                  setEditStationIdx(null);
                } catch (err) {
                  setError(err.message);
                } finally {
                  setLoading(false);
                }
              }}
            >
              <div>
                <label className="block text-xs font-medium mb-1">Station Name</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={editStation.name || ''}
                  onChange={e => setEditStation(s => ({ ...s, name: e.target.value }))}
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Street Address</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={editStation.streetAddress || ''}
                  onChange={e => setEditStation(s => ({ ...s, streetAddress: e.target.value }))}
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">City</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={editStation.city || ''}
                  onChange={e => setEditStation(s => ({ ...s, city: e.target.value }))}
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Region</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={editStation.region || ''}
                  onChange={e => setEditStation(s => ({ ...s, region: e.target.value }))}
                  required
                />
              </div>
              <div className="flex justify-end gap-2 mt-2">
                <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={() => setEditStationIdx(null)}>Cancel</button>
                <button type="submit" className="px-4 py-2 rounded bg-blue-500 text-white font-semibold">Save Changes</button>
              </div>
            </form>
          </div>
        </div>
      )}
      {deleteStationIdx !== null && deskOfficerStations[deleteStationIdx] && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-sm relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Delete Station</h2>
            <p className="mb-6">Are you sure you want to delete <span className="font-bold">{deskOfficerStations[deleteStationIdx]}</span>?</p>
            <div className="flex justify-end gap-2 mt-2">
              <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={() => setDeleteStationIdx(null)}>Cancel</button>
              <button type="button" className="px-4 py-2 rounded bg-red-500 text-white font-semibold" onClick={handleDeleteStation}>Delete</button>
            </div>
          </div>
        </div>
      )}
      {addOfficerIdx !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-md relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Add Officer</h2>
            <form
              className="flex flex-col gap-4"
              onSubmit={async (e) => {
                e.preventDefault();
                if (!newOfficer.initials.trim() || !newOfficer.name.trim() || !newOfficer.role.trim()) return;
                setLoading(true);
                try {
                  const stationToAddTo = stations[addOfficerIdx];
                  const stationId = stationToAddTo.id || stationToAddTo.name;
                  await apiService.addOfficer(stationId, { ...newOfficer, status: 'Inactive' });
                  await loadData();
                  setNewOfficer({ initials: '', name: '', role: '' });
                  setAddOfficerIdx(null);
                } catch (err) {
                  setError(err.message);
                } finally {
                  setLoading(false);
                }
              }}
            >
              <div>
                <label className="block text-xs font-medium mb-1">Initials</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={newOfficer.initials}
                  onChange={e => setNewOfficer(o => ({ ...o, initials: e.target.value }))}
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Name</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={newOfficer.name}
                  onChange={e => setNewOfficer(o => ({ ...o, name: e.target.value }))}
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Role</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={newOfficer.role}
                  onChange={e => setNewOfficer(o => ({ ...o, role: e.target.value }))}
                  required
                />
              </div>
              <div className="flex justify-end gap-2 mt-2">
                <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={() => setAddOfficerIdx(null)}>Cancel</button>
                <button type="submit" className="px-4 py-2 rounded bg-red-500 text-white font-semibold">Add Officer</button>
              </div>
            </form>
          </div>
        </div>
      )}
      {editOfficerIdx.stationIdx !== null && editOfficerIdx.officerIdx !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-md relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Edit Officer</h2>
            <form
              className="flex flex-col gap-4"
              onSubmit={async (e) => {
                e.preventDefault();
                setLoading(true);
                try {
                  const stationToUpdate = stations[editOfficerIdx.stationIdx];
                  const officerToUpdate = stationToUpdate.officers[editOfficerIdx.officerIdx];
                  const stationId = stationToUpdate.id || stationToUpdate.name;
                  const officerId = officerToUpdate.id || officerToUpdate.initials || officerToUpdate.name;
                  await apiService.updateOfficer(stationId, officerId, editOfficer);
                  await loadData();
                  setEditOfficerIdx({ stationIdx: null, officerIdx: null });
                } catch (err) {
                  setError(err.message);
                } finally {
                  setLoading(false);
                }
              }}
            >
              <div>
                <label className="block text-xs font-medium mb-1">Initials</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={editOfficer.initials}
                  onChange={e => setEditOfficer(o => ({ ...o, initials: e.target.value }))}
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Name</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={editOfficer.name}
                  onChange={e => setEditOfficer(o => ({ ...o, name: e.target.value }))}
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Role</label>
                <input
                  className="w-full border rounded px-3 py-2 text-sm"
                  value={editOfficer.role}
                  onChange={e => setEditOfficer(o => ({ ...o, role: e.target.value }))}
                  required
                />
              </div>
              <div className="flex justify-end gap-2 mt-2">
                <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={() => setEditOfficerIdx({ stationIdx: null, officerIdx: null })}>Cancel</button>
                <button type="submit" className="px-4 py-2 rounded bg-blue-500 text-white font-semibold">Save Changes</button>
              </div>
            </form>
          </div>
        </div>
      )}
      {deleteOfficerIdx.stationIdx !== null && deleteOfficerIdx.officerIdx !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-sm relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Delete Officer</h2>
            <p className="mb-6">Are you sure you want to delete <span className="font-bold">{stations[deleteOfficerIdx.stationIdx].officers[deleteOfficerIdx.officerIdx].name}</span>?</p>
            <div className="flex justify-end gap-2 mt-2">
              <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={() => setDeleteOfficerIdx({ stationIdx: null, officerIdx: null })}>Cancel</button>
              <button type="button" className="px-4 py-2 rounded bg-red-500 text-white font-semibold" onClick={async () => {
                setLoading(true);
                try {
                  const stationToDeleteFrom = stations[deleteOfficerIdx.stationIdx];
                  const officerToDelete = stationToDeleteFrom.officers[deleteOfficerIdx.officerIdx];
                  const stationId = stationToDeleteFrom.id || stationToDeleteFrom.name;
                  const officerId = officerToDelete.id || officerToDelete.initials || officerToDelete.name;
                  await apiService.deleteOfficer(stationId, officerId);
                  await loadData();
                  setDeleteOfficerIdx({ stationIdx: null, officerIdx: null });
                } catch (err) {
                  setError(err.message);
                } finally {
                  setLoading(false);
                }
              }}>Delete</button>
            </div>
          </div>
        </div>
      )}
      {deleteUserIdx !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-sm relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Delete User</h2>
            <p className="mb-6">Are you sure you want to delete <span className="font-bold">{filteredUsers[deleteUserIdx].name}</span>?</p>
            <div className="flex justify-end gap-2 mt-2">
              <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={() => setDeleteUserIdx(null)} disabled={loading}>Cancel</button>
              <button type="button" className="px-4 py-2 rounded bg-red-500 text-white font-semibold" onClick={handleDeleteUser} disabled={loading}>
                {loading ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
      {editDeskOfficer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-md relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Edit Desk Officer</h2>
            <form className="flex flex-col gap-4" onSubmit={handleEditDeskOfficerSubmit}>
              <div>
                <label className="block text-xs font-medium mb-1">Name</label>
                <input name="name" value={editDeskOfficerForm.name} onChange={handleEditDeskOfficerChange} className="w-full border rounded px-3 py-2 text-sm" required />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Status</label>
                <select name="status" value={editDeskOfficerForm.status} onChange={handleEditDeskOfficerChange} className="w-full border rounded px-3 py-2 text-sm">
                  <option value="Active">Active</option>
                  <option value="Inactive">Inactive</option>
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Password</label>
                <div className="relative">
                  <input
                    name="password"
                    value={editDeskOfficerForm.password}
                    onChange={handleEditDeskOfficerChange}
                    className="w-full border rounded px-3 py-2 text-sm pr-10"
                    type={showEditDeskOfficerPassword ? "text" : "password"}
                  />
                  <button
                    type="button"
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500"
                    onClick={() => setShowEditDeskOfficerPassword(v => !v)}
                    tabIndex={-1}
                  >
                    {showEditDeskOfficerPassword ? (
                      <EyeOffIcon className="h-5 w-5" />
                    ) : (
                      <EyeIcon className="h-5 w-5" />
                    )}
                  </button>
                </div>
              </div>
              {editDeskOfficerError && (
                <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-2 rounded">
                  {editDeskOfficerError}
                </div>
              )}
              <div className="flex justify-end gap-2 mt-2">
                <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={closeEditDeskOfficer} disabled={editDeskOfficerLoading}>Cancel</button>
                <button type="submit" className="px-4 py-2 rounded bg-blue-500 text-white font-semibold" disabled={editDeskOfficerLoading}>
                  {editDeskOfficerLoading ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
      {deleteDeskOfficer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-sm relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Delete Desk Officer</h2>
            <p className="mb-6">Are you sure you want to delete <span className="font-bold">{deleteDeskOfficer.username}</span>?</p>
            {deleteDeskOfficerError && (
              <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-2 rounded mb-4">{deleteDeskOfficerError}</div>
            )}
            <div className="flex justify-end gap-2 mt-2">
              <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={closeDeleteDeskOfficer} disabled={deleteDeskOfficerLoading}>Cancel</button>
              <button type="button" className="px-4 py-2 rounded bg-red-500 text-white font-semibold" onClick={handleDeleteDeskOfficer} disabled={deleteDeskOfficerLoading}>
                {deleteDeskOfficerLoading ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
      {addDeskOfficerStation && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
          <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-md relative animate-fadeIn">
            <h2 className="text-lg font-semibold mb-4 text-gray-700">Add Desk Officer</h2>
            <form className="flex flex-col gap-4" onSubmit={handleAddDeskOfficerSubmit}>
              <div>
                <label className="block text-xs font-medium mb-1">Name</label>
                <input name="name" value={addDeskOfficerForm.name} onChange={handleAddDeskOfficerChange} className="w-full border rounded px-3 py-2 text-sm" required />
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Status</label>
                <select name="status" value={addDeskOfficerForm.status} onChange={handleAddDeskOfficerChange} className="w-full border rounded px-3 py-2 text-sm">
                  <option value="Active">Active</option>
                  <option value="Inactive">Inactive</option>
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium mb-1">Password</label>
                <div className="relative">
                  <input
                    name="password"
                    value={addDeskOfficerForm.password}
                    onChange={handleAddDeskOfficerChange}
                    className="w-full border rounded px-3 py-2 text-sm pr-10"
                    type={showAddDeskOfficerPassword ? "text" : "password"}
                  />
                  <button
                    type="button"
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500"
                    onClick={() => setShowAddDeskOfficerPassword(v => !v)}
                    tabIndex={-1}
                  >
                    {showAddDeskOfficerPassword ? (
                      <EyeOffIcon className="h-5 w-5" />
                    ) : (
                      <EyeIcon className="h-5 w-5" />
                    )}
                  </button>
                </div>
              </div>
              {addDeskOfficerError && (
                <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-2 rounded">
                  {addDeskOfficerError}
                </div>
              )}
              <div className="flex justify-end gap-2 mt-2">
                <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={closeAddDeskOfficer} disabled={addDeskOfficerLoading}>Cancel</button>
                <button type="submit" className="px-4 py-2 rounded bg-red-500 text-white font-semibold" disabled={addDeskOfficerLoading}>
                  {addDeskOfficerLoading ? 'Adding...' : 'Add Officer'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

function AddStationModal({ onClose, onSuccess }) {
  const [stationName, setStationName] = React.useState('');
  const [streetAddress, setStreetAddress] = React.useState('');
  const [region, setRegion] = React.useState('');
  const [city, setCity] = React.useState('');
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState(null);

  // Helper to ensure region starts with 'Region '
  function formatRegion(input) {
    if (!input) return '';
    return input.trim().toLowerCase().startsWith('region ')
      ? input.trim()
      : `Region ${input.trim()}`;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
      <div className="bg-white rounded-xl shadow-lg p-8 w-full max-w-md relative animate-fadeIn">
        <h2 className="text-lg font-semibold mb-4 text-gray-700">Add New Station</h2>
        <form
          className="flex flex-col gap-4"
          onSubmit={async (e) => {
            e.preventDefault();
            if (!stationName.trim() || !streetAddress.trim() || !region.trim() || !city.trim()) return;
            setLoading(true);
            setError(null);
            try {
              const formattedRegion = formatRegion(region);
              await apiService.createStation({ name: stationName, streetAddress, region: formattedRegion, city });
              setStationName('');
              setStreetAddress('');
              setRegion('');
              setCity('');
              onSuccess();
            } catch (err) {
              setError(err.message);
            } finally {
              setLoading(false);
            }
          }}
        >
          <div>
            <label className="block text-xs font-medium mb-1">Station Name</label>
            <input
              className="w-full border rounded px-3 py-2 text-sm"
              value={stationName}
              onChange={e => setStationName(e.target.value)}
              required
            />
          </div>
          <div>
            <label className="block text-xs font-medium mb-1">Street Address</label>
            <input
              className="w-full border rounded px-3 py-2 text-sm"
              value={streetAddress}
              onChange={e => setStreetAddress(e.target.value)}
              required
            />
          </div>
          <div>
            <label className="block text-xs font-medium mb-1">City</label>
            <input
              className="w-full border rounded px-3 py-2 text-sm"
              value={city}
              onChange={e => setCity(e.target.value)}
              required
            />
          </div>
          <div>
            <label className="block text-xs font-medium mb-1">Region</label>
            <input
              className="w-full border rounded px-3 py-2 text-sm"
              value={region}
              onChange={e => setRegion(e.target.value)}
              required
            />
          </div>
          {error && (
            <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-2 rounded mb-2">
              {error}
            </div>
          )}
          <div className="flex justify-end gap-2 mt-2">
            <button type="button" className="px-4 py-2 rounded bg-gray-100 text-gray-700" onClick={onClose}>Cancel</button>
            <button
              type="submit"
              className="px-4 py-2 rounded bg-red-500 text-white font-semibold flex items-center justify-center"
              disabled={loading}
            >
              {loading ? (
                <>
                  <svg className="animate-spin h-4 w-4 mr-2" viewBox="0 0 24 24">
                    {/* spinner SVG path */}
                  </svg>
                  Adding...
                </>
              ) : (
                "Add Station"
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
} 