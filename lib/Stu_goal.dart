import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StuGoal(),
    );
  }
}

class StuGoal extends StatefulWidget {
  @override
  _StuGoalState createState() => _StuGoalState();
}

class _StuGoalState extends State<StuGoal> with TickerProviderStateMixin {
  int wateringCount = 0;  // Number of times the tree has been watered
  double treeGrowth = 0.0; // Tree size scale (0 to 1)
  String goal = "Complete five quizzes this week"; // The user's goal

  // Maximum growth (e.g., tree fully grown at 100%)
  double maxGrowth = 5;

  late AnimationController _controller;
  late Animation<double> _treeSizeAnimation;

  // Function to water the tree and grow it
  void waterTree() {
    if (wateringCount < maxGrowth) {
      setState(() {
        wateringCount++;
        treeGrowth = wateringCount / maxGrowth;
      });
      _controller.forward(from: 0.0); // Trigger the animation from the beginning
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize the AnimationController and Animation
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    // Tween to animate the tree size from 1.0 to 1.5 (adjust to your preference)
    _treeSizeAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('StudyHub')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tree Image and Watering Progress
            Center(
              child: Column(
                children: [
                  // Tree Image with Animated Scale
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/tree.png'), // Correct path for tree image
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: AnimatedBuilder(
                      animation: _treeSizeAnimation,  // Use _treeSizeAnimation here
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _treeSizeAnimation.value,  // Scale tree image based on animation
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'assets/images/tree.png', // Correct path for tree image
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Watering Pot Icon (GestureDetector to water the tree)
                  GestureDetector(
                    onTap: waterTree,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.water_drop_outlined,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Progress Bar
                  LinearProgressIndicator(
                    value: treeGrowth,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "${(treeGrowth * 100).toInt()}% grown",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),

            // Goal Setting Section
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'Goal Setting',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 10),
                  Text(
                    goal,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      // Handle save goal action
                    },
                    child: Text('Save Goal'),
                  ),
                ],
              ),
            ),

            // View Badges Button
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Handle view badges action
              },
              child: Text('View Badges'),
            ),
          ],
        ),
      ),
    );
  }
}

