import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'Authentication/role_selection.dart';
import 'Authentication/sign_in.dart';
import 'Stu_courseState.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Firebase initialization
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OnboardingScreen(),
      routes: {
        '/roleSelection': (context) => RoleSelectionPage(), // Navigate to RoleSelectionPage
        '/signIn': (context) => SignInPage(), // Navigate to SignInPage
      },
    );
  }
}


class OnboardingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get the screen width and height using MediaQuery
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // Scale the font sizes based on screen width
    double titleFontSize = screenWidth * 0.15; // Increased font size
    double subTitleFontSize = screenWidth * 0.06;
    double buttonFontSize = screenWidth * 0.05;

    // Define padding based on screen width
    double horizontalPadding = screenWidth * 0.05;
    double verticalPadding = screenHeight * 0.05;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, // Align the text to the left
            children: [
              // Separate "Study Hub" into two lines with the new color and enlarged text
              Text(
                'Study',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E4A89), // #3E4A89 color
                ),
              ),
              Text(
                'Hub',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E4A89), // #3E4A89 color
                ),
              ),
              SizedBox(height: verticalPadding / 2),
              Text(
                'Let\'s Get Started!',
                style: TextStyle(
                  fontSize: subTitleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: verticalPadding / 3),
              Text(
                'Let\'s dive into study',
                style: TextStyle(
                  fontSize: subTitleFontSize * 0.8, // Slightly smaller text
                  color: Colors.blueGrey,
                ),
              ),
              SizedBox(height: verticalPadding),
              ElevatedButton(
                onPressed: () {
                  // Navigate to the RoleSelectionPage
                  Navigator.pushNamed(context, '/roleSelection');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[400], // Background color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Rounded corners
                  ),
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.3, vertical: screenHeight * 0.02),
                ),
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: verticalPadding / 2),
              OutlinedButton(
                onPressed: () {
                  // Navigate to the SignInPage
                  Navigator.pushNamed(context, '/signIn');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.purple[400]!, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.3, vertical: screenHeight * 0.02),
                ),
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.purple[400],
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
