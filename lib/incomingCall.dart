import 'package:flutter/material.dart';
import 'emergencyCallBack.dart';
import 'package:emergency/services/ringtone_service.dart';

/// Citizen-side incoming call dialog UI.
/// Shows an overlay styled similarly to the desk officer's incoming call,
/// but tailored to police station details instead of personal information.
class CitizenIncomingCallDialog extends StatefulWidget {
  final String stationName;
  final String photoUrl;
  final String hotline;
  final String address;
  final String callId; // join to same call/channel
  final String? region; // Add region field

  final VoidCallback? onAnswer;
  final VoidCallback? onDecline;

  const CitizenIncomingCallDialog({
    Key? key,
    required this.stationName,
    required this.photoUrl,
    required this.hotline,
    required this.address,
    required this.callId,
    this.region, // Add region parameter
    this.onAnswer,
    this.onDecline,
  }) : super(key: key);

  @override
  State<CitizenIncomingCallDialog> createState() => _CitizenIncomingCallDialogState();
}

class _CitizenIncomingCallDialogState extends State<CitizenIncomingCallDialog> {
  @override
  void initState() {
    super.initState();
    // Start ringing when dialog appears
    RingtoneService.playIncoming();
  }

  @override
  void dispose() {
    // Ensure ringtone stops when dialog is dismissed
    RingtoneService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          gradient: LinearGradient(
            colors: [Color(0xFF3E45CD), Color(0xFFFF6767)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: NetworkImage(widget.photoUrl),
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.stationName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '• Incoming Emergency Call',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Station Information
                    _SectionHeader(title: 'Station Information', icon: Icons.local_police),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            label: 'Hotline',
                            value: widget.hotline.isNotEmpty ? widget.hotline : 'Not Provided',
                            icon: Icons.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoCard(
                            label: 'Station',
                            value: widget.stationName,
                            icon: Icons.apartment,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      label: 'Address',
                      value: widget.address.isNotEmpty ? widget.address : 'No address provided',
                      icon: Icons.location_on,
                    ),

                    const SizedBox(height: 32),

                    // Accept / Decline buttons for testing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // Stop ringtone then trigger callback
                              RingtoneService.stop();
                              if (widget.onAnswer != null) {
                                widget.onAnswer!();
                              }
                            },
                            child: Container(
                              height: 90,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromARGB(140, 76, 175, 80),
                                    blurRadius: 36,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call, color: Colors.white, size: 48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // Stop ringtone then trigger callback
                              RingtoneService.stop();
                              if (widget.onDecline != null) {
                                widget.onDecline!();
                              }
                            },
                            child: Container(
                              height: 90,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromARGB(160, 244, 67, 54),
                                    blurRadius: 36,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call_end, color: Colors.white, size: 48),
                            ),
                          ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        const Text('Station Information',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              Icon(icon, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}


