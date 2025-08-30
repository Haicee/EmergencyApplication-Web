import 'dart:math';
import 'package:maplibre_gl/maplibre_gl.dart';

List<LatLng> createCirclePolygon(
    LatLng center, double radiusInMeters, {int points = 64}) {
  final List<LatLng> circlePoints = [];
  const double earthRadius = 6378137; // in meters

  final double lat = center.latitude * pi / 180;
  final double lon = center.longitude * pi / 180;

  for (int i = 0; i < points; i++) {
    final double bearing = 2 * pi * i / points;

    final double angularDistance = radiusInMeters / earthRadius;

    final double pointLat = asin(sin(lat) * cos(angularDistance) +
        cos(lat) * sin(angularDistance) * cos(bearing));

    final double pointLon = lon +
        atan2(sin(bearing) * sin(angularDistance) * cos(lat),
            cos(angularDistance) - sin(lat) * sin(pointLat));

    circlePoints.add(LatLng(pointLat * 180 / pi, pointLon * 180 / pi));
  }

  // Close the polygon by adding the first point at the end
  circlePoints.add(circlePoints.first);

  return circlePoints;
}
