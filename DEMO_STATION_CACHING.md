# Demo: Station Data Caching System

## Overview
This demo shows how the station data caching system works, which ensures police station information is available even when the device is offline by caching data from Firebase Realtime Database locally.

## How Station Caching Works

### Architecture
```
Firebase Realtime Database → Local Cache (SharedPreferences) → Emergency SMS System
```

### Key Components
1. **Firebase Integration** - Fetches station data from Realtime Database
2. **Local Caching** - Stores data using SharedPreferences
3. **Cache Validation** - 24-hour expiration with automatic refresh
4. **Offline Fallback** - Uses cached data when internet unavailable

## Demo Implementation

### Step 1: Create Station Cache Demo Screen
```dart
// lib/demo/station_cache_demo.dart
import 'package:flutter/material.dart';
import '../services/offline_emergency_service.dart';

class StationCacheDemo extends StatefulWidget {
  @override
  _StationCacheDemoState createState() => _StationCacheDemoState();
}

class _StationCacheDemoState extends State<StationCacheDemo> {
  final OfflineEmergencyService _emergencyService = OfflineEmergencyService();
  Map<String, dynamic> _cacheStatus = {};
  List<Map<String, dynamic>> _stations = [];
  bool _isLoading = false;
  String _statusMessage = 'Ready to test caching system';

  @override
  void initState() {
    super.initState();
    _loadCacheStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Station Cache Demo'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cache Status Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Cache Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildCacheStatusInfo(),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _refreshCache,
                    icon: Icon(Icons.refresh),
                    label: Text('Refresh Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _clearCache,
                    icon: Icon(Icons.clear),
                    label: Text('Clear Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadCacheStatus,
              icon: Icon(Icons.info),
              label: Text('Check Cache Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),
            
            SizedBox(height: 16),
            
            // Status Message
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: _isLoading ? Colors.orange : Colors.black87,
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Cached Stations List
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.local_police, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Cached Stations (${_stations.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _stations.isEmpty
                          ? Center(
                              child: Text(
                                'No cached stations found.\nTap "Refresh Cache" to load from Firebase.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _stations.length,
                              itemBuilder: (context, index) {
                                final station = _stations[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    child: Text('${index + 1}'),
                                  ),
                                  title: Text(station['city'] ?? 'Unknown City'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Hotline: ${station['hotline'] ?? 'N/A'}'),
                                      Text('Location: ${station['latitude']}, ${station['longitude']}'),
                                      Text('Radius: ${station['radius']}m'),
                                    ],
                                  ),
                                  trailing: Icon(Icons.location_on, color: Colors.red),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStatusInfo() {
    if (_cacheStatus.isEmpty) {
      return Text('Loading cache status...');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusRow('Has Cache', _cacheStatus['hasCache'] ? '✅ Yes' : '❌ No'),
        _buildStatusRow('Cache Valid', _cacheStatus['isValid'] ? '✅ Valid' : '⚠️ Expired'),
        _buildStatusRow('Station Count', '${_cacheStatus['stationCount']} stations'),
        _buildStatusRow('Cache Size', '${(_cacheStatus['cacheSize'] / 1024).toStringAsFixed(1)} KB'),
        _buildStatusRow('Last Update', _formatLastUpdate(_cacheStatus['lastUpdate'])),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  String _formatLastUpdate(String? lastUpdate) {
    if (lastUpdate == null) return 'Never';
    try {
      DateTime dateTime = DateTime.parse(lastUpdate);
      Duration diff = DateTime.now().difference(dateTime);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _loadCacheStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading cache status...';
    });

    try {
      final status = await _emergencyService.getCacheStatus();
      final stations = await _emergencyService.getCachedStations();
      
      setState(() {
        _cacheStatus = status;
        _stations = stations;
        _statusMessage = 'Cache status loaded successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading cache status: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshCache() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Refreshing cache from Firebase...';
    });

    try {
      bool success = await _emergencyService.cacheStationData();
      if (success) {
        await _loadCacheStatus(); // Reload to show updated data
        setState(() {
          _statusMessage = 'Cache refreshed successfully from Firebase Realtime Database';
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to refresh cache. Check internet connection and Firebase setup.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error refreshing cache: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Clearing cache...';
    });

    try {
      await _emergencyService.clearStationCache();
      await _loadCacheStatus(); // Reload to show cleared state
      setState(() {
        _statusMessage = 'Cache cleared successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error clearing cache: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
```

## Testing Scenarios

### Scenario 1: Initial Cache Setup
1. **Clear existing cache** - Tap "Clear Cache"
2. **Check status** - Should show "No cached stations"
3. **Refresh cache** - Tap "Refresh Cache" (requires internet)
4. **Verify data** - Should show stations loaded from Firebase

### Scenario 2: Cache Validation
1. **Check cache age** - Look at "Last Update" time
2. **Wait or modify timestamp** - Test expiration logic
3. **Refresh when expired** - System should auto-refresh

### Scenario 3: Offline Operation
1. **Ensure cache exists** - Refresh cache while online
2. **Go offline** - Disable internet connection
3. **Check cached data** - Should still show cached stations
4. **Test emergency SMS** - Should use cached station data

### Scenario 4: Firebase Integration
1. **Add new station in Firebase** - Update your Realtime Database
2. **Refresh cache** - Should fetch new station
3. **Verify update** - New station should appear in list

## Expected Firebase Database Structure
```json
{
  "stations": {
    "PSTD01": {
      "city": "General Santos City",
      "hotline": "0951-791-8057",
      "latitude": "6.114152463229464",
      "longitude": "125.17060062489488",
      "radius": "5500.0",
      "region": "Region 12",
      "streetAddress": "Pendatun Avenue"
    },
    "PSTD02": {
      "city": "Davao City",
      "hotline": "0951-791-8058",
      "latitude": "7.073000",
      "longitude": "125.612800",
      "radius": "6000.0",
      "region": "Region 11",
      "streetAddress": "San Pedro Street"
    }
  }
}
```

## Console Output to Monitor
```
Successfully cached 2 stations
Station cache cleared
Error caching station data: [error details]
Cache is valid, using existing data
Cache expired, refreshing from Firebase
```

## Integration with Emergency System
The cached stations are automatically used by the emergency SMS system:
1. **Online**: Fresh data fetched and cached
2. **Offline**: Cached data used for nearest station calculation
3. **Seamless**: No user intervention required
4. **Reliable**: Always has backup data available
