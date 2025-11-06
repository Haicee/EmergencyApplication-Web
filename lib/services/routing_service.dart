// OSRM Routing Service for calculating shortest route/path
// Uses Open Source Routing Machine (OSRM) for accurate road-based distance calculation

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  // OSRM public instance (you can self-host for production)
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  
  // Cache settings
  static const String _routeCachePrefix = 'route_cache_';
  static const Duration _cacheValidityDuration = Duration(hours: 6);
  
  // Timeout settings
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _fastRequestTimeout = Duration(seconds: 5);

  /// Get shortest route between two points using OSRM
  /// Returns distance (km), duration (minutes), and route geometry
  Future<Map<String, dynamic>?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    bool useCache = true,
    Duration? timeout,
  }) async {
    try {
      // Generate cache key
      final cacheKey = _generateCacheKey(startLat, startLng, endLat, endLng);
      
      // Try to get from cache first
      if (useCache) {
        final cachedRoute = await _getCachedRoute(cacheKey);
        if (cachedRoute != null) {
          debugPrint('✅ Using cached route data');
          return cachedRoute;
        }
      }

      debugPrint('🗺️ Fetching route from OSRM: ($startLat,$startLng) -> ($endLat,$endLng)');
      
      // Build OSRM request URL
      // Note: OSRM uses lng,lat order (not lat,lng)
      final url = Uri.parse(
        '$_osrmBaseUrl/route/v1/driving/$startLng,$startLat;$endLng,$endLat'
        '?overview=full&geometries=geojson&steps=false'
      );
      
      // Make HTTP request with timeout
      final response = await http.get(url).timeout(
        timeout ?? _requestTimeout,
        onTimeout: () {
          throw TimeoutException('OSRM request timed out');
        },
      );
      
      if (response.statusCode != 200) {
        debugPrint('❌ OSRM returned status ${response.statusCode}');
        return null;
      }
      
      final data = jsonDecode(response.body);
      
      // Check if route was found
      if (data['code'] != 'Ok') {
        debugPrint('❌ OSRM error: ${data['code']} - ${data['message']}');
        return null;
      }
      
      if (data['routes'] == null || data['routes'].isEmpty) {
        debugPrint('❌ No routes found');
        return null;
      }
      
      final route = data['routes'][0];
      
      final routeData = {
        'distance': route['distance'] / 1000, // Convert meters to km
        'duration': route['duration'] / 60, // Convert seconds to minutes
        'geometry': route['geometry'], // GeoJSON LineString
        'coordinates': route['geometry']['coordinates'], // List of [lng, lat] pairs
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      debugPrint('✅ Route found: ${routeData['distance'].toStringAsFixed(2)} km, '
                 '${routeData['duration'].toStringAsFixed(1)} min');
      
      // Cache the result
      if (useCache) {
        await _cacheRoute(cacheKey, routeData);
      }
      
      return routeData;
      
    } on TimeoutException catch (e) {
      debugPrint('⏱️ OSRM request timeout: $e');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching route from OSRM: $e');
      return null;
    }
  }

  /// Find nearest station by ACTUAL road distance (not straight-line)
  Future<Map<String, dynamic>?> findNearestStationByRoute({
    required double userLat,
    required double userLng,
    required List<Map<String, dynamic>> stations,
    int? maxStationsToCheck, // Limit for performance
  }) async {
    try {
      if (stations.isEmpty) {
        debugPrint('❌ No stations provided for routing');
        return null;
      }

      debugPrint('🔍 Finding nearest station by route for ${stations.length} stations...');
      
      Map<String, dynamic>? nearestStation;
      double minRouteDistance = double.infinity;
      double minRouteDuration = double.infinity;
      
      // Sort stations by straight-line distance first (optimization)
      List<Map<String, dynamic>> sortedStations = List.from(stations);
      sortedStations.sort((a, b) {
        double distA = _calculateHaversineDistance(
          userLat, userLng,
          double.parse(a['latitude'].toString()),
          double.parse(a['longitude'].toString()),
        );
        double distB = _calculateHaversineDistance(
          userLat, userLng,
          double.parse(b['latitude'].toString()),
          double.parse(b['longitude'].toString()),
        );
        return distA.compareTo(distB);
      });
      
      // Limit stations to check (check closest 5-10 by straight-line distance)
      int stationsToCheck = min(maxStationsToCheck ?? 10, sortedStations.length);
      debugPrint('📊 Checking top $stationsToCheck closest stations by straight-line distance');
      
      for (int i = 0; i < stationsToCheck && i < sortedStations.length; i++) {
        var station = sortedStations[i];
        
        if (station['latitude'] == null || station['longitude'] == null) {
          continue;
        }
        
        double stationLat = double.parse(station['latitude'].toString());
        double stationLng = double.parse(station['longitude'].toString());
        
        // Get actual route distance
        final route = await getRoute(
          startLat: userLat,
          startLng: userLng,
          endLat: stationLat,
          endLng: stationLng,
          timeout: _fastRequestTimeout, // Use faster timeout for multiple requests
        );
        
        if (route != null) {
          double routeDistance = route['distance'];
          double routeDuration = route['duration'];
          
          debugPrint('  📍 ${station['name']}: ${routeDistance.toStringAsFixed(2)} km, '
                     '${routeDuration.toStringAsFixed(1)} min');
          
          if (routeDistance < minRouteDistance) {
            minRouteDistance = routeDistance;
            minRouteDuration = routeDuration;
            nearestStation = Map<String, dynamic>.from(station);
            nearestStation['routeDistance'] = routeDistance;
            nearestStation['routeDuration'] = routeDuration;
            nearestStation['routeGeometry'] = route['geometry'];
            nearestStation['routeCoordinates'] = route['coordinates'];
          }
        } else {
          debugPrint('  ⚠️ ${station['name']}: Route not found');
        }
      }
      
      if (nearestStation != null) {
        debugPrint('✅ Nearest station by route: ${nearestStation['name']} - '
                   '${minRouteDistance.toStringAsFixed(2)} km, '
                   '${minRouteDuration.toStringAsFixed(1)} min');
      } else {
        debugPrint('❌ No routes found to any station');
      }
      
      return nearestStation;
      
    } catch (e) {
      debugPrint('❌ Error finding nearest station by route: $e');
      return null;
    }
  }

  /// Calculate straight-line distance using Haversine formula (for optimization)
  double _calculateHaversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLng = _degreesToRadians(lng2 - lng1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Generate cache key for route
  String _generateCacheKey(double startLat, double startLng, double endLat, double endLng) {
    // Round to 4 decimal places (~11m precision) for cache key
    String start = '${startLat.toStringAsFixed(4)},${startLng.toStringAsFixed(4)}';
    String end = '${endLat.toStringAsFixed(4)},${endLng.toStringAsFixed(4)}';
    return '$_routeCachePrefix${start}_$end';
  }

  /// Cache route data
  Future<void> _cacheRoute(String cacheKey, Map<String, dynamic> routeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String routeJson = jsonEncode(routeData);
      await prefs.setString(cacheKey, routeJson);
      debugPrint('💾 Cached route: $cacheKey');
    } catch (e) {
      debugPrint('⚠️ Error caching route: $e');
    }
  }

  /// Get cached route data
  Future<Map<String, dynamic>?> _getCachedRoute(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? routeJson = prefs.getString(cacheKey);
      
      if (routeJson == null) {
        return null;
      }
      
      Map<String, dynamic> routeData = jsonDecode(routeJson);
      
      // Check if cache is still valid
      int timestamp = routeData['timestamp'] ?? 0;
      DateTime cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      DateTime now = DateTime.now();
      
      if (now.difference(cacheTime) > _cacheValidityDuration) {
        debugPrint('⏰ Cached route expired');
        await prefs.remove(cacheKey);
        return null;
      }
      
      return routeData;
      
    } catch (e) {
      debugPrint('⚠️ Error reading cached route: $e');
      return null;
    }
  }

  /// Clear all cached routes
  Future<void> clearRouteCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();
      
      int cleared = 0;
      for (String key in keys) {
        if (key.startsWith(_routeCachePrefix)) {
          await prefs.remove(key);
          cleared++;
        }
      }
      
      debugPrint('🗑️ Cleared $cleared cached routes');
    } catch (e) {
      debugPrint('❌ Error clearing route cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();
      
      int totalRoutes = 0;
      int validRoutes = 0;
      int expiredRoutes = 0;
      
      for (String key in keys) {
        if (key.startsWith(_routeCachePrefix)) {
          totalRoutes++;
          
          String? routeJson = prefs.getString(key);
          if (routeJson != null) {
            try {
              Map<String, dynamic> routeData = jsonDecode(routeJson);
              int timestamp = routeData['timestamp'] ?? 0;
              DateTime cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
              DateTime now = DateTime.now();
              
              if (now.difference(cacheTime) <= _cacheValidityDuration) {
                validRoutes++;
              } else {
                expiredRoutes++;
              }
            } catch (e) {
              expiredRoutes++;
            }
          }
        }
      }
      
      return {
        'totalRoutes': totalRoutes,
        'validRoutes': validRoutes,
        'expiredRoutes': expiredRoutes,
      };
    } catch (e) {
      debugPrint('❌ Error getting cache stats: $e');
      return {'totalRoutes': 0, 'validRoutes': 0, 'expiredRoutes': 0};
    }
  }

  /// Test OSRM connectivity
  Future<bool> testOSRMConnectivity() async {
    try {
      debugPrint('🧪 Testing OSRM connectivity...');
      
      // Test with a simple route (General Santos City area)
      final route = await getRoute(
        startLat: 6.1164,
        startLng: 125.1716,
        endLat: 6.1264,
        endLng: 125.1816,
        useCache: false,
        timeout: Duration(seconds: 5),
      );
      
      if (route != null) {
        debugPrint('✅ OSRM is accessible and working');
        return true;
      } else {
        debugPrint('❌ OSRM request failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ OSRM connectivity test failed: $e');
      return false;
    }
  }
}
