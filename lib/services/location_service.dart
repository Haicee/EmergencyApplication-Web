import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isTracking = false;
  String? _currentUserId;

  /// Start real-time location tracking for a user
  Future<void> startLocationTracking(String userId) async {
    if (_isTracking && _currentUserId == userId) return;

    _currentUserId = userId;
    _isTracking = true;

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions permanently denied');
        return;
      }

      // Start position stream with high accuracy
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) {
          _updateLocationInDatabase(userId, position);
        },
        onError: (error) {
          debugPrint('Location stream error: $error');
        },
      );

      debugPrint('Started location tracking for user: $userId');
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
    }
  }

  /// Update user location in Firebase database
  Future<void> _updateLocationInDatabase(String userId, Position position) async {
    try {
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': ServerValue.timestamp,
        'speed': position.speed,
        'heading': position.heading,
      };

      // Update current location
      await _database.child('users/$userId/currentLocation').set(locationData);

      // Also store in location history (optional, for tracking purposes)
      await _database.child('users/$userId/locationHistory').push().set(locationData);

      debugPrint('Updated location for $userId: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error updating location in database: $e');
    }
  }

  /// Stop location tracking
  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    _currentUserId = null;
    debugPrint('Stopped location tracking');
  }

  /// Get current location once (without tracking)
  Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  /// Update location once in database
  Future<void> updateCurrentLocationOnce(String userId) async {
    final position = await getCurrentLocation();
    if (position != null) {
      await _updateLocationInDatabase(userId, position);
    }
  }

  /// Check if location tracking is active
  bool get isTracking => _isTracking;

  /// Get current tracked user ID
  String? get currentUserId => _currentUserId;

  /// Dispose of resources
  void dispose() {
    stopLocationTracking();
  }
}
