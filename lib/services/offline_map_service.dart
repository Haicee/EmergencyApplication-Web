import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class OfflineMapService {
  static final OfflineMapService _instance = OfflineMapService._internal();
  factory OfflineMapService() => _instance;
  OfflineMapService._internal();

  final StreamController<double> _progressController = StreamController<double>.broadcast();
  Stream<double> get downloadProgressStream => _progressController.stream;

  bool _isDownloading = false;

  Future<void> startOfflineMapDownload() async {
    if (_isDownloading) {
      debugPrint('Offline map download already in progress.');
      return;
    }

    _isDownloading = true;

    try {
      final LatLngBounds bounds = LatLngBounds(
        southwest: const LatLng(5.95, 125.05),
        northeast: const LatLng(6.35, 125.25),
      );

      final offlineRegionDefinition = OfflineRegionDefinition(
        bounds: bounds,
        minZoom: 10,
        maxZoom: 16,
        mapStyleUrl: 'https://api.maptiler.com/maps/streets-v2/style.json?key=VhMngqsXGbpDhosqRB2c',
      );

      await setOfflineTileCountLimit(75000);

      debugPrint('Starting offline map download for General Santos City...');
      
      final region = await downloadOfflineRegion(
        offlineRegionDefinition,
        metadata: {
          'name': 'General Santos City',
        },
        onEvent: (DownloadRegionStatus status) {
          if (status is InProgress) {
            _progressController.add(status.progress);
            debugPrint('Offline map download progress: ${status.progress}%');
          } else if (status is Success) {
            debugPrint('Offline map download successful!');
            _progressController.add(100.0);
            _progressController.close();
          } else {
            debugPrint('Unknown event type: ${status.runtimeType}');
          }
        },
      );

      debugPrint('Offline map download completed for region: ${region.id}');

    } catch (e) {
      debugPrint('Error downloading offline map region: $e');
      _progressController.addError(e);
    } finally {
      _isDownloading = false;
    }
  }

  void dispose() {
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }
}