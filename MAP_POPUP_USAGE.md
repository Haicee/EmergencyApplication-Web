# Map Popup Usage Guide

## Overview
The MapScreen has been converted from a full-screen navigation to a popup overlay with smooth animations. This prevents navigation issues when emergency calls end unexpectedly and provides a better user experience.

## Key Benefits
1. **No Navigation Issues**: Prevents citizens from getting stuck when officers end calls first
2. **Smooth Animations**: Slide-up animation from bottom with fade-in backdrop
3. **Better UX**: Map appears as an overlay without losing context of the emergency call
4. **Easy Dismissal**: Tap backdrop or close button to dismiss
5. **Responsive Design**: Adapts to different screen sizes

## Usage

### Basic Popup Display
```dart
// Show map popup with locations
showMapPopup(
  context: context,
  citizenLocation: _citizenLocation,
  stationLocation: _stationLocation,
);
```

### Direct MapScreen Usage
```dart
// For custom implementations
MapScreen(
  stationLocation: stationLocation,
  citizenLocation: citizenLocation,
  onClose: () {
    // Custom close logic
    Navigator.of(context).pop();
  },
)
```

## Features

### Animation
- **Slide Animation**: Map slides up from bottom (300ms duration)
- **Fade Animation**: Backdrop fades in (250ms duration)
- **Smooth Curves**: Uses `Curves.easeOutCubic` for natural motion

### Interactive Elements
- **Backdrop Tap**: Tap outside map to close
- **Expand Button**: Fullscreen button in top-right corner to view map in full screen
- **My Location**: Button to center map on user's location
- **Close Button**: Bottom button for easy dismissal

### Responsive Design
- **Width**: Screen width minus 40px margin
- **Height**: 70% of screen height
- **Margins**: 20px on all sides
- **Border Radius**: 16px rounded corners

## Implementation Details

### Required Imports
```dart
import 'screens/map_screen.dart';
```

### Dependencies
The popup map requires the following Flutter packages:
- `maplibre_gl` for mapping
- `geolocator` for location services
- `permission_handler` for location permissions

### Error Handling
- Graceful fallback to default location (Manila) if GPS fails
- Permission request handling with user feedback
- Image loading error handling for map pins

## Customization

### Animation Duration
```dart
// In _initAnimations() method
_slideController = AnimationController(
  duration: const Duration(milliseconds: 300), // Adjust timing
  vsync: this,
);
```

### Map Style
```dart
// Change map style URL
styleString: 'https://api.maptiler.com/maps/streets-v2/style.json?key=YOUR_KEY'
```

### Colors and Styling
```dart
// Customize popup appearance
decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(16), // Adjust corner radius
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.3), // Adjust shadow
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ],
),
```

## Troubleshooting

### Common Issues
1. **Map not loading**: Check internet connection and API key
2. **Location not working**: Ensure location permissions are granted
3. **Animation glitches**: Verify TickerProviderStateMixin is implemented

### Performance Tips
1. **Dispose controllers**: Always dispose animation controllers
2. **Memory management**: Map controller is properly disposed
3. **Efficient rebuilds**: Use setState only when necessary

## Migration from Full-Screen

### Before (Full-Screen Navigation)
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MapScreen(
      citizenLocation: _citizenLocation,
      stationLocation: _stationLocation,
    ),
  ),
);
```

### After (Popup Overlay)
```dart
showMapPopup(
  context: context,
  citizenLocation: _citizenLocation,
  stationLocation: _stationLocation,
);
```

## Future Enhancements
1. **Custom Map Markers**: Add different icons for different location types
2. **Route Display**: Show route between citizen and station
3. **Real-time Updates**: Live location updates during emergency
4. **Offline Maps**: Cache map data for offline use
5. **Accessibility**: Voice navigation and screen reader support
