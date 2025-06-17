import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'Authentication/auth_wrapper.dart';
import 'Authentication/onboarding_screen.dart';
import 'Authentication/role_selection.dart';
import 'Authentication/sign_in.dart';
import 'Authentication/sign_up.dart';
import 'Authentication/admin_sign_up.dart';
import 'admin/admin_dashboard.dart';
import 'Course/lecturer_home.dart';
import 'student_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Study Hub',
      theme: ThemeData(
        primaryColor: Colors.purple[400],
        fontFamily: 'Abeezee',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      ),
      home: AuthWrapper(),
      routes: {
        '/onboarding': (context) => OnboardingScreen(),
        '/roleSelection': (context) => RoleSelectionPage(),
        '/signIn': (context) => SignInPage(),
        '/admin_signup': (context) => AdminSignUpPage(),
        '/admin_dashboard': (context) => AdminDashboard(),
        '/lecturer_home': (context) => LecturerHomePage(),
        '/student_home': (context) => StudentHomePage(),
      },
    );
  }
}