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
  StreamSubscription<Position>? _locationSubscription;
  MapLibreMapController? _mapController;
  Position? _currentPosition;
  Position? _lastStablePosition;
  Timer? _locationStabilizationTimer;
  final String _mapStyleUrl = 'https://api.maptiler.com/maps/streets-v2/style.json?key=VhMngqsXGbpDhosqRB2c';
  
  // Local station list that can be filled from widget or cache for offline use
  List<Station> _stationsLocal = [];
  
  // Location filtering constants
  static const double _minDistanceFilter = 5.0; // Minimum 5 meters movement to update
  static const Duration _locationUpdateInterval = Duration(seconds: 10); // Update every 10 seconds max
  DateTime _lastLocationUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _configureMapForOfflineUse();
    _initializeGeofencing();
    _getCurrentLocation();
    
    // Prefer the provided stations, but fall back to cached stations for offline
    _stationsLocal = List<Station>.from(widget.stations);
    if (_stationsLocal.isEmpty) {
      _loadOfflineStations();
    }
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
      // Get initial position with balanced accuracy (not high to avoid constant updates)
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _lastStablePosition = position;
        });
        
        // Only animate camera on first load
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude), 15.0));
        }
        
        debugPrint('📍 Initial location: ${position.latitude}, ${position.longitude}');
      }
      
      // Start listening for location updates with filtering
      _startLocationUpdates();
      
    } catch (e) {
      debugPrint('❌ Error getting initial location: $e');
      // Try to get last known position as fallback
      try {
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _currentPosition = lastKnown;
            _lastStablePosition = lastKnown;
          });
          debugPrint('📍 Using last known location: ${lastKnown.latitude}, ${lastKnown.longitude}');
        }
      } catch (e2) {
        debugPrint('❌ Error getting last known location: $e2');
      }
    }
  }
  
  void _startLocationUpdates() {
    // Cancel existing subscription if any
    _locationSubscription?.cancel();
    
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium, // Balanced accuracy
      distanceFilter: 10, // Only update if moved 10+ meters
    );
    
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _handleLocationUpdate(position);
      },
      onError: (error) {
        debugPrint('❌ Location stream error: $error');
      },
    );
  }
  
  void _handleLocationUpdate(Position newPosition) {
    if (!mounted || _lastStablePosition == null) return;
    
    // Calculate distance from last stable position
    double distance = Geolocator.distanceBetween(
      _lastStablePosition!.latitude,
      _lastStablePosition!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );
    
    // Check time since last update
    DateTime now = DateTime.now();
    bool timeThresholdMet = now.difference(_lastLocationUpdate) >= _locationUpdateInterval;
    
    // Only update if significant movement or enough time has passed
    if (distance >= _minDistanceFilter || timeThresholdMet) {
      // Cancel existing stabilization timer
      _locationStabilizationTimer?.cancel();
      
      // Start stabilization timer to avoid rapid updates
      _locationStabilizationTimer = Timer(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _currentPosition = newPosition;
            _lastStablePosition = newPosition;
            _lastLocationUpdate = now;
          });
          
          debugPrint('📍 Location updated: ${newPosition.latitude}, ${newPosition.longitude} (moved ${distance.toStringAsFixed(1)}m)');
        }
      });
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
    
    try {
      // Load station pin image
      await station_Pin(controller);
      debugPrint('✅ Station pin image loaded successfully');
      
      // Add station pins and geofences
      int addedStations = 0;
      for (var station in _stationsLocal) {
        try {
          // Validate station coordinates before adding
          if (_isValidStationCoordinate(station.latitude, station.longitude)) {
            // Add station pin
            await controller.addSymbol(SymbolOptions(
              geometry: LatLng(station.latitude, station.longitude),
              iconImage: 'station_pin',
              iconSize: 0.2,
            ));

            // Add geofence circle polygon
            final circlePolygon = createCirclePolygon(
              LatLng(station.latitude, station.longitude),
              station.radius,
            );

            await controller.addFill(
              FillOptions(
                geometry: [circlePolygon],
                fillColor: '#FF0000',
                fillOpacity: 0.3,
              ),
            );
            
            addedStations++;
            debugPrint('✅ Added station pin: ${station.name} at (${station.latitude}, ${station.longitude})');
          } else {
            debugPrint('❌ Skipped station ${station.name} with invalid coordinates: (${station.latitude}, ${station.longitude})');
          }
        } catch (e) {
          debugPrint('❌ Error adding station ${station.name}: $e');
        }
      }
      
      debugPrint('📍 Successfully added $addedStations/${_stationsLocal.length} station pins to map');
      
      // Center map on user location if available
      if (_currentPosition != null) {
        controller.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0));
        debugPrint('📍 Map centered on user location');
      }
      
    } catch (e) {
      debugPrint('❌ Error in map creation: $e');
    }
  }

  /// Load stations from cache for offline usage
  Future<void> _loadOfflineStations() async {
    try {
      final offlineService = OfflineEmergencyService();
      final cached = await offlineService.getCachedStations();
      if (cached.isEmpty) {
        debugPrint('❌ No cached stations available for offline map.');
        return;
      }

      final loaded = <Station>[];
      for (final s in cached) {
        try {
          final lat = double.tryParse(s['latitude']?.toString() ?? '') ?? 0.0;
          final lng = double.tryParse(s['longitude']?.toString() ?? '') ?? 0.0;
          if (_isValidStationCoordinate(lat, lng)) {
            loaded.add(
              Station(
                id: (s['id'] ?? s['name'] ?? 'station').toString(),
                name: (s['name'] ?? 'Unknown Station').toString(),
                hotline: (s['hotline'] ?? 'No hotline').toString(),
                streetAddress: (s['streetAddress'] ?? s['address'] ?? '').toString(),
                city: (s['city'] ?? '').toString(),
                region: (s['region'] ?? '').toString(),
                latitude: lat,
                longitude: lng,
                radius: double.tryParse(s['radius']?.toString() ?? '500.0') ?? 500.0,
              ),
            );
          }
        } catch (e) {
          debugPrint('⚠️ Skipping cached station due to parse error: $e');
        }
      }

      if (mounted && loaded.isNotEmpty) {
        setState(() {
          _stationsLocal = loaded;
        });

        // If map is already created, add pins now
        if (_mapController != null) {
          int added = 0;
          for (var station in _stationsLocal) {
            try {
              await _mapController!.addSymbol(SymbolOptions(
                geometry: LatLng(station.latitude, station.longitude),
                iconImage: 'station_pin',
                iconSize: 0.2,
              ));
              final circlePolygon = createCirclePolygon(
                LatLng(station.latitude, station.longitude),
                station.radius,
              );
              await _mapController!.addFill(
                FillOptions(
                  geometry: [circlePolygon],
                  fillColor: '#FF0000',
                  fillOpacity: 0.3,
                ),
              );
              added++;
            } catch (e) {
              debugPrint('⚠️ Failed adding cached station pin: $e');
            }
          }
          debugPrint('📍 Added $added cached station pins while offline');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading offline stations: $e');
    }
  }
  
  /// Validate station coordinates
  bool _isValidStationCoordinate(double latitude, double longitude) {
    return latitude != 0.0 && 
           longitude != 0.0 && 
           latitude >= -90.0 && 
           latitude <= 90.0 && 
           longitude >= -180.0 && 
           longitude <= 180.0;
  }

  Future<void> station_Pin(MapLibreMapController controller) async {
    try {
      final ByteData byteData = await rootBundle.load('assets/images/station_pin.png');
      final Uint8List bytes = byteData.buffer.asUint8List();
      await controller.addImage('station_pin', bytes);
      debugPrint('✅ Station pin image loaded: ${bytes.length} bytes');
    } catch (e) {
      debugPrint('❌ Error loading station pin image: $e');
      // Try to load a fallback or create a simple colored circle
      try {
        // Create a simple red circle as fallback
        final fallbackIcon = await _createFallbackIcon();
        await controller.addImage('station_pin', fallbackIcon);
        debugPrint('✅ Fallback station pin created');
      } catch (e2) {
        debugPrint('❌ Error creating fallback icon: $e2');
        rethrow;
      }
    }
  }
  
  /// Create a simple red circle as fallback station pin
  Future<Uint8List> _createFallbackIcon() async {
    // This creates a simple red circle programmatically
    // In a real implementation, you might want to use a canvas or image library
    // For now, we'll create a minimal PNG-like structure
    return Uint8List.fromList([
      // This is a placeholder - in practice you'd generate a proper image
      0xFF, 0x00, 0x00, 0xFF, // Red pixel
    ]);
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
    _locationSubscription?.cancel();
    _locationStabilizationTimer?.cancel();
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
        myLocationTrackingMode: MyLocationTrackingMode.none, // Disable auto-tracking to prevent jittery movement
      ),
    );
  }
}
