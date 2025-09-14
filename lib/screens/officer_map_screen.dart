import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/station.dart';
import '../utils/circle_polygon.dart';
import '../services/offline_emergency_service.dart'; // For connectivity check

class CallMapScreen extends StatefulWidget {
  final List<Station> stations;
  final double? callerLatitude;
  final double? callerLongitude;
  final String callerName;

  const CallMapScreen({
    Key? key,
    required this.stations,
    this.callerLatitude,
    this.callerLongitude,
    required this.callerName,
  }) : super(key: key);

  @override
  _CallMapScreenState createState() => _CallMapScreenState();
}

class _CallMapScreenState extends State<CallMapScreen> {
  MapLibreMapController? _mapController;
  final String _mapStyleUrl = 'https://api.maptiler.com/maps/streets-v2/style.json?key=VhMngqsXGbpDhosqRB2c';

  @override
  void initState() {
    super.initState();
    _configureMapForOfflineUse();
  }

  Future<void> _configureMapForOfflineUse() async {
    final offlineService = OfflineEmergencyService();
    final hasInternet = await offlineService.hasInternetConnection();

    if (!hasInternet) {
      debugPrint('Device is offline. Officer map attempting to use offline map.');
    } else {
      debugPrint('Device is online. Officer map using online map.');
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
    await _loadMapAssets(controller);

    // Add station pins and geofences (keep these unchanged)
    for (var station in widget.stations) {
      // Add station pin
      controller.addSymbol(SymbolOptions(
        geometry: LatLng(station.latitude, station.longitude),
        iconImage: 'station_pin',
        iconSize: 0.2,
      ));

      // Add geofence circle
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

    // Add caller location instead of officer location
    if (widget.callerLatitude != null && widget.callerLongitude != null) {
      controller.addSymbol(SymbolOptions(
        geometry: LatLng(widget.callerLatitude!, widget.callerLongitude!),
        iconImage: 'user_pin',
        iconSize: 0.2,
        iconAnchor: "bottom",
      ));

      // Center map on caller location
      controller.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(widget.callerLatitude!, widget.callerLongitude!), 14.0));
    } else if (widget.stations.isNotEmpty) {
      // Fallback to first station if no caller location
      controller.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(widget.stations.first.latitude, widget.stations.first.longitude), 12.0));
    }
  }

  Future<void> _loadMapAssets(MapLibreMapController controller) async {
    // Load station pin
    final stationPinData = await rootBundle.load('assets/images/station_pin.png');
    final stationPinBytes = stationPinData.buffer.asUint8List();
    await controller.addImage('station_pin', stationPinBytes);
    
    // Load user pin for caller location
    final userPinData = await rootBundle.load('assets/images/user_pin.png');
    final userPinBytes = userPinData.buffer.asUint8List();
    await controller.addImage('user_pin', userPinBytes);
  }

  void _onFocusOnCaller() {
    if (_mapController != null && 
        widget.callerLatitude != null && 
        widget.callerLongitude != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(widget.callerLatitude!, widget.callerLongitude!), 16.0),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Location'),
        actions: [
          if (widget.callerLatitude != null && widget.callerLongitude != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _onFocusOnCaller,
              tooltip: 'Focus on caller location',
            ),
        ],
      ),
      body: Column(
        children: [
          // Info panel
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: const Color.fromARGB(255, 233, 74, 69)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Red areas: Station coverage | Red pins: Police stations | Blue pin: Caller location',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 233, 74, 69),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: MapLibreMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: widget.callerLatitude != null && widget.callerLongitude != null
                    ? LatLng(widget.callerLatitude!, widget.callerLongitude!)
                    : widget.stations.isNotEmpty
                        ? LatLng(widget.stations.first.latitude, widget.stations.first.longitude)
                        : const LatLng(12.8797, 121.7740), // Philippines center
                zoom: 14.0,
              ),
              styleString: _mapStyleUrl,
              myLocationEnabled: false, // Disable officer location tracking during calls
              myLocationTrackingMode: MyLocationTrackingMode.none,
            ),
          ),
        ],
      ),
    );
  }
}
