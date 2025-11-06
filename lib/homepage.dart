import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'connecting_page.dart';
import 'incomingCall.dart';
import 'emergencyCallBack.dart';
import 'package:firebase_database/firebase_database.dart';
import 'profile.dart';
import 'models/station.dart';
import 'screens/map_screen.dart';
import 'services/geofence_manager.dart';
import 'services/emergency_mode_service.dart'; // Import the emergency mode service
import 'services/offline_emergency_service.dart'; // Import the offline emergency service
import 'services/offline_map_service.dart'; // Import the offline map service
import 'package:connectivity_plus/connectivity_plus.dart'; // Import connectivity
import 'services/sync_service.dart'; // Import the new SyncService
import 'package:fluttertoast/fluttertoast.dart'; // Import fluttertoast
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher for phone dialer
import 'services/call_notification_service.dart';

class ResponsiveHomePage extends StatelessWidget {
  final String username;

  const ResponsiveHomePage({Key? key, required this.username}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('App Name'),
        actions: [
          IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: const CircleAvatar(child: Icon(Icons.person)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLargeScreen ? size.width * 0.2 : 16.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $username!',
                style: TextStyle(fontSize: isLargeScreen ? 32 : 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: isLargeScreen ? 350 : double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      textStyle: TextStyle(fontSize: isLargeScreen ? 22 : 18),
                    ),
                    child: Text('Primary Action'),
                  ),
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Quick Access',
                style: TextStyle(fontSize: isLargeScreen ? 24 : 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 16),
              // Example: Responsive grid of cards
              GridView.count(
                crossAxisCount: isLargeScreen ? 3 : 2,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: List.generate(6, (index) {
                  return Card(
                    child: Center(child: Text('Feature ${index + 1}')),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String username;
  const HomePage({Key? key, required this.username}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  String _currentLocation = "Locating...";
  late AnimationController _controller;
  Timer? _holdTimer;
  String? _profileImageUrl;

  // Incoming callback listening
  StreamSubscription? _incomingCallSub;
  bool _isShowingIncomingDialog = false;
  final Set<String> _activeIncomingCallIds = {};
  bool _isEmergencyInProgress = false; // Add this variable
  
  // Stations data
  List<Station> _stations = [];
  bool _isLoadingStations = true;
  final GeofenceManager _geofenceManager = GeofenceManager();
  final EmergencyModeService _emergencyModeService = EmergencyModeService(); // Initialize the emergency mode service
  final OfflineEmergencyService _offlineEmergencyService = OfflineEmergencyService(); // Initialize the offline emergency service
  final OfflineMapService _offlineMapService = OfflineMapService(); // Initialize the offline map service
  final SyncService _syncService = SyncService(); // Initialize the new SyncService

  double _downloadProgress = 0.0;
  bool _isDownloadingMap = false;
  StreamSubscription? _mapDownloadSubscription;
  Timer? _toastUpdateTimer;
  double _lastToastProgress = -1.0;
  
  // Connectivity status
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;
  
  // Routing information for display
  double? _lastRouteDistance;
  double? _lastRouteDuration;
  bool _showConnectivityBanner = false;
  Timer? _connectivityBannerTimer;

  Future<void> _loadProfileImage() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(widget.username)
          .child('profileImageUrl')
          .get();
      if (snapshot.exists) {
        final url = snapshot.value?.toString();
        if (mounted) {
          setState(() {
            _profileImageUrl = (url != null && url.isNotEmpty && url != 'Not provided') ? url : null;
          });
        }
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _loadProfileImage();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // Ensure FCM token is saved for this user to receive incoming-call pushes
    CallNotificationService().saveFcmTokenForUser(widget.username);
    _listenForIncomingCallbacks();
    _loadStations();
    
    // Check profile completion after a short delay
    Future.delayed(Duration(milliseconds: 10000), () {
      _checkProfileCompletion();
    });

    // Initialize the sync service to handle background updates
    _syncService.initialize();

    // Listen for map download progress updates for the UI
    _listenForMapDownloadProgress();
    
    // Check initial connectivity status
    _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectivityStatus(result);
    });
  }

  Future<void> _checkProfileCompletion() async {
    try {
      // Check if user has incomplete profile fields
      final DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(widget.username);
      
      final DataSnapshot snapshot = await userRef.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Check if any required fields are "Not provided"
        bool hasIncompleteFields = [
          userData['country'],
          userData['region'], 
          userData['city'],
          userData['barangay'],
          userData['streetAddress'],
          userData['gender']
        ].any((field) => field == 'Not provided' || field == null || field.toString().isEmpty);
        
        if (hasIncompleteFields) {
          _showProfileCompletionDialog();
        }
      }
    } catch (e) {
      print('Error checking profile completion: $e');
    }
  }

  void _showProfileCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Set your profile for emergency purposes. Do you want to update it now?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Dialog will show again on next app open
                      },
                      child: Text(
                        'Later',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _goToProfilePage();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 247, 65, 59),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Update Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goToProfilePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(username: widget.username),
      ),
    ).then((_) => _loadProfileImage());
  }
   
  void _goToMapScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(stations: _stations),
      ),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _incomingCallSub?.cancel();
    _geofenceManager.dispose();
    _controller.dispose();
    _mapDownloadSubscription?.cancel();
    _offlineMapService.dispose();
    _syncService.dispose(); // Dispose the sync service
    _connectivitySubscription?.cancel();
    _connectivityBannerTimer?.cancel();
    _toastUpdateTimer?.cancel();
    super.dispose();
  }


  Future<void> _loadStations() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      final snapshot = await db.child('Desk Officer').get();
      
      if (snapshot.exists) {
        final stationsData = Map<String, dynamic>.from(snapshot.value as Map);
        final loadedStations = <Station>[];
        
        stationsData.forEach((stationId, data) {
          if (data is Map) {
            final stationData = Map<String, dynamic>.from(data);
            
            // Check if this is a station (has station info)
            if (stationData.containsKey('name') || stationId.startsWith('Police Station')) {
              // Parse and validate coordinates
              final latitude = double.tryParse(stationData['latitude']?.toString() ?? '0.0') ?? 0.0;
              final longitude = double.tryParse(stationData['longitude']?.toString() ?? '0.0') ?? 0.0;
              
              // Skip stations with invalid coordinates (0,0) or out of reasonable bounds
              if (_isValidCoordinate(latitude, longitude)) {
                final station = Station(
                  id: stationId,
                  name: stationData['name'] ?? stationId, // Use ID as fallback for name
                  hotline: stationData['hotline'] ?? 'No hotline',
                  streetAddress: stationData['streetAddress'] ?? stationData['address'] ?? '',
                  city: stationData['city'] ?? '',
                  region: stationData['region'] ?? '',
                  latitude: latitude,
                  longitude: longitude,
                  radius: double.tryParse(stationData['radius']?.toString() ?? '500.0') ?? 500.0,
                );
                loadedStations.add(station);
                debugPrint('✅ Loaded station: ${station.name} at (${station.latitude}, ${station.longitude})');
              } else {
                debugPrint('❌ Skipped station $stationId with invalid coordinates: ($latitude, $longitude)');
              }
            }
          }
        });
        
        // Sort stations by their ID (Police Station 1, 2, 3, etc.)
        loadedStations.sort((a, b) => a.name.compareTo(b.name));
        
        debugPrint('📍 Loaded ${loadedStations.length} valid stations with coordinates');
        
        if (mounted) {
          setState(() {
            _stations = loadedStations;
            _isLoadingStations = false;
          });
        }
      } else {
        debugPrint('❌ No station data found in Firebase');
        if (mounted) {
          setState(() {
            _isLoadingStations = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading stations: $e');
      if (mounted) {
        setState(() {
          _isLoadingStations = false;
        });
      }
    }
  }

  /// Check current connectivity status with actual internet verification
  Future<void> _checkConnectivity() async {
    try {
      debugPrint('🔍 Checking actual internet connectivity...');
      
      // Use the proper internet connectivity check from OfflineEmergencyService
      final bool hasInternet = await _offlineEmergencyService.hasInternetConnection();
      
      debugPrint('🌐 Internet connectivity result: ${hasInternet ? 'ONLINE' : 'OFFLINE'}');
      
      // Update the UI with the actual internet connectivity status
      if (mounted && _isOnline != hasInternet) {
        setState(() {
          _isOnline = hasInternet;
          _showConnectivityBanner = true;
        });
        
        // Cancel existing timer if any
        _connectivityBannerTimer?.cancel();
        
        // Hide banner after 5 seconds
        _connectivityBannerTimer = Timer(Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showConnectivityBanner = false;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking internet connectivity: $e');
      // Default to offline if connectivity check fails
      if (mounted && _isOnline != false) {
        setState(() {
          _isOnline = false;
          _showConnectivityBanner = true;
        });
      }
    }
  }

  /// Update connectivity status with actual internet verification
  void _updateConnectivityStatus(ConnectivityResult result) {
    debugPrint('📡 Connectivity change detected: ${result.name}');
    
    // If there's no basic connectivity, immediately set to offline
    if (result == ConnectivityResult.none) {
      debugPrint('❌ No WiFi/cellular connectivity detected');
      if (mounted && _isOnline != false) {
        setState(() {
          _isOnline = false;
          _showConnectivityBanner = true;
        });
        
        _connectivityBannerTimer?.cancel();
        _connectivityBannerTimer = Timer(Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showConnectivityBanner = false;
            });
          }
        });
      }
      return;
    }
    
    // If there is basic connectivity, verify actual internet access
    debugPrint('✅ Basic connectivity detected, verifying internet access...');
    _checkConnectivity(); // This will do the proper internet connectivity check
  }

  /// Handle pull-to-refresh with proper internet connectivity check
  Future<void> _handleRefresh() async {
    debugPrint('🔄 Pull-to-refresh triggered');
    
    try {
      await _loadProfileImage();
      await _loadStations();
      await _determinePosition();
      await _checkConnectivity();
      
      // Reload stations data if we have internet
      if (_isOnline) {
        setState(() {
          _isLoadingStations = true;
        });
        await _loadStations();
      } else {
        debugPrint('📱 Offline mode - skipping station reload from Firebase');
      }
      
      // Refresh location (works offline)
      await _determinePosition();
      
      // Show refresh completion message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline ? 'Refreshed successfully' : 'Refreshed in offline mode'),
            backgroundColor: _isOnline ? Colors.green : Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('❌ Error during refresh: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Validate if coordinates are reasonable (not 0,0 and within world bounds)
  bool _isValidCoordinate(double latitude, double longitude) {
    // Check if coordinates are not (0,0) and within reasonable world bounds
    return latitude != 0.0 && 
           longitude != 0.0 && 
           latitude >= -90.0 && 
           latitude <= 90.0 && 
           longitude >= -180.0 && 
           longitude <= 180.0;
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _currentLocation = 'Location services are disabled.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _currentLocation = 'Location permissions are denied';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _currentLocation = 'Location permissions are permanently denied';
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];

      List<String> addressParts = [];
      if (place.thoroughfare != null &&
          place.thoroughfare!.isNotEmpty &&
          !place.thoroughfare!.contains('+')) {
        addressParts.add(place.thoroughfare!);
      }
      if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        addressParts.add(place.subLocality!);
      }
      if (place.locality != null && place.locality!.isNotEmpty) {
        addressParts.add(place.locality!);
      }

      setState(() {
        _currentLocation = addressParts.join(', ');
      });

      // Proactive station detection and caching (works both online/offline)
      try {
        // Cache station data first (if online)
        await _offlineEmergencyService.cacheStationData();
        
        // Detect and cache current station based on geofence
        Map<String, dynamic>? currentStation = await _offlineEmergencyService.getCachedCurrentStation();
        
        if (currentStation != null) {
          debugPrint('🏢 Current station detected and cached: ${currentStation['name'] ?? currentStation['id']}');
        } else {
          debugPrint('📍 User location updated - no station geofence detected');
        }
      } catch (e) {
        debugPrint('⚠️ Error in proactive station detection: $e');
      }
    } catch (e) {
      setState(() {
        _currentLocation = "Could not get location";
      });
    }
  }

  void _listenForIncomingCallbacks() {
    final DatabaseReference db = FirebaseDatabase.instance.ref();
    
    // Listen for new incoming calls
    _incomingCallSub = db.child('users/${widget.username}/ReceivedCalls/ActiveCalls')
        .onChildAdded
        .listen((event) {
      final callId = event.snapshot.key ?? '';
      if (callId.isEmpty) return;
      final val = event.snapshot.value;
      if (val is Map) {
        final data = Map<String, dynamic>.from(val);
        final String status = (data['status'] ?? '').toString();
        
        debugPrint('Citizen received call: status=$status');
        
        if (status == 'ringing' && !_activeIncomingCallIds.contains(callId)) {
          _activeIncomingCallIds.add(callId);
          
          // Extract station information
          final stationName = (data['station'] ?? 'Police Station').toString();
          final hotline = (data['hotline'] ?? 'No hotline').toString();
          final streetAddress = (data['streetAddress'] ?? '').toString();
          final city = (data['city'] ?? '').toString();
          final region = (data['region'] ?? '').toString();
          
          // Combine address: streetAddress + city
          final combinedAddress = [streetAddress, city].where((part) => part.isNotEmpty).join(', ');
          
          _showCitizenIncomingDialog(
            callId: callId,
            stationName: stationName,
            hotline: hotline,
            address: combinedAddress.isNotEmpty ? combinedAddress : 'No address provided',
            region: region.isNotEmpty ? region : null,
          );
        }
      }
    });

    // Listen for call status changes (including cancellations)
    db.child('users/${widget.username}/ReceivedCalls/ActiveCalls')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null) return;
      
      final calls = event.snapshot.value as Map;
      calls.forEach((callId, callData) {
        if (callData is Map) {
          final status = (callData['status'] ?? '').toString();
          final cancelledBy = (callData['cancelledBy'] ?? '').toString();
          
          debugPrint('Call status update: callId=$callId, status=$status, cancelledBy=$cancelledBy');
          
          // Check if this is a cancellation by officer
          if (status == 'cancelled' && cancelledBy == 'officer' && _activeIncomingCallIds.contains(callId)) {
            debugPrint('Call cancelled by officer: $callId');
            _activeIncomingCallIds.remove(callId);
            
            // Close the incoming call dialog if it's open
            if (_isShowingIncomingDialog && mounted) {
              Navigator.of(context).pop(); // Close the dialog
              _isShowingIncomingDialog = false;
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Call was cancelled by the desk officer'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
          
          // Check if this is a timeout from officer
          if (status == 'timeout' && _activeIncomingCallIds.contains(callId)) {
            debugPrint('Call timed out by officer: $callId');
            _activeIncomingCallIds.remove(callId);
            
            // Close the incoming call dialog if it's open
            if (_isShowingIncomingDialog && mounted) {
              Navigator.of(context).pop(); // Close the dialog
              _isShowingIncomingDialog = false;
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Call timed out - no response received'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
          
          // Check if this is a new incoming call that wasn't caught by onChildAdded
          if (status == 'ringing' && !_activeIncomingCallIds.contains(callId)) {
            debugPrint('New incoming call detected: $callId');
            _activeIncomingCallIds.add(callId);
            
            // Extract station information
            final stationName = (callData['station'] ?? 'Police Station').toString();
            final hotline = (callData['hotline'] ?? 'No hotline').toString();
            final streetAddress = (callData['streetAddress'] ?? '').toString();
            final city = (callData['city'] ?? '').toString();
            final region = (callData['region'] ?? '').toString();
            
            // Combine address: streetAddress + city
            final combinedAddress = [streetAddress, city].where((part) => part.isNotEmpty).join(', ');
            
            _showCitizenIncomingDialog(
              callId: callId,
              stationName: stationName,
              hotline: hotline,
              address: combinedAddress.isNotEmpty ? combinedAddress : 'No address provided',
              region: region.isNotEmpty ? region : null,
            );
          }
        }
      });
    });

    // Listen for calls moved to MissedCalls (additional safety net)
    db.child('users/${widget.username}/ReceivedCalls/MissedCalls')
        .onChildAdded
        .listen((event) {
      final callId = event.snapshot.key ?? '';
      if (callId.isEmpty) return;
      
      // If this call was in our active list, remove it and close dialog
      if (_activeIncomingCallIds.contains(callId)) {
        debugPrint('Call moved to MissedCalls: $callId');
        _activeIncomingCallIds.remove(callId);
        
        if (_isShowingIncomingDialog && mounted) {
          Navigator.of(context).pop(); // Close the dialog
          _isShowingIncomingDialog = false;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call was ended'),
              backgroundColor: Colors.grey,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _showCitizenIncomingDialog({
    required String callId,
    required String stationName,
    required String hotline,
    required String address,
    String? region, // Add region parameter
  }) {
    if (_isShowingIncomingDialog || !mounted) return;
    _isShowingIncomingDialog = true;
    // Stop any ongoing notification sound (heads-up call) before showing in-app dialog
    CallNotificationService().dismissIncomingCallNotification();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CitizenIncomingCallDialog(
        stationName: stationName,
        photoUrl: '',
        hotline: hotline,
        address: address,
        callId: callId,
        region: region, // Pass region to dialog
        onAnswer: () async {
          // Ensure ringtone/notification is stopped as soon as user answers
          await CallNotificationService().dismissIncomingCallNotification();
          Navigator.of(ctx).pop();
          _isShowingIncomingDialog = false;
          _activeIncomingCallIds.remove(callId);
          await _answerIncomingCallback(callId: callId, stationName: stationName);
        },
        onDecline: () async {
          // Ensure ringtone/notification is stopped as soon as user declines
          await CallNotificationService().dismissIncomingCallNotification();
          Navigator.of(ctx).pop();
          _isShowingIncomingDialog = false;
          _activeIncomingCallIds.remove(callId);
          await _declineIncomingCallback(callId: callId, stationName: stationName);
        },
      ),
    ).then((_) {
      _isShowingIncomingDialog = false;
    });
  }

  Future<void> _answerIncomingCallback({required String callId, required String stationName}) async {
    final db = FirebaseDatabase.instance.ref();
    try {
      // Update status to answered in citizen's call log
      await db.child('users/${widget.username}/ReceivedCalls/ActiveCalls/$callId').update({
        'status': 'answered',
        'answeredAt': ServerValue.timestamp,
      });

      // Update status to answered in global call log
      await db.child('UsersCallLogs/ActiveCalls/$callId').update({
        'status': 'answered',
        'answeredAt': ServerValue.timestamp,
      });

      // Move to AnsweredCalls in citizen's call log
      final callSnap = await db.child('users/${widget.username}/ReceivedCalls/ActiveCalls/$callId').get();
      if (callSnap.exists) {
        final callData = callSnap.value as Map;
        await db.child('users/${widget.username}/ReceivedCalls/AnsweredCalls/$callId').set(callData);
        await db.child('users/${widget.username}/ReceivedCalls/ActiveCalls/$callId').remove();
      }

      // Move to AnsweredCalls in global call log
      final globalCallSnap = await db.child('UsersCallLogs/ActiveCalls/$callId').get();
      if (globalCallSnap.exists) {
        final globalCallData = globalCallSnap.value as Map;
        await db.child('UsersCallLogs/AnsweredCalls/$callId').set(globalCallData);
        await db.child('UsersCallLogs/ActiveCalls/$callId').remove();
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmergencyCallBackScreen(
            officerName: 'Desk Officer',
            avatarAsset: 'assets/avatar.png',
            callId: callId,
            station: stationName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to answer call. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _declineIncomingCallback({required String callId, required String stationName}) async {
    final db = FirebaseDatabase.instance.ref();
    try {
      // Update status to declined in citizen's call log
      await db.child('users/${widget.username}/ReceivedCalls/ActiveCalls/$callId').update({
        'status': 'declined',
        'declinedBy': widget.username,
        'declinedAt': ServerValue.timestamp,
      });

      // Update status to declined in global call log
      await db.child('UsersCallLogs/ActiveCalls/$callId').update({
        'status': 'declined',
        'declinedBy': widget.username,
        'declinedAt': ServerValue.timestamp,
      });

      // Move to MissedCalls in citizen's call log
      final callSnap = await db.child('users/${widget.username}/ReceivedCalls/ActiveCalls/$callId').get();
      if (callSnap.exists) {
        final callData = callSnap.value as Map;
        await db.child('users/${widget.username}/ReceivedCalls/MissedCalls/$callId').set(callData);
        await db.child('users/${widget.username}/ReceivedCalls/ActiveCalls/$callId').remove();
      }

      // Move to MissedCalls in global call log
      final globalCallSnap = await db.child('UsersCallLogs/ActiveCalls/$callId').get();
      if (globalCallSnap.exists) {
        final globalCallData = globalCallSnap.value as Map;
        await db.child('UsersCallLogs/MissedCalls/$callId').set(globalCallData);
        await db.child('UsersCallLogs/ActiveCalls/$callId').remove();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call declined'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to decline call'), backgroundColor: Colors.red),
      );
    }
  }


  // Called when the user presses and holds the emergency button
  void _onTapDown(TapDownDetails details) async {
    if (_isEmergencyInProgress) return; // Prevent multiple emergency calls
    
    _holdTimer = Timer(const Duration(seconds: 2), () async {
      debugPrint("🚨 Emergency button held for 2 seconds! Initiating emergency response...");
      
      setState(() {
        _isEmergencyInProgress = true;
      });

      try {
        debugPrint("🔍 Starting dual-mode emergency system...");
        
        // Step 1: Check connectivity and quality first
        final connectivityResult = await _offlineEmergencyService.checkInternetConnectivityWithQuality();
        bool hasInternet = connectivityResult['hasInternet'] as bool;
        String quality = connectivityResult['quality'] as String;
        int responseTime = connectivityResult['responseTime'] as int;
        
        debugPrint("🌐 Internet connectivity: ${hasInternet ? 'ONLINE' : 'OFFLINE'}");
        if (hasInternet) {
          debugPrint("📊 Connection quality: $quality (${responseTime}ms)");
        }
        
        // Get user's current location for geofence detection
        Position position = await Geolocator.getCurrentPosition();
        Station? targetStation;

        // Check if user is within any station's geofence
        debugPrint("📍 User location: ${position.latitude}, ${position.longitude}");
        for (var station in _stations) {
          double distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            station.latitude,
            station.longitude,
          );

          debugPrint("🏢 Checking ${station.name}: distance = ${distance.toStringAsFixed(2)}m, radius = ${station.radius}m");
          if (distance <= station.radius) {
            targetStation = station;
            debugPrint("✅ User is inside geofence of ${station.name}. Routing call there.");
            break; // Connect to the first station found
          }
        }

        // If not in any geofence, find the nearest station as a fallback
        if (targetStation == null) {
          debugPrint("⚠️ User not in any geofence. Will use nearest station logic.");
          targetStation = await _findNearestStation(position, _stations);
        }

        // Step 2: Route based on connectivity and quality
        if (hasInternet) {
          // Handle different connection qualities
          if (quality == 'poor') {
            debugPrint("🟡 POOR CONNECTION: Using hybrid approach (SMS + Online attempt)...");
            
            // Show user warning about poor connection
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Poor internet detected. Sending SMS backup while attempting call...'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            
            // Send SMS first as backup for poor connections
            await _handleOfflineEmergency(position, targetStation);
            
            // Then attempt online call with extended timeouts
            await _handleOnlineEmergencyWithPoorConnection(position, targetStation, responseTime);
            
          } else {
            debugPrint("🟢 ${quality.toUpperCase()} CONNECTION: Initiating Agora voice call...");
            await _handleOnlineEmergency(position, targetStation);
          }
        } else {
          debugPrint("🔴 OFFLINE MODE: Sending SMS alert...");
          await _handleOfflineEmergency(position, targetStation);
        }

      } catch (e) {
        debugPrint("💥 Error during emergency response: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Emergency system error: $e'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isEmergencyInProgress = false;
          });
        }
        debugPrint("🔄 Emergency process completed, resetting state");
      }
    });
  }

  /// Handle online emergency with Agora voice call
  Future<void> _handleOnlineEmergency(Position position, Station? targetStation) async {
    try {
      debugPrint("📞 Starting online emergency call process...");
      
      // Get user data from Firebase
      final db = FirebaseDatabase.instance.ref();
      final userSnapshot = await db.child('users/${widget.username}').get();

      if (!userSnapshot.exists) {
        debugPrint("❌ User information not found in database");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User information not found.')),
          );
        }
        return;
      }

      final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      final callId = DateTime.now().millisecondsSinceEpoch.toString();
      final String? stationName = targetStation?.name;

      debugPrint("📋 Creating call data for station: ${stationName ?? 'No specific station'}");

      // Prepare call data for Firebase logging
      final callData = {
        'caller': widget.username,
        'status': 'ringing',
        'timestamp': ServerValue.timestamp,
        'station': stationName,
        'gender': userData['gender'] ?? 'Not specified',
        'mobile': userData['contactNumber'] ?? 'Not specified',
        'address': _constructFullAddress(userData),
        'disabilityStatus': userData['pwdCondition'] ?? 'None',
        'medicalConditions': userData['medicalCondition'] ?? 'None',
        'photoUrl': userData['profileImageUrl'] ?? 'assets/default_avatar.png',
        'firstName': userData['firstName'] ?? '',
        'surname': userData['surname'] ?? '',
        'barangay': userData['barangay'] ?? '',
        'city': userData['city'] ?? '',
        'country': userData['country'] ?? '',
        'birthdate': userData['birthdate'] ?? '',
        'citizenLatitude': position.latitude.toString(),
        'citizenLongitude': position.longitude.toString(),
      };

      // Store call data in Firebase for online calls with graceful error handling
      bool firebaseWriteSuccess = false;
      if (stationName != null) {
        debugPrint('💾 Attempting to store call data in Firebase for station: $stationName');
        
        try {
          // Create StationsCallLogs with citizen location
          await db.child('StationsCallLogs/ActiveCalls/$callId').set(callData);
          await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').set(callData);

          // Create UsersCallLogs with officer location
          final stationSnapshot = await db.child('Desk Officer/$stationName').get();
          if (stationSnapshot.exists) {
            final stationData = Map<String, dynamic>.from(stationSnapshot.value as Map);
            final callDataWithOfficerLocation = Map<String, dynamic>.from(callData);
            callDataWithOfficerLocation['officerLatitude'] = stationData['latitude']?.toString() ?? '0.0';
            callDataWithOfficerLocation['officerLongitude'] = stationData['longitude']?.toString() ?? '0.0';
            callDataWithOfficerLocation['officerRadius'] = stationData['radius']?.toString() ?? '500.0';
            
            await db.child('UsersCallLogs/ActiveCalls/$callId').set(callDataWithOfficerLocation);
            debugPrint('✅ Call data stored successfully in Firebase');
            firebaseWriteSuccess = true;
          }
        } catch (firebaseError) {
          debugPrint('⚠️ Firebase write failed: $firebaseError');
          
          // Check if it's a permission error
          if (firebaseError.toString().contains('Permission denied') || 
              firebaseError.toString().contains('permission-denied')) {
            debugPrint('🚫 Firebase Database permission denied - continuing with call but will send backup SMS');
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Call logging limited due to permissions, but emergency call will proceed'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else {
            debugPrint('❌ Other Firebase error: $firebaseError');
          }
        }
      } else {
        debugPrint('⚠️ No specific station targeted - call data not stored in Firebase');
      }
      
      // Navigate to existing connecting page for Agora call
      debugPrint('🚀 Launching Agora call interface...');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectingPage(
              username: widget.username,
              callId: callId,
              station: stationName,
              distance: _lastRouteDistance,
              duration: _lastRouteDuration,
            ),
          ),
        );
      }
      
      // Send backup SMS if Firebase write failed
      if (!firebaseWriteSuccess && stationName != null) {
        debugPrint('📱 Sending backup SMS due to Firebase write failure...');
        try {
          final smsResult = await _offlineEmergencyService.handleOfflineEmergency(
            userName: widget.username,
            additionalInfo: "Emergency call initiated - Firebase logging failed",
            userPosition: position,
          );
          
          if (smsResult['success']) {
            debugPrint('✅ Backup SMS sent successfully');
          } else {
            debugPrint('❌ Backup SMS also failed: ${smsResult['message']}');
          }
        } catch (smsError) {
          debugPrint('❌ Backup SMS error: $smsError');
        }
      }
      
    } catch (e) {
      debugPrint('❌ Online emergency completely failed: $e');
      
      // Graceful degradation: Fall back to offline SMS mode
      debugPrint('🔄 Attempting automatic fallback to offline SMS mode...');
      try {
        await _handleOfflineEmergency(position, targetStation);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Online call failed, automatically switched to SMS emergency mode'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } catch (fallbackError) {
        debugPrint('❌ Even offline fallback failed: $fallbackError');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Emergency system error. Please call emergency services directly: ${targetStation?.hotline ?? "911"}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Call',
                textColor: Colors.white,
                onPressed: () {
                  // Launch phone dialer with emergency number
                  final phoneNumber = targetStation?.hotline ?? "911";
                  final uri = Uri.parse('tel:$phoneNumber');
                  launchUrl(uri);
                },
              ),
            ),
          );
        }
      }
    }
  }

  /// Handle online emergency with poor connection (extended timeouts and simplified approach)
  Future<void> _handleOnlineEmergencyWithPoorConnection(Position position, Station? targetStation, int responseTime) async {
    try {
      debugPrint("📞 Starting online emergency call process for poor connection...");
      debugPrint("⏱️ Detected response time: ${responseTime}ms - using extended timeouts");
      
      // Calculate adaptive timeout based on response time
      int adaptiveTimeout = (responseTime * 2).clamp(5000, 15000); // 2x response time, max 15s
      debugPrint("🕐 Using adaptive timeout: ${adaptiveTimeout}ms");
      
      // Get user data from Firebase with extended timeout
      final db = FirebaseDatabase.instance.ref();
      final userSnapshot = await db.child('users/${widget.username}')
          .get()
          .timeout(Duration(milliseconds: adaptiveTimeout));

      if (!userSnapshot.exists) {
        debugPrint("❌ User information not found in database");
        throw Exception('User information not found');
      }

      final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      final callId = DateTime.now().millisecondsSinceEpoch.toString();
      final String? stationName = targetStation?.name;

      debugPrint("📋 Creating call data for station: ${stationName ?? 'No specific station'}");

      // Prepare simplified call data for poor connections
      final callData = {
        'caller': widget.username,
        'status': 'ringing',
        'timestamp': ServerValue.timestamp,
        'station': stationName,
        'mobile': userData['contactNumber'] ?? 'Not specified',
        'firstName': userData['firstName'] ?? '',
        'surname': userData['surname'] ?? '',
        'citizenLatitude': position.latitude.toString(),
        'citizenLongitude': position.longitude.toString(),
        'connectionQuality': 'poor', // Mark as poor connection call
      };

      // Try Firebase write with extended timeout and graceful failure
      if (stationName != null) {
        debugPrint('💾 Attempting Firebase write with extended timeout...');
        
        try {
          // Use shorter timeout for Firebase writes on poor connections
          await db.child('StationsCallLogs/ActiveCalls/$callId')
              .set(callData)
              .timeout(Duration(milliseconds: adaptiveTimeout ~/ 2));
          await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId')
              .set(callData)
              .timeout(Duration(milliseconds: adaptiveTimeout ~/ 2));
          
          debugPrint('✅ Firebase write successful despite poor connection');
        } catch (firebaseError) {
          debugPrint('⚠️ Firebase write failed on poor connection: $firebaseError');
          // Continue anyway - SMS backup was already sent
        }
      }
      
      // Navigate to connecting page with poor connection warning
      debugPrint('🚀 Launching Agora call interface with poor connection handling...');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConnectingPage(
              username: widget.username,
              callId: callId,
              station: stationName,
              distance: _lastRouteDistance,
              duration: _lastRouteDuration,
            ),
          ),
        );
        
        // Show additional warning about call quality
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Call quality may be affected by poor connection. SMS backup was sent.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        });
      }
      
    } catch (e) {
      debugPrint('❌ Poor connection emergency call failed: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice call failed due to poor connection, but SMS was sent successfully'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Handle offline emergency with SMS
  Future<void> _handleOfflineEmergency(Position position, Station? targetStation) async {
    try {
      debugPrint("📱 Starting offline emergency SMS process...");
      
      // The offline service will find the nearest station internally
      final result = await _offlineEmergencyService.handleOfflineEmergency(
        userName: widget.username,
        additionalInfo: "Emergency assistance needed",
        userPosition: position, // Corrected parameter name
      );

      debugPrint("📋 SMS Emergency result: ${result.toString()}");

      if (result['success']) {
        debugPrint('✅ Offline emergency SMS sent successfully');
        debugPrint('📍 SMS sent to station: ${result['station']?['name'] ?? 'Unknown'}');
        debugPrint('📞 Station hotline: ${result['station']?['hotline'] ?? 'Unknown'}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🚨 Emergency SMS sent successfully!\n${result['message']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        debugPrint('❌ SMS Emergency failed: ${result['message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Emergency SMS failed: ${result['message']}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
      
    } catch (e) {
      debugPrint('❌ Offline emergency failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offline emergency failed: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<Station?> _findNearestStation(Position userLocation, List<Station> stations) async {
    try {
      debugPrint('🔍 Finding nearest station using hybrid routing...');
      
      // Use hybrid routing from offline emergency service
      final offlineService = OfflineEmergencyService();
      final nearestStationMap = await offlineService.findNearestStationHybrid(
        userLat: userLocation.latitude,
        userLng: userLocation.longitude,
      );
      
      if (nearestStationMap != null) {
        // Find matching Station object
        Station? matchedStation = stations.firstWhere(
          (s) => s.name == nearestStationMap['name'],
          orElse: () => stations.first,
        );
        
        // Log the result and store routing data
        if (nearestStationMap.containsKey('routeDistance')) {
          debugPrint('✅ Found nearest station by OSRM route: ${matchedStation.name}');
          debugPrint('   Route distance: ${nearestStationMap['routeDistance'].toStringAsFixed(2)} km');
          debugPrint('   Route duration: ${nearestStationMap['routeDuration'].toStringAsFixed(1)} min');
          
          // Store routing data for ConnectingPage
          _lastRouteDistance = nearestStationMap['routeDistance'];
          _lastRouteDuration = nearestStationMap['routeDuration'];
        } else if (nearestStationMap.containsKey('straightLineDistance')) {
          debugPrint('✅ Found nearest station by Haversine: ${matchedStation.name}');
          debugPrint('   Straight-line distance: ${nearestStationMap['straightLineDistance'].toStringAsFixed(2)} km');
          
          // Store straight-line distance
          _lastRouteDistance = nearestStationMap['straightLineDistance'];
          _lastRouteDuration = null; // No duration for Haversine
        }
        
        return matchedStation;
      }
      
      // Fallback to original Haversine method if hybrid fails
      debugPrint('⚠️ Hybrid routing failed, using fallback Haversine');
      Station? nearestStation;
      double minDistance = double.infinity;

      for (var station in stations) {
        double distance = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          station.latitude,
          station.longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestStation = station;
        }
      }

      return nearestStation;
      
    } catch (e) {
      debugPrint('❌ Error in _findNearestStation: $e');
      
      // Final fallback to simple Haversine
      Station? nearestStation;
      double minDistance = double.infinity;

      for (var station in stations) {
        double distance = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          station.latitude,
          station.longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestStation = station;
        }
      }

      return nearestStation;
    }
  }

  void _onTapUp(TapUpDetails details) {
    _holdTimer?.cancel();
  }

  void _onTapCancel() {
    _holdTimer?.cancel();
  }

  /// Listen for map download progress updates for the UI
  void _listenForMapDownloadProgress() {
    _mapDownloadSubscription = _offlineMapService.downloadProgressStream.listen(
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _isDownloadingMap = progress < 100;
          });
          
          // Show toast when download starts
          if (progress > 0 && progress < 100 && _lastToastProgress < 0) {
            _startToastUpdates();
          }
          
          // Update toast periodically (every 10% change)
          if ((progress - _lastToastProgress).abs() >= 10 || progress >= 100) {
            _showDownloadToast(progress);
            _lastToastProgress = progress;
          }
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isDownloadingMap = false;
            _downloadProgress = 100.0;
          });
          _stopToastUpdates();
          _showDownloadCompleteToast();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDownloadingMap = false;
          });
          _stopToastUpdates();
        }
        debugPrint('Error during map download: $error');
        Fluttertoast.showToast(
          msg: "Download failed: $error",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      },
    );
  }

  /// Start periodic toast updates during download
  void _startToastUpdates() {
    _toastUpdateTimer?.cancel();
    _toastUpdateTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (_isDownloadingMap && _downloadProgress < 100) {
        _showDownloadToast(_downloadProgress);
      } else {
        timer.cancel();
      }
    });
  }

  /// Stop toast updates
  void _stopToastUpdates() {
    _toastUpdateTimer?.cancel();
    _lastToastProgress = -1.0;
  }

  /// Show download progress toast
  void _showDownloadToast(double progress) {
    Fluttertoast.showToast(
      msg: "📥 Downloading data... ${progress.toStringAsFixed(0)}%",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Color.fromARGB(255, 255, 60, 57),
      textColor: Color.fromARGB(255, 81, 255, 37),
      fontSize: 16.0,
    );
  }

  /// Show download complete toast
  void _showDownloadCompleteToast() {
    Fluttertoast.showToast(
      msg: "✅ Download complete!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Color.fromARGB(255, 76, 175, 80),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      // Or return a placeholder widget
      return SizedBox.shrink();
    }
    // Stations are now loaded from Firebase
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: GestureDetector(
                onTap: () {
                  _goToProfilePage();
                },
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                  child: _profileImageUrl == null
                      ? Icon(Icons.person, color: Colors.grey[700])
                      : null,
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.map, color: Colors.white),
              onPressed: _goToMapScreen,
              tooltip: 'View Stations on Map',
            ),
          ],
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 6,),
              Stack(
                children: [
                  // Stroke
                  Text(
                    widget.username,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 1
                        ..color = const Color.fromARGB(26, 0, 0, 0), // Stroke color
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Fill
                  Text(
                    widget.username,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Fill color
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              SizedBox(height: 2),
              Row(
                children: 
                [
                  Stack
                    (
                        alignment: Alignment.center,
                        children: 
                        [
                            Icon(
                              Icons.location_on,
                              color: const Color.fromARGB(111, 0, 0, 0),
                              size: 18, // slightly larger for the stroke
                            ),
                            Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 17,
                            ),
                        ],
                    ),

                  SizedBox(width: 1),
                  Expanded(
                    child: Stack(
                      children: [
                        // Stroke
                        Text(
                          _currentLocation,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 1
                              ..color = const Color.fromARGB(61, 0, 0, 0),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Fill
                        Text(
                          _currentLocation,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          flexibleSpace: Container(
          decoration: BoxDecoration(
            
              border: Border(
                bottom: BorderSide(
                  color: const Color.fromARGB(211, 255, 255, 255), // Choose your color
                  width: 1,                          // Choose your width
                ),
              ),
              color: Color.fromARGB(255, 255, 60, 57),
            ),
          ),
        backgroundColor: Colors.transparent, // Make background transparent to show gradient
        elevation: 0,

        ),
      ),
      body: Column(
        children: [
          // Connectivity status indicator (shows for 5 seconds)
          if (_showConnectivityBanner)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: _isOnline 
                ? Color.fromARGB(255, 76, 175, 80)
                : Color.fromARGB(255, 255, 152, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _isOnline ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Color.fromARGB(255, 255, 62, 59),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(255, 255, 51, 48), // Light reddish pink
                      Color.fromARGB(255, 255, 218, 217),
                      Color.fromARGB(255, 255, 255, 255), // Existing light color
                    ],
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 25.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [

                      Text
                      (
                          "Registered Stations",
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 255, 255, 255),
                              
                          )
                      ),
                      
                      SizedBox(height: 8,),

                      // Top Section: Carousel of Stations
                      SizedBox(
                        height: 250,
                        child: _isLoadingStations
                            ? Center(child: CircularProgressIndicator())
                            : _stations.isEmpty
                                ? Center(
                                    child: Text(
                                      'No stations available',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : PageView.builder(
                                    itemCount: _stations.length,
                                    controller: PageController(viewportFraction: .9),
                                    itemBuilder: (context, index) {
                                      final station = _stations[index];
                                      return Container(
                                        margin: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                                        child: Card(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          elevation: 5,
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 22, left: 22, right: 22, bottom: 22),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [Color(0xFF1976D2), Color(0xFFD32F2F)],
                                                          begin: Alignment.centerLeft,
                                                          end: Alignment.centerRight,
                                                        ),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.local_police,
                                                        color: Colors.white,
                                                        size: 32,
                                                      ),
                                                    ),
                                                    SizedBox(width: 14),
                                                    Expanded(
                                                      child: Text(
                                                        station.name,
                                                        style: TextStyle(
                                                          fontSize: 24,
                                                          fontWeight: FontWeight.bold,
                                                          color: const Color.fromARGB(255, 61, 61, 61),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on, size: 30, color: const Color.fromARGB(255, 255, 92, 92)),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        station.fullAddress,
                                                        style: TextStyle(
                                                          color: const Color.fromARGB(255, 59, 59, 59),
                                                          fontSize: 18,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Icon(Icons.phone, size: 30, color: const Color.fromARGB(255, 107, 117, 255)),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      station.hotline,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color.fromARGB(255, 59, 59, 59),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      
                      SizedBox( height: 35,),

                      // Middle Section: Emergency Button and Instruction Text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTapDown: _onTapDown,
                            onTapUp: _onTapUp,
                            onTapCancel: _onTapCancel,
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    return CustomPaint(
                                      size: const Size(300, 300),
                                      painter: RipplePainter(progress: _controller.value),
                                    );
                                  },
                                ),
                                Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration( 
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color.fromARGB(255, 255, 73, 70).withOpacity(0.4),
                                        blurRadius: 30.0,
                                        spreadRadius: 5.0,
                                      ),
                                      BoxShadow(
                                        color: const Color.fromARGB(255, 255, 73, 70).withOpacity(0.6),
                                        blurRadius: 20.0,
                                        spreadRadius: 2.0,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {}, // Keep enabled for color, handled by GestureDetector
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(255, 255, 62, 59),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.all(20),
                                    ),
                                    child: Icon(
                                      Icons.phone,
                                      color: Colors.white,
                                      size: 100,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          Text(
                            _isEmergencyInProgress 
                              ? "Processing Emergency..." 
                              : "Press and Hold to Call Emergency",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: _isEmergencyInProgress ? Colors.orange : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                        // Empty container at the bottom to help with centering the middle content
                        Container(height: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  final int waveCount;
  final Color color;

  RipplePainter({
    required this.progress,
    this.waveCount = 5,
    this.color = Colors.red,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < waveCount; i++) {
      final double waveProgress = (progress + (i / waveCount)) % 1.0;
      final double radius = maxRadius * waveProgress;
      final double opacity =
          (1.0 - Curves.easeIn.transform(waveProgress)).clamp(0.0, 1.0);

      final Paint paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.50;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// Helper method to construct full address from user data
String _constructFullAddress(Map<String, dynamic> userData) {
  List<String> addressParts = [];
  
  // Add street address if available
  if (userData['streetAddress'] != null && userData['streetAddress'].toString().isNotEmpty) {
    addressParts.add(userData['streetAddress']);
  }
  
  // Add barangay if available
  if (userData['barangay'] != null && userData['barangay'].toString().isNotEmpty) {
    addressParts.add(userData['barangay']);
  }
  
  // Add city if available
  if (userData['city'] != null && userData['city'].toString().isNotEmpty) {
    addressParts.add(userData['city']);
  }
  
  // Add region if available
  if (userData['region'] != null && userData['region'].toString().isNotEmpty) {
    addressParts.add(userData['region']);
  }
  
  // Add country if available
  if (userData['country'] != null && userData['country'].toString().isNotEmpty) {
    addressParts.add(userData['country']);
  }
  
  return addressParts.join(', ');
}