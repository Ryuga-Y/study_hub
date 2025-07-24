import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'Authentication/auth_wrapper.dart';
import 'Authentication/onboarding_screen.dart';
import 'Authentication/role_selection.dart';
import 'Authentication/sign_in.dart';
import 'Authentication/admin_sign_up.dart';
import 'Lecturer/lecturer_home.dart';
import 'Student/student_home.dart';
import 'admin/admin_dashboard.dart';
import 'community/feed_screen.dart';
import 'community/models.dart';
import 'community/post_screen.dart';
import 'community/bloc.dart';
import 'call_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final CallListenerService _callListener = CallListenerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions(); // Add this line
    _callListener.initialize();  // Initialize call listener
  }

// Add this method in _MyAppState class
  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
    ].request();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CommunityBloc(),
      child: MaterialApp(
        navigatorKey: navigatorKey,  // ADD THIS LINE
        debugShowCheckedModeBanner: false,
        title: 'Study Hub',
        theme: ThemeData(
          primaryColor: Colors.purple[400],
          fontFamily: 'Abeezee',
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        ),
        routes: {
          '/': (context) => AuthWrapper(),
          '/feed': (context) => FeedScreen(
            organizationCode: // You'll need to get this from user data
            ModalRoute.of(context)!.settings.arguments as String,
          ),
          '/post': (context) => PostScreen(
            post: ModalRoute.of(context)!.settings.arguments as Post,
          ),
          '/onboarding': (context) => OnboardingScreen(),
          '/roleSelection': (context) => RoleSelectionPage(),
          '/signIn': (context) => SignInPage(),
          '/admin_signup': (context) => AdminSignUpPage(),
          '/admin_dashboard': (context) => AdminDashboard(),
          '/lecturer_home': (context) => LecturerHomePage(),
          '/student_home': (context) => StudentHomePage(),
        },
      ),
    );
  }
}