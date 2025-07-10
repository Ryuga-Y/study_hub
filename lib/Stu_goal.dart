import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'set_goal.dart'; // Import the new set goal page
import 'bronze_tree.dart'; // Import bronze tree
import 'silver_tree.dart'; // Import silver tree
import 'gold_tree.dart'; // Import gold tree
import 'goal_progress_service.dart'; // Import the service

void main() => runApp(MyApp());

enum TreeLevel { bronze, silver, gold }

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
  // Firebase service
  final GoalProgressService _goalService = GoalProgressService();

  // Local state (synced with Firebase)
  int wateringCount = 0;
  double treeGrowth = 0.0;
  String goal = "No goal selected - Press 'Set Goal' to choose one";
  bool hasActiveGoal = false;
  double maxGrowth = 1.0;
  int maxWatering = 49;
  int waterBuckets = 0; // New: Water bucket count

  // Tree progression system
  TreeLevel currentTreeLevel = TreeLevel.bronze;
  int completedTrees = 0;
  int totalProgress = 0;

  // Loading state
  bool isLoading = true;

  late AnimationController _growthController;
  late AnimationController _flowerController;
  late AnimationController _leafController;
  late AnimationController _levelUpController;
  late AnimationController _waterAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _flowerBloomAnimation;
  late Animation<double> _flowerRotationAnimation;
  late Animation<double> _leafScaleAnimation;
  late Animation<double> _levelUpAnimation;
  late Animation<double> _waterDropAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadGoalProgress();
  }

  void _initializeAnimations() {
    _growthController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _flowerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );

    _leafController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _levelUpController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _waterAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _growthController,
      curve: Curves.elasticOut,
    ));

    _leafScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _leafController,
      curve: Curves.elasticOut,
    ));

    _flowerBloomAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flowerController,
      curve: Curves.elasticOut,
    ));

    _flowerRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _flowerController,
      curve: Curves.easeInOut,
    ));

    _levelUpAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _levelUpController,
      curve: Curves.bounceOut,
    ));

    _waterDropAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waterAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  // Load goal progress from Firebase
  Future<void> _loadGoalProgress() async {
    try {
      final progress = await _goalService.getGoalProgress();
      if (progress != null && mounted) {
        setState(() {
          wateringCount = progress['wateringCount'] ?? 0;
          treeGrowth = (progress['treeGrowth'] ?? 0.0).toDouble();
          goal = progress['currentGoal'] ?? "No goal selected - Press 'Set Goal' to choose one";
          hasActiveGoal = progress['hasActiveGoal'] ?? false;
          maxWatering = progress['maxWatering'] ?? 49;
          waterBuckets = progress['waterBuckets'] ?? 0;

          String treeLevelString = progress['currentTreeLevel'] ?? 'bronze';
          currentTreeLevel = TreeLevel.values.firstWhere(
                (e) => e.toString().split('.').last == treeLevelString,
            orElse: () => TreeLevel.bronze,
          );

          completedTrees = progress['completedTrees'] ?? 0;
          totalProgress = progress['totalProgress'] ?? 0;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading goal progress: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void waterTree() async {
    // Check if we have water buckets
    if (waterBuckets <= 0) {
      _showNoWaterBucketsMessage();
      return;
    }

    // Use water bucket through Firebase
    final success = await _goalService.useWaterBucket();

    if (success) {
      // Reload progress from Firebase
      await _loadGoalProgress();

      // Play animations
      _growthController.forward(from: 0.0);
      _leafController.forward(from: 0.0);
      _waterAnimationController.forward(from: 0.0);

      // Start flower blooming animation when 100% complete
      if (treeGrowth >= 1.0) {
        _flowerController.forward();

        // After a delay, level up the tree (handled by Firebase)
        Future.delayed(Duration(milliseconds: 2000), () {
          _showLevelUpMessage();
          _levelUpController.forward(from: 0.0);

          // Reset animations
          _flowerController.reset();
          _growthController.reset();
          _leafController.reset();
          _waterAnimationController.reset();
        });
      }
    }
  }

  void _showNoWaterBucketsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🪣 No water buckets! Complete assignments or tutorials to earn more.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showLevelUpMessage() {
    String message = "";
    Color color = Colors.green;

    switch (currentTreeLevel) {
      case TreeLevel.silver:
        message = "🥈 Level Up! Silver Tree Unlocked!";
        color = Colors.grey[400]!;
        break;
      case TreeLevel.gold:
        message = "🥇 Level Up! Gold Tree Unlocked!";
        color = Colors.amber;
        break;
      default:
        message = "🌳 Tree Complete! Keep growing!";
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _getProgressText() {
    return "${(treeGrowth * 100).toInt()}% grown";
  }

  // Function to update goal from the set goal page
  void updateGoal(String newGoal) async {
    print('Updating goal to: $newGoal');

    await _goalService.updateGoal(newGoal);

    setState(() {
      goal = newGoal;
      hasActiveGoal = true;
    });

    // Show confirmation that goal was set
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mission set: $newGoal ⭐'),
        backgroundColor: Colors.amber,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Function to handle view badges
  void _viewBadges() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('🏆 Your Badges'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bronze Badge
                ListTile(
                  leading: Icon(
                    Icons.emoji_events,
                    color: completedTrees >= 1 ? Color(0xFFCD7F32) : Colors.grey,
                    size: 30,
                  ),
                  title: Text('Bronze Tree Master'),
                  subtitle: Text(completedTrees >= 1 ? 'Completed!' : 'Complete 1 tree'),
                  trailing: completedTrees >= 1 ? Icon(Icons.check, color: Colors.green) : null,
                ),
                // Silver Badge
                ListTile(
                  leading: Icon(
                    Icons.emoji_events,
                    color: completedTrees >= 2 ? Color(0xFFC0C0C0) : Colors.grey,
                    size: 30,
                  ),
                  title: Text('Silver Tree Guardian'),
                  subtitle: Text(completedTrees >= 2 ? 'Completed!' : 'Complete 2 trees'),
                  trailing: completedTrees >= 2 ? Icon(Icons.check, color: Colors.green) : null,
                ),
                // Gold Badge
                ListTile(
                  leading: Icon(
                    Icons.emoji_events,
                    color: completedTrees >= 3 ? Color(0xFFFFD700) : Colors.grey,
                    size: 30,
                  ),
                  title: Text('Gold Tree Legend'),
                  subtitle: Text(completedTrees >= 3 ? 'Completed!' : 'Complete 3 trees'),
                  trailing: completedTrees >= 3 ? Icon(Icons.check, color: Colors.green) : null,
                ),
                SizedBox(height: 10),
                Text(
                  'Trees Completed: $completedTrees',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Total Progress: $totalProgress points',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _getCurrentTreePainter() {
    switch (currentTreeLevel) {
      case TreeLevel.bronze:
        return CustomPaint(
          painter: BronzeTreePainter(
            growthLevel: wateringCount,
            totalGrowth: treeGrowth,
            flowerBloom: _flowerBloomAnimation.value,
            flowerRotation: _flowerRotationAnimation.value,
            leafScale: _leafScaleAnimation.value,
            waterDropAnimation: _waterDropAnimation.value,
          ),
        );
      case TreeLevel.silver:
        return CustomPaint(
          painter: SilverTreePainter(
            growthLevel: wateringCount,
            totalGrowth: treeGrowth,
            flowerBloom: _flowerBloomAnimation.value,
            flowerRotation: _flowerRotationAnimation.value,
            leafScale: _leafScaleAnimation.value,
            waterDropAnimation: _waterDropAnimation.value,
          ),
        );
      case TreeLevel.gold:
        return CustomPaint(
          painter: GoldTreePainter(
            growthLevel: wateringCount,
            totalGrowth: treeGrowth,
            flowerBloom: _flowerBloomAnimation.value,
            flowerRotation: _flowerRotationAnimation.value,
            leafScale: _leafScaleAnimation.value,
            waterDropAnimation: _waterDropAnimation.value,
          ),
        );
    }
  }

  Widget _buildMedalIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bronze Medal
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completedTrees >= 1 ? Color(0xFFCD7F32) : Colors.grey[300],
            boxShadow: completedTrees >= 1 ? [
              BoxShadow(
                color: Color(0xFFCD7F32).withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ] : null,
          ),
          child: Icon(
            Icons.emoji_events,
            color: completedTrees >= 1 ? Colors.white : Colors.grey[500],
            size: currentTreeLevel == TreeLevel.bronze ? 20 : 16,
          ),
        ),
        SizedBox(width: 8),

        // Silver Medal
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completedTrees >= 2 ? Color(0xFFC0C0C0) : Colors.grey[300],
            boxShadow: completedTrees >= 2 ? [
              BoxShadow(
                color: Color(0xFFC0C0C0).withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ] : null,
          ),
          child: Icon(
            Icons.emoji_events,
            color: completedTrees >= 2 ? Colors.white : Colors.grey[500],
            size: currentTreeLevel == TreeLevel.silver ? 20 : 16,
          ),
        ),
        SizedBox(width: 8),

        // Gold Medal
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completedTrees >= 3 ? Color(0xFFFFD700) : Colors.grey[300],
            boxShadow: completedTrees >= 3 ? [
              BoxShadow(
                color: Color(0xFFFFD700).withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ] : null,
          ),
          child: Icon(
            Icons.emoji_events,
            color: completedTrees >= 3 ? Colors.white : Colors.grey[500],
            size: currentTreeLevel == TreeLevel.gold ? 20 : 16,
          ),
        ),
      ],
    );
  }

  String _getCurrentTreeLevelText() {
    switch (currentTreeLevel) {
      case TreeLevel.bronze:
        return "🥉 Bronze Tree";
      case TreeLevel.silver:
        return "🥈 Silver Tree";
      case TreeLevel.gold:
        return "🥇 Gold Tree";
    }
  }

  @override
  void dispose() {
    _growthController.dispose();
    _flowerController.dispose();
    _leafController.dispose();
    _levelUpController.dispose();
    _waterAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.lightBlue[50],
        appBar: AppBar(
          title: Text('StudyHub'),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        title: Text('StudyHub'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tree Level Indicator
            AnimatedBuilder(
              animation: _levelUpAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_levelUpAnimation.value * 0.1),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentTreeLevel == TreeLevel.bronze ? Color(0xFFCD7F32) :
                      currentTreeLevel == TreeLevel.silver ? Color(0xFFC0C0C0) :
                      Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (currentTreeLevel == TreeLevel.bronze ? Color(0xFFCD7F32) :
                          currentTreeLevel == TreeLevel.silver ? Color(0xFFC0C0C0) :
                          Color(0xFFFFD700)).withOpacity(0.3),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      _getCurrentTreeLevelText(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 12),

            // Tree Display Area
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _scaleAnimation,
                  _flowerBloomAnimation,
                  _flowerRotationAnimation,
                  _leafScaleAnimation,
                  _waterDropAnimation,
                ]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 300,
                      height: 320,
                      child: _getCurrentTreePainter(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 15),

            // Water Button with Bucket Count
            Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: waterTree,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: waterBuckets > 0 ? Colors.blueAccent : Colors.grey[400],
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: (waterBuckets > 0 ? Colors.blue : Colors.grey).withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.water_drop_outlined,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Water bucket count at bottom right
                Positioned(
                  right: -5,
                  bottom: -5,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[600],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_drink,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '$waterBuckets',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),

            // Progress bar with medals
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: treeGrowth,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      currentTreeLevel == TreeLevel.bronze ? Color(0xFFCD7F32) :
                      currentTreeLevel == TreeLevel.silver ? Color(0xFFC0C0C0) :
                      Color(0xFFFFD700),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                _buildMedalIcons(),
              ],
            ),
            SizedBox(height: 8),
            Text(
              _getProgressText(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              "Trees Completed: $completedTrees",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 15),

            // Mission in Progress Container
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasActiveGoal ? Colors.blueAccent : Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: hasActiveGoal ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasActiveGoal) ...[
                        Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                      ],
                      Text(
                        'Mission in Progress',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    goal,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontStyle: hasActiveGoal ? FontStyle.normal : FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: 15),

            // Water Bucket Info
            if (waterBuckets > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_drink, color: Colors.orange[700], size: 16),
                    SizedBox(width: 6),
                    Text(
                      'You have $waterBuckets water bucket${waterBuckets == 1 ? '' : 's'}!',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 15),

            // Set Goal Button
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SetGoalPage(
                      onGoalStarred: (String starredGoal) {
                        updateGoal(starredGoal);
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                shadowColor: Colors.blue.withOpacity(0.3),
                elevation: 4,
              ),
              child: Text('Set Goal'),
            ),

            SizedBox(height: 8),

            // View Badges Button
            ElevatedButton(
              onPressed: _viewBadges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                shadowColor: Colors.green.withOpacity(0.3),
                elevation: 4,
              ),
              child: Text('View Badges'),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}