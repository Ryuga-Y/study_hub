import 'package:flutter/material.dart';

class StuGoal extends StatefulWidget {
  @override
  _StuGoalState createState() => _StuGoalState();
}

class _StuGoalState extends State<StuGoal> with SingleTickerProviderStateMixin {
  int score = 0;
  double water = 0;
  double treeSize = 1.0;

  // Declare as late to satisfy null-safety
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );
    _sizeAnimation = Tween<double>(begin: 1.0, end: treeSize).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Call this after the student hands in a tutorial.
  void submitTutorial() {
    setState(() {
      score += 10;
      water += 10;
    });
  }

  /// When the student taps the port, animate the tree growing based on water collected.
  void onPortPressed() {
    setState(() {
      double newSize = 1.0 + (water / 100.0);
      _sizeAnimation = Tween<double>(
        begin: _sizeAnimation.value,
        end: newSize,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      )..addListener(() {
        setState(() {});
      });
      _controller.forward(from: 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Score: $score', style: TextStyle(fontSize: 18)),
        Text('Water: ${water.toInt()}', style: TextStyle(fontSize: 18)),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: submitTutorial,
          child: Text('Submit Tutorial (+10)'),
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: onPortPressed,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('Port', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
        SizedBox(height: 24),
        Transform.scale(
          scale: _sizeAnimation.value,
          child: Icon(Icons.nature, size: 100),
        ),
      ],
    );
  }
}
