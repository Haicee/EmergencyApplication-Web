const API_BASE_URL = 'http://localhost:5000/api';

class ApiService {
  constructor() {
    this.baseURL = API_BASE_URL;
  }

  // Generic request method
  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('API request failed:', error);
      throw error;
    }
  }

  // Citizens CRUD operations
  async getCitizens() {
    return this.request('/users');
  }

  async getCitizen(id) {
    return this.request(`/users/citizens/${id}`);
  }

  async createCitizen(citizenData) {
    return this.request('/users/citizens', {
      method: 'POST',
      body: JSON.stringify(citizenData),
    });
  }

  async updateCitizen(id, citizenData) {
    return this.request(`/users/citizens/${id}`, {
      method: 'PUT',
      body: JSON.stringify(citizenData),
    });
  }

  async deleteCitizen(id) {
    return this.request(`/users/citizens/${id}`, {
      method: 'DELETE',
    });
  }

  // Stations CRUD operations
  async getStations() {
    return this.request('/users/stations');
  }

  async getStation(id) {
    return this.request(`/users/stations/${id}`);
  }

  // Create a new station under Desk Officer
  async createStation(stationData) {
    return this.request('/desk-officers', {
      method: 'POST',
      body: JSON.stringify(stationData),
    });
  }

  async updateStation(id, stationData) {
    return this.request(`/users/stations/${id}`, {
      method: 'PUT',
      body: JSON.stringify(stationData),
    });
  }

  async deleteStation(id) {
    return this.request(`/users/stations/${id}`, {
      method: 'DELETE',
    });
  }

  // Officers CRUD operations
  async addOfficer(stationId, officerData) {
    return this.request(`/users/stations/${stationId}/officers`, {
      method: 'POST',
      body: JSON.stringify(officerData),
    });
  }

  async updateOfficer(stationId, officerId, officerData) {
    return this.request(`/users/stations/${stationId}/officers/${officerId}`, {
      method: 'PUT',
      body: JSON.stringify(officerData),
    });
  }

  async deleteOfficer(stationId, officerId) {
    return this.request(`/users/stations/${stationId}/officers/${officerId}`, {
      method: 'DELETE',
    });
  }

  // Add a desk officer
  async addDeskOfficer(station, officerData) {
    return this.request(`/desk-officers/${station}`, {
      method: 'POST',
      body: JSON.stringify(officerData),
    });
  }

  // Get all desk officer stations
  async getDeskOfficerStations() {
    return this.request('/desk-officers');
  }

  // Get all officers for a station
  async getDeskOfficersByStation(station) {
    return this.request(`/desk-officers/${station}`);
  }

  // Update a desk officer
  async updateDeskOfficer(station, username, officerData) {
    return this.request(`/desk-officers/${station}/${username}`, {
      method: 'PUT',
      body: JSON.stringify(officerData),
    });
  }

  // Delete a desk officer
  async deleteDeskOfficer(station, username) {
    return this.request(`/desk-officers/${station}/${username}`, {
      method: 'DELETE',
    });
  }

  // Update a desk officer station (metadata)
  async updateDeskOfficerStation(station, data) {
    return this.request(`/desk-officers/${encodeURIComponent(station)}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  // Delete a desk officer station
  async deleteDeskOfficerStation(station) {
    return this.request(`/desk-officers/${encodeURIComponent(station)}`, {
      method: 'DELETE',
    });
  }

  // Responders - mirror Desk Officers API
  // Get all responder stations
  async getResponderStations() {
    return this.request('/responders');
  }

  // Get all responders for a station
  async getRespondersByStation(station) {
    return this.request(`/responders/${encodeURIComponent(station)}`);
  }

  // Add a responder under a station
  async addResponder(station, responderData) {
    return this.request(`/responders/${encodeURIComponent(station)}`, {
      method: 'POST',
      body: JSON.stringify(responderData),
    });
  }

  // Update a responder
  async updateResponder(station, username, responderData) {
    return this.request(`/responders/${encodeURIComponent(station)}/${encodeURIComponent(username)}`, {
      method: 'PUT',
      body: JSON.stringify(responderData),
    });
  }

  // Delete a responder
  async deleteResponder(station, username) {
    return this.request(`/responders/${encodeURIComponent(station)}/${encodeURIComponent(username)}`, {
      method: 'DELETE',
    });
  }

  // Update responder station (metadata)
  async updateResponderStation(station, data) {
    return this.request(`/responders/${encodeURIComponent(station)}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  // Delete a responder station
  async deleteResponderStation(station) {
    return this.request(`/responders/${encodeURIComponent(station)}`, {
      method: 'DELETE',
    });
  }

  // Emergency Calls operations
  async getEmergencyCalls() {
    return this.request('/emergency-calls');
  }

  async getEmergencyCallStats() {
    return this.request('/emergency-calls/stats');
  }

  async getEmergencyCall(id) {
    return this.request(`/emergency-calls/${id}`);
  }

  async createEmergencyCall(callData) {
    return this.request('/emergency-calls', {
      method: 'POST',
      body: JSON.stringify(callData),
    });
  }

  async updateEmergencyCall(id, callData) {
    return this.request(`/emergency-calls/${id}`, {
      method: 'PUT',
      body: JSON.stringify(callData),
    });
  }

  async deleteEmergencyCall(id) {
    return this.request(`/emergency-calls/${id}`, {
      method: 'DELETE',
    });
  }

  // Dashboard statistics
  async getDashboardStats() {
    try {
      const [users, emergencyStats] = await Promise.all([
        this.getCitizens(),
        this.getEmergencyCallStats()
      ]);

      const usersArray = Object.values(users);
      const totalUsers = usersArray.length;
      
      // Get recent registrations (last 10 users sorted by createdAt)
      const recentUsers = usersArray
        .filter(user => user.createdAt)
        .sort((a, b) => b.createdAt - a.createdAt)
        .slice(0, 10);

      return {
        totalUsers,
        emergencyStats,
        recentUsers
      };
    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
      throw error;
    }
  }
}

export default new ApiService();