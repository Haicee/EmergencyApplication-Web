import 'package:flutter/material.dart';
import 'emergencyCall.dart'; // Use EmergencyCallScreen for citizen in-call UI
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class ConnectingPage extends StatefulWidget
{
    final String username;
    final String callId; // Add callId parameter
    final String station; // Add station parameter


    const ConnectingPage({Key? key, required this.username, required this.callId, required this.station}) : super(key: key);

    @override
    _ConnectingPageState createState() => _ConnectingPageState();
}

class _ConnectingPageState extends State<ConnectingPage>
{
    // This would be a stream or callback from your backend or push notification
    // For demo, we'll use a Future.delayed to simulate the desk officer answering
    late StreamSubscription _callSub; // For listening to call status
    Timer? _timeoutTimer; // Timer for call timeout

    @override
    void initState()
    {
        super.initState();
        
        // Set up timeout timer (30 seconds)
        _timeoutTimer = Timer(Duration(seconds: 30), () {
          _cancelCallDueToTimeout();
        });
        
        // Listen for call status changes
        final db = FirebaseDatabase.instance.ref();
        _callSub = db.child('StationsCallLogs/ActiveCalls/${widget.callId}').onValue.listen((event) {
          if (event.snapshot.value != null) {
            final callData = event.snapshot.value as Map;
            if (callData['status'] == 'answered') {
              // Cancel timeout timer since call was answered
              _timeoutTimer?.cancel();
              // Call answered: navigate to EmergencyCallScreen
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyCallScreen(
                      officerName: callData['officer'] ?? 'Desk Officer',
                      avatarAsset: 'assets/avatar.png', // TODO: Use real avatar if available
                      callId: widget.callId,
                      station: widget.station,
                    ),
                  ),
                );
              }
            } else if (callData['status'] == 'declined') {
              // Cancel timeout timer since call was declined
              _timeoutTimer?.cancel();
              // Call declined: show message and pop
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Call was declined by the desk officer.')),
                );
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            } else if (callData['status'] == 'cancelled') {
              // Cancel timeout timer since call was cancelled
              _timeoutTimer?.cancel();
              // Call cancelled: show message and pop
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Call was cancelled.')),
                );
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            }
          }
        });
    }

    // Method to cancel call due to timeout
    void _cancelCallDueToTimeout() async {
      try {
        final db = FirebaseDatabase.instance.ref();
        final callId = widget.callId;
        final stationName = widget.station;
        
        // Update call status to timeout in both locations
        await db.child('StationsCallLogs/ActiveCalls/$callId').update({
          'status': 'timeout',
          'timeoutAt': ServerValue.timestamp,
        });
        
        await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').update({
          'status': 'timeout',
          'timeoutAt': ServerValue.timestamp,
        });
        
        // Move call to MissedCalls in both locations
        final callSnapshot = await db.child('StationsCallLogs/ActiveCalls/$callId').get();
        if (callSnapshot.exists) {
          final callData = callSnapshot.value as Map;
          await db.child('StationsCallLogs/MissedCalls/$callId').set(callData);
          await db.child('StationsCallLogs/ActiveCalls/$callId').remove();
        }
        
        final stationCallSnapshot = await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').get();
        if (stationCallSnapshot.exists) {
          final stationCallData = stationCallSnapshot.value as Map;
          await db.child('Desk Officer/$stationName/ReceivedCalls/MissedCalls/$callId').set(stationCallData);
          await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').remove();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call timed out. No desk officer available.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        debugPrint('Error handling timeout: $e');
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    }

    @override
    void dispose() {
      _callSub.cancel(); // Clean up listener
      _timeoutTimer?.cancel(); // Cancel timeout timer
      super.dispose();
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
                      'Connecting...',
                      style: TextStyle(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(flex: 2),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 60.0),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Cancel the call in Firebase
                          try {
                            debugPrint('Citizen cancelling call: ${widget.callId}');
                            final db = FirebaseDatabase.instance.ref();
                            final callId = widget.callId;
                            final stationName = widget.station;
                            
                            // Update call status to cancelled in both locations
                            await db.child('StationsCallLogs/ActiveCalls/$callId').update({
                              'status': 'cancelled',
                              'cancelledBy': 'citizen',
                              'cancelledAt': ServerValue.timestamp,
                            });
                            
                            await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').update({
                              'status': 'cancelled',
                              'cancelledBy': 'citizen',
                              'cancelledAt': ServerValue.timestamp,
                            });
                            
                            // Move call to MissedCalls in both locations
                            final callSnapshot = await db.child('StationsCallLogs/ActiveCalls/$callId').get();
                            if (callSnapshot.exists) {
                              final callData = callSnapshot.value as Map;
                              await db.child('StationsCallLogs/MissedCalls/$callId').set(callData);
                              await db.child('StationsCallLogs/ActiveCalls/$callId').remove();
                            }
                            
                            final stationCallSnapshot = await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').get();
                            if (stationCallSnapshot.exists) {
                              final stationCallData = stationCallSnapshot.value as Map;
                              await db.child('Desk Officer/$stationName/ReceivedCalls/MissedCalls/$callId').set(stationCallData);
                              await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').remove();
                            }
                            
                            debugPrint('Call cancelled successfully');
                            // Show confirmation message
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Call cancelled successfully'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                            
                            // Navigate back to homepage safely
                            if (mounted && Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            debugPrint('Error cancelling call: $e');
                            // Show error message
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to cancel call. Please try again.'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                            // Still try to navigate back even if Firebase update fails
                            if (mounted && Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
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
