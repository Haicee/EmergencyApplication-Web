import 'dart:async';
import 'package:emergency/screens/officer_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart'; // Add Agora import
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/agora_config.dart'; // Import Agora configuration
import '../models/station.dart'; // Add Station import
import '../screens/officer_map_screen.dart'; // Add CallMapScreen import

// DuringCallPage is the in-call UI for the desk officer.
// Here, you should join the Agora channel in initState, handle mute/unmute, and leave the channel when the call ends.
// TODO: Add Agora integration for real voice call functionality.

class DuringCallPage extends StatefulWidget {
  final String name;
  final String photoUrl;
  final DateTime callStartTime; // Pass the call start time
  final String callId; // Add callId parameter
  final String station;

  const DuringCallPage({
    Key? key,
    required this.name,
    required this.photoUrl,
    required this.callStartTime,
    required this.callId, // Initialize callId
    required this.station,
  }) : super(key: key);

  @override
  State<DuringCallPage> createState() => _DuringCallPageState();
}

class _DuringCallPageState extends State<DuringCallPage> {
  late Timer _timer;
  late Duration _elapsed;
  // Agora variables
  late RtcEngine _engine; // Agora engine instance
  bool _joined = false;   // Track join state
  bool _muted = false; 
  bool _speakerEnabled = false;   // Track mute state
  List<Station> _stations = []; // Initialize stations list
  double? _callerLatitude;
  double? _callerLongitude;

  @override
  void initState() {
    super.initState();
    // 1. Handle permissions first
    _handlePermissions().then((_) {
      // 2. Then initialize Agora
      _initAgora();
    });

    _elapsed = DateTime.now().difference(widget.callStartTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.callStartTime);
      });
    });
    _initStations(); // Initialize stations data
  }

  
  // Add the _handlePermissions function here
  Future<void> _handlePermissions() async {
    await [
      Permission.microphone,
    ].request();

    // Optionally, you can add logic here to check if permissions were granted
     var micStatus = await Permission.microphone.status;
     if (!micStatus.isGranted) {
       debugPrint("Microphone permission denied for desk officer.");
    }
  }

  // Initialize Agora and join the channel
  Future<void> _initAgora() async {

    // Use centralized configuration
    final String channelName = AgoraConfig.getChannelName(isTesting: true);

    // Ensure permissions are granted before proceeding
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      debugPrint("Agora initialization skipped: Microphone permission not granted.");
      return; // Do not proceed with Agora if permissions are not granted
    }

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AgoraConfig.appId));

    // Register event handlers (from earlier steps)
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
      publishCameraTrack: false, // Disable video for voice-only calls
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
    // This is the core Agora API call for speakerphone control
    
    setState(() {
      _speakerEnabled = !_speakerEnabled; // Toggle the state
    });
    
    await _engine.setEnableSpeakerphone(_speakerEnabled);

    debugPrint("Speakerphone toggled to: $_speakerEnabled");
  }

  void _goToMapScreen() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CallMapScreen(stations: _stations, callerLatitude: _callerLatitude, callerLongitude: _callerLongitude, callerName: widget.name),
    ),
  );
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
    Navigator.of(context).pop(); // Go back to the previous screen (doHomepage)
  }
}

  Future<void> _initStations() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      
      // Load stations data
      final deskOfficerSnapshot = await db.child('Desk Officer').get();
      if (deskOfficerSnapshot.exists) {
        final stationsRaw = deskOfficerSnapshot.value;
        if (stationsRaw is Map) {
          final stations = stationsRaw as Map<dynamic, dynamic>;
          List<Station> stationsList = [];
          for (final stationEntry in stations.entries) {
            final stationName = stationEntry.key.toString();
            final stationData = stationEntry.value;
            if (stationData is Map) {
              final stationMap = stationData as Map<dynamic, dynamic>;
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
          if (mounted) {
            setState(() {
              _stations = stationsList;
            });
          }
        }
      }
      
      // Load caller location from call data
      await _loadCallerLocation();
      
    } catch (e) {
      print('Error loading stations: $e');
    }
  }

  Future<void> _loadCallerLocation() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      final callId = widget.callId;
      
      // Try to get caller location from call data
      final callSnapshot = await db.child('StationsCallLogs/AnsweredCalls/$callId').get();
      if (callSnapshot.exists) {
        final callData = Map<String, dynamic>.from(callSnapshot.value as Map);
        if (mounted) {
          setState(() {
            _callerLatitude = double.tryParse(callData['citizenLatitude']?.toString() ?? '');
            _callerLongitude = double.tryParse(callData['citizenLongitude']?.toString() ?? '');
          });
        }
      }
      
      // If not found in call data, try user profile
      if (_callerLatitude == null || _callerLongitude == null) {
        final userSnapshot = await db.child('users/${widget.name}').get();
        if (userSnapshot.exists) {
          final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
          if (mounted) {
            setState(() {
              _callerLatitude = double.tryParse(userData['latitude']?.toString() ?? '');
              _callerLongitude = double.tryParse(userData['longitude']?.toString() ?? '');
            });
          }
        }
      }
    } catch (e) {
      print('Error loading caller location: $e');
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _engine.leaveChannel(); // Leave Agora channel
    _engine.release();      // Release Agora engine
    super.dispose();
  }

  // Toggle mute/unmute
  void _onToggleMute() {
    _toggleMute(); // Use the async version
  }

  void _onSpeaker()
  {
    _toggleSpeaker();
  }

  // End call and leave channel
  void _onEndCall() {
    _endCall(); // Use the async version
  }

  String get formattedDuration {
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
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
            colors:[
              Color.fromARGB(255, 95, 98, 255), // purple-ish
              Color.fromARGB(255, 255, 83, 86), // red-ish
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Profile photo
              CircleAvatar(
                radius: 48,
                backgroundImage: NetworkImage(widget.photoUrl),
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                widget.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 8),
              // Emergency Caller label
              const Text(
                'Emergency Caller',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              // Call timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    formattedDuration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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
                            _goToMapScreen();
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
                          color: Colors.redAccent,
                          onTap: _onEndCall, // Wire to end call
                        ),
                      ],
                    ),
                    
                  ],
                ),
              ),
              
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
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: backgroundColor ?? Colors.white, // <--- USE THE backgroundColor HERE
            child: Icon(
              icon,
              color: color ?? Colors.black87, // <--- Use iconColor
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
} 