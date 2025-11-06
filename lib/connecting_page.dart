import 'package:flutter/material.dart';
import 'emergencyCall.dart'; // Use EmergencyCallScreen for citizen in-call UI
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class ConnectingPage extends StatefulWidget
{
    final String username;
    final String callId; // Add callId parameter
    final String? station; // Add station parameter
    final double? distance; // Optional: distance to station in km
    final double? duration; // Optional: estimated duration in minutes


    const ConnectingPage({
      Key? key, 
      required this.username, 
      required this.callId, 
      this.station,
      this.distance,
      this.duration,
    }) : super(key: key);

    @override
    _ConnectingPageState createState() => _ConnectingPageState();
}

class _ConnectingPageState extends State<ConnectingPage>
{
    // This would be a stream or callback from your backend or push notification
    // For demo, we'll use a Future.delayed to simulate the desk officer answering
    StreamSubscription? _callSub; // For listening to call status
    Timer? _timeoutTimer; // Timer for call timeout
    Timer? _vibrationTimer; // Subtle haptic feedback while connecting

    @override
    void initState()
    {
        super.initState();
        
        if (widget.station != null) {
          // Set up timeout timer (30 seconds)
          _timeoutTimer = Timer(const Duration(seconds: 60), () {
            _cancelCallDueToTimeout();
          });
          // Start subtle vibration pulses while connecting (every 3 seconds)
          _startVibrationPulse();

          // Listen for call status changes
          final db = FirebaseDatabase.instance.ref();
          _callSub = db.child('StationsCallLogs/ActiveCalls/${widget.callId}').onValue.listen((event) {
            if (event.snapshot.value != null) {
              final callData = event.snapshot.value as Map;
              if (callData['status'] == 'answered') {
                _timeoutTimer?.cancel();
                _stopVibrationPulse();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmergencyCallScreen(
                        officerName: callData['officer'] ?? 'Desk Officer',
                        avatarAsset: 'assets/avatar.png',
                        callId: widget.callId,
                        station: widget.station!,
                      ),
                    ),
                  );
                }
              } else if (callData['status'] == 'declined' || callData['status'] == 'cancelled') {
                _timeoutTimer?.cancel();
                _stopVibrationPulse();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Call was ${callData['status']}.')),
                  );
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                }
              }
            }
          });
        }
    }

    // Method to cancel call due to timeout
    void _cancelCallDueToTimeout() async {
      if (widget.station == null) return;
      try {
        final db = FirebaseDatabase.instance.ref();
        final callId = widget.callId;
        final stationName = widget.station!;

        final callSnapshot = await db.child('StationsCallLogs/ActiveCalls/$callId').get();
        if (callSnapshot.exists) {
          final callData = callSnapshot.value as Map;
          final updatedCallData = {...callData, 'status': 'timeout', 'timeoutAt': ServerValue.timestamp};
          await db.child('StationsCallLogs/MissedCalls/$callId').set(updatedCallData);
          await db.child('StationsCallLogs/ActiveCalls/$callId').remove();
          await db.child('Desk Officer/$stationName/ReceivedCalls/MissedCalls/$callId').set(updatedCallData);
          await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').remove();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call timed out. No desk officer available.'),
              backgroundColor: Colors.red,
            ),
          );
          _stopVibrationPulse();
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error handling timeout: $e');
      }
    }

    @override
    void dispose() {
      _callSub?.cancel(); // Clean up listener
      _timeoutTimer?.cancel(); // Cancel timeout timer
      _stopVibrationPulse();
      super.dispose();
    }

    void _startVibrationPulse() {
      // Use subtle vibration every 3 seconds while connecting
      _vibrationTimer?.cancel();
      _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final canVibrate = await Vibration.hasVibrator() ?? false;
          if (canVibrate) {
            // Short vibration, moderate intensity (duration ms, amplitude 1-255 Android only)
            await Vibration.vibrate(duration: 120, amplitude: 120);
          } else {
            // Fallback to light haptic if available
            await HapticFeedback.lightImpact();
          }
        } catch (_) {
          // Ignore if device/emulator doesn't support haptics
        }
      });
    }

    void _stopVibrationPulse() {
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      // Best-effort cancel any ongoing vibration
      try { Vibration.cancel(); } catch (_) {}
    }

    String _buildDistanceInfo() {
      List<String> parts = [];
      
      if (widget.distance != null) {
        if (widget.distance! < 1.0) {
          parts.add('${(widget.distance! * 1000).toStringAsFixed(0)} m away');
        } else {
          parts.add('${widget.distance!.toStringAsFixed(2)} km away');
        }
      }
      
      return parts.join(' • ');
    }
    
    @override
    Widget build(BuildContext context)
    {
        
        return Scaffold
        (
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromARGB(255, 255, 51, 48),
                    Color.fromARGB(255, 250, 107, 104),
                    Color.fromARGB(255, 255, 255, 255),
                  ],
                  stops: [0.3, 0.6, 0.9],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Spacer(flex: 1),
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.person, size: 70, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.username,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 255, 255, 255)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.station != null 
                        ? 'Connecting to ${widget.station}...' 
                        : 'Please try again later...',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // Show distance and duration if available
                    if (widget.distance != null || widget.duration != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _buildDistanceInfo(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const Spacer(flex: 2),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 60.0),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (widget.station == null) {
                            Navigator.pop(context);
                            return;
                          }

                          try {
                            final db = FirebaseDatabase.instance.ref();
                            final callId = widget.callId;
                            final stationName = widget.station!;

                            final callSnapshot = await db.child('StationsCallLogs/ActiveCalls/$callId').get();
                            if (callSnapshot.exists) {
                              final callData = callSnapshot.value as Map;
                              final updatedCallData = {...callData, 'status': 'cancelled', 'cancelledBy': 'citizen', 'cancelledAt': ServerValue.timestamp};
                              await db.child('StationsCallLogs/MissedCalls/$callId').set(updatedCallData);
                              await db.child('StationsCallLogs/ActiveCalls/$callId').remove();
                              await db.child('Desk Officer/$stationName/ReceivedCalls/MissedCalls/$callId').set(updatedCallData);
                              await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').remove();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Call cancelled successfully')),
                              );
                              if (Navigator.canPop(context)) Navigator.pop(context);
                            }
                          } catch (e) {
                            debugPrint('Error cancelling call: $e');
                          }
                        },
                        icon: const Icon(Icons.call_end, size: 28,),
                        label: const Text('Cancel Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40.0),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );

    }




}
