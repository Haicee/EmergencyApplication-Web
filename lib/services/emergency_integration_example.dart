import 'package:flutter/material.dart';
import 'emergency_mode_service.dart';
import 'offline_emergency_service.dart';

class EmergencyIntegrationExample extends StatefulWidget {
  final String userName;
  
  const EmergencyIntegrationExample({
    Key? key,
    required this.userName,
  }) : super(key: key);

  @override
  _EmergencyIntegrationExampleState createState() => _EmergencyIntegrationExampleState();
}

class _EmergencyIntegrationExampleState extends State<EmergencyIntegrationExample> {
  final EmergencyModeService _emergencyModeService = EmergencyModeService();
  final OfflineEmergencyService _offlineService = OfflineEmergencyService();
  
  bool _isEmergencyInProgress = false;
  String _statusMessage = '';
  EmergencyMode? _currentMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency System Demo'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Display
            if (_statusMessage.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _currentMode == EmergencyMode.offline 
                      ? Colors.orange[50] 
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _currentMode == EmergencyMode.offline 
                        ? Colors.orange 
                        : Colors.blue,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _currentMode == EmergencyMode.offline 
                              ? Icons.sms 
                              : Icons.call,
                          color: _currentMode == EmergencyMode.offline 
                              ? Colors.orange 
                              : Colors.blue,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _currentMode == EmergencyMode.offline 
                              ? 'OFFLINE MODE' 
                              : 'ONLINE MODE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _currentMode == EmergencyMode.offline 
                                ? Colors.orange[800] 
                                : Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(_statusMessage),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],

            // Emergency Buttons
            _buildEmergencyButton(
              title: 'EMERGENCY CALL',
              subtitle: 'Automatic mode detection',
              icon: Icons.emergency,
              color: Colors.red,
              onPressed: _isEmergencyInProgress ? null : _handleAutomaticEmergency,
            ),
            
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildEmergencyButton(
                    title: 'FORCE SMS',
                    subtitle: 'Test offline mode',
                    icon: Icons.sms,
                    color: Colors.orange,
                    onPressed: _isEmergencyInProgress ? null : _handleOfflineEmergency,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildEmergencyButton(
                    title: 'FORCE CALL',
                    subtitle: 'Test online mode',
                    icon: Icons.call,
                    color: Colors.blue,
                    onPressed: _isEmergencyInProgress ? null : _handleOnlineEmergency,
                  ),
                ),
              ],
            ),

            SizedBox(height: 32),

            // Mode Selection Button
            ElevatedButton.icon(
              onPressed: _isEmergencyInProgress ? null : _showModeSelectionDialog,
              icon: Icon(Icons.settings),
              label: Text('Choose Emergency Mode'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            SizedBox(height: 16),

            // Connection Status
            FutureBuilder<bool>(
              future: _offlineService.hasInternetConnection(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  bool hasConnection = snapshot.data!;
                  return Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasConnection ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasConnection ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasConnection ? Icons.wifi : Icons.wifi_off,
                          color: hasConnection ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text(
                          hasConnection 
                              ? 'Internet Connected - Voice calls available'
                              : 'No Internet - SMS mode will be used',
                          style: TextStyle(
                            color: hasConnection ? Colors.green[800] : Colors.red[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return CircularProgressIndicator();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
               
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAutomaticEmergency() async {
    setState(() {
      _isEmergencyInProgress = true;
      _statusMessage = 'Detecting connection and initiating emergency...';
    });

    try {
      Map<String, dynamic> result = await _emergencyModeService.quickEmergencyCall(
        userName: widget.userName,
        additionalInfo: 'Emergency call from mobile app',
      );

      setState(() {
        _isEmergencyInProgress = false;
        _statusMessage = result['message'] ?? 'Emergency processed';
        _currentMode = result['mode'] == 'offline' 
            ? EmergencyMode.offline 
            : EmergencyMode.online;
      });

      // If online mode was selected, you would navigate to your existing Agora call screen here
      if (result['useAgoraCall'] == true) {
        _showOnlineModeMessage();
      }

    } catch (e) {
      setState(() {
        _isEmergencyInProgress = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _handleOfflineEmergency() async {
    setState(() {
      _isEmergencyInProgress = true;
      _statusMessage = 'Sending emergency SMS...';
    });

    try {
      Map<String, dynamic> result = await _emergencyModeService.forceOfflineEmergency(
        userName: widget.userName,
        additionalInfo: 'Test offline emergency',
      );

      setState(() {
        _isEmergencyInProgress = false;
        _statusMessage = result['message'] ?? 'SMS emergency processed';
        _currentMode = EmergencyMode.offline;
      });

    } catch (e) {
      setState(() {
        _isEmergencyInProgress = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _handleOnlineEmergency() async {
    setState(() {
      _isEmergencyInProgress = true;
      _statusMessage = 'Initiating voice call...';
    });

    try {
      Map<String, dynamic> result = await _emergencyModeService.forceOnlineEmergency(
        userName: widget.userName,
        additionalInfo: 'Test online emergency',
      );

      setState(() {
        _isEmergencyInProgress = false;
        _statusMessage = result['message'] ?? 'Voice call emergency processed';
        _currentMode = EmergencyMode.online;
      });

      _showOnlineModeMessage();

    } catch (e) {
      setState(() {
        _isEmergencyInProgress = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _showModeSelectionDialog() async {
    EmergencyMode? selectedMode = await _emergencyModeService.showEmergencyModeDialog(context);
    
    if (selectedMode != null) {
      setState(() {
        _statusMessage = 'Selected mode: ${selectedMode == EmergencyMode.online ? 'Voice Call' : 'SMS Alert'}';
        _currentMode = selectedMode;
      });
    }
  }

  void _showOnlineModeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('In a real app, this would navigate to your Agora voice call screen'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
