import 'package:emergency/main.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';
import 'firebase_service.dart';
import 'services/storage_service.dart';
// import 'dart:convert';  this is for hash256 password converter
// import 'package:crypto/crypto.dart';  encrypting/decrypting pass
import 'package:firebase_database/firebase_database.dart';
import 'package:emergency/homepage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// use of statefulwidget to maintain and data changes
class RegisterPage extends StatefulWidget {
    const RegisterPage({super.key});
    
    @override
    State<RegisterPage> createState() => RegistrationForm();
}

// state class that contains logic and ui
class RegistrationForm extends State<RegisterPage> {
    final TextEditingController _contactController = TextEditingController();
    final TextEditingController _fnameController = TextEditingController();
    final TextEditingController _surnameController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _confirmpassController = TextEditingController();
    
    String _countryOption = "Not provided";
    String _cityOption = 'Not provided';
    String _regionOption = "Not provided";
    String _barangayOption = "Not provided";
    String _genderSelection = 'Not provided';
    DateTime? _selectedBirthdate;
    String _birthdateText = 'Set birthdate';

    // state variable whose not text values
    bool _obscurePassword = true;
    bool _obscureConfirmPassword = true;
    File? _profileImage;

    final ImagePicker _picker = ImagePicker();
    final FaceDetector _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
            enableClassification: true,
            enableLandmarks: true,
            enableTracking: true,
            minFaceSize: 0.15,
        ),
    );

    final FirebaseService _firebaseService = FirebaseService();

    @override
    void initState() {
        super.initState();
    }

    // dispose() is for clean up controller to prevent memory leaks
    @override
    void dispose() {
        _contactController.dispose();
        _fnameController.dispose();
        _surnameController.dispose();
        _passwordController.dispose();
        _confirmpassController.dispose();
        _faceDetector.close();
        super.dispose();
    }

    // Generate username from first name and surname only
    String _generateUsername(String firstName, String surname) {
        // Preserve original casing and collapse multiple spaces
        String normFirst = firstName.trim().replaceAll(RegExp(r'\s+'), ' ');
        String normSurname = surname.trim().replaceAll(RegExp(r'\s+'), ' ');
        // Join with a single space
        return [normFirst, normSurname].where((p) => p.isNotEmpty).join(' ');
    }

    void _showErrorDialog(String message) {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
                title: Text("Required Field", style: TextStyle(fontSize: 18.0)),
                content: Text(message, style: TextStyle(fontSize: 16.0)),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("OK", style: TextStyle(fontSize: 16.0))
                    )
                ],
            )
        );
    }

    bool _isAgeValid() {
        if (_selectedBirthdate == null) {
            return false; // No birthdate selected
        }
        
        final now = DateTime.now();
        final age = now.difference(_selectedBirthdate!).inDays / 365.25;
        return age >= 8.0;
    }

    void _showAgeRestrictionDialog() {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
                title: Text("Age Restriction", style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
                content: Text(
                    "Sorry, you must be at least 8 years old to use this emergency application.",
                    style: TextStyle(fontSize: 16.0)
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("OK", style: TextStyle(fontSize: 16.0, color: Color(0xFFE74C3C)))
                    )
                ],
            )
        );
    }


    // FOR BIRTHDATE
    Future<void> _selectBirthdate() async {
        final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now().subtract(Duration(days: 2920)), // 8 years ago (default)
            firstDate: DateTime(1900),
            lastDate: DateTime.now(), // Allow all dates up to today
            builder: (context, child) {
                return Theme(
                    data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                            primary: Color(0xFFE74C3C),
                            onPrimary: Colors.white,
                            onSurface: Colors.black,
                        ),
                        textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                                foregroundColor: Color(0xFFE74C3C),
                            ),
                        ),
                    ),
                    child: child!,
                );
            },
        );
        if (picked != null && picked != _selectedBirthdate) {
            setState(() {
                _selectedBirthdate = picked;
                _birthdateText = "${picked.day}/${picked.month}/${picked.year}";
            });
        }
    }

    // Method to take picture
    Future<void> _takePicture() async {
        try {
            final XFile? photo = await _picker.pickImage(
                source: ImageSource.camera,
                preferredCameraDevice: CameraDevice.front,
            );
            
            if (photo != null) {
                final File imageFile = File(photo.path);
                
                // Perform face detection
                final inputImage = InputImage.fromFile(imageFile);
                final List<Face> faces = await _faceDetector.processImage(inputImage);
                
                if (faces.isEmpty) {
                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                            title: Text("No Face Detected"),
                            content: Text("Please make sure your face is clearly visible in the photo."),
                            actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text("OK"),
                                )
                            ],
                        ),
                    );
                    return;
                }

                // Face detected, check if it's a good quality face
                final face = faces.first;
                if (face.smilingProbability != null && face.smilingProbability! < 0.5) {
                    // Face detected but might not be a good quality photo
                    if (mounted) {
                        showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => AlertDialog(
                                title: Text('Photo Quality', style: TextStyle(fontSize: 18.0)),
                                content: Text('Please take a clearer photo with your face properly visible.', style: TextStyle(fontSize: 16.0)),
                                actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Try Again', style: TextStyle(fontSize: 16.0)),
                                    ),
                                ],
                            ),
                        );
                    }
                    return;
                }
                
                setState(() {
                    _profileImage = imageFile;
                });
            }
        } catch (e) {
            print('Error taking picture: $e');
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                    title: Text("Error"),
                    content: Text("Failed to take picture. Please try again."),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("OK"),
                        )
                    ],
                ),
            );
        }
    }

    // handles registration validation and confirmation 
    Future<void> _registerUser() async {
        try {
            print('Starting registration process...'); // Debug log

            // Validate required fields
            if (_fnameController.text.isEmpty) {
                _showErrorDialog("First Name is required");
                return;
            }
            if (_surnameController.text.isEmpty) {
                _showErrorDialog("Last Name is required");
                return;
            }
            if (_contactController.text.isEmpty) {
                _showErrorDialog("Contact Number is required");
                return;
            }
            if (_passwordController.text.isEmpty) {
                _showErrorDialog("Password is required");
                return;
            }
            if (_confirmpassController.text.isEmpty) {
                _showErrorDialog("Please confirm your password");
                return;
            }

            // Validate birthdate is selected
            if (_birthdateText == 'Set birthdate') {
                _showErrorDialog("Please select your birthdate");
                return;
            }

            // Validate age requirement (must be 8 years or older)
            if (!_isAgeValid()) {
                _showAgeRestrictionDialog();
                return;
            }

            // Validate contact number length
            if (_contactController.text.length != 9) {
                print('Contact number validation failed: ${_contactController.text}'); // Debug log
                showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                        title: Text('Invalid Contact Number', style: TextStyle(fontSize: 18.0)),
                        content: Text('Please enter a valid 9-digit contact number.', style: TextStyle(fontSize: 16.0)),
                        actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('OK', style: TextStyle(fontSize: 16.0)),
                            ),
                        ],
                        actionsPadding: EdgeInsets.only(bottom: 10.0, right: 10.0),
                    )
                );
                return;
            }

            // Validate password match
            if (_passwordController.text != _confirmpassController.text) {
                print('Password validation failed'); // Debug log
                showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                        title: Text('Password Mismatch', style: TextStyle(fontSize: 18.0)),
                        content: Text('Passwords do not match. Please try again.', style: TextStyle(fontSize: 16.0)),
                        actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('OK', style: TextStyle(fontSize: 16.0)),
                            ),
                        ],
                    )
                );
                return;
            }

            if (_profileImage == null) {
                print('Profile image validation failed'); // Debug log
                showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                        title: Text("Photo Not Found", style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
                        content: Text("Please take a photo.", style: TextStyle(fontSize: 16.0)),
                        actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("OK", style: TextStyle(fontSize: 16.0)),
                            )
                        ]
                    )
                );
                return;
            }

            print('All validations passed, proceeding with registration...'); // Debug log

            // Generate username from first name and surname only
            String username = _generateUsername(
                _fnameController.text,
                _surnameController.text
            );
            print('Generated username: $username'); // Debug log

            // Check if username already exists (keyed by username -> O(1), no index needed)
            print('Checking if username exists...'); // Debug log
            final usernameSnapshot = await FirebaseDatabase.instance
                .ref()
                .child('users')
                .child(username)
                .get();

            if (usernameSnapshot.exists) {
                print('Username already exists'); // Debug log
                showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                        title: Text("Username Already Exists", style: TextStyle(fontSize: 18.0)),
                        content: Text("A user with this name combination already exists. Please contact support.", style: TextStyle(fontSize: 16.0)),
                        actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("OK", style: TextStyle(fontSize: 16.0)),
                            )
                        ]
                    )
                );
                return;
            }

            // Also prevent duplicates in AuthAccounts (centralized auth)
            final authAccountExisting = await FirebaseDatabase.instance
                .ref()
                .child('AuthAccounts')
                .child(username)
                .get();
            if (authAccountExisting.exists) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: Text('Username Already Exists', style: TextStyle(fontSize: 18.0)),
                  content: Text('This username is already used in the authentication system. Please contact support or choose a different name.', style: TextStyle(fontSize: 16.0)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK', style: TextStyle(fontSize: 16.0)),
                    )
                  ],
                ),
              );
              return;
            }

            // Check if contact number already exists
            String fullContactNumber = '09${_contactController.text}';
            print('Checking if contact number exists: $fullContactNumber'); // Debug log
            bool contactExists = false;
            try {
              final contactSnapshot = await FirebaseDatabase.instance
                  .ref()
                  .child('users')
                  .orderByChild('contactNumber')
                  .equalTo(fullContactNumber)
                  .get();
              contactExists = contactSnapshot.exists;
            } catch (e) {
              // Fallback if index is not defined in rules: scan small dataset client-side
              try {
                final usersSnapshot = await FirebaseDatabase.instance
                    .ref()
                    .child('users')
                    .get();
                if (usersSnapshot.exists) {
                  for (final child in usersSnapshot.children) {
                    final val = child.value;
                    if (val is Map && val['contactNumber'] == fullContactNumber) {
                      contactExists = true;
                      break;
                    }
                  }
                }
              } catch (_) {}
            }

            if (contactExists) {
                print('Contact number already exists'); // Debug log
                showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                        title: Text("Contact Number Already Exists", style: TextStyle(fontSize: 18.0)),
                        content: Text("A user with this contact number already exists.", style: TextStyle(fontSize: 16.0)),
                        actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("OK", style: TextStyle(fontSize: 16.0)),
                            )
                        ]
                    )
                );
                return;
            }

            print('Username and contact number checks passed'); // Debug log

            // Show loading dialog while uploading image and saving data
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(
                child: CircularProgressIndicator(),
              ),
            );

            String profileImageUrl;
            try {
              profileImageUrl = await StorageService().uploadProfileImage(
                file: _profileImage!,
                username: username,
              );
              print('Profile image uploaded successfully: $profileImageUrl');
            } catch (e, stackTrace) {
              print('Error uploading profile image: $e');
              print('Stack trace: $stackTrace');
              if (mounted) {
                Navigator.pop(context); // close loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text('Upload Failed'),
                    content: const Text('Could not upload profile photo. Please try again.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
              return;
            }

            print('Attempting to save user data to Firebase...'); // Debug log
            // Save user data to Firebase
            await _firebaseService.saveUserData(
                username: username,
                contactNumber: fullContactNumber,
                firstName: _fnameController.text,
                surname: _surnameController.text,
                country: _countryOption,
                region: _regionOption,
                city: _cityOption,
                barangay: _barangayOption,
                streetAddress: "Not provided",
                gender: _genderSelection,
                pwdCondition: 'None',
                medicalCondition: 'None',
                password: _passwordController.text,
                profileImageUrl: profileImageUrl,
                birthdate: _birthdateText,
            );
            print('User data saved successfully'); // Debug log

            if (mounted) {
              Navigator.pop(context); // Close loading dialog
            }

            // Write to centralized AuthAccounts for role-based login (duplicate for authentication)
            await FirebaseDatabase.instance
                .ref()
                .child('AuthAccounts')
                .child(username)
                .set({
                  'username': username,
                  'password': _passwordController.text,
                  'role': 'Citizen',
                  'createdAt': ServerValue.timestamp,
                });
            print('AuthAccounts entry created for $username');

            // Save login state for auto-login
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('username', username);
            await prefs.setString('userType', 'citizen');
            print('Login state saved for new user: $username'); // Debug log

            // Show success dialog with username
            showDialog(
                context: context,
                barrierDismissible: false, // Prevent dismissing by tapping outside
                builder: (context) => AlertDialog(
                    title: Text("Registration Successful", style: TextStyle(fontSize: 21.0, fontWeight: FontWeight.bold)),
                    content: Text("Your account has been created successfully.\n\nYour username is: $username", style: TextStyle(fontSize: 16.0)),
                    actions: [
                        TextButton(
                            onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => HomePage(username: username)),
                                );
                            },
                            child: Text("Proceed now", style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
                        )
                    ]
                )
            );
        } catch (e, stackTrace) {
            // Show error dialog with detailed error information
            print('Registration error: $e'); // Debug log
            print('Stack trace: $stackTrace'); // Debug log
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                    title: Text("Registration Failed", style: TextStyle(fontSize: 18.0)),
                    content: Text("An error occurred during registration. Please try again later.", style: TextStyle(fontSize: 16.0)),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("OK", style: TextStyle(fontSize: 16.0)),
                        )
                    ]
                )
            );
        }
    }

    @override
    Widget build(BuildContext context) {   
        return Scaffold(
        body: Container(
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
            child: SafeArea(
                child: SingleChildScrollView(
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                // App Icon and Title
                                Container(
                                    width: 150,
                                    height: 150,
                                    padding: EdgeInsets.all(8),
                                    child: Image.asset(
                                      'assets/images/Resme LOGO..png',
                                      fit: BoxFit.contain,
                                    ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                    'Register Here!',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                    ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                    'Set up your emergency contact profile',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.9),
                                    ),
                                    textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 40),
                                
                                // Registration Form Card
                                Container(
                                    padding: EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                            BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 10,
                                                offset: Offset(0, 5),
                                            ),
                                        ],
                                    ),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            // Your Name Section
                                            Text(
                                                ' Your Name',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color.fromARGB(255, 46, 46, 46),
                                                ),
                                            ),
                                            SizedBox(height: 5),
                                            Row(
                                                children: [
                                                    Expanded(
                                                        child: TextField(
                                                            controller: _fnameController,
                                                            textCapitalization: TextCapitalization.words,
                                                            decoration: InputDecoration(
                                                                hintText: 'First name',
                                                                hintStyle: TextStyle(
                                                                    color: Colors.grey[500],
                                                                    fontSize: 16,
                                                                ),
                                                                filled: true,
                                                                fillColor: Colors.grey[50],
                                                                border: OutlineInputBorder(
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    borderSide: BorderSide(
                                                                        color: Colors.grey[400]!,
                                                                        width: 1,
                                                                    ),
                                                                ),
                                                                enabledBorder: OutlineInputBorder(
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    borderSide: BorderSide(
                                                                        color: Colors.grey[400]!,
                                                                        width: 1,
                                                                    ),
                                                                ),
                                                                focusedBorder: OutlineInputBorder(
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    borderSide: BorderSide(
                                                                        color: Color(0xFFE74C3C),
                                                                        width: 2,
                                                                    ),
                                                                ),
                                                                contentPadding: EdgeInsets.symmetric(
                                                                    horizontal: 16,
                                                                    vertical: 16,
                                                                ),
                                                            ),
                                                        ),
                                                    ),
                                                    SizedBox(width: 12),
                                                    Expanded(
                                                        child: TextField(
                                                            controller: _surnameController,
                                                            textCapitalization: TextCapitalization.words,
                                                            decoration: InputDecoration(
                                                                hintText: 'Last name',
                                                                hintStyle: TextStyle(
                                                                    color: Colors.grey[500],
                                                                    fontSize: 16,
                                                                ),
                                                                filled: true,
                                                                fillColor: Colors.grey[50],
                                                                border: OutlineInputBorder(
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    borderSide: BorderSide(
                                                                        color: Colors.grey[400]!,
                                                                        width: 1,
                                                                    ),
                                                                ),
                                                                enabledBorder: OutlineInputBorder(
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    borderSide: BorderSide(
                                                                        color: Colors.grey[400]!,
                                                                        width: 1,
                                                                    ),
                                                                ),
                                                                focusedBorder: OutlineInputBorder(
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    borderSide: BorderSide(
                                                                        color: Color(0xFFE74C3C),
                                                                        width: 2,
                                                                    ),
                                                                ),
                                                                contentPadding: EdgeInsets.symmetric(
                                                                    horizontal: 16,
                                                                    vertical: 16,
                                                                ),
                                                            ),
                                                        ),
                                                    ),
                                                ],
                                            ),
                                            SizedBox(height: 14),
                                            
                                            // Contact Number
                                            Text(
                                                ' Contact Number',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color.fromARGB(255, 46, 46, 46),
                                                ),
                                            ),
                                            SizedBox(height: 5),
                                            TextField(
                                                controller: _contactController,
                                                keyboardType: TextInputType.number,
                                                maxLength: 9,
                                                decoration: InputDecoration(
                                                    hintText: 'XXXXXXXXX',
                                                    hintStyle: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 16,
                                                    ),
                                                    prefixText: '09',
                                                    prefixStyle: TextStyle(
                                                        fontSize: 17,
                                                        color: Colors.black87,
                                                        fontWeight: FontWeight.w500,
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    counterText: '',
                                                    border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                            color: Colors.grey[400]!,
                                                            width: 1,
                                                        ),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                            color: Colors.grey[400]!,
                                                            width: 1,
                                                        ),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                            color: Color(0xFFE74C3C),
                                                            width: 2,
                                                        ),
                                                    ),
                                                    contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 16,
                                                    ),
                                                ),
                                                inputFormatters: [
                                                    FilteringTextInputFormatter.digitsOnly,
                                                ],
                                            ),
                                            SizedBox(height: 14),
                                            
                                            // Password
                                            Text(
                                                ' Password',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color.fromARGB(255, 46, 46, 46),
                                                ),
                                            ),
                                            SizedBox(height: 5),
                                            TextField(
                                                controller: _passwordController,
                                                obscureText: _obscurePassword,
                                                decoration: InputDecoration(
                                                    hintText: 'Enter your password',
                                                    hintStyle: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 16,
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    suffixIcon: IconButton(
                                                        icon: Icon(
                                                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                                            color: Colors.grey[600],
                                                        ),
                                                        onPressed: () {
                                                            setState(() {
                                                                _obscurePassword = !_obscurePassword;
                                                            });
                                                        },
                                                    ),
                                                    border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                            color: Colors.grey[400]!,
                                                            width: 1,
                                                        ),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                            color: Colors.grey[400]!,
                                                            width: 1,
                                                        ),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                            color: Color(0xFFE74C3C),
                                                            width: 2,
                                                        ),
                                                    ),
                                                    contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 16,
                                                    ),
                                                ),
                                            ),
                                            SizedBox(height: 14),
                                            
                                            // Confirm Password
                                            Text(
                                                ' Confirm Password',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color.fromARGB(255, 46, 46, 46),
                                                ),
                                            ),
                                            SizedBox(height: 5),
                                            TextField(
                                                controller: _confirmpassController,
                                                obscureText: _obscureConfirmPassword,
                                                decoration: InputDecoration(
                                                    hintText: 'Confirm your password',
                                                    hintStyle: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 16,
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    suffixIcon: IconButton(
                                                        icon: Icon(
                                                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                                            color: Colors.grey[600],
                                                        ),
                                                        onPressed: () {
                                                            setState(() {
                                                                _obscureConfirmPassword = !_obscureConfirmPassword;
                                                            });
                                                        },
                                                    ),
                                                    border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                            color: Colors.grey[400]!,
                                                            width: 1,
                                                        ),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                            color: Colors.grey[400]!,
                                                            width: 1,
                                                        ),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                            color: Color(0xFFE74C3C),
                                                            width: 2,
                                                        ),
                                                    ),
                                                    contentPadding: EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 16,
                                                    ),
                                                ),
                                            ),
                                            SizedBox(height: 14),
                                            
                                            // Birthdate Field
                                            Text(
                                                ' Birthdate',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color.fromARGB(255, 46, 46, 46),
                                                ),
                                            ),
                                            SizedBox(height: 5),
                                            GestureDetector(
                                                onTap: _selectBirthdate,
                                                child: Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                                    decoration: BoxDecoration(
                                                        color: Colors.grey[50],
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                            color: Colors.grey[400]!,
                                                            width: 1,
                                                        ),
                                                    ),
                                                    child: Row(
                                                        children: [
                                                            Icon(
                                                                Icons.calendar_today,
                                                                color: Colors.grey[600],
                                                                size: 20,
                                                            ),
                                                            SizedBox(width: 12),
                                                            Text(
                                                                _birthdateText,
                                                                style: TextStyle(
                                                                    fontSize: 16,
                                                                    color: _birthdateText == 'Set birthdate' 
                                                                        ? Colors.grey[500] 
                                                                        : Colors.black,
                                                                ),
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ),
                                            SizedBox(height: 14),
                                            
                                            // Profile Photo
                                            Text(
                                                ' Profile Photo',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color.fromARGB(255, 46, 46, 46),
                                                ),
                                            ),
                                            SizedBox(height: 12),
                                            Center(
                                                child: GestureDetector(
                                                    onTap: _takePicture,
                                                    child: Container(
                                                        width: 120,
                                                        height: 120,
                                                        decoration: BoxDecoration(
                                                            color: Colors.grey[100],
                                                            borderRadius: BorderRadius.circular(60),
                                                            border: Border.all(
                                                                color: Colors.grey[300]!,
                                                                width: 2,
                                                            ),
                                                        ),
                                                        child: _profileImage != null
                                                            ? ClipRRect(
                                                                borderRadius: BorderRadius.circular(58),
                                                                child: Image.file(
                                                                    _profileImage!,
                                                                    fit: BoxFit.cover,
                                                                ),
                                                            )
                                                            : Column(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                    Icon(
                                                                        Icons.camera_alt,
                                                                        size: 32,
                                                                        color: Colors.grey[600],
                                                                    ),
                                                                    SizedBox(height: 8),
                                                                    Text(
                                                                        'Take Photo',
                                                                        style: TextStyle(
                                                                            fontSize: 14,
                                                                            color: Colors.grey[600],
                                                                            fontWeight: FontWeight.w500,
                                                                        ),
                                                                    ),
                                                                ],
                                                            ),
                                                    ),
                                                ),
                                            ),
                                            SizedBox(height: 32),
                                            
                                            // Register Button
                                            SizedBox(
                                                width: double.infinity,
                                                height: 56,
                                                child: ElevatedButton(
                                                    onPressed: _registerUser,
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: Color(0xFFE74C3C),
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(12),
                                                        ),
                                                    ),
                                                    child: Text(
                                                        'Register',
                                                        style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w600,
                                                        ),
                                                    ),
                                                ),
                                            ),
                                            SizedBox(height: 16),
                                            
                                            // Back to Login Button
                                            Center(
                                                child: TextButton(
                                                    onPressed: () {
                                                        Navigator.pop(context);
                                                    },
                                                    child: Text(
                                                        'Back to Login',
                                                        style: TextStyle(
                                                            fontSize: 16,
                                                            color: Colors.grey[600],
                                                            fontWeight: FontWeight.w500,
                                                        ),
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
            ),
        ),
        );
    }
}
