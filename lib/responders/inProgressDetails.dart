import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/station.dart';
import '../screens/officer_map_screen.dart';

class InProgressDetailsPage extends StatelessWidget {
  final Map<String, dynamic> taskData;

  const InProgressDetailsPage({Key? key, required this.taskData}) : super(key: key);

  // Helpers copied/adapted from ResponderTaskDetailsPage
  static DateTime? _parseTimestamp(dynamic ts) {
    if (ts == null) return null;
    try {
      if (ts is int) {
        if (ts > 100000000000) {
          return DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
        }
        return DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
      }
      if (ts is String) {
        return DateTime.parse(ts).toLocal();
      }
    } catch (_) {}
    return null;
  }

  static int? _readInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _readDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.street ?? '').isNotEmpty) p.street!,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
          if ((p.postalCode ?? '').isNotEmpty) p.postalCode!,
          if ((p.country ?? '').isNotEmpty) p.country!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {}
    return 'Not provided';
  }

  Future<void> _openSharedLocation(BuildContext context) async {
    try {
      final double? lat = _readDouble(taskData['citizenLatitude']);
      final double? lng = _readDouble(taskData['citizenLongitude']);
      final String callerName = (taskData['callerName'] ?? 'Caller').toString();

      // Load stations from Responders node
      final respondersSnap = await FirebaseDatabase.instance.ref('Responders').get();
      final List<Station> stations = [];
      if (respondersSnap.exists && respondersSnap.value is Map) {
        final map = respondersSnap.value as Map;
        for (final entry in map.entries) {
          final stationName = entry.key.toString();
          final stationData = entry.value;
          if (stationData is Map) {
            final m = stationData as Map;
            final loc = m['location'] ?? m;
            final sMap = {
              'name': stationName,
              'hotline': m['hotline'] ?? '',
              'streetAddress': m['streetAddress'] ?? '',
              'city': m['city'] ?? '',
              'region': m['region'] ?? '',
              'latitude': (loc is Map ? loc['latitude'] : m['latitude'])?.toString() ?? '0.0',
              'longitude': (loc is Map ? loc['longitude'] : m['longitude'])?.toString() ?? '0.0',
              'radius': m['radius']?.toString() ?? '500.0',
            };
            stations.add(Station.fromMap(stationName, sMap));
          }
        }
      }

      // Navigate to map screen
      // ignore: use_build_context_synchronously
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OfficerMapScreen(
            stations: stations,
            officerName: 'Responder',
            callerLatitude: lat,
            callerLongitude: lng,
            callerName: callerName,
          ),
        ),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open map: $e')),
      );
    }
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

  static String _formatDuration(int? answeredAt, int? endedAt) {
    if (answeredAt == null || answeredAt == 0) return 'N/A';
    int end = (endedAt == null || endedAt == 0)
        ? DateTime.now().millisecondsSinceEpoch
        : endedAt;
    final d = Duration(milliseconds: end - answeredAt);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m ${d.inSeconds % 60}s';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  Future<void> _finishTask(BuildContext context) async {
    try {
      final station = (taskData['station'] ?? '').toString();
      final callId = (taskData['callId'] ?? '').toString();
      if (station.isEmpty || callId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing station or call ID.')),
        );
        return;
      }

      final basePath = 'Responders/$station/ReceivedCallDetails';
      final root = FirebaseDatabase.instance.ref();
      final inProgressRef = root.child('$basePath/InProgress/$callId');

      final snap = await inProgressRef.get();
      if (!snap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('In-Progress task not found.')),
        );
        return;
      }

      final raw = snap.value;
      if (raw is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected data format for task: ${raw.runtimeType}')),
        );
        return;
      }
      final data = raw.map((k, v) => MapEntry(k.toString(), v));

      // Validate required fields
      final description = (data['description'] ?? data['responder_description'] ?? '').toString().trim();
      final imageAttached = (data['imageAttached'] ?? '').toString().trim();
      final hasImage = imageAttached.isNotEmpty && imageAttached.toLowerCase() != 'none';
      if (description.isEmpty || !hasImage) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Missing Required Info'),
            content: const Text('Please add an incident description and attach an image before finishing.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Confirm finish
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mark as Completed?'),
          content: const Text('Are you sure this incident has been resolved and should be moved to Completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Yes, Finish'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      data['status'] = 'Completed';
      data['completedAt'] = DateTime.now().toIso8601String();

      await root.update({
        '$basePath/Completed/$callId': data,
        '$basePath/InProgress/$callId': null,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task moved to Completed.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete task: $e')),
        );
      }
    }
  }

  Widget _buildHeader(
    BuildContext context,
    String callerName,
    String? photoUrl,
    String gender,
    String contact,
    String address,
    String birthDate,
    String disability,
    String medical,
  ) {
    Widget chip({
      required String label,
      IconData? icon,
      Color color = const Color.fromARGB(51, 255, 255, 255),
      Color textColor = Colors.white,
      Color? borderColor,
      bool softWrap = true,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label.isNotEmpty ? label : 'Not provided',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12),
                softWrap: softWrap,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
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
                const Text('Call Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _finishTask(context),
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  label: const Text('Finish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: (photoUrl != null && photoUrl.isNotEmpty)
                      ? ClipOval(
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            width: 64,
                            height: 64,
                            errorBuilder: (context, error, stack) => const Icon(Icons.person, color: Colors.grey, size: 32),
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.grey, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        callerName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          chip(label: gender, icon: Icons.person),
                          chip(label: contact, icon: Icons.phone),
                          chip(label: birthDate.isNotEmpty ? birthDate : 'Not provided', icon: Icons.cake),
                          chip(label: address, icon: Icons.location_on, softWrap: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          chip(
                            label: disability,
                            icon: Icons.accessibility,
                            color: const Color(0xFFFFE5E5),
                            textColor: Colors.red,
                            borderColor: Colors.red,
                          ),
                          const SizedBox(height: 8),
                          chip(
                            label: medical,
                            icon: Icons.healing,
                            color: const Color(0xFFFFF2CC),
                            textColor: Color(0xFFCC8A00),
                            borderColor: Color(0xFFCC8A00),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final callerName = (taskData['callerName'] ?? 'Unknown Caller').toString();
    final contact = (taskData['mobile'] ?? taskData['contactNumber'] ?? 'Not Provided').toString();
    final address = (taskData['address'] ?? taskData['location'] ?? 'No address').toString();
    final gender = (taskData['gender'] ?? 'Unknown').toString();
    final disability = (taskData['disabilityStatus'] ?? 'None').toString();
    final medical = (taskData['medicalConditions'] ?? 'None').toString();
    final photoUrl = taskData['callerImage']?.toString();
    final birthDate = (taskData['birthDate'] ?? 'Not provided').toString();

    final answeredAt = _readInt(taskData['answeredAt']);
    final endedAt = _readInt(taskData['endedAt']);
    final ts = _parseTimestamp(taskData['timestamp']);

    // Prefer the actual moment the call happened/was answered
    DateTime? callMoment;
    if (answeredAt != null && answeredAt > 0) {
      callMoment = DateTime.fromMillisecondsSinceEpoch(answeredAt).toLocal();
    } else if (ts != null) {
      callMoment = ts; // created timestamp fallback
    } else if (endedAt != null && endedAt > 0) {
      callMoment = DateTime.fromMillisecondsSinceEpoch(endedAt).toLocal();
    } else {
      callMoment = null;
    }

    final callDuration = _formatDuration(answeredAt, endedAt);
    final dateStr = callMoment != null ? _formatDate(callMoment) : 'Not provided';
    final timeStr = callMoment != null ? _formatTime(callMoment) : 'Not provided';

    final lat = _readDouble(taskData['citizenLatitude']);
    final lng = _readDouble(taskData['citizenLongitude']);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context, callerName, photoUrl, gender, contact, address, birthDate, disability, medical),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionCard(
                    title: 'Location Details',
                    icon: Icons.location_on,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<String>(
                          future: (lat != null && lng != null)
                              ? _reverseGeocode(lat, lng)
                              : Future<String>.value(address.isNotEmpty ? address : 'Not provided'),
                          builder: (context, snapshot) {
                            final addr = snapshot.connectionState == ConnectionState.done
                                ? (snapshot.data ?? address)
                                : address;
                            return _LabeledBox(label: 'Address', value: addr);
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location, size: 16, color: Colors.black54),
                              const SizedBox(width: 8),
                              const Text('Latitude & Longitude', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 12)),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Copy coordinates',
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: (lat != null && lng != null)
                                    ? () async {
                                        final text = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
                                        await Clipboard.setData(ClipboardData(text: text));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Coordinates copied')),
                                        );
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Text(
                            (lat != null && lng != null)
                                ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                                : 'Not provided',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ResponderReportSection(taskData: taskData),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Call Info',
                    icon: Icons.info_outline,
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.timer_outlined,
                          label: 'Call Duration',
                          trailing: callDuration,
                          trailingColor: Colors.green,
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.calendar_today,
                          label: 'Date',
                          trailing: dateStr,
                          isBold: true,
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.access_time,
                          label: 'Time',
                          trailing: timeStr,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _openSharedLocation(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View Shared Location'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponderReportSection extends StatefulWidget {
  final Map<String, dynamic> taskData;
  const _ResponderReportSection({required this.taskData});

  @override
  State<_ResponderReportSection> createState() => _ResponderReportSectionState();
}

class _ResponderReportSectionState extends State<_ResponderReportSection> {
  late final TextEditingController _controller;
  bool _isEditing = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    // Use the same key we write to: 'description'. Fallback to any legacy key.
    final initialText = (widget.taskData['description'] ?? widget.taskData['responder_description'] ?? '')
        .toString();
    _controller = TextEditingController(text: initialText);

    // If initial snapshot did not include description, try to fetch it from DB once.
    if (initialText.isEmpty) {
      final station = (widget.taskData['station'] ?? '').toString();
      final callId = (widget.taskData['callId'] ?? '').toString();
      if (station.isNotEmpty && callId.isNotEmpty) {
        final dref = FirebaseDatabase.instance
            .ref('Responders/$station/ReceivedCallDetails/InProgress/$callId/description');
        dref.get().then((snap) {
          if (!mounted) return;
          final v = snap.value?.toString() ?? '';
          if (v.isNotEmpty) {
            setState(() {
              _controller.text = v;
            });
          }
        }).catchError((_) {/* ignore */});
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear);
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
        // Write placeholder to DB: imageAttached = "Image Attached"
        final station = (widget.taskData['station'] ?? '').toString();
        final callId = (widget.taskData['callId'] ?? '').toString();
        if (station.isNotEmpty && callId.isNotEmpty) {
          final ref = FirebaseDatabase.instance
              .ref('Responders/$station/ReceivedCallDetails/InProgress/$callId');
          await ref.update({'imageAttached': 'Image Attached'});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image Attached saved to report.')),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Missing station or callId; cannot save image flag.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _saveReport() {
    final text = _controller.text.trim();
    final station = (widget.taskData['station'] ?? '').toString();
    final callId = (widget.taskData['callId'] ?? '').toString();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description is empty. Nothing to save.')),
      );
      setState(() => _isEditing = false);
      return;
    }

    if (station.isEmpty || callId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing station or callId; cannot save description.')),
      );
      return;
    }

    final ref = FirebaseDatabase.instance
        .ref('Responders/$station/ReceivedCallDetails/InProgress/$callId');
    ref.update({'description': text}).then((_) {
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description saved.')),
      );
    }).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: "Incident Report",
      icon: Icons.edit_document,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
              if (_isEditing)
                TextButton(onPressed: _saveReport, child: const Text('Save'))
              else
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => setState(() => _isEditing = true),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _isEditing
              ? TextField(
                  controller: _controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe the incident...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              : GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _controller.text.isNotEmpty ? _controller.text : 'No description yet. Tap to add.',
                      style: TextStyle(color: _controller.text.isNotEmpty ? Colors.black87 : Colors.grey),
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openCamera,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.grey[600], size: 40),
                        const SizedBox(height: 8),
                        Text('Add Photo', style: TextStyle(color: Colors.grey[800])),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LabeledBox extends StatelessWidget {
  final String label;
  final String value;
  const _LabeledBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String trailing;
  final bool isBold;
  final Color? trailingColor;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.isBold = false,
    this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[700]),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(
          trailing,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: trailingColor ?? Colors.black,
          ),
        )
      ],
    );
  }
}

