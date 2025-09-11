/// Agora configuration constants for the emergency app
class AgoraConfig {
  // App ID for testing - replace with your actual App ID
  static const String appId = '7d2f10a871174d0cb736b6aa70aac070';
  
  // Channel name for testing
  static const String testChannelName = 'test_emergency_channel';
  
  // Production channel name (matches your Agora Console channel)
  static const String productionChannelName = 'EmergencyApp';
  
  // Token for production (should be generated server-side)
  static const String? productionToken = null; // Set to null for testing
  
  /// Get the appropriate channel name based on environment
  static String getChannelName({bool isTesting = true}) {
    return isTesting ? testChannelName : productionChannelName;
  }
  
  /// Get the appropriate token based on environment
  /// Returns empty string for testing (no token required)
  /// Returns production token for production use
  static String getToken({bool isTesting = true}) {
    return isTesting ? '' : (productionToken ?? '');
  }
}