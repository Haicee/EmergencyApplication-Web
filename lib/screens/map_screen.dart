import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  final LatLng? stationLocation;
  final LatLng? citizenLocation;

  const MapScreen({Key? key, this.stationLocation, this.citizenLocation}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MaplibreMapController? _mapController;
  LatLng? _currentLocation;
  bool _isLoading = true;
  final LatLng _defaultLocation = const LatLng(14.5995, 120.9842); // Manila

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      final result = await Permission.location.request();
      if (result.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to show the map.'),
            ),
          );
        }
        setState(() {
          _isLoading = false;
          _currentLocation = _defaultLocation;
        });
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      
      if (_mapController != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 14.0),
        );
        // Marker is now added in _onMapCreated to avoid duplicates
      }
    } catch (e) {
      setState(() {
        _currentLocation = _defaultLocation;
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(MaplibreMapController controller) async {
    _mapController = controller;
    await _addPinImage();

    

    if (widget.stationLocation != null) {
      _addStationMarker(widget.stationLocation!); // Add station marker
    }
  }

  Future<void> _addPinImage() async {
    final ByteData byteData = await rootBundle.load('assets/images/Pin - Copy.png');
    final Uint8List uint8List = byteData.buffer.asUint8List();
    await _mapController?.addImage('pin_icon', uint8List);
  }

  void _addStationMarker(LatLng stationLocation) {
    _mapController?.addSymbol(
      SymbolOptions(
        geometry: stationLocation,
        iconImage: 'pin_icon',
        iconSize: 0.2, // Adjust size as needed
      ),
    );
  }
  
  void _onMyLocationPressed() {
    if (_currentLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _onMyLocationPressed,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : MaplibreMap(
              styleString: 'https://api.maptiler.com/maps/streets-v2/style.json?key=VhMngqsXGbpDhosqRB2c',
              initialCameraPosition: CameraPosition(
                target: widget.citizenLocation ?? _currentLocation ?? _defaultLocation,
                zoom: 14.0,
              ),
              onMapCreated: _onMapCreated,
              myLocationEnabled: true,
            ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
