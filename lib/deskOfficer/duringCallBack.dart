import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/agora_config.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:emergency/screens/officer_map_screen.dart';
import '../models/station.dart';

class DuringCallBackPage extends StatefulWidget {
  final String name;
  final String photoUrl;
  final DateTime callStartTime;
  final String callId;
  final String station;

  const DuringCallBackPage({
    Key? key,
    required this.name,
    required this.photoUrl,
    required this.callStartTime,
    required this.callId,
    required this.station,
  }) : super(key: key);

  @override
  State<DuringCallBackPage> createState() => _DuringCallBackPageState();
}

class _DuringCallBackPageState extends State<DuringCallBackPage> {
  late Timer _timer;
  late Duration _elapsed;
  late RtcEngine _engine;
  bool _joined = false;
  bool _muted = false;
  bool _speakerEnabled = false;

  List<Station> _stations = [];
  double? _callerLatitude;
  double? _callerLongitude;

  Map<String, dynamic>? _callerData;
  String _callerGender = 'Not provided';
  String _callerMobile = 'Not provided';
  String _callerAddress = 'Not provided';
  String _callerBirthdate = 'Not provided';
  String _callerDisabilityStatus = 'Not provided';
  String _callerMedicalConditions = 'Not provided';

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.callStartTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.callStartTime);
      });
    });
    _handlePermissions().then((_) {
      _initAgora();
    });
    _initStations();
    _loadCallerProfile();
  }

  Future<void> _handlePermissions() async {
    await [Permission.microphone].request();
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      debugPrint("Microphone permission denied for desk officer.");
    }
  }

  Future<void> _initAgora() async {
    // Use centralized channel name to match the citizen app
    final String channelName = AgoraConfig.getChannelName(isTesting: true);
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      debugPrint("Agora initialization skipped: Microphone permission not granted.");
      return;
    }
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: AgoraConfig.appId));
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Agora: Local user ${connection.localUid} joined channel: $channelName");
          setState(() {
            _joined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Agora: Remote user $remoteUid joined the channel $channelName");
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("Agora: Remote user $remoteUid left the channel $channelName, reason: $reason");
          _endCall();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint("Agora: Local user left channel $channelName");
          setState(() {
            _joined = false;
          });
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("Agora Error: $err, $msg");
        },
      ),
    );
    await _engine.enableAudio();
    await _engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioGameStreaming,
    );
    await _engine.setDefaultAudioRouteToSpeakerphone(true);
    await _engine.enableAudioVolumeIndication(
      interval: 200,
      smooth: 3,
      reportVad: true,
    );
    await _engine.joinChannel(
      token: AgoraConfig.getToken(isTesting: true),
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ),
    );
    debugPrint("Attempted to join channel: $channelName for voice-only testing.");
  }

  Future<void> _toggleMute() async {
    await _engine.muteLocalAudioStream(!_muted);
    setState(() {
      _muted = !_muted;
    });
    debugPrint("Microphone ${_muted ? 'muted' : 'unmuted'}");
  }

  Future<void> _toggleSpeaker() async {
    setState(() {
      _speakerEnabled = !_speakerEnabled;
    });
    await _engine.setEnableSpeakerphone(_speakerEnabled);
    debugPrint("Speakerphone toggled to: $_speakerEnabled");
  }

  Future<void> _endCall() async {
    _timer.cancel();
    await _engine.leaveChannel();
    await _engine.release();
    
    // Update call logs when call ends
    final dbRef = FirebaseDatabase.instance.ref();
    final callId = widget.callId;
    final citizenName = widget.name;

    final updates = {
      'status': 'ended',
      'endedAt': ServerValue.timestamp,
    };

    // Update all relevant logs
    await dbRef.child('UsersCallLogs/AnsweredCalls/$callId').update(updates);
    await dbRef.child('StationsCallLogs/AnsweredCalls/$callId').update(updates);
    await dbRef.child('users/$citizenName/ReceivedCalls/AnsweredCalls/$callId').update(updates);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _initStations() async {
    try {
      final db = FirebaseDatabase.instance.ref();
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
      await _loadCallerLocation();
    } catch (e) {
      debugPrint('Error loading stations: $e');
    }
  }

  Future<void> _loadCallerLocation() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      final callId = widget.callId;
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
      debugPrint('Error loading caller location: $e');
    }
  }

  Future<void> _loadCallerProfile() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      final callId = widget.callId;
      final callSnapshot = await db.child('StationsCallLogs/AnsweredCalls/$callId').get();
      if (callSnapshot.exists) {
        final callData = Map<String, dynamic>.from(callSnapshot.value as Map);
        final callerName = callData['name'] ?? widget.name;
        final userSnapshot = await db.child('users/$callerName').get();
        if (userSnapshot.exists) {
          final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
          if (mounted) {
            setState(() {
              _callerData = userData;
              _callerGender = userData['gender'] ?? 'Not provided';
              _callerMobile = userData['mobile'] ?? callData['mobile'] ?? 'Not provided';
              _callerAddress = _buildFullAddress(userData);
              _callerBirthdate = userData['birthdate'] ?? 'Not provided';
              _callerDisabilityStatus = userData['disabilityStatus'] ?? 'Not provided';
              _callerMedicalConditions = userData['medicalConditions'] ?? 'Not provided';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading caller profile: $e');
    }
  }

  String _buildFullAddress(Map<String, dynamic> userData) {
    List<String> addressParts = [];
    if (userData['streetAddress'] != null && userData['streetAddress'].toString().isNotEmpty) {
      addressParts.add(userData['streetAddress'].toString());
    }
    if (userData['city'] != null && userData['city'].toString().isNotEmpty) {
      addressParts.add(userData['city'].toString());
    }
    if (userData['region'] != null && userData['region'].toString().isNotEmpty) {
      addressParts.add(userData['region'].toString());
    }
    return addressParts.isNotEmpty ? addressParts.join(', ') : 'Not provided';
  }

  void _showViewProfile() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      const Text(
                        'Caller Profile',
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: NetworkImage(widget.photoUrl),
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _SectionHeader(title: 'Personal Information', icon: Icons.person),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoCard(
                                label: 'Gender',
                                value: _callerGender,
                                icon: Icons.person_outline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoCard(
                                label: 'Contact Number',
                                value: _callerMobile,
                                icon: Icons.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          label: 'Address',
                          value: _callerAddress,
                          icon: Icons.location_on,
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          label: 'Birthdate',
                          value: _callerBirthdate,
                          icon: Icons.cake,
                        ),
                        const SizedBox(height: 24),
                        const _SectionHeader(title: 'Medical Information', icon: Icons.medical_services),
                        const SizedBox(height: 12),
                        _InfoCard(
                          label: 'Disability Status',
                          value: _callerDisabilityStatus,
                          icon: Icons.accessibility,
                          labelColor: Colors.red,
                          backgroundColor: const Color(0xFFFFE5E5),
                          borderColor: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          label: 'Medical Conditions',
                          value: _callerMedicalConditions,
                          icon: Icons.healing,
                          labelColor: Colors.orange,
                          backgroundColor: const Color(0xFFFFF3E0),
                          borderColor: Colors.orange,
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

  void _goToMapScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallMapScreen(
          stations: _stations,
          callerLatitude: _callerLatitude,
          callerLongitude: _callerLongitude,
          callerName: widget.name,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  String get formattedDuration {
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onToggleMute() {
    _toggleMute();
  }

  void _onSpeaker() {
    _toggleSpeaker();
  }

  void _onEndCall() {
    _endCall();
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
              Color.fromARGB(255, 95, 98, 255),
              Color.fromARGB(255, 255, 83, 86),
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
                          onTap: _showViewProfile,
                        ),
                        _ActionButton(
                          icon: Icons.location_on,
                          label: 'Location',
                          color: const Color.fromARGB(255, 85, 85, 85),
                          onTap: _goToMapScreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: _muted ? Icons.mic_off : Icons.mic,
                          label: 'Mic',
                          color: _muted ? const Color.fromARGB(255, 88, 99, 255) : const Color.fromARGB(255, 85, 85, 85),
                          onTap: _onToggleMute,
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
                          onTap: _onEndCall,
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
            backgroundColor: backgroundColor ?? Colors.white,
            child: Icon(
              icon,
              color: color ?? Colors.black87,
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
