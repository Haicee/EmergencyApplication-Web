import 'package:emergency/models/station.dart';
import 'package:flutter/material.dart';
import 'offline_emergency_service.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator package for Position class

enum EmergencyMode {
  online,  // Agora voice call + real-time map
  offline, // SMS alert + GPS coordinates
}

class EmergencyModeService {
  static final EmergencyModeService _instance = EmergencyModeService._internal();
  factory EmergencyModeService() => _instance;
  EmergencyModeService._internal();

  final OfflineEmergencyService _offlineService = OfflineEmergencyService();

  /// Determine the best emergency mode based on connectivity
  Future<EmergencyMode> determineEmergencyMode() async {
    bool hasInternet = await _offlineService.hasInternetConnection();
    return hasInternet ? EmergencyMode.online : EmergencyMode.offline;
  }

  /// Handle emergency call with automatic mode selection
  Future<Map<String, dynamic>> handleEmergencyCall({
    required String userName,
    String? additionalInfo,
    EmergencyMode? forceMode,
    Station? targetStation,
    Position? userLocation,
  }) async {
    try {
      // Determine emergency mode (or use forced mode)
      EmergencyMode mode = forceMode ?? await determineEmergencyMode();
      
      if (mode == EmergencyMode.offline) {
        // Handle offline emergency with SMS
        return await _handleOfflineEmergency(userName, additionalInfo, targetStation, userLocation);
      } else {
        // Handle online emergency with existing Agora system
        return await _handleOnlineEmergency(userName, additionalInfo, targetStation, userLocation);
      }
    } catch (e) {
      return {
        'success': false,
        'mode': 'error',
        'message': 'Emergency service error: $e',
      };
    }
  }

  /// Handle offline emergency using SMS
  Future<Map<String, dynamic>> _handleOfflineEmergency(String userName, String? additionalInfo, Station? targetStation, Position? userPosition) async {
    Map<String, dynamic> result = await _offlineService.handleOfflineEmergency(
      userName: userName,
      additionalInfo: additionalInfo,
      userPosition: userPosition, // Pass the location to avoid re-requesting GPS
    );
    
    result['mode'] = 'offline';
    return result;
  }

  /// Handle online emergency using existing Agora system
  Future<Map<String, dynamic>> _handleOnlineEmergency(String userName, String? additionalInfo, Station? targetStation, Position? userLocation) async {
    // This will integrate with your existing Agora voice call system
    // For now, return a placeholder that indicates online mode should be used
    // Include station information if available
    return {
      'success': true,
      'mode': 'online',
      'message': 'Connecting to emergency services via voice call...',
      'useAgoraCall': true,
      'stationName': targetStation?.name,
      'targetStation': targetStation,
      'userLocation': userLocation,
    };
  }

  /// Show emergency mode dialog to user
  Future<EmergencyMode?> showEmergencyModeDialog(BuildContext context) async {
    EmergencyMode currentMode = await determineEmergencyMode();
    
    return showDialog<EmergencyMode>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '🚨 Emergency Mode',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentMode == EmergencyMode.online
                    ? 'Internet connection detected'
                    : 'No internet connection detected',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              _buildModeOption(
                context: context,
                icon: Icons.call,
                title: 'Voice Call',
                subtitle: 'Live call with emergency services',
                isRecommended: currentMode == EmergencyMode.online,
                isAvailable: currentMode == EmergencyMode.online,
                mode: EmergencyMode.online,
              ),
              SizedBox(height: 12),
              _buildModeOption(
                context: context,
                icon: Icons.sms,
                title: 'SMS Alert',
                subtitle: 'Send location via text message',
                isRecommended: currentMode == EmergencyMode.offline,
                isAvailable: true,
                mode: EmergencyMode.offline,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isRecommended,
    required bool isAvailable,
    required EmergencyMode mode,
  }) {
    return Builder(
      builder: (context) => InkWell(
        onTap: isAvailable
            ? () => Navigator.of(context).pop(mode)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isRecommended ? Colors.red : Colors.grey[300]!,
              width: isRecommended ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isAvailable
                ? (isRecommended ? Colors.red[50] : Colors.grey[50])
                : Colors.grey[100],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isAvailable
                    ? (isRecommended ? Colors.red : Colors.grey[600])
                    : Colors.grey[400],
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? Colors.black : Colors.grey[400],
                          ),
                        ),
                        if (isRecommended) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isAvailable ? Colors.grey[600] : Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAvailable)
                Icon(
                  Icons.block,
                  color: Colors.grey[400],
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quick emergency call without dialog (uses automatic mode detection)
  Future<Map<String, dynamic>> quickEmergencyCall({
    required String userName,
    String? additionalInfo,
    Station? targetStation,
    Position? userLocation,
  }) async {
    return await handleEmergencyCall(
      userName: userName,
      additionalInfo: additionalInfo,
      targetStation: targetStation,
      userLocation: userLocation,
    );
  }

  /// Force offline mode (useful for testing)
  Future<Map<String, dynamic>> forceOfflineEmergency({
    required String userName,
    String? additionalInfo,
    Station? targetStation,
    Position? userLocation,
  }) async {
    return await handleEmergencyCall(
      userName: userName,
      additionalInfo: additionalInfo,
      forceMode: EmergencyMode.offline,
      targetStation: targetStation,
      userLocation: userLocation,
    );
  }

  /// Force online mode
  Future<Map<String, dynamic>> forceOnlineEmergency({
    required String userName,
    String? additionalInfo,
    Station? targetStation,
    Position? userLocation,
  }) async {
    return await handleEmergencyCall(
      userName: userName,
      additionalInfo: additionalInfo,
      forceMode: EmergencyMode.online,
      targetStation: targetStation,
      userLocation: userLocation,
    );
  }
}
