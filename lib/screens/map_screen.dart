import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geofencing_api/geofencing_api.dart' hide LatLng;
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/station.dart';
import '../services/geofence_manager.dart';
import '../utils/circle_polygon.dart';
import '../services/offline_emergency_service.dart';

class MapScreen extends StatefulWidget {
  final List<Station> stations;

  const MapScreen({Key? key, required this.stations}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GeofenceManager _geofenceManager = GeofenceManager();
  StreamSubscription<GeofenceRegion>? _geofenceSubscription;
  MapLibreMapController? _mapController;
  Position? _currentPosition;
  final String _mapStyleUrl = 'https://api.maptiler.com/maps/streets-v2/style.json?key=VhMngqsXGbpDhosqRB2c';

  @override
  void initState() {
    super.initState();
    _configureMapForOfflineUse();
    _initializeGeofencing();
    _getCurrentLocation();
  }

  Future<void> _configureMapForOfflineUse() async {
    final offlineService = OfflineEmergencyService();
    final hasInternet = await offlineService.hasInternetConnection();

    if (!hasInternet) {
      // If offline, point to the local offline style. This assumes the region was downloaded.
      // MapLibre will automatically use the downloaded region if the style matches.
      debugPrint('Device is offline. Attempting to use offline map.');
      // The style URL must match the one used for downloading.
      // MapLibre handles the rest automatically.
    } else {
      debugPrint('Device is online. Using online map.');
    }
    // No need to change the URL, MapLibre handles it if the style matches the downloaded one.
  }

  Future<void> _initializeGeofencing() async {
    bool permissionsGranted = await _geofenceManager.requestPermissions();
    if (permissionsGranted) {
      _geofenceManager.startGeofencing(widget.stations);
      _geofenceSubscription = _geofenceManager.geofenceStream.listen((region) {
        final station = _findStationById(region.id);
        if (station != null) {
          _showGeofenceEnteredDialog(station);
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude), 15.0));
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
    await station_Pin(controller);

    for (var station in widget.stations) {
      // Add station pin
      controller.addSymbol(SymbolOptions(
        geometry: LatLng(station.latitude, station.longitude),
        iconImage: 'station_pin',
        iconSize: 0.2,
      ));

      // Add geofence circle polygon
      final circlePolygon = createCirclePolygon(
        LatLng(station.latitude, station.longitude),
        station.radius,
      );

      controller.addFill(
        FillOptions(
          geometry: [circlePolygon],
          fillColor: '#FF0000',
          fillOpacity: 0.3,
        ),
      );
    }
    if (_currentPosition != null) {
       controller.animateCamera(CameraUpdate.newLatLngZoom(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0));
    }
  }

  Future<void> station_Pin(MapLibreMapController controller) async {
    final ByteData byteData = await rootBundle.load('assets/images/station_pin.png');
    final Uint8List bytes = byteData.buffer.asUint8List();
    return controller.addImage('station_pin', bytes);
  }

  Station? _findStationById(String id) {
    try {
      return widget.stations.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  void _showGeofenceEnteredDialog(Station station) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Police Station Area'),
        content: Text('You have entered the area for ${station.name}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _onMyLocationPressed() {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 14.0),
      );
    }
  }


  @override
  void dispose() {
    _geofenceSubscription?.cancel();
    _geofenceManager.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police Stations Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _onMyLocationPressed,
          ),
        ],
      ),
      body: MapLibreMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : const LatLng(12.8797, 121.7740), // Philippines center
          zoom: _currentPosition != null ? 15.0 : 5.0,
        ),
        styleString: _mapStyleUrl,
        myLocationEnabled: true,
        myLocationTrackingMode: MyLocationTrackingMode.tracking,
      ),
    );
  }
}
