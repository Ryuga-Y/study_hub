import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up user
  Future<AuthResult> signUpUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required String organizationCode,
    String? facultyId,
    String? facultyName,
    String? programId,
    String? programName,
  }) async {
    try {
      // Ensure organization code is uppercase
      final String orgCode = organizationCode.toUpperCase();

      // Create user account
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user == null) throw Exception('User creation failed');

      // Update display name
      await user.updateDisplayName(fullName);

      // Send email verification
      await user.sendEmailVerification();

      // Get organization details - use the uppercase code
      DocumentSnapshot orgDoc = await _firestore
          .collection('organizations')
          .doc(orgCode)  // Use the uppercase version
          .get();

      if (!orgDoc.exists) {
        await user.delete(); // Clean up if org not found
        throw Exception('Organization not found with code: $orgCode');
      }

      Map<String, dynamic> orgData = orgDoc.data() as Map<String, dynamic>;

      // Create user document
      Map<String, dynamic> userData = {
        'uid': user.uid,
        'email': email,
        'fullName': fullName,
        'role': role,
        'organizationCode': orgCode,  // Store the uppercase version
        'organizationName': orgData['name'],
        'facultyId': facultyId,
        'facultyName': facultyName,
        'isActive': true,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add program details for students
      if (role == 'student' && programId != null) {
        userData['programId'] = programId;
        userData['programName'] = programName;
      }

      // Save user data
      await _firestore.collection('users').doc(user.uid).set(userData);

      // Create audit log - use uppercase org code
      await _createAuditLog(
        organizationCode: orgCode,
        action: '${role}_account_created',
        userId: user.uid,
        details: {
          'userEmail': email,
          'userName': fullName,
          'role': role,
        },
      );

      return AuthResult(success: true, message: 'Account created successfully');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _getErrorMessage(e.code));
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  // Sign up admin
  Future<AuthResult> signUpAdmin({
    required String email,
    required String password,
    required String fullName,
    required String organizationCode,
    required String organizationName,
    required bool isJoiningExisting,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user == null) throw Exception('User creation failed');

      await user.updateDisplayName(fullName);
      await user.sendEmailVerification();

      String orgCode = organizationCode.toUpperCase();

      if (isJoiningExisting) {
        // Check if organization exists
        DocumentSnapshot orgDoc = await _firestore
            .collection('organizations')
            .doc(orgCode)
            .get();

        if (!orgDoc.exists) {
          await user.delete();
          throw Exception('Organization not found');
        }

        // Add admin to existing organization
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'fullName': fullName,
          'role': 'admin',
          'organizationCode': orgCode,
          'organizationName': orgDoc['name'],
          'isActive': false, // Set to false for joining admins - requires activation
          'requiresActivation': true, // Flag to identify pending admins
          'emailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create audit log first (this is allowed for everyone)
        await _createAuditLog(
          organizationCode: orgCode,
          action: 'admin_joined_pending_activation',
          userId: user.uid,
          details: {
            'adminEmail': email,
            'adminName': fullName,
            'status': 'pending_activation',
          },
        );

        // Update organization's pending admins list
        // Using a batch to ensure consistency
        WriteBatch batch = _firestore.batch();

        batch.update(_firestore.collection('organizations').doc(orgCode), {
          'pendingAdmins': FieldValue.arrayUnion([user.uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        try {
          await batch.commit();
        } catch (e) {
          // If batch fails, the admin is still created and can be manually activated
          print('Warning: Could not update pendingAdmins list: $e');
          // Continue execution - the admin account is created successfully
        }

        // Notify creator admin about pending admin
        Map<String, dynamic> orgData = orgDoc.data() as Map<String, dynamic>;
        String creatorId = orgData['createdBy'] ?? '';
        if (creatorId.isNotEmpty) {
          try {
            await _createNotification(
              userId: creatorId,
              title: 'New Admin Pending Activation',
              message: '$fullName has joined your organization and requires activation.',
              type: 'admin_pending',
              data: {
                'pendingAdminId': user.uid,
                'pendingAdminName': fullName,
                'pendingAdminEmail': email,
              },
            );
          } catch (e) {
            print('Warning: Could not create notification: $e');
            // Continue execution - the admin account is created successfully
          }
        }
      } else {
        // Create new organization
        DocumentSnapshot existingOrg = await _firestore
            .collection('organizations')
            .doc(orgCode)
            .get();

        if (existingOrg.exists) {
          await user.delete();
          throw Exception('Organization code already exists');
        }

        // Use batch write for consistency
        WriteBatch batch = _firestore.batch();

        // Create user document - creator is always active
        batch.set(_firestore.collection('users').doc(user.uid), {
          'uid': user.uid,
          'email': email,
          'fullName': fullName,
          'role': 'admin',
          'organizationCode': orgCode,
          'organizationName': organizationName,
          'isActive': true,
          'isOrganizationCreator': true, // Mark as organization creator
          'emailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create organization document
        batch.set(_firestore.collection('organizations').doc(orgCode), {
          'name': organizationName,
          'code': orgCode,
          'createdBy': user.uid,
          'admins': [user.uid],
          'pendingAdmins': [], // Initialize empty pending admins list
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'settings': {
            'allowStudentRegistration': true,
            'allowLecturerRegistration': true,
            'requireEmailVerification': true,
            'requireAdminActivation': true, // New setting for admin activation
          }
        });

        await batch.commit();
      }

      return AuthResult(
          success: true,
          message: isJoiningExisting
              ? 'Admin account created. Awaiting activation from organization creator.'
              : 'Organization created successfully!'
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _getErrorMessage(e.code));
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  // Sign in
  Future<AuthResult> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user == null) throw Exception('Sign in failed');

      // Get user data
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();
        throw Exception('User data not found');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Check if account is active
      if (!(userData['isActive'] ?? true)) {
        await _auth.signOut();

        // Check if it's a pending admin
        if (userData['role'] == 'admin' && (userData['requiresActivation'] ?? false)) {
          throw Exception('Your admin account is pending activation. Please wait for the organization creator to activate your account.');
        }

        throw Exception('Account has been deactivated');
      }

      // Update email verification status
      if (user.emailVerified && !(userData['emailVerified'] ?? false)) {
        await _firestore.collection('users').doc(user.uid).update({
          'emailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return AuthResult(
        success: true,
        message: 'Sign in successful',
        data: userData,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _getErrorMessage(e.code));
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  // Activate admin (for organization creators)
  Future<AuthResult> activateAdmin(String adminId, String organizationCode) async {
    try {
      // Verify caller is organization creator
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      DocumentSnapshot orgDoc = await _firestore
          .collection('organizations')
          .doc(organizationCode)
          .get();

      if (!orgDoc.exists) throw Exception('Organization not found');

      Map<String, dynamic> orgData = orgDoc.data() as Map<String, dynamic>;
      if (orgData['createdBy'] != currentUser.uid) {
        throw Exception('Only organization creator can activate admins');
      }

      // Update admin status
      await _firestore.collection('users').doc(adminId).update({
        'isActive': true,
        'requiresActivation': false,
        'activatedBy': currentUser.uid,
        'activatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update organization lists
      await _firestore.collection('organizations').doc(organizationCode).update({
        'admins': FieldValue.arrayUnion([adminId]),
        'pendingAdmins': FieldValue.arrayRemove([adminId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create audit log
      await _createAuditLog(
        organizationCode: organizationCode,
        action: 'admin_activated',
        userId: currentUser.uid,
        details: {
          'activatedAdminId': adminId,
          'activatedBy': currentUser.uid,
        },
      );

      // Notify the activated admin
      await _createNotification(
        userId: adminId,
        title: 'Account Activated',
        message: 'Your admin account has been activated. You can now sign in.',
        type: 'account_activated',
      );

      return AuthResult(success: true, message: 'Admin activated successfully');
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  // Deactivate admin (for organization creators)
  Future<AuthResult> deactivateAdmin(String adminId, String organizationCode) async {
    try {
      // Verify caller is organization creator
      User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      DocumentSnapshot orgDoc = await _firestore
          .collection('organizations')
          .doc(organizationCode)
          .get();

      if (!orgDoc.exists) throw Exception('Organization not found');

      Map<String, dynamic> orgData = orgDoc.data() as Map<String, dynamic>;
      if (orgData['createdBy'] != currentUser.uid) {
        throw Exception('Only organization creator can deactivate admins');
      }

      // Prevent deactivating self
      if (adminId == currentUser.uid) {
        throw Exception('Cannot deactivate your own account');
      }

      // Update admin status
      await _firestore.collection('users').doc(adminId).update({
        'isActive': false,
        'deactivatedBy': currentUser.uid,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create audit log
      await _createAuditLog(
        organizationCode: organizationCode,
        action: 'admin_deactivated',
        userId: currentUser.uid,
        details: {
          'deactivatedAdminId': adminId,
          'deactivatedBy': currentUser.uid,
        },
      );

      return AuthResult(success: true, message: 'Admin deactivated successfully');
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  // Get pending admins for organization
  Future<List<Map<String, dynamic>>> getPendingAdmins(String organizationCode) async {
    try {
      DocumentSnapshot orgDoc = await _firestore
          .collection('organizations')
          .doc(organizationCode)
          .get();

      if (!orgDoc.exists) return [];

      Map<String, dynamic> data = orgDoc.data() as Map<String, dynamic>;
      List<dynamic> pendingAdminIds = data['pendingAdmins'] ?? [];

      if (pendingAdminIds.isEmpty) return [];

      // Get user details for pending admins
      List<Map<String, dynamic>> pendingAdmins = [];
      for (String adminId in pendingAdminIds) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(adminId)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          pendingAdmins.add({
            'uid': adminId,
            'email': userData['email'],
            'fullName': userData['fullName'],
            'createdAt': userData['createdAt'],
          });
        }
      }

      return pendingAdmins;
    } catch (e) {
      return [];
    }
  }

  // Create notification
  Future<void> _createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(
        success: true,
        message: 'Password reset email sent',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _getErrorMessage(e.code));
    }
  }

  // Check if organization exists
  Future<bool> checkOrganizationExists(String orgCode) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('organizations')
          .doc(orgCode.toUpperCase())
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get organization details
  Future<Map<String, dynamic>?> getOrganizationDetails(String orgCode) async {
    try {
      final String upperOrgCode = orgCode.toUpperCase();
      print('Checking for organization with code: $upperOrgCode');

      DocumentSnapshot doc = await _firestore
          .collection('organizations')
          .doc(upperOrgCode)
          .get();

      print('Document exists: ${doc.exists}');

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('Organization found: ${data['name']}');

        return {
          'id': doc.id,
          'name': data['name'],
          'isActive': data['isActive'] ?? true,
        };
      } else {
        print('No organization found with code: $upperOrgCode');

        // List all organizations for debugging
        QuerySnapshot allOrgs = await _firestore.collection('organizations').get();
        print('Available organizations:');
        for (var org in allOrgs.docs) {
          print('- ${org.id}: ${org.data()}');
        }
      }
      return null;
    } catch (e) {
      print('Error getting organization details: $e');
      return null;
    }
  }

  // Get faculties for organization
  Future<List<Map<String, dynamic>>> getFaculties(String organizationId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('faculties')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'],
        'code': doc['code'],
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get programs for faculty
  Future<List<Map<String, dynamic>>> getPrograms(String organizationId, String facultyId) async {
    try {
      print('Fetching programs for org: $organizationId, faculty: $facultyId');

      // First, try without orderBy to avoid index issues
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('faculties')
          .doc(facultyId)
          .collection('programs')
          .get(); // Get all programs first

      print('Total programs found: ${snapshot.docs.length}');

      // Filter and sort in memory
      final programs = snapshot.docs
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Program',
          'code': data['code'] ?? '',
          'degree': data['degree'] ?? '',
          'isActive': data['isActive'] ?? true, // Default to true if not set
          ...data,
        };
      })
          .where((program) => program['isActive'] == true) // Filter active programs
          .toList();

      // Sort by name in memory
      programs.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      print('Active programs found: ${programs.length}');
      programs.forEach((program) {
        print('Program: ${program['code']} - ${program['name']} (Active: ${program['isActive']})');
      });

      return programs;
    } catch (e) {
      print('Error fetching programs: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Create audit log
  Future<void> _createAuditLog({
    required String organizationCode,
    required String action,
    required String userId,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _firestore
          .collection('organizations')
          .doc(organizationCode)
          .collection('audit_logs')
          .add({
        'action': action,
        'performedBy': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      });
    } catch (e) {
      print('Error creating audit log: $e');
    }
  }

  // Get error message
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'invalid-email':
        return 'Invalid email format';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return 'An error occurred. Please try again';
    }
  }
}

// Result class for auth operations
class AuthResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  AuthResult({
    required this.success,
    required this.message,
    this.data,
  });
}