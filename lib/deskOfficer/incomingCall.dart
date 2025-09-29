import 'package:flutter/material.dart';
import 'duringCall.dart'; // Import the in-call page
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:emergency/services/ringtone_service.dart';


class IncomingCallPage extends StatefulWidget {
  final String name;
  final String photoUrl;
  final String gender;
  final String mobile;
  final String address;
  final String disabilityStatus;
  final String medicalConditions;
  final String callId; // Added callId parameter
  final String station; // Add station parameter
  final String officerId; // Add officerId parameter

  const IncomingCallPage({
    Key? key,
    required this.name,
    required this.photoUrl,
    required this.gender,
    required this.mobile,
    required this.address,
    required this.disabilityStatus,
    required this.medicalConditions,
    required this.callId, // Initialize callId
    required this.station, // Initialize station
    required this.officerId,
  }) : super(key: key);

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  Map<String, dynamic>? userData;
  String fullAddress = '';
  String contactNumber = '';
  String pwdCondition = '';
  String medicalCondition = '';
  bool isLoading = false; // Set to false since we have data from the call
  late StreamSubscription _callStatusSubscription; // Listen for call status changes

  @override
  void initState() {
    super.initState();
    _processCallData();
    _listenForCallStatusChanges();
    // Start incoming ringtone when this page shows
    RingtoneService.playIncoming();
  }

  void _processCallData() {
    // Use the data passed from the emergency call
    setState(() {
      fullAddress = widget.address;
      contactNumber = widget.mobile;
      pwdCondition = widget.disabilityStatus;
      medicalCondition = widget.medicalConditions;
      isLoading = false;
    });
  }

  void _listenForCallStatusChanges() {
    // Listen for changes to the call status in both locations
    final db = FirebaseDatabase.instance.ref();
    debugPrint('Setting up listener for call: ${widget.callId} in station: ${widget.station}');
    
    // Listen to All Calls first (primary source)
    _callStatusSubscription = db.child('StationsCallLogs/ActiveCalls/${widget.callId}').onValue.listen((event) {
      debugPrint('Call status update received for ${widget.callId}: ${event.snapshot.value}');
      
      if (event.snapshot.value == null) {
        // Call was moved to MissedCalls or removed
        debugPrint('Call ${widget.callId} was moved to MissedCalls or removed');
        if (mounted && Navigator.canPop(context)) {
          // Stop ringtone on removal
          RingtoneService.stop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call was cancelled by ${widget.name}'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      final callData = event.snapshot.value as Map;
      final status = callData['status'];
      debugPrint('Call ${widget.callId} status: $status');
      
      if (status == 'cancelled') {
        debugPrint('Call ${widget.callId} was cancelled by citizen');
        // Call was cancelled by citizen, close this page
        if (mounted && Navigator.canPop(context)) {
          // Stop ringtone on cancel
          RingtoneService.stop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call was cancelled by ${widget.name}'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } else if (status == 'timeout') {
        debugPrint('Call ${widget.callId} timed out');
        // Call timed out, close this page
        if (mounted && Navigator.canPop(context)) {
          // Stop ringtone on timeout
          RingtoneService.stop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call timed out'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _callStatusSubscription.cancel(); // Clean up the listener
    // Ensure ringtone stops when leaving this page
    RingtoneService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IncomingCallPage is shown when a call is incoming to the desk officer.
    // When "Answer" is tapped, join the Agora channel and navigate to DuringCallPage.
    // When "Decline" is tapped, dismiss this page and notify the caller.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3E45CD), Color(0xFFFF6767)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
              // Incoming Emergency Call status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '• Incoming Emergency Call',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Enhanced Info cards with comprehensive caller information
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Personal Information Section
                      _SectionHeader(title: 'Personal Information', icon: Icons.person),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              label: 'Gender',
                              value: widget.gender,
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              label: 'Contact Number',
                              value: contactNumber,
                              icon: Icons.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        label: 'Address',
                        value: fullAddress,
                        icon: Icons.location_on,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Medical Information Section
                      _SectionHeader(title: 'Medical Information', icon: Icons.medical_services),
                      const SizedBox(height: 12),
                      _InfoCard(
                        label: 'Disability Status',
                        value: pwdCondition,
                        icon: Icons.accessibility,
                        labelColor: Colors.red,
                        backgroundColor: Color(0xFFFFE5E5),
                        borderColor: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        label: 'Medical Conditions',
                        value: medicalCondition,
                        icon: Icons.healing,
                        labelColor: Colors.orange,
                        backgroundColor: Color(0xFFFFF3E0),
                        borderColor: Colors.orange,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      
                    ],
                  ),
                ),
              ),
                  // Answer/Decline buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Answer
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              // Cancel the call status listener to prevent wrong notifications
                              _callStatusSubscription.cancel();
                              // Stop incoming ringtone on answer
                              await RingtoneService.stop();
                              
                              // On answer: update call status to 'answered', set officer, and navigate to DuringCallPage
                              final db = FirebaseDatabase.instance.ref();
                              final callId = widget.callId;
                              final stationName = widget.station;
                              
                              try {
                                // Update call status in both locations
                                await db.child('StationsCallLogs/ActiveCalls/$callId').update({
                                  'status': 'answered',
                                  'officer': widget.officerId, // Set answering officer's username
                                  'answeredAt': ServerValue.timestamp,
                                });
                                
                                await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').update({
                                  'status': 'answered',
                                  'officer': widget.officerId,
                                  'answeredAt': ServerValue.timestamp,
                                });
                                
                                // Move call to AnsweredCalls in both locations
                                final callSnapshot = await db.child('StationsCallLogs/ActiveCalls/$callId').get();
                                if (callSnapshot.exists) {
                                  final callData = Map<String, dynamic>.from(callSnapshot.value as Map);
                                  // Ensure location data is preserved as strings
                                  if (callData['citizenLatitude'] != null) {
                                    callData['citizenLatitude'] = callData['citizenLatitude'].toString();
                                  }
                                  if (callData['citizenLongitude'] != null) {
                                    callData['citizenLongitude'] = callData['citizenLongitude'].toString();
                                  }
                                  await db.child('StationsCallLogs/AnsweredCalls/$callId').set(callData);
                                  await db.child('StationsCallLogs/ActiveCalls/$callId').remove();
                                }
                                
                                final stationCallSnapshot = await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').get();
                                if (stationCallSnapshot.exists) {
                                  final stationCallData = Map<String, dynamic>.from(stationCallSnapshot.value as Map);
                                  // Ensure location data is preserved as strings
                                  if (stationCallData['citizenLatitude'] != null) {
                                    stationCallData['citizenLatitude'] = stationCallData['citizenLatitude'].toString();
                                  }
                                  if (stationCallData['citizenLongitude'] != null) {
                                    stationCallData['citizenLongitude'] = stationCallData['citizenLongitude'].toString();
                                  }
                                  await db.child('Desk Officer/$stationName/ReceivedCalls/AnsweredCalls/$callId').set(stationCallData);
                                  await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').remove();
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
                                  userCallData['status'] = 'answered';
                                  userCallData['officer'] = widget.officerId;
                                  userCallData['answeredAt'] = ServerValue.timestamp;
                                  await db.child('UsersCallLogs/AnsweredCalls/$callId').set(userCallData);
                                  await db.child('UsersCallLogs/ActiveCalls/$callId').remove();
                                }
                                
                                // Navigate to DuringCallPage
                                if (mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DuringCallPage(
                                        name: widget.name,
                                        photoUrl: widget.photoUrl,
                                        callStartTime: DateTime.now(),
                                        callId: widget.callId, // Pass callId for Agora
                                        station: widget.station,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error answering call: $e');
                                // Re-enable the listener if there's an error
                                _listenForCallStatusChanges();
                              }
                            },
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color.fromARGB(255, 136, 255, 140),
                                    blurRadius: 40,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call, color: Colors.white, size: 60),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Decline
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              // Cancel the call status listener to prevent wrong notifications
                              _callStatusSubscription.cancel();
                              // Stop incoming ringtone on decline
                              await RingtoneService.stop();
                              
                              // On decline: update call status to 'declined' and move to MissedCalls
                              final db = FirebaseDatabase.instance.ref();
                              final callId = widget.callId;
                              final stationName = widget.station;
                              
                              try {
                                // Update call status in both locations
                                await db.child('StationsCallLogs/ActiveCalls/$callId').update({
                                  'status': 'declined',
                                  'declinedBy': widget.officerId,
                                  'declinedAt': ServerValue.timestamp,
                                });
                                
                                await db.child('Desk Officer/$stationName/ReceivedCalls/ActiveCalls/$callId').update({
                                  'status': 'declined',
                                  'declinedBy': widget.officerId,
                                  'declinedAt': ServerValue.timestamp,
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
                                
                                // Navigate back to homepage
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                debugPrint('Error declining call: $e');
                                // Re-enable the listener if there's an error
                                _listenForCallStatusChanges();
                              }
                            },
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color.fromARGB(255, 243, 74, 62),
                                    blurRadius: 40,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call_end, color: Colors.white, size: 60),
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
            offset: Offset(0, 2),
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