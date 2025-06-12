import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up method
  Future<void> signUp(String email, String password, String name, String programOrDepartment, String role) async {
    try {
      // Create a new user with Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get the user data
      User? user = userCredential.user;

      // Store the user's details in Firestore if the registration is successful
      if (user != null) {
        // Reference to the users collection in Firestore
        CollectionReference users = _firestore.collection('users');

        // Add user data to Firestore
        await users.doc(user.uid).set({
          'name': name,
          'email': email,
          'role': role, // Store role as either 'student' or 'lecturer'
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),  // Timestamp of when the account was created
          // Store 'program' for students and 'department' for lecturers
          role == 'student' ? 'program' : 'department': programOrDepartment,
        });
      }
    } on FirebaseAuthException catch (e) {
      // Handle registration errors
      throw e.message ?? 'Error during registration';
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Print detailed logs for debugging (in development, you can remove this later)
      print("FirebaseAuthException: ${e.code} - ${e.message}");

      // Return user-friendly error messages based on the Firebase error codes
      if (e.code == 'invalid-email') {
        throw 'The email address is badly formatted.';
      } else if (e.code == 'user-not-found') {
        throw 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        throw 'Incorrect password. Please try again.';
      } else {
        throw 'An error occurred. Please try again later.';
      }

    } catch (e) {
      // Catch other errors (non-Firebase related)
      print('Unknown Error: $e');
      throw 'Something went wrong. Please try again later.';
    }
  }

  // Sign out method
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get the current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
