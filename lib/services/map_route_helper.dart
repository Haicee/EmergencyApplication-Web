// Helper service for displaying routes on MapLibre GL maps
// Converts OSRM route data to MapLibre-compatible format

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong;

class MapRouteHelper {
  /// Convert OSRM route coordinates to MapLibre LatLng list
  /// OSRM returns coordinates as [longitude, latitude] pairs
  static List<LatLng> convertRouteCoordinates(List<dynamic> coordinates) {
    List<LatLng> latLngList = [];
    
    for (var coord in coordinates) {
      if (coord is List && coord.length >= 2) {
        double lng = coord[0].toDouble();
        double lat = coord[1].toDouble();
        latLngList.add(LatLng(lat, lng));
      }
    }
    
    return latLngList;
  }

  /// Create a line layer for the route on MapLibre map
  /// Returns the line options that can be added to the map
  static Map<String, dynamic> createRouteLineOptions({
    required List<LatLng> routeCoordinates,
    Color lineColor = Colors.blue,
    double lineWidth = 5.0,
    double lineOpacity = 0.8,
  }) {
    return {
      'coordinates': routeCoordinates,
      'lineColor': '#${lineColor.value.toRadixString(16).substring(2)}',
      'lineWidth': lineWidth,
      'lineOpacity': lineOpacity,
    };
  }

  /// Add route line to MapLibre map controller
  static Future<Line?> addRouteToMap({
    required MaplibreMapController mapController,
    required List<dynamic> routeCoordinates,
    Color lineColor = const Color(0xFF2196F3), // Blue
    double lineWidth = 5.0,
  }) async {
    try {
      // Convert coordinates
      List<LatLng> latLngList = convertRouteCoordinates(routeCoordinates);
      
      if (latLngList.isEmpty) {
        debugPrint('❌ No valid coordinates to display');
        return null;
      }

      // Add line to map
      final line = await mapController.addLine(
        LineOptions(
          geometry: latLngList,
          lineColor: '#${lineColor.value.toRadixString(16).substring(2, 8)}',
          lineWidth: lineWidth,
          lineOpacity: 0.8,
        ),
      );

      debugPrint('✅ Route line added to map with ${latLngList.length} points');
      return line;
      
    } catch (e) {
      debugPrint('❌ Error adding route to map: $e');
      return null;
    }
  }

  /// Remove route line from map
  static Future<void> removeRouteFromMap({
    required MaplibreMapController mapController,
    required Line line,
  }) async {
    try {
      await mapController.removeLine(line);
      debugPrint('✅ Route line removed from map');
    } catch (e) {
      debugPrint('❌ Error removing route from map: $e');
    }
  }

  /// Add markers for start and end points
  static Future<Map<String, Symbol>> addRouteMarkers({
    required MaplibreMapController mapController,
    required LatLng startPoint,
    required LatLng endPoint,
    String? startIconImage,
    String? endIconImage,
  }) async {
    try {
      // Add start marker (user location)
      final startMarker = await mapController.addSymbol(
        SymbolOptions(
          geometry: startPoint,
          iconImage: startIconImage ?? 'marker-15',
          iconSize: 1.5,
          textField: 'You',
          textSize: 12,
          textOffset: Offset(0, 2),
        ),
      );

      // Add end marker (station)
      final endMarker = await mapController.addSymbol(
        SymbolOptions(
          geometry: endPoint,
          iconImage: endIconImage ?? 'marker-15',
          iconSize: 1.5,
          textField: 'Station',
          textSize: 12,
          textOffset: Offset(0, 2),
        ),
      );

      debugPrint('✅ Route markers added to map');
      
      return {
        'start': startMarker,
        'end': endMarker,
      };
      
    } catch (e) {
      debugPrint('❌ Error adding route markers: $e');
      return {};
    }
  }

  /// Fit map camera to show entire route
  static Future<void> fitMapToRoute({
    required MaplibreMapController mapController,
    required List<LatLng> routeCoordinates,
    double padding = 50.0,
  }) async {
    try {
      if (routeCoordinates.isEmpty) {
        return;
      }

      // Calculate bounds
      double minLat = routeCoordinates[0].latitude;
      double maxLat = routeCoordinates[0].latitude;
      double minLng = routeCoordinates[0].longitude;
      double maxLng = routeCoordinates[0].longitude;

      for (var coord in routeCoordinates) {
        if (coord.latitude < minLat) minLat = coord.latitude;
        if (coord.latitude > maxLat) maxLat = coord.latitude;
        if (coord.longitude < minLng) minLng = coord.longitude;
        if (coord.longitude > maxLng) maxLng = coord.longitude;
      }

      // Create bounds
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // Animate camera to bounds
      await mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: padding,
          top: padding,
          right: padding,
          bottom: padding,
        ),
      );

      debugPrint('✅ Map camera fitted to route');
      
    } catch (e) {
      debugPrint('❌ Error fitting map to route: $e');
    }
  }

  /// Calculate total distance of route in kilometers
  static double calculateRouteDistance(List<LatLng> routeCoordinates) {
    if (routeCoordinates.length < 2) {
      return 0.0;
    }

    final distance = latlong.Distance();
    double totalDistance = 0.0;

    for (int i = 0; i < routeCoordinates.length - 1; i++) {
      final start = latlong.LatLng(
        routeCoordinates[i].latitude,
        routeCoordinates[i].longitude,
      );
      final end = latlong.LatLng(
        routeCoordinates[i + 1].latitude,
        routeCoordinates[i + 1].longitude,
      );
      
      totalDistance += distance.as(latlong.LengthUnit.Kilometer, start, end);
    }

    return totalDistance;
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distanceKm.toStringAsFixed(2)} km';
    }
  }

  /// Format duration for display
  static String formatDuration(double durationMinutes) {
    if (durationMinutes < 1.0) {
      return '< 1 min';
    } else if (durationMinutes < 60) {
      return '${durationMinutes.toStringAsFixed(0)} min';
    } else {
      int hours = (durationMinutes / 60).floor();
      int minutes = (durationMinutes % 60).round();
      return '${hours}h ${minutes}min';
    }
  }

  /// Create route info widget for display
  static Widget buildRouteInfoCard({
    required double distance,
    required double duration,
    String? stationName,
    VoidCallback? onNavigate,
  }) {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stationName != null) ...[
              Text(
                'Route to $stationName',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(Icons.straighten, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Distance: ${formatDistance(distance)}',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Duration: ${formatDuration(duration)}',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            if (onNavigate != null) ...[
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onNavigate,
                  icon: Icon(Icons.navigation),
                  label: Text('Start Navigation'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
