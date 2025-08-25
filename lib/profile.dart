import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  final String username;

  const ProfilePage({Key? key, required this.username}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditMode = false;
  bool _isLoading = true;
  
  // User data
  Map<String, dynamic> _userData = {};
  
  // Controllers for edit mode
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  
  // Dropdown values
  String? _selectedCountry;
  String? _selectedRegion;
  String? _selectedCity;
  String? _selectedBarangay;
  String? _selectedGender;
  bool _isPWD = false;
  bool _hasMedicalCondition = false;
  
  // Birthdate
  DateTime? _selectedBirthdate;
  String _birthdateText = 'Not provided';
  
  // Profile image
  File? _profileImage;
  String? _profileImageUrl;
  
  // Dropdown options
  final List<String> _countries = ['Philippines', 'United States', 'Canada', 'Japan', 'South Korea'];
  final List<String> _regions = ['NCR', 'Region I', 'Region II', 'Region III', 'Region IV-A', 'Region IV-B'];
  final List<String> _cities = ['Manila', 'Quezon City', 'Makati', 'Pasig', 'Taguig', 'Marikina'];
  final List<String> _barangays = ['Barangay 1', 'Barangay 2', 'Barangay 3', 'Barangay 4', 'Barangay 5'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(widget.username);
      
      final DataSnapshot snapshot = await userRef.get();
      
      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          _userData = Map<String, dynamic>.from(snapshot.value as Map);
          _populateControllers();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('User data not found');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error loading profile: $e');
    }
  }

  void _populateControllers() {
    _firstNameController.text = _userData['firstName'] ?? '';
    _lastNameController.text = _userData['surname'] ?? '';
    _contactController.text = _userData['contactNumber'] ?? '';
    _streetController.text = _userData['streetAddress'] ?? '';
    
    // Handle birthdate
    _birthdateText = _userData['birthdate'] ?? 'Not provided';
    if (_birthdateText != 'Not provided') {
      try {
        final parts = _birthdateText.split('/');
        if (parts.length == 3) {
          _selectedBirthdate = DateTime(
            int.parse(parts[2]), // year
            int.parse(parts[1]), // month
            int.parse(parts[0]), // day
          );
        }
      } catch (e) {
        print('Error parsing birthdate: $e');
      }
    }
    
    _selectedCountry = _userData['country'] == 'Not provided' ? null : _userData['country'];
    _selectedRegion = _userData['region'] == 'Not provided' ? null : _userData['region'];
    _selectedCity = _userData['city'] == 'Not provided' ? null : _userData['city'];
    _selectedBarangay = _userData['barangay'] == 'Not provided' ? null : _userData['barangay'];
    _selectedGender = _userData['gender'] == 'Not provided' ? null : _userData['gender'];
    
    _isPWD = _userData['pwdCondition'] != 'Not provided' && _userData['pwdCondition'] == 'Yes';
    _hasMedicalCondition = _userData['medicalCondition'] != 'Not provided' && _userData['medicalCondition'] == 'Yes';
    
    _profileImageUrl = _userData['profileImageUrl'];
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return _profileImageUrl;
    
    try {
      final String fileName = 'profile_${widget.username}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child('profile_images').child(fileName);
      
      final UploadTask uploadTask = storageRef.putFile(_profileImage!);
      final TaskSnapshot snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return _profileImageUrl;
    }
  }

  Future<void> _saveProfile() async {
    if (!_validateFields()) return;
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE74C3C)),
          ),
        ),
      );
      
      // Upload profile image if changed
      String? imageUrl = await _uploadProfileImage();
      
      // Prepare updated data
      Map<String, dynamic> updatedData = {
        'firstName': _firstNameController.text.trim(),
        'surname': _lastNameController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'birthdate': _birthdateText,
        'country': _selectedCountry ?? 'Not provided',
        'region': _selectedRegion ?? 'Not provided',
        'city': _selectedCity ?? 'Not provided',
        'barangay': _selectedBarangay ?? 'Not provided',
        'streetAddress': _streetController.text.trim().isEmpty ? 'Not provided' : _streetController.text.trim(),
        'gender': _selectedGender ?? 'Not provided',
        'pwdCondition': _isPWD ? 'Yes' : 'Not provided',
        'medicalCondition': _hasMedicalCondition ? 'Yes' : 'Not provided',
      };
      
      if (imageUrl != null) {
        updatedData['profileImageUrl'] = imageUrl;
      }
      
      // Update Firebase
      final DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(widget.username);
      
      await userRef.update(updatedData);
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Update local data and switch to view mode
      setState(() {
        _userData.addAll(updatedData);
        _isEditMode = false;
        _profileImage = null;
        if (imageUrl != null) _profileImageUrl = imageUrl;
      });
      
      _showSuccessDialog('Profile updated successfully!');
      
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorDialog('Error saving profile: $e');
    }
  }

  bool _validateFields() {
    if (_firstNameController.text.trim().isEmpty) {
      _showErrorDialog('First name is required');
      return false;
    }
    if (_lastNameController.text.trim().isEmpty) {
      _showErrorDialog('Last name is required');
      return false;
    }
    if (_contactController.text.trim().isEmpty) {
      _showErrorDialog('Contact number is required');
      return false;
    }
    return true;
  }

  // FOR BIRTHDATE
  Future<void> _selectBirthdate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ?? DateTime.now().subtract(Duration(days: 2920)), // 8 years ago (default)
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout' , style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Logout',
              style: TextStyle(color: Color(0xFFE74C3C)),
            ),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true) {
      try {
        // Clear SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        // Navigate to login page and clear all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      } catch (e) {
        print('Error during logout: $e');
        // Still navigate to login even if SharedPreferences fails
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildWarningIcon() {
    return Icon(
      Icons.warning,
      color: Colors.orange,
      size: 16,
    );
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    bool showWarning = false,
    Widget? editWidget,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              if (showWarning) ...[
                SizedBox(width: 4),
                _buildWarningIcon(),
              ],
            ],
          ),
          SizedBox(height: 8),
          _isEditMode && editWidget != null
              ? editWidget
              : Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                  child: Text(
                    value.isEmpty ? 'Not provided' : value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: value.isEmpty || value == 'Not provided' 
                          ? Colors.grey[500] 
                          : const Color.fromARGB(225, 0, 0, 0),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool showWarning = false,
  }) {
    return _buildProfileField(
      label: label,
      value: value ?? 'Not provided',
      showWarning: showWarning,
      editWidget: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          hintText: 'Select $label',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFE74C3C), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextFieldEdit({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFE74C3C), width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFE74C3C),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

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
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit Profile' : 'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditMode) {
                _saveProfile();
              } else {
                setState(() {
                  _isEditMode = true;
                });
              }
            },
            child: Text(
              _isEditMode ? 'Save' : 'Edit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Photo Section
            Container(
              padding: EdgeInsets.only(bottom: 20),
              child: Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      child: ClipOval(
                        child: _profileImage != null
                            ? Image.file(_profileImage!, fit: BoxFit.cover)
                            : _profileImageUrl != null
                                ? Image.network(_profileImageUrl!, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey[300],
                                    child: Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                      ),
                    ),
                    if (_isEditMode)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _takePicture,
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: Color(0xFFE74C3C),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Profile Form Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildProfileField(
                          label: 'First name',
                          value: _userData['firstName'] ?? '',
                          editWidget: _buildTextFieldEdit(
                            controller: _firstNameController,
                            hint: 'Enter first name',
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildProfileField(
                          label: 'Last name',
                          value: _userData['surname'] ?? '',
                          editWidget: _buildTextFieldEdit(
                            controller: _lastNameController,
                            hint: 'Enter last name',
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  _buildProfileField(
                    label: 'Contact',
                    value: _userData['contactNumber'] ?? '',
                    editWidget: _buildTextFieldEdit(
                      controller: _contactController,
                      hint: 'Enter contact number',
                    ),
                  ),
                  
                  _buildProfileField(
                    label: 'Birthdate',
                    value: _birthdateText,
                    showWarning: _birthdateText == 'Not provided',
                    editWidget: GestureDetector(
                      onTap: _selectBirthdate,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE74C3C), width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Color(0xFFE74C3C), size: 20),
                            SizedBox(width: 8),
                            Text(
                              _birthdateText,
                              style: TextStyle(
                                fontSize: 16,
                                color: _birthdateText == 'Not provided' ? Colors.grey[500] : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  _buildDropdownField(
                    label: 'Country',
                    value: _selectedCountry,
                    items: _countries,
                    showWarning: _userData['country'] == 'Not provided',
                    onChanged: (value) => setState(() => _selectedCountry = value),
                  ),
                  
                  _buildDropdownField(
                    label: 'Region',
                    value: _selectedRegion,
                    items: _regions,
                    showWarning: _userData['region'] == 'Not provided',
                    onChanged: (value) => setState(() => _selectedRegion = value),
                  ),
                  
                  _buildDropdownField(
                    label: 'City',
                    value: _selectedCity,
                    items: _cities,
                    showWarning: _userData['city'] == 'Not provided',
                    onChanged: (value) => setState(() => _selectedCity = value),
                  ),
                  
                  _buildDropdownField(
                    label: 'Barangay',
                    value: _selectedBarangay,
                    items: _barangays,
                    showWarning: _userData['barangay'] == 'Not provided',
                    onChanged: (value) => setState(() => _selectedBarangay = value),
                  ),
                  
                  _buildProfileField(
                    label: 'Street',
                    value: _userData['streetAddress'] ?? 'Not provided',
                    showWarning: _userData['streetAddress'] == 'Not provided',
                    editWidget: _buildTextFieldEdit(
                      controller: _streetController,
                      hint: 'Enter your street',
                    ),
                  ),
                  
                  // Gender Section
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Gender',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (_userData['gender'] == 'Not provided') ...[
                              SizedBox(width: 4),
                              _buildWarningIcon(),
                            ],
                          ],
                        ),
                        SizedBox(height: 12),
                        _isEditMode
                            ? Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: Text('Male', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                      value: 'Male',
                                      groupValue: _selectedGender,
                                      activeColor: Color(0xFFE74C3C),
                                      onChanged: (value) => setState(() => _selectedGender = value),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: Text('Female', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                      value: 'Female',
                                      groupValue: _selectedGender,
                                      activeColor: Color(0xFFE74C3C),
                                      onChanged: (value) => setState(() => _selectedGender = value),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              )
                            : Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                                  ),
                                ),
                                child: Text(
                                  _userData['gender'] ?? 'Not provided',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _userData['gender'] == 'Not provided' 
                                        ? Colors.grey[500] 
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Checkboxes
                  if (_isEditMode) ...[
                    CheckboxListTile(
                      title: Text('I am a Person with Disability (PWD)'),
                      value: _isPWD,
                      activeColor: Color(0xFFE74C3C),
                      onChanged: (value) => setState(() => _isPWD = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      title: Text('I have a medical condition'),
                      value: _hasMedicalCondition,
                      activeColor: Color(0xFFE74C3C),
                      onChanged: (value) => setState(() => _hasMedicalCondition = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFE74C3C), width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _isPWD
                                ? Icon(Icons.check, size: 16, color: Color(0xFFE74C3C))
                                : null,
                          ),
                          SizedBox(width: 12),
                          Text('I am a Person with Disability (PWD)'),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFE74C3C), width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _hasMedicalCondition
                                ? Icon(Icons.check, size: 16, color: Color(0xFFE74C3C))
                                : null,
                          ),
                          SizedBox(width: 12),
                          Text('I have a medical condition'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Logout Button
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 243, 243).withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
          ],
        ),
      ),
        ),
      ),
    );
  }
}