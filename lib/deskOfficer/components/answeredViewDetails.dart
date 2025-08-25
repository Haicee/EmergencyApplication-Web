import 'package:flutter/material.dart';
import '../callBack.dart';

// AnsweredViewDetails: full page showing personal info + call details
class AnsweredViewDetails extends StatelessWidget {
  final String name;
  final String photoUrl;
  final String gender;
  final String mobile;
  final String address;
  final String disabilityStatus;
  final String medicalConditions;
  final String callId;
  final String station;
  final int timestamp; // call created time (ms)
  final int answeredAt; // when desk officer answered (ms)
  final int endedAt; // when call ended (ms) - optional 0 if ongoing
  final String? officerId; // Add officer ID

  const AnsweredViewDetails({
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
    required this.timestamp,
    required this.answeredAt,
    required this.endedAt,
    this.officerId, // Add officer ID parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final callDuration = _formatCallDuration(answeredAt, endedAt);
    final dateStr = _formatDate(DateTime.fromMillisecondsSinceEpoch(timestamp));
    final timeStr = _formatTime(DateTime.fromMillisecondsSinceEpoch(timestamp));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Gradient Header with back button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3E45CD), Color(0xFFFF6767)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Call Details',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.call, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OfficerCallBackPage(
                                citizenName: name,
                                station: station,
                                callId: '',
                                photoUrl: photoUrl,
                                mobile: mobile,
                                address: address,
                                officerId: officerId ?? 'PS1DO1', // Add officer ID - should be passed from parent
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.message_rounded, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(photoUrl),
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                            const SizedBox(height: 8),
                            // Row 1 chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _chip(label: gender.isNotEmpty ? gender : 'Unknown', color: Colors.white.withOpacity(0.2), textColor: Colors.white, icon: Icons.person),
                                _chip(label: mobile.isNotEmpty ? mobile : 'Not Provided', color: Colors.white.withOpacity(0.2), textColor: Colors.white, icon: Icons.phone),
                                _chip(label: address.isNotEmpty ? address : 'No address', color: Colors.white.withOpacity(0.2), textColor: Colors.white, icon: Icons.location_on, softWrap: true, overflow: TextOverflow.visible),
                              ],
                            ),
                            
                            const SizedBox(height: 8),
                            // Disability and Medical each on their own row
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _chip(
                                  label: disabilityStatus.isNotEmpty ? disabilityStatus : 'None',
                                  color: const Color(0xFFFFE5E5),
                                  textColor: Colors.red,
                                  icon: Icons.accessibility,
                                  borderColor: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                _chip(
                                  label: medicalConditions.isNotEmpty ? medicalConditions : 'None',
                                  color: const Color(0xFFFFF2CC),
                                  textColor: const Color(0xFFCC8A00),
                                  icon: Icons.healing,
                                  borderColor: const Color(0xFFCC8A00),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 6),
                            const Text('Location Details', style: TextStyle(fontWeight: FontWeight.w700)),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _addressCard(address), // change ni into shared location of the caller, use geocoding para ma convert into address
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Call Details List
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _labelValueRow(Icons.av_timer, 'Call Duration', callDuration, valueColor: Colors.green, iconColor: Colors.green),
                        const SizedBox(height: 10),
                        _labelValueRow(Icons.event, 'Date', dateStr),
                        const SizedBox(height: 10),
                        _labelValueRow(Icons.access_time, 'Time', timeStr),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening shared location...')),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6767), Color(0xFFFF8A7A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'View Shared Location',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers  
  static Widget _chip({
  required String label,
  Color color = Colors.white24,
  Color textColor = Colors.white,
  Color? borderColor,
  IconData? icon,
  bool softWrap = true,
  TextOverflow overflow = TextOverflow.visible,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: borderColor != null
          ? Border.all(color: borderColor, width: 1)
          : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, // allows multi-line text
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            softWrap: softWrap,
            overflow: overflow,
          ),
        ),
      ],
    ),
  );
}


  

  static Widget _miniTile({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

 

  static Widget _addressCard(String address) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Address', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            address.isNotEmpty ? address : 'Not specified',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            softWrap: true,
            maxLines: null,
          ),
        ],
      ),
    );
  }

  // Compact row with an icon + label on the left and the value on the right
  static Widget _labelValueRow(IconData icon, String label, String value, {Color? valueColor, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor ?? Colors.black54),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 12)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor ?? Colors.black87),
          ),
        ],
      ),
    );
  }

  static String _formatCallDuration(int answeredAt, int endedAt) {
    if (answeredAt == 0) return 'N/A';
    int end = endedAt == 0 ? DateTime.now().millisecondsSinceEpoch : endedAt;
    final d = Duration(milliseconds: end - answeredAt);
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m ${d.inSeconds % 60}s';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    return '${d.inSeconds}s';
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'January','February','March','April','May','June','July','August','September','October','November','December'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }

  static String _formatTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$mm $ampm';
  }
}

