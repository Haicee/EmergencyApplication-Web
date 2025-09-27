import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
//import 'dart:io';

class FirebaseService {
  late final DatabaseReference _database;

  FirebaseService() {
    // Initialize the database reference
    _database = FirebaseDatabase.instance.ref();
  }

  // Method to save user registration data
  Future<void> saveUserData({
    required String username,
    required String contactNumber,
    required String firstName,
    required String surname,
    required String country,
    required String region,
    required String city,
    required String barangay,
    required String streetAddress,
    required String gender,
    required String pwdCondition,
    required String medicalCondition,
    required String password,
    required String profileImageUrl,
    String? birthdate,
  }) async {
    try {
      print('Saving user data with username: $username'); // Debug log
      
      // Create a new user entry under 'users' node
      final userRef = _database.child('users').child(username);
      
      // Create user data map
      final userData = {
        'username': username,
        'contactNumber': contactNumber,
        'firstName': firstName,
        'surname': surname,
        'country': country,
        'region': region,
        'city': city,
        'barangay': barangay,
        'streetAddress': streetAddress,
        'gender': gender,
        'pwdCondition': pwdCondition,
        'medicalCondition': medicalCondition,
        'password': password,
        'profileImageUrl': profileImageUrl,
        'birthdate': birthdate ?? 'Not provided',
        'createdAt': ServerValue.timestamp,
      };

      print('User data to be saved: $userData'); // Debug log

      // Save the data
      await userRef.set(userData);
      
      print('User data saved successfully'); // Debug log

      // Ensure AuthAccounts is in sync for this citizen
      await _syncCitizenAuthAccount(username: username, password: password);
    } catch (e) {
      print('Error saving user data: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  // Method to check if a user exists
  Future<bool> userExists(String username) async {
    try {
      final snapshot = await _database
          .child('users')
          .orderByChild('username')
          .equalTo(username)
          .get();
      return snapshot.exists;
    } catch (e) {
      print('Error checking user existence: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      return false;
    }
  }

  // Method to get user data
  Future<Map<String, dynamic>?> getUserData(String username) async {
    try {
      final snapshot = await _database.child('users').child(username).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      return null;
    }
  }

  // Method to update user data
  Future<void> updateUserData(String username, Map<String, dynamic> updates) async {
    try {
      await _database.child('users').child(username).update(updates);
      
      // If password changed or AuthAccounts entry missing, sync AuthAccounts as well
      final String? maybePassword = updates['password']?.toString();
      await _syncCitizenAuthAccount(username: username, password: maybePassword);
    } catch (e) {
      print('Error updating user data: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  // Method to authenticate user
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    try {
      // Query users by username
      final snapshot = await _database
          .child('users')
          .orderByChild('username')
          .equalTo(username)
          .get();

      if (!snapshot.exists) {
        return null; // User not found
      }

      // Get the first matching user - handle potential type casting issues
      Map<String, dynamic>? userData;
      try {
        final firstChild = snapshot.children.first;
        if (firstChild.value is Map) {
          userData = Map<String, dynamic>.from(firstChild.value as Map);
        } else {
          // If the value is not a Map, try to get the user directly by username
          final directUserSnapshot = await _database.child('users').child(username).get();
          
          if (directUserSnapshot.exists && directUserSnapshot.value is Map) {
            userData = Map<String, dynamic>.from(directUserSnapshot.value as Map);
          }
        }
      } catch (e) {
        print('Error parsing user data: $e');
        // Try direct access as fallback
        try {
          final directUserSnapshot = await _database.child('users').child(username).get();
          
          if (directUserSnapshot.exists && directUserSnapshot.value is Map) {
            userData = Map<String, dynamic>.from(directUserSnapshot.value as Map);
          }
        } catch (directError) {
          print('Error with direct user access: $directError');
        }
      }
      
      if (userData != null && userData['password'] == password) {
        return userData;
      }

      return null; // Password doesn't match or user data couldn't be parsed
    } catch (e) {
      print('Error authenticating user: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      return null;
    }
  }

  // Internal helper: ensure a citizen has an AuthAccounts record and keep it updated
  Future<void> _syncCitizenAuthAccount({
    required String username,
    String? password,
  }) async {
    try {
      final authRef = _database.child('AuthAccounts').child(username);
      final authSnap = await authRef.get();

      if (authSnap.exists) {
        // Update minimal fields
        final Map<String, Object?> updates = {
          'username': username,
          'role': 'Citizen',
        };
        if (password != null && password.isNotEmpty) {
          updates['password'] = password;
        }
        await authRef.update(updates);
      } else {
        // Create entry if missing
        await authRef.set({
          'username': username,
          'password': password ?? '',
          'role': 'Citizen',
          'createdAt': ServerValue.timestamp,
        });
      }
    } catch (e) {
      print('Error syncing AuthAccounts for $username: $e');
    }
  }
}