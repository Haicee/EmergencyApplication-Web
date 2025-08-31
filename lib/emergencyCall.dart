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

  @override
  void initState() {
    super.initState();
    _initAgora(); // call tis to set up agora
    _getLocations();
    _fetchAllStations();
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
                          onTap: () {},
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
