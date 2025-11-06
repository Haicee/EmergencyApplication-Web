# Offline Routing Setup Guide

## Overview
This guide explains how to set up offline routing for the ResMe Emergency Application using OSRM (Open Source Routing Machine).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Client)                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Routing Service (routing_service.dart)                │ │
│  │  - Detects online/offline status                       │ │
│  │  - Routes to appropriate OSRM server                   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↓
              ┌─────────────┴─────────────┐
              ↓                           ↓
    ┌─────────────────┐         ┌─────────────────┐
    │  Online Mode    │         │  Offline Mode   │
    │  Public OSRM    │         │  Local OSRM     │
    │  (Internet)     │         │  (Your Server)  │
    └─────────────────┘         └─────────────────┘
              ↓                           ↓
    router.project-osrm.org     http://your-server:5000
                                          ↓
                                ┌─────────────────┐
                                │  OSM Map Data   │
                                │  (Philippines)  │
                                │  ~200-500 MB    │
                                └─────────────────┘
```

---

## Option 1: OSRM Server Setup (Recommended)

### Prerequisites
- Linux server (Ubuntu 20.04+ recommended) or Docker
- 4GB+ RAM
- 10GB+ disk space
- Node.js/Express backend (you already have this!)

### Step 1: Download Philippines Map Data

```bash
# Download OSM data for Philippines
wget https://download.geofabrik.de/asia/philippines-latest.osm.pbf

# Or for General Santos City only (smaller file)
wget https://download.geofabrik.de/asia/philippines/mindanao-latest.osm.pbf
```

**File sizes:**
- Philippines: ~200-500 MB
- Mindanao: ~50-100 MB

### Step 2: Install OSRM (Docker Method - Easiest)

```bash
# Pull OSRM Docker image
docker pull osrm/osrm-backend

# Process the map data (this takes 5-15 minutes)
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-extract -p /opt/car.lua /data/philippines-latest.osm.pbf

# Prepare for routing
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-partition /data/philippines-latest.osrm
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-customize /data/philippines-latest.osrm

# Start OSRM server
docker run -t -i -p 5000:5000 -v "${PWD}:/data" osrm/osrm-backend osrm-routed --algorithm mld /data/philippines-latest.osrm
```

### Step 3: Test Your OSRM Server

```bash
# Test route calculation (General Santos City coordinates)
curl "http://localhost:5000/route/v1/driving/125.1364543,6.0904102;125.1515027,6.1017131?overview=full&geometries=polyline"
```

You should get a JSON response with route data!

### Step 4: Deploy to Production

**Option A: Same Server as Backend**
- Run OSRM on your Express backend server
- Access via `http://your-backend-server:5000`

**Option B: Separate Server**
- Run OSRM on dedicated server
- Better performance for multiple users

**Option C: Cloud Hosting**
- AWS EC2, Google Cloud, DigitalOcean
- Use Docker for easy deployment

---

## Option 2: GraphHopper On-Device (Advanced)

### Prerequisites
- Android native development knowledge
- Flutter platform channels

### Implementation
1. Add GraphHopper Android SDK to your project
2. Download map data to device storage
3. Create Flutter platform channel to call GraphHopper
4. Handle routing on device

**Pros:** No server needed, truly offline
**Cons:** Complex integration, large app size

---

## Code Changes Required

### Update `routing_service.dart`

```dart
class RoutingService {
  // Add configuration for offline OSRM
  static const String _onlineOsrmUrl = 'https://router.project-osrm.org';
  static const String _offlineOsrmUrl = 'http://YOUR_SERVER_IP:5000'; // Your OSRM server
  
  // Detect which server to use
  Future<String> _getOsrmBaseUrl() async {
    // Check if device has internet
    final hasInternet = await _checkInternetConnection();
    
    if (hasInternet) {
      // Try online OSRM first
      try {
        final response = await http.get(
          Uri.parse('$_onlineOsrmUrl/route/v1/driving/125.1,6.1;125.2,6.2'),
        ).timeout(Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          return _onlineOsrmUrl; // Online OSRM works
        }
      } catch (e) {
        debugPrint('Online OSRM unavailable, trying offline...');
      }
    }
    
    // Try offline OSRM
    try {
      final response = await http.get(
        Uri.parse('$_offlineOsrmUrl/route/v1/driving/125.1,6.1;125.2,6.2'),
      ).timeout(Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        return _offlineOsrmUrl; // Offline OSRM works
      }
    } catch (e) {
      debugPrint('Offline OSRM unavailable: $e');
    }
    
    // Both failed, will use Haversine fallback
    throw Exception('No OSRM server available');
  }
  
  Future<Map<String, dynamic>?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    Duration? timeout,
  }) async {
    try {
      // Get appropriate OSRM URL
      final baseUrl = await _getOsrmBaseUrl();
      
      // Rest of your existing code...
      final url = '$baseUrl/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=polyline';
      
      // ... existing implementation
    } catch (e) {
      debugPrint('❌ OSRM routing failed: $e');
      return null; // Will trigger Haversine fallback
    }
  }
}
```

---

## Configuration

### Add to `pubspec.yaml` (if needed)

```yaml
# No new dependencies needed for OSRM server approach!
# Your existing http package works fine
```

### Add Server URL to Environment Config

Create `lib/config/routing_config.dart`:

```dart
class RoutingConfig {
  // Online OSRM (public)
  static const String onlineOsrmUrl = 'https://router.project-osrm.org';
  
  // Offline OSRM (your server)
  // Update this with your actual server IP/domain
  static const String offlineOsrmUrl = 'http://192.168.1.100:5000'; // Local network
  // static const String offlineOsrmUrl = 'https://osrm.yourdomain.com'; // Production
  
  // Fallback timeout settings
  static const Duration onlineTimeout = Duration(seconds: 10);
  static const Duration offlineTimeout = Duration(seconds: 5);
}
```

---

## Testing Checklist

### Online Mode
- [ ] Connect to internet
- [ ] Trigger emergency call
- [ ] Verify uses public OSRM
- [ ] Check routing accuracy

### Offline Mode (Local OSRM)
- [ ] Disconnect from internet
- [ ] Ensure local OSRM server is running
- [ ] Trigger emergency call
- [ ] Verify uses local OSRM
- [ ] Check routing accuracy

### Fallback Mode
- [ ] Disconnect from internet
- [ ] Stop local OSRM server
- [ ] Trigger emergency call
- [ ] Verify uses Haversine fallback
- [ ] Check distance calculation

---

## Maintenance

### Updating Map Data

```bash
# Download latest Philippines map (monthly recommended)
wget https://download.geofabrik.de/asia/philippines-latest.osm.pbf

# Reprocess the data
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-extract -p /opt/car.lua /data/philippines-latest.osm.pbf
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-partition /data/philippines-latest.osrm
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-customize /data/philippines-latest.osrm

# Restart OSRM server
docker restart osrm-server
```

### Monitoring

```bash
# Check OSRM server status
curl http://localhost:5000/route/v1/driving/125.1,6.1;125.2,6.2

# Check server logs
docker logs osrm-server

# Monitor resource usage
docker stats osrm-server
```

---

## Cost Analysis

### OSRM Server Hosting

**Option 1: Self-hosted (Existing Server)**
- Cost: $0 (use your existing backend server)
- Storage: ~1-2 GB for Philippines data
- RAM: +1-2 GB

**Option 2: Cloud Server**
- DigitalOcean Droplet: $12-24/month (2GB RAM)
- AWS EC2 t3.small: ~$15/month
- Google Cloud e2-small: ~$13/month

**Option 3: Serverless (AWS Lambda + EFS)**
- More complex setup
- Pay per request
- Good for low traffic

### Comparison with Alternatives

| Solution | Setup Cost | Monthly Cost | Complexity |
|----------|-----------|--------------|------------|
| OSRM Server | Low | $0-24 | Low |
| GraphHopper On-Device | High | $0 | High |
| Mapbox Offline | Low | $50-500+ | Low |
| Current (Online Only) | None | $0 | None |

---

## Recommended Approach for Your App

### Phase 1: Quick Win (1-2 hours)
1. Set up OSRM Docker on your backend server
2. Update `routing_service.dart` with offline URL
3. Test with local network

### Phase 2: Production (1 day)
1. Deploy OSRM to production server
2. Add proper error handling
3. Implement smart fallback logic
4. Test all scenarios

### Phase 3: Optimization (optional)
1. Add route caching for offline mode
2. Implement map data auto-updates
3. Monitor performance metrics

---

## Benefits for Emergency Response

✅ **Reliability:** Works even if internet fails
✅ **Speed:** Local routing is faster (50-200ms vs 500-1000ms)
✅ **Accuracy:** Road-based routing in offline mode
✅ **Cost:** Free and open source
✅ **Control:** You own the infrastructure
✅ **Privacy:** Routes calculated on your server

---

## Support & Resources

- OSRM Documentation: https://project-osrm.org/
- OSM Data Downloads: https://download.geofabrik.de/
- Docker Hub: https://hub.docker.com/r/osrm/osrm-backend
- Community: https://github.com/Project-OSRM/osrm-backend

---

## Next Steps

1. **Decide on hosting:** Use existing backend or separate server?
2. **Set up OSRM:** Follow Docker setup above
3. **Update code:** Implement smart server selection
4. **Test thoroughly:** All three modes (online, offline, fallback)
5. **Deploy:** Push to production
6. **Monitor:** Track performance and errors

**Estimated implementation time:** 2-4 hours for basic setup, 1 day for production-ready
