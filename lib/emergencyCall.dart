import 'package:flutter/material.dart';
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:permission_handler/permission_handler.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'utils/agora_config.dart';
import '../screens/map_screen.dart';
import '../models/station.dart';

// EmergencyCallScreen is the citizen's in-call UI during an emergency call.
// TODO: Add Agora integration for real voice call functionality (join/leave channel, mute, end call, etc.)

class EmergencyCallScreen extends StatefulWidget {
  final String officerName;
  final String avatarAsset;
  final String callId; // Add callId parameter
  final String station;

  const EmergencyCallScreen({
    Key? key,
    required this.officerName,
    required this.avatarAsset,
    required this.callId, // Initialize callId
    required this.station,
  }) : super(key: key);

  @override
  _EmergencyCallScreenState createState() => _EmergencyCallScreenState();
}

class _EmergencyCallScreenState extends State<EmergencyCallScreen> {
  late Timer _timer;
  int _seconds = 0;
  late RtcEngine _engine;
  bool _joined = false;
  bool _muted = false;
  bool _speakerEnabled = false;
  LatLng? _citizenLocation;
  LatLng? _stationLocation;
  List<Station> _allStations = [];
  Map<String, dynamic>? _stationData;
  String _stationHotline = '';
  String _stationAddress = '';
  String _stationLatitude = '';
  String _stationLongitude = '';
  String _stationName = '';
  String _stationRadius = '';

  @override
  void initState() {
    super.initState();
    _initAgora(); // call tis to set up agora
    _getLocations();
    _fetchAllStations();
    _loadStationProfile();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
    // TODO: Initialize Agora engine and join channel here
  }

  Future<void> _getLocations() async {
    // Get citizen's current location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _citizenLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint('Failed to get citizen location: $e');
    }

    // Get station's location from Firebase
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final snapshot = await dbRef.child('Desk Officer/${widget.station}').get();
      if (snapshot.exists && snapshot.value != null) {
        final stationData = Map<String, dynamic>.from(snapshot.value as Map);
        final lat = double.tryParse(stationData['latitude']?.toString() ?? '');
        final lon = double.tryParse(stationData['longitude']?.toString() ?? '');

        if (lat != null && lon != null) {
          if (mounted) {
            setState(() {
              _stationLocation = LatLng(lat, lon);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get station location: $e');
    }
  }

  Future<void> _fetchAllStations() async {
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
            _allStations = loadedStations;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch all stations: $e');
    }
  }

  Future<void> _loadStationProfile() async {
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final snapshot = await dbRef.child('Desk Officer/${widget.station}').get();
      if (snapshot.exists && snapshot.value != null) {
        final stationData = Map<String, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          setState(() {
            _stationData = stationData;
            _stationHotline = stationData['hotline'] ?? 'Not provided';
            _stationAddress = _buildFullAddress(stationData);
            _stationLatitude = stationData['latitude']?.toString() ?? 'Not provided';
            _stationLongitude = stationData['longitude']?.toString() ?? 'Not provided';
            _stationName = stationData['name'] ?? widget.station;
            _stationRadius = stationData['radius']?.toString() ?? 'Not provided';
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load station profile: $e');
    }
  }
  
  String _buildFullAddress(Map<String, dynamic> stationData) {
    List<String> addressParts = [];
    
    if (stationData['streetAddress'] != null && stationData['streetAddress'].toString().isNotEmpty) {
      addressParts.add(stationData['streetAddress'].toString());
    }
    if (stationData['city'] != null && stationData['city'].toString().isNotEmpty) {
      addressParts.add(stationData['city'].toString());
    }
    if (stationData['region'] != null && stationData['region'].toString().isNotEmpty) {
      addressParts.add(stationData['region'].toString());
    }
    
    return addressParts.isNotEmpty ? addressParts.join(', ') : 'Not provided';
  }

  Future<void> _handlePermissions() async {
    await [
      Permission.microphone,
      Permission.camera, // Include if you use video, otherwise remove
    ].request();

    // Optionally, you can add logic here to check if permissions were granted
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
    //   // Show a dialog or message to the user explaining why microphone is needed
    debugPrint("Microphone permission denied for citizen.");
    }
  }


  Future<void> _initAgora() async {

    // Use centralized configuration
    final String channelName = AgoraConfig.getChannelName(isTesting: true);

    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      debugPrint("Agora initialization skipped: Microphone permission not granted.");
      return; // Do not proceed with Agora if permissions are not granted
    }

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AgoraConfig.appId));
    
    // Register Agora event handlers to get feedback on call status
    _engine.registerEventHandler(
    RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("Agora: Local user ${connection.localUid} joined channel: $channelName"); // Added channelName to log
        setState(() {
          _joined = true;
        });
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("Agora: Remote user $remoteUid joined the channel $channelName"); // Added channelName to log
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint("Agora: Remote user $remoteUid left the channel $channelName, reason: $reason"); // Added channelName to log
        _endCall();
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        debugPrint("Agora: Local user left channel $channelName"); // Added channelName to log
        setState(() {
          _joined = false;
        });
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint("Agora Error: $err, $msg"); // Generic error log
      },
    ),
  );

    // Enable audio functionality for voice calls
    await _engine.enableAudio();
    
    // Set audio profile for voice calls
    await _engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioGameStreaming,
    );
    
    // Set audio route to speaker for better voice call experience
    await _engine.setDefaultAudioRouteToSpeakerphone(true);
    
    // Enable audio volume indication to monitor audio levels
    await _engine.enableAudioVolumeIndication(
      interval: 200,
      smooth: 3,
      reportVad: true,
    );

  // Join the channel with voice-only options
  await _engine.joinChannel(
    token: AgoraConfig.getToken(isTesting: true), // Use centralized token configuration
    channelId: channelName, // Use centralized channel name
    uid: 0,
    options: const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      publishMicrophoneTrack: true,
      publishCameraTrack: false, // Disable video para voice calls ra hays pagkanalang
      autoSubscribeAudio: true,
      autoSubscribeVideo: false, // Disable video subscription
    ),
  );
  debugPrint("Attempted to join channel: $channelName for voice-only testing."); // Confirmation log
}

  Future<void> _toggleMute() async {
    await _engine.muteLocalAudioStream(!_muted);
    setState(() {
      _muted = !_muted;
    });
    debugPrint("Microphone ${_muted ? 'muted' : 'unmuted'}");
  }

  Future<void> _toggleSpeaker() async {
  // Toggle state first, then apply to engine so the value matches UI
  setState(() {
    _speakerEnabled = !_speakerEnabled;
  });
  await _engine.setEnableSpeakerphone(_speakerEnabled);
  debugPrint("Speakerphone toggled to: $_speakerEnabled");
}

  Future<void> _endCall() async {
  _timer.cancel(); // Stop the call timer

  // Leave the Agora channel and release resources
  await _engine.leaveChannel();
  await _engine.release();

  // Update the call status in Firebase Realtime Database using new structure
  final dbRef = FirebaseDatabase.instance.ref();
  final callId = widget.callId;
  final stationName = widget.station;
  
  // Update call status in StationsCallLogs and preserve citizen location data
  final stationCallSnapshot = await dbRef.child('StationsCallLogs/AnsweredCalls/$callId').get();
  if (stationCallSnapshot.exists) {
    final callData = Map<String, dynamic>.from(stationCallSnapshot.value as Map);
    // Ensure location data is preserved as strings
    if (callData['citizenLatitude'] != null) {
      callData['citizenLatitude'] = callData['citizenLatitude'].toString();
    }
    if (callData['citizenLongitude'] != null) {
      callData['citizenLongitude'] = callData['citizenLongitude'].toString();
    }
    callData['status'] = 'ended';
    callData['endedAt'] = ServerValue.timestamp;
    await dbRef.child('StationsCallLogs/AnsweredCalls/$callId').update(callData);
  }
  
  // Update call status in Desk Officer logs and preserve citizen location data
  final deskOfficerCallSnapshot = await dbRef.child('Desk Officer/$stationName/ReceivedCalls/AnsweredCalls/$callId').get();
  if (deskOfficerCallSnapshot.exists) {
    final callData = Map<String, dynamic>.from(deskOfficerCallSnapshot.value as Map);
    // Ensure location data is preserved as strings
    if (callData['citizenLatitude'] != null) {
      callData['citizenLatitude'] = callData['citizenLatitude'].toString();
    }
    if (callData['citizenLongitude'] != null) {
      callData['citizenLongitude'] = callData['citizenLongitude'].toString();
    }
    callData['status'] = 'ended';
    callData['endedAt'] = ServerValue.timestamp;
    await dbRef.child('Desk Officer/$stationName/ReceivedCalls/AnsweredCalls/$callId').update(callData);
  }

  // Update call status in UsersCallLogs and preserve officer location data
  final userCallSnapshot = await dbRef.child('UsersCallLogs/AnsweredCalls/$callId').get();
  if (userCallSnapshot.exists) {
    final callData = Map<String, dynamic>.from(userCallSnapshot.value as Map);
    // Ensure officer location data is preserved as strings
    if (callData['officerLatitude'] != null) {
      callData['officerLatitude'] = callData['officerLatitude'].toString();
    }
    if (callData['officerLongitude'] != null) {
      callData['officerLongitude'] = callData['officerLongitude'].toString();
    }
    if (callData['officerRadius'] != null) {
      callData['officerRadius'] = callData['officerRadius'].toString();
    }
    callData['status'] = 'ended';
    callData['endedAt'] = ServerValue.timestamp;
    await dbRef.child('UsersCallLogs/AnsweredCalls/$callId').update(callData);
  }

  if (mounted) {
    Navigator.of(context).pop(); // Go back to the previous screen (homepage)
  }
}


  @override
  void dispose() {
    _timer.cancel();    // stop timer
    _engine.leaveChannel();   // ensure leaving channel
    _engine.release();    // release agora resourecs
    // TODO: Leave Agora channel and dispose engine here
    super.dispose();
  }

  void _onToggleMute() {
    _toggleMute(); // Use the async version
  }

  void _onSpeaker()
  {
    _toggleSpeaker();
  }

  void _onEndCall() {
    _endCall(); // Use the async version
  }

  void _onViewProfile() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3E45CD), Color(0xFFFF6767)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header with close button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      const Text(
                        'Station Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Profile content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Station icon and name
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.local_police,
                            size: 48,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _stationName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Contact Information Section
                        _SectionHeader(title: 'Contact Information', icon: Icons.contact_phone),
                        const SizedBox(height: 12),
                        _InfoCard(
                          label: 'Hotline',
                          value: _stationHotline,
                          icon: Icons.phone,
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          label: 'Address',
                          value: _stationAddress,
                          icon: Icons.location_on,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Location Information Section
                        _SectionHeader(title: 'Location Information', icon: Icons.map),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoCard(
                                label: 'Latitude',
                                value: _stationLatitude,
                                icon: Icons.my_location,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoCard(
                                label: 'Longitude',
                                value: _stationLongitude,
                                icon: Icons.my_location,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          label: 'Service Radius',
                          value: '$_stationRadius meters',
                          icon: Icons.radio_button_checked,
                          labelColor: Colors.blue,
                          backgroundColor: const Color(0xFFE3F2FD),
                          borderColor: Colors.blue,
                        ),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _formattedTime {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 111, 114, 253), // purple-ish
              Color.fromARGB(255, 253, 97, 99), // red-ish
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage(widget.avatarAsset), // TODO: Use real officer avatar
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.station, // TODO: Use real officer name
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, color: Colors.white70, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: Icons.person,
                          label: 'View Profile',
                          color: const Color.fromARGB(255, 85, 85, 85),
                          onTap: _onViewProfile,
                        ),
                        _ActionButton(
                          icon: Icons.location_on,
                          label: 'Location',
                          color: const Color.fromARGB(255, 85, 85, 85),
                          onTap: () {
                            if (_citizenLocation != null && _stationLocation != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapScreen(
                                    stations: _allStations,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Locating data...'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: _muted ? Icons.mic_off : Icons.mic, // Use mute state
                          label: 'Mic',
                          color: _muted ? const Color.fromARGB(255, 88, 99, 255) : const Color.fromARGB(255, 85, 85, 85),
                          onTap: _onToggleMute, // Wire to mute/unmute
                        ),
                        _ActionButton(
                          icon: Icons.volume_up,
                          label: 'Speaker',
                          color: _speakerEnabled ? const Color.fromARGB(255, 88, 99, 255) : const Color.fromARGB(255, 85, 85, 85),
                          onTap: _onSpeaker,
                        ),
                        _ActionButton(
                          icon: Icons.call_end,
                          label: 'End Call',
                          color: const Color.fromARGB(255, 253, 82, 82),
                          
                          onTap: _onEndCall, // Wire to end call
                        ),
                      ],
                    ),
                    
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? color;
  

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.color,
  }) : super(key: key);



  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color ?? Colors.black87,
              size: 28,
            ),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
} 

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    Key? key,
    required this.title,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? labelColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const _InfoCard({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    this.labelColor,
    this.backgroundColor,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null ? Border.all(color: borderColor!, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: labelColor ?? Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: labelColor ?? Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: labelColor ?? Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
