import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';
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

class OfficerMapScreen extends StatefulWidget {
  final List<Station> stations;
  final String officerName;

  const OfficerMapScreen({
    Key? key,
    required this.stations,
    required this.officerName,
  }) : super(key: key);

  @override
  _OfficerMapScreenState createState() => _OfficerMapScreenState();
}

class _OfficerMapScreenState extends State<OfficerMapScreen> {
  MapLibreMapController? _mapController;
  final String _mapStyleUrl = 'https://api.maptiler.com/maps/streets-v2/style.json?key=VhMngqsXGbpDhosqRB2c';
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;
  
  // Current location
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  
  // Search result marker
  Symbol? _searchMarker;
  LatLng? _searchedLatLng;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _configureMapForOfflineUse();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
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

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Center map on current location if map is ready
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude), 
            14.0
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;
    await _loadMapAssets(controller);

    // Add station pins and geofences
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

    // Center map on current location if available, but don't add a pin
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
          14.0
        ),
      );
    } else if (widget.stations.isNotEmpty) {
      // Fallback to first station if no current location
      controller.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(widget.stations.first.latitude, widget.stations.first.longitude), 12.0));
    }
  }

  Future<void> _loadMapAssets(MapLibreMapController controller) async {
    // Load station pin
    final stationPinData = await rootBundle.load('assets/images/station_pin.png');
    final stationPinBytes = stationPinData.buffer.asUint8List();
    await controller.addImage('station_pin', stationPinBytes);
    
    // Load user pin for search results
    final userPinData = await rootBundle.load('assets/images/user_pin.png');
    final userPinBytes = userPinData.buffer.asUint8List();
    await controller.addImage('user_pin', userPinBytes);

    // Create a custom officer pin (blue version of user pin)
    await controller.addImage('officer_pin', userPinBytes);
  }

  void _searchCoordinates() {
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter coordinates'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final parts = searchText.split(',');
    if (parts.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid format. Use: latitude,longitude'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid coordinate numbers'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordinates out of valid range'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _addSearchMarker(lat, lng);
  }

  void _addSearchMarker(double lat, double lng) async {
    if (_mapController == null) return;

    // Remove previous search marker if exists
    if (_searchMarker != null) {
      try {
        await _mapController!.removeSymbol(_searchMarker!);
      } catch (e) {
        debugPrint('Error removing previous marker: $e');
      }
    }

    // Add new search marker
    final symbol = await _mapController!.addSymbol(SymbolOptions(
      geometry: LatLng(lat, lng),
      iconImage: 'user_pin',
      iconSize: 0.25,
      iconAnchor: "bottom",
    ));

    _searchMarker = symbol;

    // Animate to the searched location
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.0),
    );

    // Collapse search bar
    setState(() {
      _isSearchExpanded = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Location found: $lat, $lng'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Clear',
          textColor: Colors.white,
          onPressed: _clearSearchMarker,
        ),
      ),
    );

    setState(() {
      _searchedLatLng = LatLng(lat, lng);
    });
  }

  void _clearSearchMarker() async {
    if (_mapController != null && _searchMarker != null) {
      try {
        await _mapController!.removeSymbol(_searchMarker!);
        _searchMarker = null;
        _searchController.clear();
        setState(() {
          _searchedLatLng = null;
        });
      } catch (e) {
        debugPrint('Error clearing search marker: $e');
      }
    }
  }

  void _focusOnCurrentLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
          16.0
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location not available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _resetBearing() {
    _mapController?.animateCamera(CameraUpdate.bearingTo(0));
  }

  Future<void> _launchDirections() async {
    if (_searchedLatLng == null) return;

    final lat = _searchedLatLng!.latitude;
    final lng = _searchedLatLng!.longitude;
    
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open maps for directions.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isSearchExpanded ? 120 : 60,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
              });
            },
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search Coordinates',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Icon(
                  _isSearchExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color.fromARGB(255, 75, 84, 255),
                ),
              ],
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          hintText: 'Ex: 6.315735, 125.121748',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color.fromARGB(255, 75, 84, 255), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: _clearSearchMarker,
                                  tooltip: 'Clear search',
                                )
                              : null,
                        ),
                        onChanged: (text) => setState(() {}), // To rebuild and show clear icon
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _searchCoordinates,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 75, 84, 255),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Map'),
        backgroundColor: const Color.fromARGB(255, 75, 84, 255),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Map
          MapLibreMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : widget.stations.isNotEmpty
                      ? LatLng(widget.stations.first.latitude, widget.stations.first.longitude)
                      : const LatLng(12.8797, 121.7740), // Philippines center
              zoom: 14.0,
            ),
            styleString: _mapStyleUrl,
            myLocationEnabled: true,  
            myLocationTrackingMode: MyLocationTrackingMode.none,
            compassEnabled: false, // Disable compass for now
          ),
          
          // Search bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildSearchBar(),
          ),
          
          // Floating Action Buttons for Compass and Location
          Positioned(
            bottom: 80, // Adjust this value to position above the info panel
            right: 16,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _resetBearing,
                  tooltip: 'Reset Compass',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color.fromARGB(255, 75, 84, 255),
                  child: const Icon(Icons.explore_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  onPressed: _focusOnCurrentLocation,
                  tooltip: 'My Location',
                  backgroundColor: const Color.fromARGB(255, 75, 84, 255),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // Info panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white.withOpacity(0.95),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: const Color.fromARGB(255, 75, 84, 255)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Red areas: Station coverage | Red pins: Police stations | Orange pin: Search result',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isLoadingLocation)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Getting your location...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_searchedLatLng != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Searched Location:',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                                ),
                                Text(
                                  '${_searchedLatLng!.latitude.toStringAsFixed(6)}, ${_searchedLatLng!.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _launchDirections,
                            icon: const Icon(Icons.directions, size: 18),
                            label: const Text('Directions'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
