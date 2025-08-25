import 'package:flutter/material.dart';
import '../callBack.dart';

// MissedViewDetails shows a pop-up/overlay with caller information for a missed call.
// Reference design is based on incomingCall.dart, but adapted for a dialog overlay.
class MissedViewDetails extends StatelessWidget {
  final String name;
  final String photoUrl;
  final String gender;
  final String mobile;
  final String address;
  final String disabilityStatus;
  final String medicalConditions;
  final String callId;
  final String station;
  final String? officerId; // Add officer ID

  const MissedViewDetails({
    Key? key,
    required this.name,
    required this.photoUrl,
    required this.gender,
    required this.mobile,
    required this.address,
    required this.disabilityStatus,
    required this.medicalConditions,
    required this.callId,
    required this.station,
    this.officerId, // Add officer ID parameter
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    // Centered dialog overlay with rounded corners and gradient background
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // Profile photo
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: NetworkImage(photoUrl),
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      // Name
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Section: Personal Information
                      const _SectionHeader(title: 'Personal Information', icon: Icons.person),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              label: 'Gender',
                              value: gender,
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              label: 'Contact Number',
                              value: mobile,
                              icon: Icons.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _InfoCard(
                        label: 'Address',
                        value: address,
                        icon: Icons.location_on,
                      ),

                      const SizedBox(height: 20),
                      // Section: Medical Information
                      const _SectionHeader(title: 'Medical Information', icon: Icons.medical_services),
                      const SizedBox(height: 10),
                      _InfoCard(
                        label: 'Disability Status',
                        value: disabilityStatus,
                        icon: Icons.accessibility,
                        labelColor: Colors.red,
                        backgroundColor: const Color(0xFFFFE5E5),
                        borderColor: Colors.red,
                      ),
                      const SizedBox(height: 10),
                      _InfoCard(
                        label: 'Medical Conditions',
                        value: medicalConditions,
                        icon: Icons.healing,
                        labelColor: Colors.orange,
                        backgroundColor: const Color(0xFFFFF3E0),
                        borderColor: Colors.orange,
                      ),

                      const SizedBox(height: 90), // Space for the bottom call button
                    ],
                  ),
                ),
              ),

              // Close button (top-right)
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ),

              // Call button (center-bottom)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      // Close the dialog then navigate to OfficerCallBackPage to initiate call
                      final route = MaterialPageRoute(
                        builder: (_) => OfficerCallBackPage(
                          citizenName: name,
                          station: station,
                          callId: '', // generate new call id inside callback page
                          photoUrl: photoUrl,
                          mobile: mobile,
                          address: address,
                          officerId: officerId, // Add officer ID - should be passed from parent
                        ),
                      );
                      Navigator.of(context).pop();
                      await Future.microtask(() {
                        Navigator.of(context, rootNavigator: true).push(route);
                      });
                    },
                    child: Container(
                      height: 84,
                      width: 84,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromARGB(120, 0, 128, 0),
                            blurRadius: 24,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call, color: Colors.white, size: 40),
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
    required this.label,
    required this.value,
    required this.icon,
    this.labelColor,
    this.backgroundColor,
    this.borderColor,
  });

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
              Icon(icon, size: 16, color: labelColor ?? Colors.grey[600]),
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
            value.isNotEmpty ? value : 'Not specified',
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


