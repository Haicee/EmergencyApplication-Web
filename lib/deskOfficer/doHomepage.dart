import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_database/firebase_database.dart';
import '../main.dart';
import 'incomingCall.dart'; // Added import for IncomingCallPage
import 'components/missedViewDetails.dart';
import 'dart:async';
import 'components/answeredViewDetails.dart';
import '../models/station.dart'; // Add Station import
import '../screens/officer_map_screen.dart'; // Add OfficerMapScreen import

class DeskOfficerHomePage extends StatefulWidget {
  final String username;
  final String officerId;

  const DeskOfficerHomePage({
    Key? key,
    required this.username,
    required this.officerId,
  }) : super(key: key);

  @override
  State<DeskOfficerHomePage> createState() => _DeskOfficerHomePageState();
}

class _DeskOfficerHomePageState extends State<DeskOfficerHomePage> with TickerProviderStateMixin {
  String _currentLocation = "Locating...";
  String _stationName = "";
  String _stationAddress = "";
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Set<String> _activeCallIds = {};
  List<Station> _stations = []; // Initialize _stations list
  
  // Tab controller
  TabController? _tabController;
  
  // Search controllers
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Call data
  Map<String, dynamic> _activeCalls = {};
  Map<String, dynamic> _missedCalls = {};
  Map<String, dynamic> _answeredCalls = {};
  
  // Stream subscriptions
  late StreamSubscription _activeCallsSubscription;
  late StreamSubscription _missedCallsSubscription;
  late StreamSubscription _answeredCallsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAndSetLocation();
    _fetchStationInfo(); // This will call _setupCallDataListeners() after station is loaded
    _setupCallListeners();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _activeCallsSubscription.cancel();
    _missedCallsSubscription.cancel();
    _answeredCallsSubscription.cancel();
    super.dispose();
  }

  void _setupCallDataListeners() {
    // Wait for station name to be loaded before setting up listeners
    if (_stationName.isEmpty || _stationName == "Police Station") {
      // Retry after a short delay if station name is not loaded yet
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) _setupCallDataListeners();
      });
      return;
    }
    
    final db = FirebaseDatabase.instance.ref();
    
    // Listen for active calls from the specific station
    _activeCallsSubscription = db.child('Desk Officer/$_stationName/ReceivedCalls/ActiveCalls')
        .onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _activeCalls = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      } else {
        setState(() {
          _activeCalls = {};
        });
      }
    });
    
    // Listen for missed calls from the specific station
    _missedCallsSubscription = db.child('Desk Officer/$_stationName/ReceivedCalls/MissedCalls')
        .onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _missedCalls = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      } else {
        setState(() {
          _missedCalls = {};
        });
      }
    });
    
    // Listen for answered calls from the specific station
    _answeredCallsSubscription = db.child('Desk Officer/$_stationName/ReceivedCalls/AnsweredCalls')
        .onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _answeredCalls = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      } else {
        setState(() {
          _answeredCalls = {};
        });
      }
    });
    
    print('Setup call listeners for station: $_stationName');
  }

  void _setupCallListeners() {
    // Wait for station name to be loaded before setting up listeners
    if (_stationName.isEmpty || _stationName == "Police Station") {
      // Retry after a short delay if station name is not loaded yet
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) _setupCallListeners();
      });
      return;
    }
    
    // Listen for incoming calls in the station's ReceivedCalls/ActiveCalls
    final db = FirebaseDatabase.instance.ref();
    db.child('Desk Officer/$_stationName/ReceivedCalls/ActiveCalls')
      .onChildAdded
      .listen((event) {
        if (event.snapshot.value != null) {
          final callId = event.snapshot.key ?? '';
          final callData = event.snapshot.value as Map;
          
          // Only show incoming call if status is 'ringing'
          if (callData['status'] == 'ringing' && !_activeCallIds.contains(callId)) {
            _activeCallIds.add(callId);
            
            // Navigate to IncomingCallPage
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IncomingCallPage(
                  name: callData['caller'],
                  photoUrl: callData['photoUrl'] ?? 'assets/default_avatar.png',
                  callId: callId,
                  station: _stationName,
                         officerId: widget.officerId,
                  gender: callData['gender'] ?? 'Male',
                  mobile: callData['mobile'] ?? '0912-345-6789',
                  address: callData['address'] ?? 'Not Specified',
                  disabilityStatus: callData['disabilityStatus'] ?? 'None',
                  medicalConditions: callData['medicalConditions'] ?? 'None',
                ),
              ),
            ).then((_) {
              // Remove callId from active calls when page is closed
              _activeCallIds.remove(callId);
            });
          }
        }
      });
      
    // Listen for calls moved to MissedCalls (cancelled, declined, timeout) - Station Specific
    db.child('Desk Officer/$_stationName/ReceivedCalls/MissedCalls')
      .onChildAdded
      .listen((event) {
        if (event.snapshot.value != null) {
          final callId = event.snapshot.key ?? '';
          final callData = event.snapshot.value as Map;
          
          // Remove from active calls
          _activeCallIds.remove(callId);
          
          // Only show notification for actual missed calls (not answered calls)
          if (callData['status'] != 'answered') {
            // Show appropriate notification based on status
            String message = '';
            Color backgroundColor = Colors.orange;
            
            switch (callData['status']) {
              case 'cancelled':
                message = 'Emergency call from ${callData['caller']} was cancelled';
                break;
              case 'declined':
                message = 'Emergency call from ${callData['caller']} was declined';
                backgroundColor = Colors.red;
                break;
              case 'timeout':
                message = 'Emergency call from ${callData['caller']} timed out';
                backgroundColor = Colors.red;
                break;
              default:
                message = 'Emergency call from ${callData['caller']} was missed';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: backgroundColor,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      });
      
    // Listen for answered calls to prevent wrong notifications - Station Specific
    db.child('Desk Officer/$_stationName/ReceivedCalls/AnsweredCalls')
      .onChildAdded
      .listen((event) {
        if (event.snapshot.value != null) {
          final callId = event.snapshot.key ?? '';
          final callData = event.snapshot.value as Map;
          
          // Remove from active calls since it's now answered
          _activeCallIds.remove(callId);
        }
      });
      
    print('Setup notification listeners for station: $_stationName');
  }

  Future<void> _fetchAndSetLocation() async {
    print('Locating......');
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    print('Service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      setState(() {
        _currentLocation = 'Location services are disabled.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    print('Permission: $permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print('Requested permission: $permission');
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
      print('Position: $position');
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      print('Placemarks: $placemarks');
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
      print('Error: $e');
      setState(() {
        _currentLocation = "Could not get location";
      });
    }
  }

  Future<void> _fetchStationInfo() async {
    try {
      final deskOfficerSnapshot = await _database.child('Desk Officer').get();
      if (deskOfficerSnapshot.exists) {
        final stationsRaw = deskOfficerSnapshot.value;
        if (stationsRaw is Map) {
          final stations = stationsRaw as Map<dynamic, dynamic>;
          print('Stations: $stations');
          
          // Load stations data for map
          List<Station> stationsList = [];
          for (final stationEntry in stations.entries) {
            final stationName = stationEntry.key.toString();
            final stationData = stationEntry.value;
            if (stationData is Map) {
              final stationMap = stationData as Map<dynamic, dynamic>;
              // Create Station object if we have location data
              if (stationMap.containsKey('latitude') && stationMap.containsKey('longitude')) {
                stationsList.add(Station(
                  id: stationName,
                  name: stationName,
                  latitude: double.tryParse(stationMap['latitude'].toString()) ?? 0.0,
                  longitude: double.tryParse(stationMap['longitude'].toString()) ?? 0.0,
                  radius: double.tryParse(stationMap['radius']?.toString() ?? '500') ?? 500.0,
                  hotline: stationMap['hotline'] ?? '',
                  streetAddress: stationMap['streetAddress'] ?? '',
                  city: stationMap['city'] ?? '',
                  region: stationMap['region'] ?? '',
                ));
              }
            }
          }
          setState(() {
            _stations = stationsList;
          });
          
          for (final stationEntry in stations.entries) {
            final officersRaw = stationEntry.value;
            if (officersRaw is Map) {
              final officers = officersRaw as Map<dynamic, dynamic>;
              print('Checking station: ${stationEntry.key}, officers: ${officers.keys}');
              if (officers.containsKey(widget.officerId)) {
                final officerDataRaw = officers[widget.officerId];
                if (officerDataRaw is Map) {
                  final officerData = officerDataRaw as Map<dynamic, dynamic>;
                  print('Officer data: $officerData');
                  final stationName = officerData['station'] ?? stationEntry.key;
                  setState(() {
                    _stationName = stationName;
                  });
                  // Setup call listeners after station name is loaded
                  _setupCallDataListeners();
                  _setupCallListeners();
                  return;
                } else {
                  print('Officer data is not a Map: $officerDataRaw');
                }
              }
            } else {
              print('Officers node is not a Map: $officersRaw');
            }
          }
        } else {
          print('Stations node is not a Map: $stationsRaw');
        }
      }
      setState(() {
        _stationName = "Police Station";
      });
    } catch (e) {
      print('Error fetching station info: $e');
      setState(() {
        _stationName = "Police Station";
      });
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(top: 32.0, left: 5.0, right: 5.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color.fromARGB(255, 75, 84, 255),
                      Color.fromARGB(255, 255, 69, 69),],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24.0),
            bottomRight: Radius.circular(24.0),
            topLeft: Radius.circular(12.0),
            topRight: Radius.circular(12.0),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stationName.isNotEmpty ? _stationName : 'Police Station',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22.0,
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.white, size: 18.0),
                        SizedBox(width: 6.0),
                        Expanded(
                          child: Text(
                            _currentLocation,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.0),
              GestureDetector(
                onTap: () => _showLogoutDialog(),
                child: CircleAvatar(
                radius: 28.0,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person_3,
                  color: Color(0xFF7F53AC),
                  size: 32.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: Text('Are you sure you want to logout from the system?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
      onPressed: () {
                Navigator.of(context).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if tab controller is initialized
    if (_tabController == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
        body: Column(
          children: [
          // Header
            _buildHeader(),
          
          // Tabs
            Container(
              color: Colors.white,
            child: TabBar(
              controller: _tabController!,
              labelColor: Colors.red,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.red,
              indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: [
                Tab(text: 'Active Calls'),
                  Tab(text: 'Missed Calls'),
                  Tab(text: 'Answered Calls'),
                ],
            ),
          ),
          
          Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 75, 84, 255),
                    Color.fromARGB(255, 255, 69, 69),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: _buildSearchBar(),
            ),
          
          
          // Tab Content with gradient background
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 75, 84, 255),
                      Color.fromARGB(255, 255, 69, 69),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: TabBarView(
                controller: _tabController!,
                children: [
                  // Active Calls Tab
                  _buildActiveCallsTab(),
                  
                  // Missed Calls Tab
                  _buildMissedCallsTab(),
                  
                  // Answered Calls Tab
                  _buildAnsweredCallsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
      // Add floating action button for map
      floatingActionButton: Positioned(
        bottom: 20,
        left: 20,
        child: FloatingActionButton(
          onPressed: _goToOfficerMapScreen,
          backgroundColor: Color.fromARGB(255, 75, 84, 255),
          foregroundColor: Colors.white,
          tooltip: 'View Map & Search Coordinates',
          child: Icon(Icons.map, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  void _goToOfficerMapScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfficerMapScreen(
          stations: _stations,
          officerName: widget.username,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: _getSearchHint(),
          hintStyle: TextStyle(color: const Color.fromARGB(139, 0, 0, 0)),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[400]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
      ),
      
    );
    
  }

  String _getSearchHint() {
    if (_tabController == null) return 'Search...';
    
    switch (_tabController!.index) {
      case 0:
        return 'Search here...';
      case 1:
        return 'Search here...';
      case 2:
        return 'Search here...';
      default:
        return 'Search...';
    }
  }

  Widget _buildActiveCallsTab() {
    final filteredCalls = _activeCalls.entries.where((entry) {
      final callData = entry.value as Map;
      final callerName = callData['caller']?.toString().toLowerCase() ?? '';
      final phoneNumber = callData['mobile']?.toString().toLowerCase() ?? '';
      return callerName.contains(_searchQuery) || phoneNumber.contains(_searchQuery);
    }).toList();

    // Sort active calls by timestamp in ascending order (oldest first)
    filteredCalls.sort((a, b) {
      final aTimestamp = a.value['timestamp'] ?? 0;
      final bTimestamp = b.value['timestamp'] ?? 0;
      return aTimestamp.compareTo(bTimestamp);
    });

    if (filteredCalls.isEmpty) {
      return _buildEmptyState('No active calls', );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredCalls.length,
      itemBuilder: (context, index) {
        final entry = filteredCalls[index];
        final callId = entry.key;
        final callData = Map<String, dynamic>.from(entry.value as Map);
        
        return _buildActiveCallCard(callId, callData);
      },
    );
  }

  Widget _buildMissedCallsTab() {
    final filteredCalls = _missedCalls.entries.where((entry) {
      final callData = entry.value as Map;
      final callerName = callData['caller']?.toString().toLowerCase() ?? '';
      final phoneNumber = callData['mobile']?.toString().toLowerCase() ?? '';
      return callerName.contains(_searchQuery) || phoneNumber.contains(_searchQuery);
    }).toList();

    // Sort missed calls by timestamp in ascending order (oldest first)
    filteredCalls.sort((a, b) {
      final aTimestamp = a.value['timestamp'] ?? 0;
      final bTimestamp = b.value['timestamp'] ?? 0;
      return aTimestamp.compareTo(bTimestamp);
    });

    if (filteredCalls.isEmpty) {
      return _buildEmptyState('No missed calls');
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredCalls.length,
      itemBuilder: (context, index) {
        final entry = filteredCalls[index];
        final callId = entry.key;
        final callData = Map<String, dynamic>.from(entry.value as Map);
        
        return _buildMissedCallCard(callId, callData);
      },
    );
  }

  Widget _buildAnsweredCallsTab() {
    final filteredCalls = _answeredCalls.entries.where((entry) {
      final callData = entry.value as Map;
      final callerName = callData['caller']?.toString().toLowerCase() ?? '';
      final phoneNumber = callData['mobile']?.toString().toLowerCase() ?? '';
      return callerName.contains(_searchQuery) || phoneNumber.contains(_searchQuery);
    }).toList();

    // Sort answered calls by timestamp in descending order (newest first)
    filteredCalls.sort((a, b) {
      final aTimestamp = a.value['timestamp'] ?? 0;
      final bTimestamp = b.value['timestamp'] ?? 0;
      return bTimestamp.compareTo(aTimestamp); // Descending order
    });

    if (filteredCalls.isEmpty) {
      return _buildEmptyState('No answered calls');
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredCalls.length,
      itemBuilder: (context, index) {
        final entry = filteredCalls[index];
        final callId = entry.key;
        final callData = Map<String, dynamic>.from(entry.value as Map);
        
        return _buildAnsweredCallCard(callId, callData);
      },
    );
  }

  Widget _buildEmptyState(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 60, color: const Color.fromARGB(255, 255, 255, 255)),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          SizedBox(height: 8),
          
        ],
      ),
    );
  }

  Widget _buildActiveCallCard(String callId, Map<String, dynamic> callData) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: NetworkImage(callData['photoUrl'] ?? 'https://via.placeholder.com/50'),
                  backgroundColor: Colors.grey[200],
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                        callData['caller'] ?? 'Unknown Caller',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                      children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Incoming Emergency Call',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                            onPressed: () {
                    Navigator.push(
                      context,
                                MaterialPageRoute(
                                  builder: (context) => IncomingCallPage(
                          name: callData['caller'],
                          photoUrl: callData['photoUrl'] ?? 'assets/default_avatar.png',
                          callId: callId,
                          station: _stationName,
                         officerId: widget.officerId,
                          gender: callData['gender'] ?? 'Male',
                          mobile: callData['mobile'] ?? '0912-345-6789',
                          address: callData['address'] ?? 'Not Specified',
                          disabilityStatus: callData['disabilityStatus'] ?? 'None',
                          medicalConditions: callData['medicalConditions'] ?? 'None',
                                  ),
                                ),
                              );
                            },
                  child: Text(
                    'View Details',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IncomingCallPage(
                            name: callData['caller'],
                            photoUrl: callData['photoUrl'] ?? 'assets/default_avatar.png',
                            callId: callId,
                            station: _stationName,
                         officerId: widget.officerId,
                            gender: callData['gender'] ?? 'Male',
                            mobile: callData['mobile'] ?? '0912-345-6789',
                            address: callData['address'] ?? 'Not Specified',
                            disabilityStatus: callData['disabilityStatus'] ?? 'None',
                            medicalConditions: callData['medicalConditions'] ?? 'None',
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.check, color: Colors.white),
                    label: Text('Answer Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _declineCall(callId, callData),
                    icon: Icon(Icons.close, color: Colors.white),
                    label: Text('Decline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissedCallCard(String callId, Map<String, dynamic> callData) {
    final timestamp = callData['timestamp'] ?? 0;
    final callTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final timeAgo = _getTimeAgo(callTime);
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(callData['photoUrl'] ?? 'https://via.placeholder.com/50'),
              backgroundColor: Colors.grey[200],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    callData['caller'] ?? 'Unknown Caller',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatDateAndTime(callTime),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Missed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Show Missed Call details as an overlay dialog
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (ctx) {
                        return MissedViewDetails(
                          name: callData['caller'] ?? 'Unknown Caller',
                          photoUrl: callData['photoUrl'] ?? 'https://via.placeholder.com/100',
                          gender: callData['gender'] ?? 'Unknown',
                          mobile: callData['mobile'] ?? 'Not Provided',
                          address: callData['address'] ?? 'Not Specified',
                          disabilityStatus: callData['disabilityStatus'] ?? 'None',
                          medicalConditions: callData['medicalConditions'] ?? 'None',
                          callId: callId,
                          station: _stationName,
                          officerId: widget.officerId, // Pass officer ID
                        );
                      },
                    );
                  },
                  child: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 255, 229, 229), // Button background color
                        foregroundColor: Colors.red,    // Text color
                        elevation: 3,                   // Shadow elevation
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                    ),
                  
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnsweredCallCard(String callId, Map<String, dynamic> callData) {
    final timestamp = callData['timestamp'] ?? 0;
    final callTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final answeredAt = callData['answeredAt'] ?? 0;
    final endedAt = callData['endedAt'] ?? 0;
    final duration = _calculateCallDuration(timestamp, answeredAt, endedAt);
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(callData['photoUrl'] ?? 'https://via.placeholder.com/50'),
              backgroundColor: Colors.grey[200],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    callData['caller'] ?? 'Unknown Caller',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatDateAndTime(callTime),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Answered',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
                    Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                      children: [
                    Icon(Icons.access_time, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Show Answered Call details overlay
                    final ts = (callData['timestamp'] ?? 0) as int;
                    final ans = (callData['answeredAt'] ?? 0) as int;
                    final end = (callData['endedAt'] ?? 0) as int;
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (ctx) {
                        return AnsweredViewDetails(
                          name: callData['caller'] ?? 'Unknown Caller',
                          photoUrl: callData['photoUrl'] ?? 'https://via.placeholder.com/100',
                          gender: callData['gender'] ?? 'Unknown',
                          mobile: callData['mobile'] ?? 'Not Provided',
                          address: callData['address'] ?? 'Not Specified',
                          disabilityStatus: callData['disabilityStatus'] ?? 'None',
                          medicalConditions: callData['medicalConditions'] ?? 'None',
                          callId: callId,
                          station: _stationName,
                          timestamp: ts,
                          answeredAt: ans,
                          endedAt: end,
                          officerId: widget.officerId, // Pass officer ID
                        );
                      },
                    );
                  },
                  child: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 228, 255, 229), // Button background color
                        foregroundColor: Colors.green,    // Text color
                        elevation: 3,                   // Shadow elevation
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                    ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _declineCall(String callId, Map<String, dynamic> callData) async {
    try {
      final db = FirebaseDatabase.instance.ref();
      
      // Update call status in both locations
      await db.child('StationsCallLogs/ActiveCalls/$callId').update({
        'status': 'declined',
        'declinedBy': widget.officerId,
        'declinedAt': ServerValue.timestamp,
      });
      
      await db.child('Desk Officer/$_stationName/ReceivedCalls/ActiveCalls/$callId').update({
        'status': 'declined',
        'declinedBy': widget.officerId,
        'declinedAt': ServerValue.timestamp,
      });
      
      // Move call to MissedCalls in both locations with preserved location data
      final callSnapshot = await db.child('StationsCallLogs/ActiveCalls/$callId').get();
      if (callSnapshot.exists) {
        final callData = Map<String, dynamic>.from(callSnapshot.value as Map);
        // Ensure citizen location data is preserved as strings
        if (callData['citizenLatitude'] != null) {
          callData['citizenLatitude'] = callData['citizenLatitude'].toString();
        }
        if (callData['citizenLongitude'] != null) {
          callData['citizenLongitude'] = callData['citizenLongitude'].toString();
        }
        await db.child('StationsCallLogs/MissedCalls/$callId').set(callData);
        await db.child('StationsCallLogs/ActiveCalls/$callId').remove();
      }
      
      final stationCallSnapshot = await db.child('Desk Officer/$_stationName/ReceivedCalls/ActiveCalls/$callId').get();
      if (stationCallSnapshot.exists) {
        final stationCallData = Map<String, dynamic>.from(stationCallSnapshot.value as Map);
        // Ensure citizen location data is preserved as strings
        if (stationCallData['citizenLatitude'] != null) {
          stationCallData['citizenLatitude'] = stationCallData['citizenLatitude'].toString();
        }
        if (stationCallData['citizenLongitude'] != null) {
          stationCallData['citizenLongitude'] = stationCallData['citizenLongitude'].toString();
        }
        await db.child('Desk Officer/$_stationName/ReceivedCalls/MissedCalls/$callId').set(stationCallData);
        await db.child('Desk Officer/$_stationName/ReceivedCalls/ActiveCalls/$callId').remove();
      }
      
      // Also update UsersCallLogs
      final userCallSnapshot = await db.child('UsersCallLogs/ActiveCalls/$callId').get();
      if (userCallSnapshot.exists) {
        final userCallData = Map<String, dynamic>.from(userCallSnapshot.value as Map);
        // Ensure officer location data is preserved as strings
        if (userCallData['officerLatitude'] != null) {
          userCallData['officerLatitude'] = userCallData['officerLatitude'].toString();
        }
        if (userCallData['officerLongitude'] != null) {
          userCallData['officerLongitude'] = userCallData['officerLongitude'].toString();
        }
        if (userCallData['officerRadius'] != null) {
          userCallData['officerRadius'] = userCallData['officerRadius'].toString();
        }
        userCallData['status'] = 'declined';
        userCallData['declinedBy'] = widget.officerId;
        userCallData['declinedAt'] = ServerValue.timestamp;
        await db.child('UsersCallLogs/MissedCalls/$callId').set(userCallData);
        await db.child('UsersCallLogs/ActiveCalls/$callId').remove();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Call from ${callData['caller']} declined'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error declining call'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatDateAndTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (callDate == today) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (callDate == today.subtract(Duration(days: 1))) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${_formatTime(dateTime)}';
    }
  }

  String _calculateCallDuration(int callStartTime, int answeredAt, int endedAt) {
    // If the call hasn't ended yet, calculate duration from answer time to now
    int endTime = endedAt;
    if (endTime == 0) {
      endTime = DateTime.now().millisecondsSinceEpoch;
    }
    
    // Calculate actual call duration (from when call was answered to when it ended)
    final callDuration = Duration(milliseconds: endTime - answeredAt);
    
    if (callDuration.inHours > 0) {
      final hours = callDuration.inHours;
      final minutes = callDuration.inMinutes % 60;
      final seconds = callDuration.inSeconds % 60;
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (callDuration.inMinutes > 0) {
      final minutes = callDuration.inMinutes;
      final seconds = callDuration.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    } else {
      final seconds = callDuration.inSeconds;
      return '${seconds}s';
    }
  }

  String _calculateDuration(int startTime, int endTime) {
    final duration = Duration(milliseconds: endTime - startTime);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
