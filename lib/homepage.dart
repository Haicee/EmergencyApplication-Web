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
            child: CircleAvatar(child: Icon(Icons.person)),
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
  String _currentLocation = "Fetching location...";
  late AnimationController _controller;
  Timer? _holdTimer;
  // Incoming callback listening
  StreamSubscription? _incomingCallSub;
  bool _isShowingIncomingDialog = false;
  final Set<String> _activeIncomingCallIds = {};
  
  // Stations data
  List<Station> _stations = [];
  bool _isLoadingStations = true;
  final GeofenceManager _geofenceManager = GeofenceManager();


  @override
  void initState() {
    super.initState();
    _determinePosition();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _listenForIncomingCallbacks();
    _loadStations();
    
    // Check profile completion after a short delay
    Future.delayed(Duration(milliseconds: 10000), () {
      _checkProfileCompletion();
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
    );
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
              // Create a station with the data we have
              final station = Station(
                id: stationId,
                name: stationData['name'] ?? stationId, // Use ID as fallback for name
                hotline: stationData['hotline'] ?? 'No hotline',
                streetAddress: stationData['streetAddress'] ?? stationData['address'] ?? '',
                city: stationData['city'] ?? '',
                region: stationData['region'] ?? '',
                latitude: double.tryParse(stationData['latitude']?.toString() ?? '0.0') ?? 0.0,
                longitude: double.tryParse(stationData['longitude']?.toString() ?? '0.0') ?? 0.0,
                radius: double.tryParse(stationData['radius']?.toString() ?? '500.0') ?? 500.0,
              );
              loadedStations.add(station);
            }
          }
        });
        
        // Sort stations by their ID (Police Station 1, 2, 3, etc.)
        loadedStations.sort((a, b) => a.name.compareTo(b.name));
        
        if (mounted) {
          setState(() {
            _stations = loadedStations;
            _isLoadingStations = false;
          });
        }
      }
    } catch (e) {
      print('Error loading stations: $e');
      if (mounted) {
        setState(() {
          _isLoadingStations = false;
        });
      }
    }
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
          Navigator.of(ctx).pop();
          _isShowingIncomingDialog = false;
          _activeIncomingCallIds.remove(callId);
          await _answerIncomingCallback(callId: callId, stationName: stationName);
        },
        onDecline: () async {
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
    _holdTimer = Timer(const Duration(seconds: 3), () async {
      debugPrint("Emergency button held for 3 seconds! Initiating call...");

      try {
        // Get user's current location
        Position position = await Geolocator.getCurrentPosition();
        Station? targetStation;

        // Check if user is within any station's geofence
        for (var station in _stations) {
          double distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            station.latitude,
            station.longitude,
          );

          if (distance <= station.radius) {
            targetStation = station;
            break; // Connect to the first station found
          }
        }

        final db = FirebaseDatabase.instance.ref();
        final userSnapshot = await db.child('users/${widget.username}').get();

        if (!userSnapshot.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User information not found.')),
          );
          return;
        }

        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        final callId = DateTime.now().millisecondsSinceEpoch.toString();

        // Determine station name from geofence
        final String? stationName;
        if (targetStation != null) {
          stationName = targetStation.name;
          debugPrint('User is inside geofence of ${targetStation.name}. Routing call there.');
        } else {
          stationName = null;
          debugPrint('User not in any geofence. Call will not be routed to a specific station.');
        }

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
        };

        // Only create call logs if a station is targeted
        if (stationName != null) {
          await db.child('StationsCallLogs/ActiveCalls/$callId').set(callData);
          await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').set(callData);
        }

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConnectingPage(
                username: widget.username,
                callId: callId,
                station: stationName,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint("Error initiating call: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to initiate call: $e')),
          );
        }
      }
    });
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










  void _onTapUp(TapUpDetails details) {
    _holdTimer?.cancel();
  }

  void _onTapCancel() {
    _holdTimer?.cancel();
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
                  child: Icon(Icons.person, color: Colors.grey[700]),
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
      body: Container(
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
                                shape: CircleBorder(),
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
                      "Press and Hold to Call Emergency",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
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