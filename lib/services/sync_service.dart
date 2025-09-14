import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'offline_emergency_service.dart';
import 'offline_map_service.dart';

/// A service responsible for synchronizing offline data when the app comes online.
class SyncService {
  final OfflineEmergencyService _offlineEmergencyService = OfflineEmergencyService();
  final OfflineMapService _offlineMapService = OfflineMapService();

  StreamSubscription? _connectivitySubscription;

  /// Initializes the service and starts listening for connectivity changes.
  void initialize() {
    // Check initial connectivity and sync if online
    Connectivity().checkConnectivity().then((result) {
      if (result != ConnectivityResult.none) {
        _runSyncTasks();
      }
    });

    // Listen for future connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        debugPrint('App is online. Starting background data sync...');
        _runSyncTasks();
      }
    });
  }

  /// Runs all the necessary data synchronization tasks.
  Future<void> _runSyncTasks() async {
    // Task 1: Update the station cache
    await _offlineEmergencyService.cacheStationData();

    // Task 2: Check and download the offline map if it doesn't exist
    await _offlineMapService.startOfflineMapDownload();
  }

  /// Disposes of the connectivity stream subscription.
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
