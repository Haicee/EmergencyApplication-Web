import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../callBack.dart';
import '../../models/station.dart';
import '../../screens/officer_map_screen.dart';

// AnsweredViewDetails: full page showing personal info + call details
class AnsweredViewDetails extends StatefulWidget {
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
  final double citizenLatitude;
  final double citizenLongitude;
  final String birthDate;
  final List<Station> stations; // Pass stations for map overlays

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
    required this.citizenLatitude,
    required this.citizenLongitude,
    required this.birthDate,
    required this.stations,
  }) : super(key: key);

  @override
  State<AnsweredViewDetails> createState() => _AnsweredViewDetailsState();
}

class _AnsweredViewDetailsState extends State<AnsweredViewDetails> {
  bool _isSending = false;
  bool _isSent = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadySent();
  }

  Future<void> _checkAlreadySent() async {
    try {
      final root = FirebaseDatabase.instance.ref();

      // 1) Prefer durable flag on Desk Officer AnsweredCalls
      final flagRef = root.child(
        'Desk Officer/${widget.station}/ReceivedCalls/AnsweredCalls/${widget.callId}/sendDetails',
      );
      final flagSnap = await flagRef.get();
      if (!mounted) return;
      if (flagSnap.value == true) {
        setState(() => _isSent = true);
        return;
      }

      // 2) Fallback: consider any responder status as already sent
      final base = 'Responders/${widget.station}/ReceivedCallDetails';
      final assigned = await root.child('$base/Assigned/${widget.callId}').get();
      if (!mounted) return;
      if (assigned.exists) {
        setState(() => _isSent = true);
        // Self-heal: backfill the flag so UI stays stable next time
        root
            .child('Desk Officer/${widget.station}/ReceivedCalls/AnsweredCalls/${widget.callId}')
            .update({'sendDetails': true, 'sentAt': ServerValue.timestamp}).catchError((_) {});
        return;
      }

      final inProg = await root.child('$base/InProgress/${widget.callId}').get();
      if (!mounted) return;
      if (inProg.exists) {
        setState(() => _isSent = true);
        root
            .child('Desk Officer/${widget.station}/ReceivedCalls/AnsweredCalls/${widget.callId}')
            .update({'sendDetails': true, 'sentAt': ServerValue.timestamp}).catchError((_) {});
        return;
      }

      final completed = await root.child('$base/Completed/${widget.callId}').get();
      if (!mounted) return;
      if (completed.exists) {
        setState(() => _isSent = true);
        root
            .child('Desk Officer/${widget.station}/ReceivedCalls/AnsweredCalls/${widget.callId}')
            .update({'sendDetails': true, 'sentAt': ServerValue.timestamp}).catchError((_) {});
      }
    } catch (_) {
      // Silently ignore; default is not sent
    }
  }

  @override
  Widget build(BuildContext context) {
    final callDuration = _formatCallDuration(widget.answeredAt, widget.endedAt);
    final dateStr = _formatDate(DateTime.fromMillisecondsSinceEpoch(widget.timestamp));
    final timeStr = _formatTime(DateTime.fromMillisecondsSinceEpoch(widget.timestamp));
    final lat = widget.citizenLatitude;
    final lng = widget.citizenLongitude;
    final hasValidCoords = lat != 0 && lng != 0 && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

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
                      if (_isSent)
                        const Icon(Icons.check_circle, color: Colors.white, size: 28)
                      else if (_isSending)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: (_isSending || _isSent) ? null : _showSendConfirmationDialog,
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.call, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OfficerCallBackPage(
                                citizenName: widget.name,
                                station: widget.station,
                                callId: '',
                                photoUrl: widget.photoUrl,
                                mobile: widget.mobile,
                                address: widget.address,
                                officerId: widget.officerId ?? 'PS1DO1', // Add officer ID - should be passed from parent
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: _buildAvatar(widget.photoUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                            const SizedBox(height: 8),
                            // Row 1 chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _chip(label: widget.gender.isNotEmpty ? widget.gender : 'Unknown', color: Colors.white.withOpacity(0.2), textColor: Colors.white, icon: Icons.person),
                                _chip(label: widget.mobile.isNotEmpty ? widget.mobile : 'Not Provided', color: Colors.white.withOpacity(0.2), textColor: Colors.white, icon: Icons.phone),
                                _chip(label: widget.birthDate.isNotEmpty ? widget.birthDate : 'Not provided', color: Colors.white.withOpacity(0.2), textColor: Colors.white, icon: Icons.cake),
                                _chip(label: _cleanAddressDisplay(widget.address), color: Colors.white.withOpacity(0.2), textColor: Colors.white, icon: Icons.location_on, softWrap: true, overflow: TextOverflow.visible),
                              ],
                            ),
                            
                            const SizedBox(height: 8),
                            // Disability and Medical each on their own row
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _chip(
                                  label: widget.disabilityStatus.isNotEmpty ? widget.disabilityStatus : 'None',
                                  color: const Color(0xFFFFE5E5),
                                  textColor: Colors.red,
                                  icon: Icons.accessibility,
                                  borderColor: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                _chip(
                                  label: widget.medicalConditions.isNotEmpty ? widget.medicalConditions : 'None',
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
                        FutureBuilder<String>(
                          future: hasValidCoords
                              ? _reverseGeocode(lat, lng)
                              : Future<String>.value(_cleanAddressDisplay(widget.address)),
                          builder: (context, snapshot) {
                            final resolved = snapshot.connectionState == ConnectionState.done
                                ? (snapshot.data ?? _cleanAddressDisplay(widget.address))
                                : _cleanAddressDisplay(widget.address);
                            return _addressCard(_cleanAddressDisplay(resolved));
                          },
                        ),
                        const SizedBox(height: 12),
                        // Latitude & Longitude row with copy action
                        Container(
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
                                  const Icon(Icons.my_location, size: 16, color: Colors.black54),
                                  const SizedBox(width: 8),
                                  const Text('Latitude & Longitude', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 12)),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Copy coordinates',
                                    icon: const Icon(Icons.copy, size: 18),
                                    onPressed: hasValidCoords
                                        ? () async {
                                            final text = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
                                            await Clipboard.setData(ClipboardData(text: text));
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Coordinates copied')),
                                            );
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                hasValidCoords
                                    ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                                    : 'Not provided',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
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
                if (!hasValidCoords) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Caller location not available.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CallMapScreen(
                      stations: widget.stations,
                      callerLatitude: lat,
                      callerLongitude: lng,
                      callerName: widget.name,
                    ),
                  ),
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

  void _showSendConfirmationDialog() {
    if (_isSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details already sent to responders.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Send'),
          content: const Text('Are you sure you want to send these details to the responders?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                _sendDetailsToResponders();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendDetailsToResponders() async {
    if (_isSent) {
      // Double guard
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details already sent to responders.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSending = true;
    });

    try {
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      final responderAssignedPath = 'Responders/${widget.station}/ReceivedCallDetails/Assigned/${widget.callId}';
      final responderInProgressPath = 'Responders/${widget.station}/ReceivedCallDetails/InProgress/${widget.callId}';
      final responderCompletedPath = 'Responders/${widget.station}/ReceivedCallDetails/Completed/${widget.callId}';
      final officerFlagBase = 'Desk Officer/${widget.station}/ReceivedCalls/AnsweredCalls/${widget.callId}';

      // Idempotency check: flag OR any responder status
      final flagSnap = await dbRef.child('$officerFlagBase/sendDetails').get();
      final alreadyFlagged = flagSnap.value == true;
      final existsAssigned = (await dbRef.child(responderAssignedPath).get()).exists;
      if (!mounted) return;
      final existsInProg = (await dbRef.child(responderInProgressPath).get()).exists;
      if (!mounted) return;
      final existsCompleted = (await dbRef.child(responderCompletedPath).get()).exists;
      if (alreadyFlagged || existsAssigned || existsInProg || existsCompleted) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _isSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Details already sent.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final Map<String, dynamic> taskData = {
        'location': widget.address,
        'callerName': widget.name,
        'callerImage': widget.photoUrl,
        'timestamp': DateTime.now().toIso8601String(),
        'gender': widget.gender,
        'mobile': widget.mobile,
        'disabilityStatus': widget.disabilityStatus,
        'medicalConditions': widget.medicalConditions,
        'callId': widget.callId,
        'station': widget.station,
        'officerId': widget.officerId,
        'answeredAt': widget.answeredAt,
        'endedAt': widget.endedAt,
        'birthDate': widget.birthDate,
        'citizenLatitude': widget.citizenLatitude,
        'citizenLongitude': widget.citizenLongitude,
      };

      // Atomic multi-path update: create responder task + set durable flag
      final Map<String, dynamic> updates = {
        responderAssignedPath: taskData,
        '$officerFlagBase/sendDetails': true,
        '$officerFlagBase/sentAt': ServerValue.timestamp,
      };
      if ((widget.officerId ?? '').isNotEmpty) {
        updates['$officerFlagBase/sentBy'] = widget.officerId;
      }
      await dbRef.update(updates);

      if (!mounted) return;
      setState(() {
        _isSending = false;
        _isSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Details successfully sent to responders.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send details: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  // Cleans a comma-separated address string by removing placeholders like
  // "Not provided"/"No address" and empty parts. If everything is removed,
  // returns exactly "Not provided".
  static String _cleanAddressDisplay(String? raw) {
    if (raw == null) return 'Not provided';
    final parts = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) {
          if (s.isEmpty) return false;
          final lower = s.toLowerCase();
          if (lower == 'not provided' || lower == 'no address' || lower == 'unknown' || lower == 'n/a') {
            return false;
          }
          // Filter out obvious plus codes like "34RP+6HG"
          if (s.contains('+') && s.length <= 12) return false;
          return true;
        })
        .toList();
    if (parts.isEmpty) return 'Not provided';
    return parts.join(', ');
  }

  // Reverse geocode coordinates into a readable address for display
  static Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      // Use default locale; some versions don't support localeIdentifier
      final placemarks = await geocoding.placemarkFromCoordinates(
        lat,
        lng,
      );
      if (placemarks.isEmpty) return 'Not provided';

      final p = placemarks.first;

      // Extract granular fields with good fallbacks
      final houseNo = (p.subThoroughfare ?? '').trim();
      final street = (p.thoroughfare ?? p.street ?? '').trim();
      final barangay = (p.subLocality ?? '').trim(); // PH: often Barangay
      final city = (p.locality ?? '').trim(); // City/Municipality
      final province = (p.subAdministrativeArea ?? '').trim(); // Province
      final region = (p.administrativeArea ?? '').trim(); // Region
      final country = (p.country ?? '').trim();

      // Helper: remove Plus Codes and noisy tokens from any component
      bool _isPlusCode(String s) {
        final t = s.trim();
        if (!t.contains('+')) return false;
        // common plus code tokens are short and contain '+'
        return t.length <= 12;
      }

      String composeStreetLine() {
        if (street.isEmpty) return '';
        if (_isPlusCode(street)) return '';
        return [if (houseNo.isNotEmpty) houseNo, street].join(' ').trim();
      }

      final streetLine = composeStreetLine();

      // Build a clean, human-readable sentence-like address
      final rawParts = <String>[
        if (streetLine.isNotEmpty) streetLine,
        if (barangay.isNotEmpty) barangay,
        if (city.isNotEmpty) city,
        if (province.isNotEmpty) province else if (region.isNotEmpty) region,
        if (country.isNotEmpty) country,
      ];

      // Sanitize: drop anything that looks like a plus code anywhere
      final parts = rawParts.where((p) => !_isPlusCode(p)).toList();

      if (parts.isNotEmpty) {
        return parts.join(', ');
      }

      // Last resort: try a minimal fallback using locality/region
      final fallback = <String>[
        if (city.isNotEmpty) city,
        if (region.isNotEmpty) region,
        if (country.isNotEmpty) country,
      ];
      if (fallback.isNotEmpty) return fallback.join(', ');
    } catch (_) {}
    return 'Not provided';
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

  bool _isValidHttpUrl(String? url) {
    if (url == null) return false;
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return false;
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Widget _buildAvatar(String? url) {
    if (_isValidHttpUrl(url)) {
      return ClipOval(
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (context, error, stack) => const Icon(Icons.person, color: Colors.grey, size: 48),
        ),
      );
    }
    return const Icon(Icons.person, color: Colors.grey, size: 48);
  }
}
