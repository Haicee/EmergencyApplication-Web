/// Agora configuration constants for the emergency app
class AgoraConfig {
  // App ID for testing - replace with your actual App ID
  static const String appId = '5b4c251d850a452d9783de64d8f098d4';
  
  // Channel name for testing
  static const String testChannelName = 'test_emergency_channel';
  
  // Production channel name (when using tokens)
  static const String productionChannelName = 'emergency';
  
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