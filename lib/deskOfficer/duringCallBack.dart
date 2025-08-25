import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/agora_config.dart';
import 'package:firebase_database/firebase_database.dart';

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
  }

  Future<void> _handlePermissions() async {
    await [Permission.microphone].request();
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      debugPrint("Microphone permission denied for desk officer.");
    }
  }

  Future<void> _initAgora() async {
    final String channelName = widget.callId; // Use callId for unique channel
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
          debugPrint("Agora: Local user  {connection.localUid} joined channel: $channelName");
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
    debugPrint("Microphone  {_muted ? 'muted' : 'unmuted'}");
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
                          onTap: () {},
                        ),
                        _ActionButton(
                          icon: Icons.location_on,
                          label: 'Location',
                          color: const Color.fromARGB(255, 85, 85, 85),
                          onTap: () {},
                        ),
                        _ActionButton(
                          icon: Icons.message,
                          label: 'Message',
                          color: const Color.fromARGB(255, 85, 85, 85),
                          onTap: () {},
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