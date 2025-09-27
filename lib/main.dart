import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'registration.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'homepage.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'deskOfficer/doHomepage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'responders/resHompage.dart';

Future<void> main() async {
  try {
    // Ensure Flutter is initialized
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).whenComplete(() => print('Firebase Initialized'));
    
    runApp(MyApp());
  } catch (e) {
    print('Error initializing Firebase: $e');
    // If Firebase is already initialized, just run the app
    if (e.toString().contains('duplicate-app')) {
      runApp(MyApp());
    } else {
      rethrow;
    }
  }
}

class MyApp extends StatelessWidget
{
  const MyApp({super.key});

    @override
    Widget build(BuildContext context)
    {
      return MaterialApp
      (
        title: 'Emergency App',
        debugShowCheckedModeBanner: false,
        home: SplashScreen(), // Start with splash screen to check login state

      );
    }
}

// Splash Screen to check login state
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedUsername = prefs.getString('username');
      final String? savedUserType = prefs.getString('userType');
      
      // Add a small delay for splash effect
      await Future.delayed(Duration(seconds: 2));
      
      if (savedUsername != null && savedUsername.isNotEmpty) {
        // User is already logged in, navigate to appropriate homepage
        if (savedUserType == 'deskOfficer') {
          final String? officerId = prefs.getString('officerId');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DeskOfficerHomePage(
                username: savedUsername,
                officerId: officerId ?? '',
              ),
            ),
          );
        } else if (savedUserType == 'responder') {
          final String? responderId = prefs.getString('responderId');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResponderHomePage(
                username: savedUsername,
                responderId: responderId ?? '',
              ),
            ),
          );
        } else {
          // Regular user - go to citizen homepage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(username: savedUsername),
            ),
          );
        }
      } else {
        // No saved login, go to login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      }
    } catch (e) {
      print('Error checking login state: $e');
      // On error, go to login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE74C3C),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                Icons.security,
                size: 50,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Emergency App',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Fast Emergency Response',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget
{
  const LoginPage({super.key});

    @override
    LoginPageDetails createState() => LoginPageDetails();
}

class LoginPageDetails extends State<LoginPage>
{
    final TextEditingController fullname = TextEditingController();
    final TextEditingController password = TextEditingController();
    bool isConnected = true;
    bool isLocationEnabled = false;
    bool isMicrophoneEnabled = false;

    // Track if dialogs are already showing to prevent duplicates
    bool _isShowingLocationDialog = false;
    bool _isShowingMicrophoneDialog = false;
    bool _isShowingConnectionDialog = false;

    @override
    void initState()
    {
      super.initState();
      // Reset dialog flags on initialization
      _isShowingLocationDialog = false;
      _isShowingMicrophoneDialog = false;
      _isShowingConnectionDialog = false;
      
      // Initialize permissions and connectivity
      _initializePermissions();
      // Listen to connectivity changes
      Connectivity().onConnectivityChanged.listen((ConnectivityResult result)
      {
        setState(()
        {
          isConnected = result != ConnectivityResult.none;
        });
      });
    }

    // Initialize all permissions and connectivity status
    Future<void> _initializePermissions() async {
      await checkConnectivity();
      await _checkLocationPermissionStatus();
      await _checkMicrophonePermissionStatus();
    }

    // Check current location permission status without requesting
    Future<void> _checkLocationPermissionStatus() async {
      LocationPermission permission = await Geolocator.checkPermission();
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      setState(() {
        // Only enable if both permission is granted AND location services are enabled
        isLocationEnabled = (permission == LocationPermission.whileInUse || 
                           permission == LocationPermission.always) && 
                           serviceEnabled;
      });
    }

    // Check current microphone permission status without requesting
    Future<void> _checkMicrophonePermissionStatus() async {
      PermissionStatus status = await Permission.microphone.status;
      
      setState(() {
        isMicrophoneEnabled = status.isGranted;
      });
    }

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      // Show dialogs automatically when there are issues (only if not already showing)
      // This ensures dialogs appear in the correct order: Connection -> Location -> Microphone
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Recheck permissions before showing dialogs to ensure accurate state
        await _checkLocationPermissionStatus();
        await _checkMicrophonePermissionStatus();
        
        if (!isConnected && !_isShowingConnectionDialog) {
          _showConnectionDialog();
        } else if (isConnected && !isLocationEnabled && !_isShowingLocationDialog) {
          _showLocationDialog();
        } else if (isConnected && isLocationEnabled && !isMicrophoneEnabled && !_isShowingMicrophoneDialog) {
          _showMicrophoneDialog();
        }
      });
    }

    // Check internet connectivity and update state
    Future<void> checkConnectivity() async
    {
      var connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        isConnected = connectivityResult != ConnectivityResult.none;
        // Reset dialog flag when connection is restored
        if (isConnected) {
          _isShowingConnectionDialog = false;
        }
      });
    }

    // Show modern popup dialog for connection status
    void _showConnectionDialog() {
      // Prevent duplicate dialogs
      if (_isShowingConnectionDialog) return;
      _isShowingConnectionDialog = true;
      
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissal by tapping outside
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 10,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                   Color.fromARGB(255, 255, 52, 38),
                    Color.fromARGB(255, 255, 98, 77),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi_off,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No Internet Connection",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Please check your connection and try again",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _isShowingConnectionDialog = false; // Reset flag when dialog is closed
                            checkConnectivity();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Color.fromARGB(255, 255, 67, 67),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Retry",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Show modern popup dialog for location permission
    void _showLocationDialog() {
      // Prevent duplicate dialogs
      if (_isShowingLocationDialog) return;
      _isShowingLocationDialog = true;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 10,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 255, 52, 38),
                    Color.fromARGB(255, 255, 98, 77),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Location Permission Required",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "This app needs location access for emergency services",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _isShowingLocationDialog = false; // Reset flag when dialog is closed
                            requestLocationPermission();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Color.fromARGB(255, 255, 67, 67),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Grant Permission",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Show modern popup dialog for microphone permission
    void _showMicrophoneDialog() {
      // Prevent duplicate dialogs
      if (_isShowingMicrophoneDialog) return;
      _isShowingMicrophoneDialog = true;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 10,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 255, 52, 38),
                    Color.fromARGB(255, 255, 98, 77),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Microphone Permission Required",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "This app needs microphone access for voice calls",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _isShowingMicrophoneDialog = false; // Reset flag when dialog is closed
                            requestMicrophonePermission();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Color.fromARGB(255, 255, 67, 67),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Grant Permission",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Request location permission with proper state management
    Future<void> requestLocationPermission() async
    {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show system dialog to enable location services
        await Geolocator.openLocationSettings();
        // Check again after user returns from settings
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          // If still not enabled, show dialog and close app
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Location Required'),
                content: Text('This app requires location services to function. Please enable location services to continue.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('CLOSE'),
                  ),
                ],
              );
            },
          );
          return;
        }
      }

      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        // After requesting, check the status again
        await Future.delayed(Duration(milliseconds: 500)); // Small delay to ensure permission is processed
        permission = await Geolocator.checkPermission();
        
        if (permission == LocationPermission.denied) {
          // Show dialog and close app if permission denied
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Permission Required'),
                content: Text('This app requires location permission to function. Please grant location permission to continue.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      SystemNavigator.pop(); // Close the app
                    },
                    child: Text('CLOSE APP'),
                  ),
                ],
              );
            },
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Show dialog and close app if permission permanently denied
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Permission Required'),
              content: Text('Location permission has been permanently denied. Please enable it in app settings to use this app.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('CLOSE'),
                ),
                TextButton(
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                  },
                  child: Text('OPEN SETTINGS'),
                ),
              ],
            );
          },
        );
        return;
      }

      // If we get here, location permission is granted
      setState(() {
        isLocationEnabled = true;
        _isShowingLocationDialog = false; // Reset dialog flag when permission is granted
      });
      
      // Recheck all permissions to ensure proper state
      await _checkLocationPermissionStatus();
    }

    // Request microphone permission with proper state management
    Future<void> requestMicrophonePermission() async {
      // Check microphone permission status
      PermissionStatus status = await Permission.microphone.status;
      
      if (status.isDenied) {
        // Request microphone permission
        status = await Permission.microphone.request();
        // After requesting, check the status again
        await Future.delayed(Duration(milliseconds: 500)); // Small delay to ensure permission is processed
        status = await Permission.microphone.status;
        
        if (status.isDenied) {
          // Show dialog if permission denied
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Microphone Permission Required'),
                content: Text('This app requires microphone permission for voice calls. Please grant microphone permission to continue.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      SystemNavigator.pop(); // Close the app
                    },
                    child: Text('CLOSE APP'),
                  ),
                ],
              );
            },
          );
          return;
        }
      }

      if (status.isPermanentlyDenied) {
        // Show dialog if permission permanently denied
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Microphone Permission Required'),
              content: Text('Microphone permission has been permanently denied. Please enable it in app settings to use voice calls.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('CLOSE'),
                ),
                TextButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  child: Text('OPEN SETTINGS'),
                ),
              ],
            );
          },
        );
        return;
      }

      // If we get here, microphone permission is granted
      setState(() {
        isMicrophoneEnabled = true;
        _isShowingMicrophoneDialog = false; // Reset dialog flag when permission is granted
      });
      
      // Recheck all permissions to ensure proper state
      await _checkMicrophonePermissionStatus();
    }

    @override
    void dispose()
    {
        fullname.dispose();
        password.dispose();
        // Reset all dialog flags when disposing
        _isShowingLocationDialog = false;
        _isShowingMicrophoneDialog = false;
        _isShowingConnectionDialog = false;
        super.dispose();
    }
    
    // creating ui
    @override
    Widget build(BuildContext context)
    {
      return Scaffold
      (
        backgroundColor: const Color.fromARGB(255, 226, 100, 100),  //sets the backgroud color
        body: Container
        (
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(255, 231, 45, 42),
                      Color.fromARGB(255, 236, 113, 109),
                      Color.fromARGB(255, 247, 76, 76),
                    ]
                )
            ),
        



        child: GestureDetector
        (
          onTap: ()  // unfocus when tapping outside of text field
          {
            FocusScope.of(context).unfocus();
          },
        
            child: Center
            (
              child: SingleChildScrollView
              (
                child: Padding
                (
                  padding: const EdgeInsets.all(20.0), // space around the content
                  child: Column
                  (
                    mainAxisAlignment: MainAxisAlignment.center,  //center vertically
                    crossAxisAlignment: CrossAxisAlignment.stretch, // para mag full width
                    
                    children: 
                    [
                        // Status indicator buttons that show dialogs when pressed
                        // Removed interactive buttons as they are now shown automatically

                      FlutterLogo(size: 100),  // logo sa emergency ni sample
                      SizedBox(height: 40),  // space between logo and input

                      Text  // Welcome text
                      (
                        "Welcome",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white,),
                        
                      ),

                      Text // description
                      (
                        "An Emergency Mobile App",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.white,),

                      ),
                      SizedBox(height: 50),

                      
                      TextField  // for name TextField (fullname)
                      (
                        controller: fullname,
                        decoration: InputDecoration(labelText: "Enter your name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person), filled: true, fillColor: const Color.fromARGB(174, 255, 255, 255)), // design textfield and icon
                        textCapitalization: TextCapitalization.words,
                      
                      ),
                      SizedBox(height: 20), // space between name and password

                      
                      TextField  // for password  (password)
                      (
                        controller: password,
                        obscureText: true,  // hides password input
                        decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock), filled: true, fillColor: const Color.fromARGB(174, 255, 255, 255)) // password styling

                      ),
                      SizedBox(height: 15),

                      ElevatedButton  // login button
                        (
                          onPressed: () async
                          {
                            if (!isConnected) {
                              _showConnectionDialog();
                              return;
                            }

                            // Force refresh permission status before checking
                            await _checkLocationPermissionStatus();
                            await _checkMicrophonePermissionStatus();

                            if (!isLocationEnabled) {
                              await requestLocationPermission();
                              return;
                            }

                            if (!isMicrophoneEnabled) {
                              await requestMicrophonePermission();
                              return;
                            }

                            String username = fullname.text;
                            String userPassword = password.text;

                            if (username.isEmpty || userPassword.isEmpty) {
                              showDialog
                              (
                                  context: context, 
                                  builder: (context) => AlertDialog(
                                      title: Text("Enter credentials"),
                                      titleTextStyle: TextStyle(
                                        fontSize: 25, 
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.black
                                      ),
                                      content: Text("Please make sure your credentials are entered."),
                                      contentTextStyle: TextStyle(
                                        fontSize: 19, 
                                        color: const Color.fromARGB(255, 51, 50, 50)
                                      ),
                                      actions:[
                                          TextButton(
                                              onPressed: () => Navigator.pop(context), 
                                              child: Text("Try Again")
                                          )
                                      ],
                                      actionsPadding: EdgeInsets.only(bottom: 10, right: 15),
                                  )
                              );
                              return;
                            }

                            // 0. Centralized Auth: Check AuthAccounts first (role-based)
                            try {
                              final authRef = FirebaseDatabase.instance.ref().child('AuthAccounts').child(username);
                              final authSnap = await authRef.get();
                              if (authSnap.exists && authSnap.value is Map) {
                                final authData = Map<String, dynamic>.from(authSnap.value as Map);
                                final storedPassword = authData['password']?.toString() ?? '';
                                final role = (authData['role']?.toString() ?? '').toLowerCase();

                                if (storedPassword == userPassword) {
                                  // Save basic session
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('username', username);

                                  if (role == 'citizen') {
                                    await prefs.setString('userType', 'citizen');
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => HomePage(username: username),
                                      ),
                                    );
                                    return;
                                  } else if (role == 'desk officer' || role == 'desk_officer' || role == 'deskofficer') {
                                    // Find officerId and station by username
                                    final deskOfficerRef = FirebaseDatabase.instance.ref().child('Desk Officer');
                                    final stationSnapshot = await deskOfficerRef.get();
                                    if (stationSnapshot.exists && stationSnapshot.value is Map) {
                                      final stations = stationSnapshot.value as Map<dynamic, dynamic>;
                                      String foundOfficerId = '';
                                      for (final stationEntry in stations.entries) {
                                        if (stationEntry.value is Map) {
                                          final officers = stationEntry.value as Map<dynamic, dynamic>;
                                          for (final offEntry in officers.entries) {
                                            if (offEntry.value is Map) {
                                              final data = Map<String, dynamic>.from(offEntry.value as Map);
                                              if (data['username']?.toString() == username) {
                                                foundOfficerId = offEntry.key.toString();
                                                break;
                                              }
                                            }
                                          }
                                          if (foundOfficerId.isNotEmpty) break;
                                        }
                                      }
                                      await prefs.setString('userType', 'deskOfficer');
                                      await prefs.setString('officerId', foundOfficerId);
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DeskOfficerHomePage(
                                            username: username,
                                            officerId: foundOfficerId,
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                  } else if (role == 'responder') {
                                    // Find responderId and station by username
                                    final responderRef = FirebaseDatabase.instance.ref().child('Responders');
                                    final responderSnapshot = await responderRef.get();
                                    if (responderSnapshot.exists && responderSnapshot.value is Map) {
                                      final stations = responderSnapshot.value as Map<dynamic, dynamic>;
                                      String foundResponderId = '';
                                      String foundResponderStation = '';
                                      for (final stationEntry in stations.entries) {
                                        if (stationEntry.value is Map) {
                                          final responders = stationEntry.value as Map<dynamic, dynamic>;
                                          for (final respEntry in responders.entries) {
                                            if (respEntry.value is Map) {
                                              final data = Map<String, dynamic>.from(respEntry.value as Map);
                                              final candidateUsername = (data['username']?.toString().trim().toLowerCase() ?? respEntry.key.toString().trim().toLowerCase());
                                              if (candidateUsername == username.trim().toLowerCase()) {
                                                foundResponderId = respEntry.key.toString();
                                                foundResponderStation = stationEntry.key.toString();
                                                break;
                                              }
                                            }
                                          }
                                          if (foundResponderId.isNotEmpty) break;
                                        }
                                      }
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setString('userType', 'responder');
                                      await prefs.setString('responderId', foundResponderId);
                                      await prefs.setString('responderStation', foundResponderStation);
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ResponderHomePage(
                                            username: username,
                                            responderId: foundResponderId,
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                  }
                                } else {
                                  // Wrong password for AuthAccounts
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text("Login Failed"),
                                      content: Text("Incorrect password. Please try again."),
                                      actions:[
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text("Try Again")
                                        )
                                      ],
                                    )
                                  );
                                  return;
                                }
                              }
                            } catch (e) {
                              debugPrint('AuthAccounts check error: $e');
                            }

                            // 1. Check Desk Officer credentials (legacy, kept for backward compatibility)
                            final deskOfficerRef = FirebaseDatabase.instance.ref().child('Desk Officer');
                            bool foundDeskOfficer = false;
                            String foundOfficerId = '';
                            String foundStation = '';
                            Map<String, dynamic>? officerData;

                            final stationSnapshot = await deskOfficerRef.get();
                            if (stationSnapshot.exists) {
                              final stationsRaw = stationSnapshot.value;
                              if (stationsRaw is Map) {
                                final stations = stationsRaw as Map<dynamic, dynamic>;
                                for (final stationEntry in stations.entries) {
                                  if (stationEntry.value is Map) {
                                    final officersRaw = stationEntry.value;
                                    if (officersRaw is Map) {
                                      final officers = officersRaw as Map<dynamic, dynamic>;
                                      for (final officerEntry in officers.entries) {
                                        if (officerEntry.value is Map) {
                                          final data = Map<String, dynamic>.from(officerEntry.value as Map);
                                          if (data['username'] == username && data['password'].toString() == userPassword) {
                                            foundDeskOfficer = true;
                                            foundOfficerId = officerEntry.key;
                                            foundStation = stationEntry.key;
                                            officerData = Map<String, dynamic>.from(data);
                                            break;
                                          }
                                        }
                                      }
                                      if (foundDeskOfficer) break;
                                    } else {
                                      print('Officers node is not a Map: ${officersRaw}');
                                    }
                                  } else {
                                    print('Station entry is not a Map: ${stationEntry.value}');
                                  }
                                }
                              } else {
                                print('Stations node is not a Map: ${stationsRaw}');
                              }
                            }

                            if (foundDeskOfficer) {
                              // Save login state for desk officer
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('username', username);
                              await prefs.setString('userType', 'deskOfficer');
                              await prefs.setString('officerId', foundOfficerId);
                              
                              // Login as Desk Officer
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeskOfficerHomePage(
                                    username: username,
                                    officerId: foundOfficerId,
                                  ),
                                ),
                              );
                              return;
                            }

                            // 2. Check Responder credentials
                            final responderRef = FirebaseDatabase.instance.ref().child('Responders');
                            bool foundResponder = false;
                            String foundResponderId = '';
                            String foundResponderStation = '';
                            Map<String, dynamic>? responderData;

                            final responderSnapshot = await responderRef.get();
                            if (responderSnapshot.exists) {
                              final stationsRaw = responderSnapshot.value;
                              if (stationsRaw is Map) {
                                final stations = stationsRaw as Map<dynamic, dynamic>;
                                for (final stationEntry in stations.entries) {
                                  if (stationEntry.value is Map) {
                                    final respondersRaw = stationEntry.value;
                                    if (respondersRaw is Map) {
                                      final responders = respondersRaw as Map<dynamic, dynamic>;
                                      for (final responderEntry in responders.entries) {
                                        if (responderEntry.value is Map) {
                                          final data = Map<String, dynamic>.from(responderEntry.value as Map);
                                          if (data['username'] == username && data['password'].toString() == userPassword) {
                                            foundResponder = true;
                                            foundResponderId = responderEntry.key;
                                            foundResponderStation = stationEntry.key;
                                            responderData = Map<String, dynamic>.from(data);
                                            break;
                                          }
                                        }
                                      }
                                      if (foundResponder) break;
                                    } else {
                                      print('Responders node is not a Map: ${respondersRaw}');
                                    }
                                  } else {
                                    print('Station entry is not a Map: ${stationEntry.value}');
                                  }
                                }
                              } else {
                                print('Responder stations node is not a Map: ${stationsRaw}');
                              }
                            }

                            if (foundResponder) {
                              // Save login state for responder
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('username', username);
                              await prefs.setString('userType', 'responder');
                              await prefs.setString('responderId', foundResponderId);
                              
                              // Login as Responder
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ResponderHomePage(
                                    username: username,
                                    responderId: foundResponderId,
                                  ),
                                ),
                              );
                              return;
                            }

                            // 3. Query Firebase for the user (citizen)
                            final userSnapshot = await FirebaseDatabase.instance
                                .ref()
                                .child('users')
                                .orderByChild('username')
                                .equalTo(username)
                                .get();

                            if (userSnapshot.exists) {
                              Map<String, dynamic>? userData;
                              try {
                                final firstChild = userSnapshot.children.first;
                                if (firstChild.value is Map) {
                                  userData = Map<String, dynamic>.from(firstChild.value as Map);
                                }
                              } catch (e) {
                                debugPrint('Error parsing user data: $e');
                              }

                              if (userData != null && userData['password'] == userPassword) {
                                debugPrint('Citizen login successful for: $username'); // Debug log
                                
                                // Save login state for citizen
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('username', username);
                                await prefs.setString('userType', 'citizen');
                                
                                // Login successful
                                debugPrint('Navigating to HomePage...'); // Debug log
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HomePage(username: username),
                                  ),
                                );
                              } else {
                                // Password doesn't match
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text("Login Failed"),
                                      titleTextStyle: TextStyle(
                                        fontSize: 25, 
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.black
                                      ),
                                    content: Text("Incorrect password. Please try again."),
                                      contentTextStyle: TextStyle(
                                        fontSize: 19, 
                                        color: const Color.fromARGB(255, 51, 50, 50)
                                      ),
                                      actions:[
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                              child: Text("Try Again")
                                      )
                                    ],
                                      actionsPadding: EdgeInsets.only(bottom: 10, right: 15),
                                  )
                                );
                              }
                            } else {
                              // User not found
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text("Login Failed"),
                                      titleTextStyle: TextStyle(
                                        fontSize: 25, 
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.black
                                      ),
                                      content: Text("Username not found. Please register or try again."),
                                      contentTextStyle: TextStyle(
                                        fontSize: 19, 
                                        color: const Color.fromARGB(255, 51, 50, 50)
                                      ),
                                      actions:[
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                              child: Text("Try Again")
                                    )
                                  ],
                                      actionsPadding: EdgeInsets.only(bottom: 10, right: 15),
                                  )
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: 13,
                              horizontal: 20,
                            ), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))
                          ),
                          child: Text(
                            "Log In", 
                            style: TextStyle(
                              fontSize: 18, 
                              color: const Color.fromARGB(255, 97, 91, 91)
                            ),
                          ),
                        
                        ),



                      TextButton  // for forgot password button
                      (
                        onPressed: ()
                        {
                           // TODO: Add forgot password logic
                        },
                        child: Text("Forgot Password?", style: TextStyle(fontSize: 16),),

                      ),

                      Row  // register button
                      (
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: 
                        [
                          Text("Don't have an account? ", style: TextStyle(fontSize: 16),),
                          TextButton
                          (
                            onPressed: () 
                            {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterPage()),);
                            },
                            child: Text("Register here", style: TextStyle(fontSize: 16),),

                          ),
                        ],
                      ),

                    ],

                  )

                )
              )
            )
          )
        )
      );
    }

}