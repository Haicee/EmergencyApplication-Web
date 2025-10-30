import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService._();

  static final StorageService _instance = StorageService._();

  factory StorageService() => _instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfileImage({
    required File file,
    required String username,
  }) {
    final sanitizedUsername = _sanitizePathSegment(
      username.isEmpty ? 'anonymous' : username,
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'profile_images/$sanitizedUsername/profile_$timestamp.jpg';

    return _uploadFile(
      file: file,
      storagePath: path,
      metadata: SettableMetadata(customMetadata: {
        'username': username,
        'uploadedAt': DateTime.now().toIso8601String(),
        'type': 'profile',
      }),
    );
  }

  Future<String> uploadResponderIncidentImage({
    required File file,
    required String station,
    required String callId,
    String? responder,
    void Function(double progress)? onProgress,
  }) {
    final sanitizedStation = _sanitizePathSegment(
      station.isEmpty ? 'unknown_station' : station,
    );
    final sanitizedCallId = _sanitizePathSegment(
      callId.isEmpty ? 'unknown_call' : callId,
    );
    final path =
        'incident_reports/$sanitizedStation/$sanitizedCallId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    return _uploadFile(
      file: file,
      storagePath: path,
      metadata: SettableMetadata(customMetadata: {
        'station': station,
        'callId': callId,
        'responder': responder ?? '',
        'uploadedAt': DateTime.now().toIso8601String(),
        'type': 'incident',
      }),
      onProgress: onProgress,
    );
  }

  Future<String> _uploadFile({
    required File file,
    required String storagePath,
    SettableMetadata? metadata,
    void Function(double progress)? onProgress,
  }) async {
    final Reference ref = _storage.ref().child(storagePath);
    final UploadTask uploadTask = ref.putFile(file, metadata);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final total = snapshot.totalBytes;
        if (total > 0) {
          final progress = snapshot.bytesTransferred / total;
          onProgress(progress.clamp(0.0, 1.0));
        }
      });
    }

    final TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
    return snapshot.ref.getDownloadURL();
  }

  String _sanitizePathSegment(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[\\/#\[\]\*\?]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }
}
