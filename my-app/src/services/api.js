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
}

export default new ApiService(); 