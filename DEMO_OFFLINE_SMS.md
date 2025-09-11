# Demo: Offline Emergency SMS System

## Overview
This demo shows how to use the offline emergency SMS functionality that automatically sends GPS-based emergency alerts to the nearest police station when internet is unavailable.

## Prerequisites Setup

### 1. Update pubspec.yaml Dependencies
Ensure these packages are in your `pubspec.yaml`:
```yaml
dependencies:
  telephony: ^0.2.0
  geolocator: ^9.0.2
  connectivity_plus: ^4.0.2
  shared_preferences: ^2.2.2
  firebase_database: ^10.5.0
```

### 2. Android Permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
```

## Demo Implementation

### Step 1: Create Demo Screen
```dart
// lib/demo/offline_sms_demo.dart
import 'package:flutter/material.dart';
import '../services/offline_emergency_service.dart';

class OfflineSMSDemo extends StatefulWidget {
  @override
  _OfflineSMSDemoState createState() => _OfflineSMSDemoState();
}

class _OfflineSMSDemoState extends State<OfflineSMSDemo> {
  final OfflineEmergencyService _emergencyService = OfflineEmergencyService();
  String _status = 'Ready';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Offline Emergency SMS Demo'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Display
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.emergency,
                      size: 48,
                      color: Colors.red,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Emergency SMS System',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 16,
                        color: _isLoading ? Colors.orange : Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Demo Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testConnectivity,
              icon: Icon(Icons.wifi),
              label: Text('Check Connectivity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testGPSLocation,
              icon: Icon(Icons.location_on),
              label: Text('Test GPS Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendTestEmergencySMS,
              icon: Icon(Icons.sms),
              label: Text('Send Test Emergency SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Emergency Button (Main Feature)
            Container(
              height: 80,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleEmergency,
                icon: Icon(Icons.emergency, size: 32),
                label: Text(
                  'EMERGENCY ALERT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Instructions
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demo Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Test individual components first'),
                    Text('2. Use "EMERGENCY ALERT" for full demo'),
                    Text('3. Check console for detailed logs'),
                    Text('4. Ensure you have SMS permissions'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnectivity() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking connectivity...';
    });

    try {
      bool hasInternet = await _emergencyService.hasInternetConnection();
      setState(() {
        _status = hasInternet ? 'Online Mode Available' : 'Offline Mode - SMS Ready';
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking connectivity: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testGPSLocation() async {
    setState(() {
      _isLoading = true;
      _status = 'Getting GPS location...';
    });

    try {
      var position = await _emergencyService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _status = 'Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        });
      } else {
        setState(() {
          _status = 'Failed to get GPS location';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'GPS Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestEmergencySMS() async {
    setState(() {
      _isLoading = true;
      _status = 'Sending test SMS...';
    });

    try {
      // Use your own phone number for testing
      String testPhoneNumber = "YOUR_PHONE_NUMBER"; // Replace with your number
      
      bool success = await _emergencyService.sendEmergencySMS(
        stationPhoneNumber: testPhoneNumber,
        userName: "Demo User",
        latitude: 6.114152463229464,
        longitude: 125.17060062489488,
        additionalInfo: "This is a test emergency SMS",
      );

      setState(() {
        _status = success ? 'Test SMS sent successfully!' : 'Failed to send test SMS';
      });
    } catch (e) {
      setState(() {
        _status = 'SMS Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmergency() async {
    setState(() {
      _isLoading = true;
      _status = 'Processing emergency...';
    });

    try {
      var result = await _emergencyService.handleOfflineEmergency(
        userName: "Demo User",
        additionalInfo: "Emergency assistance needed",
      );

      setState(() {
        if (result['success']) {
          _status = 'Emergency alert sent successfully!\n${result['message']}';
        } else {
          _status = 'Emergency failed: ${result['message']}';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Emergency Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
```

### Step 2: Add Demo to Main App
```dart
// In your main.dart or navigation
import 'demo/offline_sms_demo.dart';

// Add navigation to demo
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => OfflineSMSDemo()),
);
```

## Testing the Demo

### Test Scenario 1: Online Mode
1. Ensure device has internet connection
2. Tap "Check Connectivity" → Should show "Online Mode Available"
3. Tap "Test GPS Location" → Should show your coordinates
4. Tap "EMERGENCY ALERT" → Should detect online mode and show appropriate message

### Test Scenario 2: Offline Mode
1. Turn off WiFi and mobile data (keep cellular for SMS)
2. Tap "Check Connectivity" → Should show "Offline Mode - SMS Ready"
3. Tap "Test GPS Location" → Should still work (GPS doesn't need internet)
4. Tap "Send Test Emergency SMS" → Should send SMS to your test number
5. Tap "EMERGENCY ALERT" → Should send SMS to nearest station

### Expected SMS Format
```
🚨 EMERGENCY ALERT
Location: 6.114152, 125.170601
User: Demo User
Time: 14:30
Emergency assistance needed
- Emergency App
```

## Console Output to Monitor
```
Emergency SMS sent to: +639519918057
Current location: 6.114152463229464, 125.17060062489488
Nearest station: PSTD01
Distance to station: 2.5 km
Successfully cached 5 stations
```
