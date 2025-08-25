# Agora Configuration

This directory contains configuration files for the Agora RTC (Real-Time Communication) integration.

## Files

- `agora_config.dart` - Centralized Agora configuration constants

## Configuration

### Testing Mode
- **App ID**: `5b4c251d850a452d9783de64d8f098d4` 
- **Channel Name**: `test_emergency_channel`
- **Token**: Empty string `''` (no token required for testing)

### Production Mode
- **App ID**: Your production App ID
- **Channel Name**: `emergency`
- **Token**: Server-generated token (for security)

## Usage

```dart
import 'utils/agora_config.dart';

// For testing
final channelName = AgoraConfig.getChannelName(isTesting: true);
final token = AgoraConfig.getToken(isTesting: true); // Returns empty string

// For production
final channelName = AgoraConfig.getChannelName(isTesting: false);
final token = AgoraConfig.getToken(isTesting: false); // Returns production token
```

## Security Notes

- Never commit real App IDs or tokens to version control
- Use environment variables for production credentials
- Generate tokens server-side for production use
- Testing mode should only be used in development