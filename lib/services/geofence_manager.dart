import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/station.dart';

class GeofenceManager {
  final _geofenceStreamController = StreamController<GeofenceRegion>.broadcast();
  Stream<GeofenceRegion> get geofenceStream => _geofenceStreamController.stream;

  Future<bool> requestPermissions() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        var backgroundStatus = await Permission.locationAlways.request();
        return backgroundStatus.isGranted;
      }
      return true;
    }
    return false;
  }

  void startGeofencing(List<Station> stations) {
    Geofencing.instance.setup(
      interval: 5000,
      accuracy: 100,
      statusChangeDelay: 10000,
      allowsMockLocation: false,
      printsDebugLog: true,
    );

    final regions = stations.map((station) => GeofenceRegion.circular(
      id: station.id,
      center: LatLng(station.latitude, station.longitude),
      radius: station.radius,
      data: {'name': station.name, 'hotline': station.hotline},
    )).toSet();

    Geofencing.instance.addGeofenceStatusChangedListener(_onGeofenceStatusChanged);
    Geofencing.instance.start(regions: regions);
  }

  Future<void> _onGeofenceStatusChanged(
    GeofenceRegion region,
    GeofenceStatus status,
    Location location,
  ) async {
    if (status == GeofenceStatus.enter) {
      _geofenceStreamController.add(region);
    }
  }

  void stopGeofencing() {
    Geofencing.instance.removeGeofenceStatusChangedListener(_onGeofenceStatusChanged);
    Geofencing.instance.stop();
  }

  void dispose() {
    _geofenceStreamController.close();
    stopGeofencing();
  }
}
