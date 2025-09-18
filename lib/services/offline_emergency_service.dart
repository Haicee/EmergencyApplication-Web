import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/station.dart';

class OfflineEmergencyService {
  static final OfflineEmergencyService _instance = OfflineEmergencyService._internal();
  factory OfflineEmergencyService() => _instance;
  OfflineEmergencyService._internal();

  final Telephony _telephony = Telephony.instance;
  static const String _stationCacheKey = 'cached_stations';
  static const String _lastUpdateKey = 'stations_last_update';
  static const Duration _cacheValidityDuration = Duration(hours: 24);

  // Native Android SMS channel for multi-SIM support
  static const MethodChannel _smsChannel = MethodChannel('emergency_sms');

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      // TESTING: Force offline mode for testing
      // return false; // Uncomment this line to force offline mode
      
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Get current GPS coordinates (works offline) - Enhanced with better timeout handling
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled');
        throw Exception('Location services are disabled');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permissions are denied');
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permissions are permanently denied');
        throw Exception('Location permissions are permanently denied');
      }

      debugPrint('🔍 Attempting to get GPS location...');

      // Try high accuracy first with shorter timeout
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        );
        debugPrint('✅ Got high accuracy location: ${position.latitude}, ${position.longitude}');
        return position;
      } on TimeoutException {
        debugPrint('⚠️ High accuracy GPS timed out, trying medium accuracy...');
      }

      // Fallback to medium accuracy with longer timeout
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        );
        debugPrint('✅ Got medium accuracy location: ${position.latitude}, ${position.longitude}');
        return position;
      } on TimeoutException {
        debugPrint('⚠️ Medium accuracy GPS timed out, trying low accuracy...');
      }

      // Final fallback to low accuracy or last known position
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        );
        debugPrint('✅ Got low accuracy location: ${position.latitude}, ${position.longitude}');
        return position;
      } on TimeoutException {
        debugPrint('⚠️ All GPS attempts timed out, trying last known position...');
        
        // Try to get last known position as final fallback
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          debugPrint('✅ Using last known location: ${lastPosition.latitude}, ${lastPosition.longitude}');
          return lastPosition;
        }
      }

      debugPrint('❌ All location attempts failed');
      return null;

    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      
      // Try last known position as emergency fallback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          debugPrint('✅ Emergency fallback - using last known location: ${lastPosition.latitude}, ${lastPosition.longitude}');
          return lastPosition;
        }
      } catch (e2) {
        debugPrint('❌ Even last known position failed: $e2');
      }
      
      return null;
    }
  }

  /// Find nearest station based on geofence data
  Future<Map<String, dynamic>?> findNearestStation(double userLat, double userLng) async {
    try {
      List<Map<String, dynamic>> stations = await getCachedStations();
      
      if (stations.isEmpty) {
        print('No cached station data available');
        return null;
      }

      Map<String, dynamic>? nearestStation;
      double minDistance = double.infinity;

      for (var station in stations) {
        if (station['latitude'] != null && station['longitude'] != null) {
          double stationLat = double.parse(station['latitude'].toString());
          double stationLng = double.parse(station['longitude'].toString());
          
          double distance = _calculateDistance(userLat, userLng, stationLat, stationLng);
          
          if (distance < minDistance) {
            minDistance = distance;
            nearestStation = station;
          }
        }
      }

      return nearestStation;
    } catch (e) {
      print('Error finding nearest station: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
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

  /// Format emergency SMS message
  String formatEmergencySMS({
    required String userName,
    required double latitude,
    required double longitude,
    String? additionalInfo,
  }) {
    DateTime now = DateTime.now();
    String timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    String message = '''🚨 EMERGENCY ALERT 🚨
Location: $latitude, $longitude
User: $userName
Time: $timeStr
Instruction: Copy the location and paste it on the map.''';

    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      message += '\nInfo: $additionalInfo';
    }

    message += '\n- Emergency App';
    
    return message;
  }

  /// Send emergency SMS using hybrid approach: telephony first, url_launcher fallback
  Future<Map<String, dynamic>> sendEmergencySMSHybrid({
    required String stationPhoneNumber,
    required String userName,
    required double latitude,
    required double longitude,
    String? additionalInfo,
  }) async {
    Map<String, dynamic> result = {
      'success': false,
      'method': '',
      'message': '',
      'requiresUserAction': false,
    };

    try {
      debugPrint('🔄 Starting hybrid SMS approach...');
      
      // Step 1: Try telephony first (silent SMS)
      debugPrint('📱 Attempting telephony (silent SMS)...');
      bool telephonySuccess = await _sendViaTelephonyEnhanced(
        stationPhoneNumber: stationPhoneNumber,
        userName: userName,
        latitude: latitude,
        longitude: longitude,
        additionalInfo: additionalInfo,
      );

      if (telephonySuccess) {
        result['success'] = true;
        result['method'] = 'telephony';
        result['message'] = 'Emergency SMS sent successfully';
        result['requiresUserAction'] = false;
        debugPrint('✅ Telephony SMS successful - no user action required');
        return result;
      }

      // Step 2: Fallback to url_launcher (requires user tap)
      debugPrint('📱 Telephony failed, falling back to url_launcher...');
      bool urlLauncherSuccess = await _sendViaUrlLauncher(
        stationPhoneNumber: stationPhoneNumber,
        userName: userName,
        latitude: latitude,
        longitude: longitude,
        additionalInfo: additionalInfo,
      );

      if (urlLauncherSuccess) {
        result['success'] = true;
        result['method'] = 'url_launcher';
        result['message'] = 'Please tap SEND in the Messages app';
        result['requiresUserAction'] = true;
        debugPrint('✅ URL launcher successful - user needs to tap SEND');
        return result;
      }

      // Both methods failed
      result['message'] = 'Both SMS methods failed - please call emergency services directly';
      debugPrint('❌ Both telephony and url_launcher failed');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error in hybrid SMS system: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      result['message'] = 'SMS system error: $e';
    }

    return result;
  }

  /// Private method: Check if app can send SMS (simplified approach)
  Future<bool> _checkSmsCapability() async {
    try {
      // Check if device supports SMS
      bool? isSmsCapable = await _telephony.isSmsCapable;
      if (isSmsCapable != true) {
        debugPrint('❌ Device does not support SMS');
        return false;
      }

      debugPrint('✅ Device supports SMS');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking SMS capability: $e');
      return false;
    }
  }

  /// Private method: Send SMS via telephony (silent)
  Future<bool> _sendViaTelephony({
    required String stationPhoneNumber,
    required String userName,
    required double latitude,
    required double longitude,
    String? additionalInfo,
  }) async {
    try {
      debugPrint('🔍 Checking SMS permissions for telephony...');
      
      // Check if platform is Android
      if (!Platform.isAndroid) {
        debugPrint('❌ Telephony only works on Android');
        return false;
      }

      // Check SMS capability first
      bool hasCapability = await _checkSmsCapability();
      if (!hasCapability) {
        debugPrint('❌ Device SMS capability check failed');
        return false;
      }

      // Request SMS permissions first
      final smsStatus = await Permission.sms.request();
      final phoneStatus = await Permission.phone.request();
      
      if (!smsStatus.isGranted) {
        debugPrint('❌ SMS permission not granted for telephony');
        return false;
      }
      
      if (!phoneStatus.isGranted) {
        debugPrint('❌ Phone permission not granted for telephony');
        return false;
      }

      // Format the message
      final message = formatEmergencySMS(
        userName: userName,
        latitude: latitude,
        longitude: longitude,
        additionalInfo: additionalInfo,
      );

      debugPrint('📱 Attempting telephony SMS to: $stationPhoneNumber');
      debugPrint('📄 Message content: $message');

      // Method 1: Try native Android SMS (works better with MediaTek)
      try {
        debugPrint('📱 Trying native Android SMS...');
        final result = await _smsChannel.invokeMethod('sendSMS', {
          'phoneNumber': stationPhoneNumber,
          'message': message,
        });
        debugPrint('✅ Native Android SMS sent successfully: $result');
        return true;
      } catch (e) {
        debugPrint('⚠️ Native Android SMS failed: $e');
      }

      // Method 2: Try Flutter telephony plugin
      try {
        debugPrint('� Trying Flutter telephony plugin...');
        await _telephony.sendSms(
          to: stationPhoneNumber,
          message: message,
        );
        debugPrint('✅ Flutter telephony SMS sent successfully');
        return true;
      } catch (e) {
        debugPrint('⚠️ Flutter telephony failed: $e');
      }

      // Method 3: Try with status listener
      try {
        debugPrint('📱 Trying telephony with status listener...');
        await _telephony.sendSms(
          to: stationPhoneNumber,
          message: message,
          statusListener: (status) {
            debugPrint('📋 SMS Status: $status');
          },
        );
        debugPrint('✅ Telephony with status listener sent successfully');
        return true;
      } catch (e) {
        debugPrint('⚠️ Telephony with status listener failed: $e');
      }

      return false;
      
    } on PlatformException catch (e) {
      debugPrint('❌ Platform error in telephony SMS: ${e.message}');
      debugPrint('📋 Error code: ${e.code}');
      debugPrint('📋 Error details: ${e.details}');
      
      // Common telephony errors and their meanings
      if (e.message?.contains('SmsManager') == true) {
        debugPrint('💡 SmsManager error - this usually means:');
        debugPrint('   1. App is not set as default SMS app (Android 4.4+)');
        debugPrint('   2. Device has restricted SMS access');
        debugPrint('   3. SIM card issues or no SIM card');
        debugPrint('   4. MediaTek device with custom SMS restrictions');
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error in telephony SMS: $e');
      return false;
    }
  }

  /// Check SIM card status and availability
  Future<Map<String, dynamic>> checkSimStatus() async {
    try {
      final result = await _smsChannel.invokeMethod('checkSimCards');
      debugPrint('📱 SIM Status: $result');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('❌ Error checking SIM status: $e');
      return {'hasSimCard': false, 'error': e.toString()};
    }
  }

  /// Private method: Send SMS via url_launcher (requires user action)
  Future<bool> _sendViaUrlLauncher({
    required String stationPhoneNumber,
    required String userName,
    required double latitude,
    required double longitude,
    String? additionalInfo,
  }) async {
    try {
      // Format the message
      final message = formatEmergencySMS(
        userName: userName,
        latitude: latitude,
        longitude: longitude,
        additionalInfo: additionalInfo,
      );

      debugPrint('📱 Attempting url_launcher SMS to: $stationPhoneNumber');

      // Create SMS URL with pre-filled message
      final encodedMessage = Uri.encodeComponent(message);
      final smsUri = Uri.parse('sms:$stationPhoneNumber?body=$encodedMessage');

      // Check if SMS can be launched
      if (!await canLaunchUrl(smsUri)) {
        debugPrint('❌ Cannot launch SMS URL');
        return false;
      }

      // Launch SMS app with pre-filled message
      await launchUrl(smsUri);
      
      debugPrint('✅ SMS app opened with pre-filled message');
      return true;
      
    } catch (e) {
      debugPrint('❌ Error in url_launcher SMS: $e');
      return false;
    }
  }

  /// Check device compatibility for SMS sending
  Future<Map<String, dynamic>> checkDeviceCompatibility() async {
    try {
      final result = await _smsChannel.invokeMethod('checkDeviceCompatibility');
      debugPrint('📱 Device Compatibility: $result');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('❌ Error checking device compatibility: $e');
      return {
        'supportsSMS': false, 
        'knownIssues': 'Unable to check device compatibility',
        'recommendedAction': 'Use URL launcher method',
        'error': e.toString()
      };
    }
  }

  /// Enhanced telephony method with device compatibility check
  Future<bool> _sendViaTelephonyEnhanced({
    required String stationPhoneNumber,
    required String userName,
    required double latitude,
    required double longitude,
    String? additionalInfo,
  }) async {
    try {
      debugPrint('🔍 Enhanced telephony SMS process starting...');
      
      // Check SIM status
      final simStatus = await checkSimStatus();
      if (!(simStatus['hasSimCard'] ?? false)) {
        debugPrint('❌ No active SIM card found');
        return false;
      }
      
      debugPrint('✅ SIM Status: ${simStatus['activeSimCount'] ?? 0} active SIM(s)');
      
      // Format the message
      final message = formatEmergencySMS(
        userName: userName,
        latitude: latitude,
        longitude: longitude,
        additionalInfo: additionalInfo,
      );

      debugPrint('📱 Attempting enhanced telephony SMS to: $stationPhoneNumber');
      
      // Try native Android SMS first (best compatibility)
      try {
        debugPrint('📱 Trying enhanced native Android SMS...');
        final result = await _smsChannel.invokeMethod('sendSMS', {
          'phoneNumber': stationPhoneNumber,
          'message': message,
        });
        debugPrint('✅ Enhanced native Android SMS sent successfully: $result');
        return true;
      } catch (e) {
        debugPrint('⚠️ Enhanced native Android SMS failed: $e');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Error in enhanced telephony SMS: $e');
      return false;
    }
  }

  /// Main method to handle offline emergency
  Future<Map<String, dynamic>> handleOfflineEmergency({
    required String userName,
    String? additionalInfo,
    Position? userPosition, // Add optional position parameter
  }) async {
    Map<String, dynamic> result = {
      'success': false,
      'message': '',
      'location': null,
      'station': null,
    };

    try {
      // Step 1: Get current location (use provided position or get new one)
      Position? position = userPosition;
      if (position == null) {
        debugPrint('📍 No position provided, attempting to get current location...');
        position = await getCurrentLocation();
        if (position == null) {
          debugPrint('⚠️ Unable to get current location, will send SMS without precise location');
          // Don't return here - continue with SMS sending using fallback location
        }
      } else {
        debugPrint('📍 Using provided position: ${position.latitude}, ${position.longitude}');
      }

      if (position != null) {
        result['location'] = {
          'latitude': position.latitude,
          'longitude': position.longitude,
        };
      }

      Map<String, dynamic>? targetStation;

      // Step 1: If we have a position, find the nearest station.
      if (position != null) {
        targetStation = await findNearestStation(
          position.latitude,
          position.longitude,
        );
      }

      // Step 2: If still no station (e.g., location failed), get any available station from cache as a last resort.
      if (targetStation == null) {
        print('No station found via location. Getting first available station...');
        List<Map<String, dynamic>> stations = await getCachedStations();
        if (stations.isNotEmpty) {
          targetStation = stations.first;
          print('📍 Using first available station: ${targetStation['name']}');
        }
      }

      if (targetStation == null) {
        result['message'] = 'No station available for emergency SMS';
        return result;
      }

      result['station'] = targetStation;

      // Step 6: Send SMS to station
      String stationPhone = targetStation['hotline'] ?? '';
      if (stationPhone.isEmpty) {
        result['message'] = 'Station phone number not available';
        return result;
      }

      print('📞 Found station hotline: $stationPhone');
      print('👤 Sending SMS for user: $userName');

      // Use the new hybrid SMS system with fallback coordinates
      Map<String, dynamic> smsResult = await sendEmergencySMSHybrid(
        stationPhoneNumber: stationPhone,
        userName: userName,
        latitude: position?.latitude ?? 0.0, // Use 0.0 as fallback
        longitude: position?.longitude ?? 0.0, // Use 0.0 as fallback
        additionalInfo: position == null 
            ? 'Location unavailable - please call back for precise location. ${additionalInfo ?? ''}'
            : additionalInfo,
      );

      // Update result based on SMS sending outcome
      if (smsResult['success']) {
        result['success'] = true;
        result['message'] = smsResult['message'];
        result['smsMethod'] = smsResult['method'];
        result['requiresUserAction'] = smsResult['requiresUserAction'];
        
        if (smsResult['requiresUserAction']) {
          print('⚠️ Emergency SMS prepared - user needs to tap SEND in Messages app');
        } else {
          print('🎉 Emergency SMS sent silently - no user action required');
        }
      } else {
        result['message'] = smsResult['message'] ?? 'Failed to send emergency SMS';
        print('💥 Emergency SMS process failed: ${result['message']}');
      }

    } catch (e) {
      result['message'] = 'Emergency service error: $e';
      debugPrint('❌ Error in handleOfflineEmergency: $e');
    }

    return result;
  }

  /// Cache station data from Firebase for offline use
  Future<bool> cacheStationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if we have internet to fetch fresh data
      if (!await hasInternetConnection()) {
        print('No internet connection. Using existing cached data.');
        return await _hasCachedStations();
      }

      // Fetch stations from Firebase Realtime Database
      final database = FirebaseDatabase.instance.ref();
      final stationsSnapshot = await database.child('Desk Officer').get();

      if (!stationsSnapshot.exists || stationsSnapshot.value == null) {
        print('No stations found in Firebase Realtime Database under Desk Officer');
        return false;
      }

      // Convert stations to cacheable format
      List<Map<String, dynamic>> stationsData = [];
      Map<dynamic, dynamic> stationsMap = stationsSnapshot.value as Map<dynamic, dynamic>;
      
      stationsMap.forEach((key, value) {
        if (value is Map) {
          Map<String, dynamic> stationData = Map<String, dynamic>.from(value as Map);
          
          // Check if this is a station (has station info)
          if (stationData.containsKey('name') || key.toString().startsWith('Police Station')) {
            stationData['id'] = key.toString();
            stationData['name'] = stationData['name'] ?? key.toString();
            stationsData.add(stationData);
          }
        }
      });

      // Cache the data
      String stationsJson = jsonEncode(stationsData);
      await prefs.setString(_stationCacheKey, stationsJson);
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);

      print('Successfully cached ${stationsData.length} stations');
      return true;
    } catch (e) {
      print('Error caching station data: $e');
      return await _hasCachedStations();
    }
  }

  /// Get cached station data
  Future<List<Map<String, dynamic>>> getCachedStations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if cache exists and is valid
      if (!await _isCacheValid()) {
        // Try to refresh cache if we have internet
        if (await hasInternetConnection()) {
          await cacheStationData();
        }
      }

      String? stationsJson = prefs.getString(_stationCacheKey);
      if (stationsJson == null) {
        print('No cached stations found');
        return [];
      }

      List<dynamic> stationsData = jsonDecode(stationsJson);
      return stationsData.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting cached stations: $e');
      return [];
    }
  }

  /// Check if cached data exists
  Future<bool> _hasCachedStations() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_stationCacheKey);
  }

  /// Check if cached data is still valid
  Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (!prefs.containsKey(_lastUpdateKey)) {
        return false;
      }

      int lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      DateTime lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      DateTime now = DateTime.now();

      return now.difference(lastUpdateTime) < _cacheValidityDuration;
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
  }

  /// Clear cached station data
  Future<void> clearStationCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stationCacheKey);
      await prefs.remove(_lastUpdateKey);
      print('Station cache cleared');
    } catch (e) {
      print('Error clearing station cache: $e');
    }
  }

  /// Get cache status information
  Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool hasCache = await _hasCachedStations();
      bool isValid = await _isCacheValid();
      
      int lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      DateTime? lastUpdateTime = lastUpdate > 0 
          ? DateTime.fromMillisecondsSinceEpoch(lastUpdate)
          : null;

      List<Map<String, dynamic>> stations = await getCachedStations();

      return {
        'hasCache': hasCache,
        'isValid': isValid,
        'lastUpdate': lastUpdateTime?.toIso8601String(),
        'stationCount': stations.length,
        'cacheSize': prefs.getString(_stationCacheKey)?.length ?? 0,
      };
    } catch (e) {
      print('Error getting cache status: $e');
      return {
        'hasCache': false,
        'isValid': false,
        'lastUpdate': null,
        'stationCount': 0,
        'cacheSize': 0,
      };
    }
  }

  /// Get cached current station from SharedPreferences
  Future<Map<String, dynamic>?> getCachedCurrentStation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stationJson = prefs.getString('current_station');
      if (stationJson != null) {
        return Map<String, dynamic>.from(jsonDecode(stationJson));
      }
    } catch (e) {
      print('Error getting cached station: $e');
    }
    return null;
  }

  /// Find station by geofence
  Future<Map<String, dynamic>?> findStationByGeofence(
      double userLat, double userLng) async {
    try {
      final stations = await getCachedStations();
      print('🔍 Checking geofence for ${stations.length} cached stations');
      
      for (final station in stations) {
        try {
          final stationLat = double.tryParse(station['latitude']?.toString() ?? '');
          final stationLng = double.tryParse(station['longitude']?.toString() ?? '');
          final radius = double.tryParse(station['radius']?.toString() ?? '0') ?? 0;

          if (stationLat == null || stationLng == null) continue;

          final distance = _calculateDistance(
            userLat,
            userLng,
            stationLat,
            stationLng,
          ) * 1000; // Convert to meters

          print('🏢 Checking ${station['name'] ?? 'Unknown Station'}: distance = ${distance.toStringAsFixed(2)}m, radius = ${radius}m');

          if (distance <= radius) {
            print('✅ User is inside geofence of ${station['name'] ?? 'Unknown Station'}. Routing call there.');
            print('📞 Station hotline: ${station['hotline']}');
            
            // Cache this station for future use
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('current_station', jsonEncode(station));
            return station;
          }
        } catch (e) {
          print('Error processing station ${station['name']}: $e');
          continue;
        }
      }
      
      print('❌ User is not within any station geofence');
    } catch (e) {
      print('Error in findStationByGeofence: $e');
    }
    return null;
  }
}
