import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_database/firebase_database.dart';
import '../main.dart';
import 'dart:async';
import '../models/station.dart';
import '../screens/officer_map_screen.dart';

// Responder task details UI
import 'task_details_page.dart';
import 'inProgressDetails.dart';
import 'completedDetails.dart';

class ResponderHomePage extends StatefulWidget {
  final String username;
  final String responderId;

  const ResponderHomePage({
    Key? key,
    required this.username,
    required this.responderId,
  }) : super(key: key);

  @override
  State<ResponderHomePage> createState() => _ResponderHomePageState();
}

class _ResponderHomePageState extends State<ResponderHomePage> with TickerProviderStateMixin {
  String _currentLocation = "Locating...";
  String _stationName = "";
  String _responderName = "";
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Station> _stations = [];
  
  // Tab controller
  TabController? _tabController;
  
  // Search controllers
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Task data
  Map<String, dynamic> _assignedTasks = {};
  Map<String, dynamic> _completedTasks = {};
  Map<String, dynamic> _inProgressTasks = {};
  
  // Stream subscriptions
  late StreamSubscription _assignedTasksSubscription;
  late StreamSubscription _completedTasksSubscription;
  late StreamSubscription _inProgressTasksSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAndSetLocation();
    _fetchResponderInfo();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    // Cancel subscriptions if they exist
    try {
      _assignedTasksSubscription.cancel();
      _completedTasksSubscription.cancel();
      _inProgressTasksSubscription.cancel();
    } catch (e) {
      // Subscriptions may not be initialized yet
    }
    super.dispose();
  }

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(Duration(days: 1));
  final taskDate = DateTime(date.year, date.month, date.day);
  
  if (taskDate == today) {
    return 'Today, ${_getMonthName(date.month)} ${date.day}';
  } else if (taskDate == yesterday) {
    return 'Yesterday, ${_getMonthName(date.month)} ${date.day}';
  } else {
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }
}

String _getMonthName(int month) {
  const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                  'July', 'August', 'September', 'October', 'November', 'December'];
  return months[month];
}

String _formatTimeAgo(DateTime time) {
  // Normalize both to local time to avoid timezone skew issues
  final now = DateTime.now().toLocal();
  final ts = time.toLocal();
  Duration diff = now.difference(ts);

  // If timestamp is slightly in the future (device clock skew), clamp to zero
  if (diff.isNegative) {
    // Allow up to 5 minutes skew; otherwise still show future as 'just now'
    final futureSkew = diff.abs();
    if (futureSkew.inMinutes <= 5) {
      diff = Duration.zero;
    } else {
      // For larger future values, we still show 'just now' to avoid confusion in monitoring
      return 'just now';
    }
  }

  final seconds = diff.inSeconds;
  if (seconds < 60) return 'just now';

  final minutes = diff.inMinutes;
  if (minutes < 60) return '$minutes minute${minutes == 1 ? '' : 's'} ago';

  final hours = diff.inHours;
  if (hours < 24) return '$hours hour${hours == 1 ? '' : 's'} ago';

  final days = diff.inDays;
  if (days < 7) return '$days day${days == 1 ? '' : 's'} ago';

  final weeks = days ~/ 7;
  if (weeks < 4) return '$weeks week${weeks == 1 ? '' : 's'} ago';

  final months = days ~/ 30; // Approximation suitable for monitoring
  return '$months month${months == 1 ? '' : 's'} ago';
}

DateTime? _parseTimestamp(String? timestamp) {
  if (timestamp == null) return null;
  try {
    return DateTime.parse(timestamp);
  } catch (e) {
    return null;
  }
}

  Future<void> _fetchAndSetLocation() async {
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

  Future<void> _fetchResponderInfo() async {
    try {
      final respondersSnapshot = await _database.child('Responders').get();
      if (respondersSnapshot.exists) {
        final stations = respondersSnapshot.value as Map<dynamic, dynamic>;
        
        // Load stations data for map
        List<Station> stationsList = [];
        
        for (final stationEntry in stations.entries) {
          final stationName = stationEntry.key.toString();
          final stationData = stationEntry.value;
          
          if (stationData is Map) {
            final stationMap = stationData as Map<dynamic, dynamic>;
            
            // Check if this responder belongs to this station
            if (stationMap.containsKey(widget.responderId)) {
              final responderData = stationMap[widget.responderId] as Map<dynamic, dynamic>;
              
              setState(() {
                _stationName = stationName;
                _responderName = responderData['fullName'] ?? widget.username;
              });
              
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
              
              _setupTaskListeners();
              break;
            }
          }
        }
        
        setState(() {
          _stations = stationsList;
        });
      }
    } catch (e) {
      print('Error fetching responder info: $e');
      setState(() {
        _stationName = "Police Station";
        _responderName = widget.username;
      });
    }
  }

  void _setupTaskListeners() {
    if (_stationName.isEmpty) return;
    
    final db = FirebaseDatabase.instance.ref();
    
    // Listen for assigned tasks
    _assignedTasksSubscription = db
    .child('Responders/$_stationName/ReceivedCallDetails/Assigned')
    .onValue.listen((event) {
      final v = event.snapshot.value;
      if (v != null && v is Map) {
        setState(() {
          _assignedTasks = _asStringMap(v);
        });
      } else {
        setState(() {
          _assignedTasks = {};
        });
      }
    }); 
    
    // Listen for in-progress tasks
    _inProgressTasksSubscription = db
    .child('Responders/$_stationName/ReceivedCallDetails/InProgress')
    .onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        setState(() {
          _inProgressTasks = _asStringMap(event.snapshot.value);
        });
      } else {
        setState(() {
          _inProgressTasks = {};
        });
      }
    }); 
    
    // Listen for completed tasks
    _completedTasksSubscription = db.child('Responders/$_stationName/ReceivedCallDetails/Completed')
        .onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        setState(() {
          _completedTasks = _asStringMap(event.snapshot.value);
        });
      } else {
        setState(() {
          _completedTasks = {};
        });
      }
    });
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
                      '${_stationName.isNotEmpty ? _stationName : 'Police Station'} Resp.',
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
                  Icons.local_police,
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
    body: Stack( // Wrap body with a Stack
      children: [
        Column(
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
                  Tab(text: 'Assigned'),
                  Tab(text: 'In Progress'),
                  Tab(text: 'Completed'),
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
                    // Assigned Tasks Tab
                    RefreshIndicator(
                      onRefresh: _refreshTasks,
                      child: _buildAssignedTasksTab(),
                    ),

                    // In Progress Tasks Tab
                    RefreshIndicator(
                      onRefresh: _refreshTasks,
                      child: _buildInProgressTasksTab(),
                    ),

                    // Completed Tasks Tab
                    RefreshIndicator(
                      onRefresh: _refreshTasks,
                      child: _buildCompletedTasksTab(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Place the Positioned FAB as a child of the Stack
        Positioned(
          bottom: 20,
          left: 20,
          child: FloatingActionButton(
            onPressed: _goToResponderMapScreen,
            backgroundColor: Color.fromARGB(255, 75, 84, 255),
            foregroundColor: Colors.white,
            tooltip: 'View Map & Navigate to Incidents',
            child: Icon(Icons.map, size: 28),
          ),
        ),
      ],
    ),
  );
}

  void _goToResponderMapScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfficerMapScreen(
          stations: _stations,
          officerName: _responderName,
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
      return 'Search assigned tasks...';
    case 1:
      return 'Search in progress tasks...';
    case 2:
      return 'Search completed tasks...';
    default:
      return 'Search...';
  }
}

  // Safely convert any dynamic snapshot value to a string-keyed map.
  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  Widget _buildAssignedTasksTab() {
    final filteredTasks = _assignedTasks.entries
        .where((entry) => entry.value is Map)
        .where((entry) {
          final taskData = entry.value as Map;
          final callerName = taskData['callerName']?.toString().toLowerCase() ?? '';
          final location = taskData['location']?.toString().toLowerCase() ?? '';
          return callerName.contains(_searchQuery) || location.contains(_searchQuery);
        }).toList();

    if (filteredTasks.isEmpty) {
      return _buildEmptyState('No emergency assigned', Icons.assignment);
    }

    // Group tasks by date
    Map<String, List<MapEntry<String, dynamic>>> groupedTasks = {};
    for (var entry in filteredTasks) {
      final taskData = entry.value as Map;
      final timestamp = _parseTimestamp(taskData['timestamp']?.toString());
      final dateKey = timestamp != null ? _formatDate(timestamp) : 'Unknown Date';
      
      if (!groupedTasks.containsKey(dateKey)) {
        groupedTasks[dateKey] = [];
      }
      groupedTasks[dateKey]!.add(entry);
    }

    // Sort tasks within each date group by timestamp (descending - newest first)
    groupedTasks.forEach((dateKey, tasks) {
      tasks.sort((a, b) {
        final aMap = a.value is Map ? a.value as Map : const {};
        final bMap = b.value is Map ? b.value as Map : const {};
        final aTimestamp = _parseTimestamp(aMap['timestamp']?.toString());
        final bTimestamp = _parseTimestamp(bMap['timestamp']?.toString());
        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;
        return bTimestamp.compareTo(aTimestamp); // Descending order
      });
    });

    // Sort date groups (Today first, then Yesterday, then older dates)
    final sortedDateKeys = groupedTasks.keys.toList()..sort((a, b) {
      if (a.startsWith('Today')) return -1;
      if (b.startsWith('Today')) return 1;
      if (a.startsWith('Yesterday')) return -1;
      if (b.startsWith('Yesterday')) return 1;
      return b.compareTo(a); // For other dates, newer first
    });

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sortedDateKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDateKeys[index];
        final tasksForDate = groupedTasks[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                dateKey,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Tasks for this date
            ...tasksForDate.where((e) => e.value is Map).map((entry) {
              final taskId = entry.key;
              final taskData = Map<String, dynamic>.from(entry.value as Map);
              return _buildEnhancedTaskCard(taskId, taskData, 'assigned');
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildInProgressTasksTab() {
    final filteredTasks = _inProgressTasks.entries
        .where((entry) => entry.value is Map)
        .where((entry) {
          final taskData = entry.value as Map;
          final callerName = taskData['callerName']?.toString().toLowerCase() ?? '';
          final location = taskData['location']?.toString().toLowerCase() ?? '';
          return callerName.contains(_searchQuery) || location.contains(_searchQuery);
        }).toList();

    if (filteredTasks.isEmpty) {
      return _buildEmptyState('No emergency in progress', Icons.pending_actions);
    }

    // Group tasks by date
    Map<String, List<MapEntry<String, dynamic>>> groupedTasks = {};
    for (var entry in filteredTasks) {
      final taskData = entry.value as Map;
      final timestamp = _parseTimestamp(taskData['timestamp']?.toString());
      final dateKey = timestamp != null ? _formatDate(timestamp) : 'Unknown Date';
      
      if (!groupedTasks.containsKey(dateKey)) {
        groupedTasks[dateKey] = [];
      }
      groupedTasks[dateKey]!.add(entry);
    }

    // Sort tasks within each date group by timestamp (descending - newest first)
    groupedTasks.forEach((dateKey, tasks) {
      tasks.sort((a, b) {
        final aMap = a.value is Map ? a.value as Map : const {};
        final bMap = b.value is Map ? b.value as Map : const {};
        final aTimestamp = _parseTimestamp(aMap['timestamp']?.toString());
        final bTimestamp = _parseTimestamp(bMap['timestamp']?.toString());
        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;
        return bTimestamp.compareTo(aTimestamp); // Descending order
      });
    });

    // Sort date groups (Today first, then Yesterday, then older dates)
    final sortedDateKeys = groupedTasks.keys.toList()..sort((a, b) {
      if (a.startsWith('Today')) return -1;
      if (b.startsWith('Today')) return 1;
      if (a.startsWith('Yesterday')) return -1;
      if (b.startsWith('Yesterday')) return 1;
      return b.compareTo(a); // For other dates, newer first
    });

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sortedDateKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDateKeys[index];
        final tasksForDate = groupedTasks[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                dateKey,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Tasks for this date
            ...tasksForDate.where((e) => e.value is Map).map((entry) {
              final taskId = entry.key;
              final taskData = Map<String, dynamic>.from(entry.value as Map);
              return _buildEnhancedTaskCard(taskId, taskData, 'inprogress');
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildCompletedTasksTab() {
    final filteredTasks = _completedTasks.entries
        .where((entry) => entry.value is Map)
        .where((entry) {
          final taskData = entry.value as Map;
          final callerName = taskData['callerName']?.toString().toLowerCase() ?? '';
          final location = taskData['location']?.toString().toLowerCase() ?? '';
          return callerName.contains(_searchQuery) || location.contains(_searchQuery);
        }).toList();

    if (filteredTasks.isEmpty) {
      return _buildEmptyState('No emergency completed', Icons.task_alt);
    }

    // Group tasks by date
    Map<String, List<MapEntry<String, dynamic>>> groupedTasks = {};
    for (var entry in filteredTasks) {
      final taskData = entry.value as Map;
      final timestamp = _parseTimestamp(taskData['timestamp']?.toString());
      final dateKey = timestamp != null ? _formatDate(timestamp) : 'Unknown Date';
      
      if (!groupedTasks.containsKey(dateKey)) {
        groupedTasks[dateKey] = [];
      }
      groupedTasks[dateKey]!.add(entry);
    }

    // Sort tasks within each date group by timestamp (descending - newest first)
    groupedTasks.forEach((dateKey, tasks) {
      tasks.sort((a, b) {
        final aTimestamp = _parseTimestamp((a.value as Map)['timestamp']?.toString());
        final bTimestamp = _parseTimestamp((b.value as Map)['timestamp']?.toString());
        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;
        return bTimestamp.compareTo(aTimestamp); // Descending order
      });
    });

    // Sort date groups (Today first, then Yesterday, then older dates)
    final sortedDateKeys = groupedTasks.keys.toList()..sort((a, b) {
      if (a.startsWith('Today')) return -1;
      if (b.startsWith('Today')) return 1;
      if (a.startsWith('Yesterday')) return -1;
      if (b.startsWith('Yesterday')) return 1;
      return b.compareTo(a); // For other dates, newer first
    });

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedDateKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDateKeys[index];
        final tasksForDate = groupedTasks[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                dateKey,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Tasks for this date
            ...tasksForDate.where((e) => e.value is Map).map((entry) {
              final taskId = entry.key;
              final taskData = Map<String, dynamic>.from(entry.value as Map);
              return _buildEnhancedTaskCard(taskId, taskData, 'completed');
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String title, IconData icon) {
    // Wrap in a ListView with AlwaysScrollableScrollPhysics so pull-to-refresh works even when empty
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      children: [
        SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: const Color.fromARGB(255, 255, 255, 255)),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 255, 255, 255),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(height: 400),
      ],
    );
  }

  Future<void> _refreshTasks() async {
    try {
      if (_stationName.isEmpty) {
        await _fetchResponderInfo();
        return;
      }
      final baseRef = FirebaseDatabase.instance.ref('Responders/$_stationName/ReceivedCallDetails');
      final assignedSnap = await baseRef.child('Assigned').get();
      final inProgSnap = await baseRef.child('InProgress').get();
      final completedSnap = await baseRef.child('Completed').get();

      setState(() {
        _assignedTasks = (assignedSnap.value != null && assignedSnap.value is Map)
            ? _asStringMap(assignedSnap.value)
            : {};
        _inProgressTasks = (inProgSnap.value != null && inProgSnap.value is Map)
            ? _asStringMap(inProgSnap.value)
            : {};
        _completedTasks = (completedSnap.value != null && completedSnap.value is Map)
            ? _asStringMap(completedSnap.value)
            : {};
      });
    } catch (e) {
      // Optionally show a snackbar on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh tasks: $e')),
        );
      }
    }
  }

  

  Widget _buildEnhancedTaskCard(String taskId, Map<String, dynamic> taskData, String status) {
    final timestamp = _parseTimestamp(taskData['timestamp']?.toString());
    final timeAgo = timestamp != null ? _formatTimeAgo(timestamp) : 'Unknown time';

    // Get status color and text based on status
    Color statusColor;
    String statusText;
    switch (status) {
      case 'assigned':
        statusColor = Colors.orange;
        statusText = 'Assigned';
        break;
      case 'inprogress':
        statusColor = Colors.blue;
        statusText = 'In Progress';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Completed';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
    }

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
            // Profile Avatar
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[300],
              backgroundImage: taskData['callerImage'] != null
                  ? NetworkImage(taskData['callerImage'])
                  : null,
              child: taskData['callerImage'] == null
                  ? Icon(Icons.person, color: Colors.grey[600], size: 25)
                  : null,
            ),
            SizedBox(width: 16),
            // Content section that expands
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Caller name
                  Text(
                    taskData['callerName'] ?? 'Unknown Caller',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  // Time only (leave time-ago to the trailing column)
                  Text(
                    timestamp != null
                        ? '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} ${timestamp.hour >= 12 ? 'PM' : 'AM'}'
                        : 'Time not available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  // Status indicator
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            SizedBox(width: 12),
            // Trailing column with time-ago above the button
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
                  onPressed: () => _showTaskDetails(taskId, taskData, status: status),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size(0, 36),
                  ),
                  child: Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 14,
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
  }

  void _showTaskDetails(String taskId, Map<String, dynamic> taskData, {String? status}) {
    // Decide target page based on status/tab
    final Map<String, dynamic> safeData = taskData;
    Widget page;
    switch (status) {
      case 'inprogress':
        page = InProgressDetailsPage(taskData: safeData);
        break;
      // You can route completed to a dedicated page later
      case 'completed':
        page = CompletedDetailsPage(taskData: safeData);
        break;
      case 'assigned':
      default:
        page = ResponderTaskDetailsPage(taskData: safeData);
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _acceptTask(String taskId, Map<String, dynamic> taskData) {
    // TODO: Move task from assigned to in-progress
    _showTaskDetails(taskId, taskData, status: 'inprogress');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task accepted.')),
    );
  }

  void _completeTask(String taskId, Map<String, dynamic> taskData) {
    // TODO: Move task from in-progress to completed
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task completed: ${taskData['incidentType']}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _navigateToIncident(Map<String, dynamic> taskData) {
    // TODO: Open navigation to incident location
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation to: ${taskData['location']}'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}