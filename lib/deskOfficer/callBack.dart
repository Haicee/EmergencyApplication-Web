import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'duringCallBack.dart';
import 'dart:async'; // Added for StreamSubscription
import 'dart:async'; // Added for Timer
import 'package:emergency/services/ringtone_service.dart';

class OfficerCallBackPage extends StatefulWidget {
  final String citizenName;
  final String station;
  final String callId;
  final String photoUrl;
  final String mobile;
  final String address;
  final String? officerId; // Add officer ID

  const OfficerCallBackPage({
    Key? key,
    required this.citizenName,
    required this.station,
    required this.callId,
    required this.photoUrl,
    required this.mobile,
    required this.address,
    this.officerId, // Add officer ID parameter
  }) : super(key: key);

  @override
  State<OfficerCallBackPage> createState() => _OfficerCallBackPageState();
}

class _OfficerCallBackPageState extends State<OfficerCallBackPage> {
  bool _isCalling = false;
  String _generatedCallId = '';
  StreamSubscription? _callResponseSubscription;
  Timer? _timeoutTimer; // Add timeout timer
  Timer? _countdownTimer; // Add countdown timer
  int _remainingSeconds = 30; // Countdown seconds

  @override
  void initState() {
    super.initState();
    _generatedCallId = DateTime.now().millisecondsSinceEpoch.toString();
    _startCallbackSignaling();
    _listenForCitizenResponse();
    _startTimeoutTimer(); // Start the timeout timer
    _startCountdownTimer(); // Start the countdown timer
    // Start outgoing ringback tone
    RingtoneService.playOutgoing();
  }

  @override
  void dispose() {
    _callResponseSubscription?.cancel();
    _timeoutTimer?.cancel(); // Cancel timeout timer
    _countdownTimer?.cancel(); // Cancel countdown timer
    // Ensure ringtone stops when leaving this page
    RingtoneService.stop();
    super.dispose();
  }

  Future<void> _startCallbackSignaling() async {
    setState(() {
      _isCalling = true;
    });

    try {
      final db = FirebaseDatabase.instance.ref();
      
      // Fetch station information from Firebase
      final stationSnapshot = await db.child('Desk Officer/${widget.station}').get();
      String stationCity = 'City Not Provided';
      String stationRegion = 'Region Not Provided';
      String stationHotline = 'No hotline';
      String stationAddress = 'No address';
      String stationLatitude = '0.0';
      String stationLongitude = '0.0';
      String stationRadius = '500.0';
      
      if (stationSnapshot.exists) {
        final stationData = Map<String, dynamic>.from(stationSnapshot.value as Map);
        stationCity = (stationData['city'] ?? 'Unknown City').toString();
        stationRegion = (stationData['region'] ?? 'Unknown Region').toString();
        stationHotline = (stationData['hotline'] ?? 'No hotline').toString();
        stationAddress = (stationData['streetAddress'] ?? 'No address').toString();
        stationLatitude = (stationData['latitude'] ?? '0.0').toString();
        stationLongitude = (stationData['longitude'] ?? '0.0').toString();
        stationRadius = (stationData['radius'] ?? '500.0').toString();
      }
      
      // Create call data for the citizen with actual station information
      final callData = {
        'callId': _generatedCallId,
        'city': stationCity,
        'region': stationRegion,
        'station': widget.station,
        'officer': widget.officerId, // Desk officer ID
        'photoURL': '', // Officer/station photo
        'status': 'ringing',
        'streetAddress': stationAddress,
        'hotline': stationHotline, // Add hotline to call data
        'latitude': stationLatitude, // Station latitude
        'longitude': stationLongitude, // Station longitude
        'radius': stationRadius, // Station radius
        'timestamp': ServerValue.timestamp,
        'citizenName': widget.citizenName,
        'citizenPhotoURL': widget.photoUrl,
        'citizenMobile': widget.mobile,
      };

      // Write to citizen's call log for incoming call detection
      await db.child('users/${widget.citizenName}/ReceivedCalls/ActiveCalls/$_generatedCallId').set(callData);
      
      // Also write to global call logs
      await db.child('UsersCallLogs/ActiveCalls/$_generatedCallId').set(callData);

      debugPrint('Call initiated to citizen: ${widget.citizenName} with callId: $_generatedCallId');
      debugPrint('Station info: $stationCity, $stationRegion, $stationHotline, $stationAddress');
      
    } catch (e) {
      debugPrint('Error initiating call: $e');
      setState(() {
        _isCalling = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _listenForCitizenResponse() {
    final db = FirebaseDatabase.instance.ref();
    _callResponseSubscription = db.child('users/${widget.citizenName}/ReceivedCalls/ActiveCalls/$_generatedCallId')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null) {
        // Call was moved to AnsweredCalls or MissedCalls
        return;
      }
      
      final callData = event.snapshot.value as Map;
      final status = callData['status'];
      
      debugPrint('Citizen response received: $status');
      
      if (status == 'answered') {
        // Cancel timeout timer since citizen answered
        _timeoutTimer?.cancel();
        _countdownTimer?.cancel(); // Cancel countdown timer
        _isCalling = false;
        // Stop outgoing ringtone
        RingtoneService.stop();
        
        // Citizen answered the call
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DuringCallBackPage(
                name: widget.citizenName,
                photoUrl: widget.photoUrl,
                callStartTime: DateTime.now(),
                callId: _generatedCallId,
                station: widget.station,
              ),
            ),
          );
        }
      } else if (status == 'declined') {
        // Cancel timeout timer since citizen declined
        _timeoutTimer?.cancel();
        _countdownTimer?.cancel(); // Cancel countdown timer
        _isCalling = false;
        // Stop outgoing ringtone
        RingtoneService.stop();
        
        // Citizen declined the call
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call declined by ${widget.citizenName}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  Future<void> _cancelCall() async {
    try {
      // Cancel timeout timer since we're manually cancelling
      _timeoutTimer?.cancel();
      _countdownTimer?.cancel(); // Cancel countdown timer
      _isCalling = false;
      // Stop outgoing ringtone
      RingtoneService.stop();
      
      final db = FirebaseDatabase.instance.ref();
      
      // Update call status to cancelled in citizen's call log
      await db.child('users/${widget.citizenName}/ReceivedCalls/ActiveCalls/$_generatedCallId').update({
        'status': 'cancelled',
        'cancelledBy': 'officer',
        'cancelledAt': ServerValue.timestamp,
      });

      // Also update in global call log
      await db.child('UsersCallLogs/ActiveCalls/$_generatedCallId').update({
        'status': 'cancelled',
        'cancelledBy': 'officer',
        'cancelledAt': ServerValue.timestamp,
      });

      // Move to MissedCalls in citizen's call log
      final callSnap = await db.child('users/${widget.citizenName}/ReceivedCalls/ActiveCalls/$_generatedCallId').get();
      if (callSnap.exists) {
        final callData = callSnap.value as Map;
        await db.child('users/${widget.citizenName}/ReceivedCalls/MissedCalls/$_generatedCallId').set(callData);
        await db.child('users/${widget.citizenName}/ReceivedCalls/ActiveCalls/$_generatedCallId').remove();
      }

      // Move to MissedCalls in global call log
      final globalCallSnap = await db.child('UsersCallLogs/ActiveCalls/$_generatedCallId').get();
      if (globalCallSnap.exists) {
        final globalCallData = globalCallSnap.value as Map;
        await db.child('UsersCallLogs/MissedCalls/$_generatedCallId').set(globalCallData);
        await db.child('UsersCallLogs/ActiveCalls/$_generatedCallId').remove();
      }

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling call: $e');
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(Duration(seconds: 30), () async {
      debugPrint('Call timeout reached for callId: $_generatedCallId');
      
      // Only handle timeout if we're still on this page and the call hasn't been answered/declined
      if (mounted && _isCalling) {
        await _handleTimeout();
      }
    });
  }

  Future<void> _handleTimeout() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      // Stop outgoing ringtone on timeout
      RingtoneService.stop();
      
      // Update call status to timeout in citizen's call log
      await db.child('users/${widget.citizenName}/ReceivedCalls/ActiveCalls/$_generatedCallId').update({
        'status': 'timeout',
        'timeoutAt': ServerValue.timestamp,
      });

      // Also update in global call log
      await db.child('UsersCallLogs/ActiveCalls/$_generatedCallId').update({
        'status': 'timeout',
        'timeoutAt': ServerValue.timestamp,
      });

      // Move to MissedCalls in citizen's call log
      final callSnap = await db.child('users/${widget.citizenName}/ReceivedCalls/ActiveCalls/$_generatedCallId').get();
      if (callSnap.exists) {
        final callData = callSnap.value as Map;
        await db.child('users/${widget.citizenName}/ReceivedCalls/MissedCalls/$_generatedCallId').set(callData);
        await db.child('users/${widget.citizenName}/ReceivedCalls/ActiveCalls/$_generatedCallId').remove();
      }

      // Move to MissedCalls in global call log
      final globalCallSnap = await db.child('UsersCallLogs/ActiveCalls/$_generatedCallId').get();
      if (globalCallSnap.exists) {
        final globalCallData = globalCallSnap.value as Map;
        await db.child('UsersCallLogs/MissedCalls/$_generatedCallId').set(globalCallData);
        await db.child('UsersCallLogs/ActiveCalls/$_generatedCallId').remove();
      }

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call timed out - no response from ${widget.citizenName}'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling timeout: $e');
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && _isCalling && _remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String safeName = widget.citizenName;
    final String safeMobile = widget.mobile;
    final String safeAddress = widget.address;
    final String safePhoto = widget.photoUrl;
    final bool hasNetworkPhoto = safePhoto.isNotEmpty &&
        (safePhoto.startsWith('http://') || safePhoto.startsWith('https://'));
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3E45CD),
              Color(0xFFFF6767),
              Colors.white,
            ],
            stops: [0.25, 0.55, 0.9],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Text(
                      'Calling Citizen',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.station,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Citizen avatar and name
              CircleAvatar(
                radius: 56,
                backgroundColor: Colors.white,
                backgroundImage: hasNetworkPhoto ? NetworkImage(safePhoto) : null,
                child: hasNetworkPhoto ? null : const Icon(Icons.person, size: 56, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text(
                safeName.isNotEmpty ? safeName : 'Unknown Citizen',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 60),
              // Progress
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              const SizedBox(height: 12),
              Text(
                _isCalling ? 'Calling...' : 'Call initiated',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)
              ),
              const SizedBox(height: 8),
               

              const Spacer(),
              // Testing buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    
                    SizedBox(height: 16),
                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _cancelCall,
                        icon: const Icon(Icons.call_end, color: Colors.white),
                        label: const Text('Cancel Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
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
