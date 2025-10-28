import React, { useState, useEffect } from "react";
import { UserGroupIcon, PhoneIncomingIcon, ShieldCheckIcon } from "@heroicons/react/solid";
import apiService from "./services/api";

const profileImageCandidates = [
  'profileImageUrl',
  'profileImageURL',
  'profileImage',
  'profilePicture',
  'photoURL',
  'photoUrl',
  'avatarUrl',
  'avatarURL',
  'imageUrl'
];

const getProfileImageUrl = (user = {}) => {
  for (const key of profileImageCandidates) {
    const value = user?.[key];
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed) return trimmed;
    }
  }
  return '';
};

const AvatarCell = ({ user, initials, isMale }) => {
  const [imageError, setImageError] = useState(false);
  const avatarUrl = getProfileImageUrl(user);
  const showInitials = imageError || !avatarUrl;
  const bgClass = isMale ? "bg-blue-500" : "bg-red-500";

  return (
    <div className={`relative w-8 h-8 rounded-full overflow-hidden flex items-center justify-center text-white text-sm font-semibold mr-3 ${showInitials ? bgClass : 'bg-gray-100'}`}>
      {!showInitials && (
        <img
          src={avatarUrl}
          alt={`${user?.fullName || user?.name || user?.username || 'User'} profile`}
          className="h-full w-full object-cover"
          loading="lazy"
          onError={() => setImageError(true)}
        />
      )}
      {showInitials && <span>{initials}</span>}
    </div>
  );
};

export default function Dashboard() {
  const [dashboardData, setDashboardData] = useState({
    totalUsers: 0,
    emergencyStats: { total: 0, ongoing: 0, answered: 0, missed: 0 },
    reportStats: { total: 0, byStatus: {} },
    recentUsers: []
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await apiService.getDashboardStats();
      setDashboardData(data);
    } catch (err) {
      console.error('Error fetching dashboard data:', err);
      setError('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (timestamp) => {
    if (!timestamp) return 'N/A';
    return new Date(timestamp).toLocaleDateString();
  };

  const getInitials = (name) => {
    if (!name) return '?';
    return name.split(' ').map(n => n[0]).join('').toUpperCase();
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 p-6 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-red-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 p-6 flex items-center justify-center">
        <div className="text-center">
          <div className="text-red-600 mb-4">
            <svg className="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <p className="text-gray-600 mb-4">{error}</p>
          <button 
            onClick={fetchDashboardData}
            className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        {/* Total Registered Users */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 hover:shadow-lg transition-shadow duration-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 mb-1">Total Users</p>
              <p className="text-3xl font-bold text-gray-900">{dashboardData.totalUsers}</p>
              <p className="text-xs text-gray-500 mt-1">Active users</p>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-rose-400/20 to-rose-500/20 flex items-center justify-center text-rose-500">
              <UserGroupIcon className="h-6 w-6" />
            </div>
          </div>
        </div>

        {/* Total Emergency Calls */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 hover:shadow-lg transition-shadow duration-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 mb-1">Emergency Calls</p>
              <p className="text-3xl font-bold text-gray-900">{dashboardData.emergencyStats.total}</p>
              <p className="text-xs text-gray-500 mt-1">
                {dashboardData.emergencyStats.ongoing} ongoing, {dashboardData.emergencyStats.answered} answered, {dashboardData.emergencyStats.missed} missed
              </p>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-amber-400/20 to-orange-500/20 flex items-center justify-center text-orange-500">
              <PhoneIncomingIcon className="h-6 w-6" />
            </div>
          </div>
        </div>
        
        {/* Report Status */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 hover:shadow-lg transition-shadow duration-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 mb-1">Report Status</p>
              <p className="text-3xl font-bold text-gray-900">{dashboardData.reportStats.total}</p>
              <p className="text-xs text-gray-500 mt-1">Responded</p>
            </div>
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-emerald-400/20 to-emerald-500/20 flex items-center justify-center text-emerald-500">
              <ShieldCheckIcon className="h-6 w-6" />
            </div>
          </div>
        </div>
      </div>

      {/* Recent Users Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-100">
          <h2 className="text-xl font-semibold text-gray-900">Recent Registrations</h2>
          <p className="text-sm text-gray-600 mt-1">Latest user registrations in the system</p>
        </div>
        
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-100">
                <th className="px-6 py-4 text-left text-xs font-medium text-gray-600 uppercase tracking-wider">User</th>
                <th className="px-6 py-4 text-left text-xs font-medium text-gray-600 uppercase tracking-wider">Contact</th>
                <th className="px-6 py-4 text-left text-xs font-medium text-gray-600 uppercase tracking-wider">Gender</th>
                <th className="px-6 py-4 text-left text-xs font-medium text-gray-600 uppercase tracking-wider">Location</th>
                <th className="px-6 py-4 text-left text-xs font-medium text-gray-600 uppercase tracking-wider">Registered</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {dashboardData.recentUsers.length === 0 ? (
                <tr>
                  <td colSpan="5" className="px-6 py-8 text-center text-gray-500">
                    <div className="flex flex-col items-center">
                      <svg className="w-12 h-12 text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                      </svg>
                      <p>No recent registrations found</p>
                    </div>
                  </td>
                </tr>
              ) : (
                dashboardData.recentUsers.map((user, idx) => {
                  const initials = getInitials(user.fullName || user.name || user.username);
                  const gender = user.gender || 'Unknown';
                  const isMale = gender.toLowerCase() === 'male';
                  
                  return (
                    <tr key={user.username || user.fullName || user.name || idx} className="hover:bg-gray-50 transition-colors duration-150">
                      <td className="px-6 py-4">
                        <div className="flex items-center">
                          <AvatarCell user={user} initials={initials} isMale={isMale} />
                          <div>
                            <p className="text-sm font-medium text-gray-900">
                              {user.fullName || user.name || user.username || 'Unknown User'}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <p className="text-sm text-gray-900">{user.contactNumber || user.phone || 'N/A'}</p>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`inline-flex px-2.5 py-0.5 rounded-full text-xs font-medium ${
                          isMale 
                            ? "bg-blue-100 text-blue-800" 
                            : "bg-red-100 text-red-800"
                        }`}>
                          {gender}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <p className="text-sm text-gray-600 max-w-xs truncate">
                          {user.address || user.location || 'Not provided'}
                        </p>
                      </td>
                      <td className="px-6 py-4">
                        <p className="text-sm text-gray-600">{formatDate(user.createdAt)}</p>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}