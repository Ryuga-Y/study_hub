import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'dart:async'; // Add Timer import
import 'set_goal.dart'; // Import the new set goal page
import 'bronze_tree.dart'; // Import bronze tree
import 'silver_tree.dart'; // Import silver tree
import 'gold_tree.dart'; // Import gold tree
import 'goal_progress_service.dart'; // Import the service
import 'view_badges.dart'; // Import the new view badges page

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
  // 🔧 ADD: New field to track actual water consumption count
  int actualWaterConsumptionCount = 0;
  double treeGrowth = 0.0;
  String goal = "No goal selected - Press 'Set Goal' to choose one";
  List<String> pinnedGoals = []; // List of pinned goals
  bool hasActiveGoal = false;
  double maxGrowth = 1.0;
  int maxWatering = 20; // Changed to 20 since each bucket = 5%
  int waterBuckets = 0; // Water bucket count

  // Tree progression system
  TreeLevel currentTreeLevel = TreeLevel.bronze;
  int completedTrees = 0;
  int totalProgress = 0;

  // Loading state
  bool isLoading = true;
  bool isAutoSyncing = false; // Track auto-sync status

  // Animation controllers
  late AnimationController _growthController;
  late AnimationController _flowerController;
  late AnimationController _leafController;
  late AnimationController _levelUpController;
  late AnimationController _waterAnimationController;
  late AnimationController _bucketPulseController; // New animation for bucket count
  late Animation<double> _scaleAnimation;
  late Animation<double> _flowerBloomAnimation;
  late Animation<double> _flowerRotationAnimation;
  late Animation<double> _leafScaleAnimation;
  late Animation<double> _levelUpAnimation;
  late Animation<double> _waterDropAnimation;
  late Animation<double> _bucketPulseAnimation; // New animation

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadGoalProgress();
    _startListeningForSubmissions(); // Add automatic submission detection
    _startRealtimeGoalProgressListener(); // Add real-time Firebase listener
    _startAutoSyncTimer(); // 🔄 NEW: Start auto-sync timer

    // Check for missed rewards on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForMissedRewards();
    });
  }

  // Add this new method:
  Future<void> _checkForMissedRewards() async {
    try {
      print('🔍 Checking for any missed submission rewards...');
      await _goalService.scanAndRewardMissedSubmissions();
    } catch (e) {
      print('Error checking missed rewards: $e');
    }
  }

  // 🚀 UPDATED: Auto-sync timer with longer intervals
  void _startAutoSyncTimer() {
    // Check every 2 minutes for deleted rewards (longer interval)
    Timer.periodic(Duration(minutes: 2), (timer) {
      if (mounted && !isLoading) {
        _performAutoSync();
      } else {
        timer.cancel();
      }
    });
  }

  // 🚀 UPDATED: Less aggressive auto-sync
  Future<void> _performAutoSync() async {
    if (isAutoSyncing || isLoading) return; // Prevent concurrent syncs

    try {
      setState(() {
        isAutoSyncing = true;
      });

      // Only perform auto-sync if there's a significant discrepancy
      final bucketCountChanged = await _goalService.autoSyncWaterBuckets();

      if (bucketCountChanged) {
        print('🔄 Auto-sync detected significant changes - refreshing UI...');

        // Reload goal progress to get updated bucket count
        await _loadGoalProgress();

        // Show subtle notification that buckets were updated (only for major changes)
        _showAutoSyncNotification();
      }
    } catch (e) {
      print('❌ Error during auto-sync: $e');
    } finally {
      setState(() {
        isAutoSyncing = false;
      });
    }
  }

  // 🔄 NEW: Show notification when auto-sync corrects bucket count
  void _showAutoSyncNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.sync, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '🔄 Water bucket count synchronized',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80),
      ),
    );
  }

  // 🔄 NEW: Manual recalculation method for debugging/maintenance
  Future<void> _manualRecalculation() async {
    try {
      setState(() {
        isLoading = true;
      });

      final result = await _goalService.recalculateWaterBuckets();

      if (result['success'] == true) {
        final oldCount = result['oldBucketCount'] ?? 0;
        final newCount = result['newBucketCount'] ?? 0;
        final difference = result['bucketDifference'] ?? 0;

        // Reload UI with corrected data
        await _loadGoalProgress();

        // Show detailed result
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.sync, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text('Recalculation Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Water bucket count has been synchronized with submission rewards.'),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Old count: $oldCount buckets'),
                      Text('New count: $newCount buckets'),
                      if (difference != 0) ...[
                        SizedBox(height: 4),
                        Text(
                          'Correction: ${difference > 0 ? '+' : ''}$difference buckets',
                          style: TextStyle(
                            color: difference > 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      SizedBox(height: 8),
                      Text('Total assignments: ${result['totalAssignments'] ?? 0}'),
                      Text('Total tutorials: ${result['totalTutorials'] ?? 0}'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Recalculation failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error during recalculation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Start real-time listener for goal progress changes
  void _startRealtimeGoalProgressListener() {
    _goalService.getGoalProgressStream().listen((snapshot) async {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        final newWaterBuckets = data['waterBuckets'] ?? 0;
        final newTreeGrowth = (data['treeGrowth'] ?? 0.0).toDouble();
        final newWateringCount = data['wateringCount'] ?? 0;

        // 🔧 FIX: Get actual water consumption count
        final newActualWaterConsumptionCount = await _goalService.getActualWaterConsumptionCount();

        // 🚀 FIXED: Only trigger reward notification if buckets increased significantly
        // This prevents interference with normal bucket consumption
        if (newWaterBuckets > waterBuckets + 1) {
          // Significant increase detected (new submission reward)
          final bucketsAdded = newWaterBuckets - waterBuckets;

          setState(() {
            waterBuckets = newWaterBuckets;
            wateringCount = newWateringCount;
            actualWaterConsumptionCount = newActualWaterConsumptionCount; // 🔧 Update
            treeGrowth = newTreeGrowth;

            // Handle pinned goals
            if (data['pinnedGoals'] != null && data['pinnedGoals'] is List) {
              pinnedGoals = List<String>.from(data['pinnedGoals']);
              hasActiveGoal = pinnedGoals.isNotEmpty;
            } else {
              pinnedGoals = [];
              hasActiveGoal = data['hasActiveGoal'] ?? false;
            }

            goal = data['currentGoal'] ?? "No goal selected - Press 'Set Goal' to choose one";

            String treeLevelString = data['currentTreeLevel'] ?? 'bronze';
            currentTreeLevel = TreeLevel.values.firstWhere(
                  (e) => e.toString().split('.').last == treeLevelString,
              orElse: () => TreeLevel.bronze,
            );
            completedTrees = data['completedTrees'] ?? 0;
            totalProgress = data['totalProgress'] ?? 0;
          });

          // Trigger bucket pulse animation
          _triggerBucketPulse();

          // Show congratulations message
          _showBucketRewardMessage(bucketsAdded);
        } else {
          // 🚀 FIXED: For normal updates (like bucket consumption), update silently
          // Don't override if we're in the middle of a water operation
          if (!isLoading) {
            setState(() {
              // Only update if the values are different to avoid unnecessary rebuilds
              if (waterBuckets != newWaterBuckets) waterBuckets = newWaterBuckets;
              if (wateringCount != newWateringCount) wateringCount = newWateringCount;
              if (actualWaterConsumptionCount != newActualWaterConsumptionCount) {
                actualWaterConsumptionCount = newActualWaterConsumptionCount; // 🔧 Update
              }
              if (treeGrowth != newTreeGrowth) treeGrowth = newTreeGrowth;

              // Handle pinned goals
              if (data['pinnedGoals'] != null && data['pinnedGoals'] is List) {
                pinnedGoals = List<String>.from(data['pinnedGoals']);
                hasActiveGoal = pinnedGoals.isNotEmpty;
              } else {
                pinnedGoals = [];
                hasActiveGoal = data['hasActiveGoal'] ?? false;
              }

              goal = data['currentGoal'] ?? "No goal selected - Press 'Set Goal' to choose one";

              String treeLevelString = data['currentTreeLevel'] ?? 'bronze';
              TreeLevel newTreeLevel = TreeLevel.values.firstWhere(
                    (e) => e.toString().split('.').last == treeLevelString,
                orElse: () => TreeLevel.bronze,
              );
              if (currentTreeLevel != newTreeLevel) currentTreeLevel = newTreeLevel;

              int newCompletedTrees = data['completedTrees'] ?? 0;
              if (completedTrees != newCompletedTrees) completedTrees = newCompletedTrees;

              int newTotalProgress = data['totalProgress'] ?? 0;
              if (totalProgress != newTotalProgress) totalProgress = newTotalProgress;
            });
          }
        }
      }
    });
  }

  // 🚀 UPDATED: Modified to reduce frequency and avoid interference
  void _startListeningForSubmissions() {
    // Check for new submissions when app starts
    _checkForNewSubmissions();

    // Set up periodic checks (reduced frequency to every 30 seconds)
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkForNewSubmissions();
      } else {
        timer.cancel();
      }
    });
  }

  // Check for new submissions and update water buckets
  Future<void> _checkForNewSubmissions() async {
    try {
      await _goalService.checkAndProcessNewSubmissions();
    } catch (e) {
      print('Error checking for new submissions: $e');
    }
  }

  // Show message when new water buckets are earned
  void _showBucketRewardMessage(int bucketsAdded) {
    String submissionType = '';
    if (bucketsAdded == 1) {
      submissionType = 'tutorial';
    } else if (bucketsAdded == 4) {
      submissionType = 'assignment';
    } else {
      submissionType = 'submission';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.celebration, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('🎉 Great job! You earned $bucketsAdded water bucket${bucketsAdded == 1 ? '' : 's'} for completing a $submissionType!'),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_drink, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '+$bucketsAdded',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

    // New bucket pulse animation
    _bucketPulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
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

    // New bucket pulse animation
    _bucketPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _bucketPulseController,
      curve: Curves.elasticOut,
    ));
  }

  // 🚀 UPDATED: Remove auto-sync from refresh method to avoid interference
  Future<void> _refreshWaterBuckets() async {
    try {
      // Get bucket count directly without auto-sync
      final progress = await _goalService.getGoalProgress();
      if (progress != null && mounted) {
        setState(() {
          waterBuckets = progress['waterBuckets'] ?? 0;
        });
      }
    } catch (e) {
      print('Error refreshing water buckets: $e');
    }
  }

  // 🔧 UPDATE: Load goal progress method
  Future<void> _loadGoalProgress() async {
    try {
      final progress = await _goalService.getGoalProgress();
      if (progress != null && mounted) {
        setState(() {
          wateringCount = progress['wateringCount'] ?? 0;
          // 🔧 FIX: Load actual water consumption count
          actualWaterConsumptionCount = progress['actualWaterConsumptionCount'] ?? 0;

          treeGrowth = (progress['treeGrowth'] ?? 0.0).toDouble();
          goal = progress['currentGoal'] ?? "No goal selected - Press 'Set Goal' to choose one";

          // Handle pinned goals
          if (progress['pinnedGoals'] != null && progress['pinnedGoals'] is List) {
            pinnedGoals = List<String>.from(progress['pinnedGoals']);
            hasActiveGoal = pinnedGoals.isNotEmpty;
          } else {
            pinnedGoals = [];
            hasActiveGoal = progress['hasActiveGoal'] ?? false;
          }

          maxWatering = progress['maxWatering'] ?? 20;
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

        // Trigger bucket pulse animation if there are water buckets
        if (waterBuckets > 0) {
          _triggerBucketPulse();
        }
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

  // Trigger bucket pulse animation
  void _triggerBucketPulse() {
    _bucketPulseController.forward(from: 0.0).then((_) {
      _bucketPulseController.reverse();
    });
  }

  Future<void> waterTree() async {
    // Check if we have water buckets
    if (waterBuckets <= 0) {
      _showNoWaterBucketsMessage();
      return;
    }

    // Store initial values for animation
    double previousGrowth = treeGrowth;
    int previousBuckets = waterBuckets;

    // 🚀 FIXED: Update UI immediately for responsive feedback
    setState(() {
      waterBuckets = previousBuckets - 1;
      treeGrowth = math.min(previousGrowth + 0.05, 1.0);
    });

    // Use water bucket through Firebase
    final success = await _goalService.useWaterBucket();

    if (success) {
      // Firebase operation successful - UI already updated above

      // Calculate growth increase for visual feedback
      double growthIncrease = 0.05;

      // Play animations
      _growthController.forward(from: 0.0);
      _leafController.forward(from: 0.0);
      _waterAnimationController.forward(from: 0.0);

      // Show growth feedback
      _showGrowthFeedback(growthIncrease);

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

      // 🔧 FIX: Update actual water consumption count after watering
      final newActualCount = await _goalService.getActualWaterConsumptionCount();
      setState(() {
        actualWaterConsumptionCount = newActualCount;
      });

      // Reload progress from Firebase after a short delay to ensure consistency
      Future.delayed(Duration(milliseconds: 500), () {
        _loadGoalProgress();
      });
    } else {
      // Firebase operation failed - revert UI changes
      setState(() {
        waterBuckets = previousBuckets;
        treeGrowth = previousGrowth;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to use water bucket. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showGrowthFeedback(double growthIncrease) {
    if (growthIncrease > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.local_florist, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('🌱 Tree grew by ${(growthIncrease * 100).toStringAsFixed(0)}%!'),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(treeGrowth * 100).toStringAsFixed(0)}% Complete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showNoWaterBucketsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.water_drop_outlined, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🪣 No water buckets available!'),
                  SizedBox(height: 4),
                  Text(
                    'Complete assignments (4 buckets) or tutorials (1 bucket) to earn more.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
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

  // Calculate how many times user can water (each watering = 5% growth)
  int _getMaxWateringTimes() {
    return waterBuckets; // Each bucket allows one watering (5% growth)
  }

  // Get water bucket source breakdown
  Map<String, int> _getWaterBucketBreakdown() {
    // This is an estimation based on the reward system
    // In a real implementation, you might want to track this separately
    int assignmentBuckets = (waterBuckets / 20).floor() * 20;
    int tutorialBuckets = waterBuckets - assignmentBuckets;

    return {
      'assignments': assignmentBuckets ~/ 20,
      'tutorials': tutorialBuckets ~/ 5,
      'remaining': waterBuckets % 5,
    };
  }

  // Function to update goal from the set goal page
  void updateGoal(String newGoal) async {
    print('Updating goals with: $newGoal');

    // The newGoal string contains all pinned goals joined by ' • '
    setState(() {
      goal = newGoal;
      if (newGoal != "No goal selected - Press 'Set Goal' to choose one") {
        pinnedGoals = newGoal.split(' • ').where((g) => g.isNotEmpty).toList();
        hasActiveGoal = pinnedGoals.isNotEmpty;
      } else {
        pinnedGoals = [];
        hasActiveGoal = false;
      }
    });

    // Show confirmation that goals were updated
    if (pinnedGoals.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Missions updated: ${pinnedGoals.length} goal${pinnedGoals.length > 1 ? 's' : ''} pinned ⭐'),
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Function to handle view badges - UPDATED to navigate to ViewBadgesPage
  void _viewBadges() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewBadgesPage(),
      ),
    );
  }

  // Show water bucket details
  void _showWaterBucketDetails() {
    final breakdown = _getWaterBucketBreakdown();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.local_drink, color: Colors.orange[600]),
              SizedBox(width: 8),
              Text('Water Bucket Details'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_drink, color: Colors.orange[600], size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Total: $waterBuckets buckets',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Each bucket waters your tree by 5%',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'How to earn more buckets:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.assignment, color: Colors.purple[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete Assignment: +4 buckets',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.quiz, color: Colors.blue[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete Tutorial: +1 bucket',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              if (waterBuckets > 0) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You can water your tree ${_getMaxWateringTimes()} time${_getMaxWateringTimes() == 1 ? '' : 's'}!',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'This will grow your tree by ${(_getMaxWateringTimes() * 5)}%',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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

  // 🔍 DEBUG: Show bucket count verification dialog
  Future<void> _showBucketVerification() async {
    try {
      final verification = await _goalService.verifyBucketCount();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bug_report, color: Colors.blue[600]),
              SizedBox(width: 8),
              Text('Bucket Count Debug'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (verification['error'] != null)
                Text('Error: ${verification['error']}')
              else ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: verification['isCorrect'] ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: verification['isCorrect'] ? Colors.green[300]! : Colors.red[300]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verification['message'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: verification['isCorrect'] ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Current in Firebase: ${verification['currentBuckets']}'),
                      Text('Calculated (earned - consumed): ${verification['calculatedBuckets']}'),
                      Text('Total earned: ${verification['totalEarned']}'),
                      Text('Total consumed: ${verification['totalConsumed']}'),
                      if (verification['discrepancy'] != 0)
                        Text(
                          'Discrepancy: ${verification['discrepancy']}',
                          style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (verification['error'] == null && !verification['isCorrect'])
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _manualRecalculation();
                },
                child: Text('Fix Discrepancy'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _getCurrentTreePainter() {
    // 🔧 FIX: Use actual water consumption count instead of wateringCount
    final int leafCount = actualWaterConsumptionCount;

    switch (currentTreeLevel) {
      case TreeLevel.bronze:
        return CustomPaint(
          painter: BronzeTreePainter(
            growthLevel: leafCount, // 🔧 Use actual consumption count
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
            growthLevel: leafCount, // 🔧 Use actual consumption count
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
            growthLevel: leafCount, // 🔧 Use actual consumption count
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
                color: Color(0xFFCD7F32).withValues(alpha: 0.3),
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
                color: Color(0xFFC0C0C0).withValues(alpha: 0.3),
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
                color: Color(0xFFFFD700).withValues(alpha: 0.3),
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
    _bucketPulseController.dispose();
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
        actions: [
          // 🔄 Debug verification button (remove after testing)
          IconButton(
            onPressed: _showBucketVerification,
            icon: Icon(Icons.bug_report, color: Colors.orange[600]),
            tooltip: 'Debug Bucket Count',
          ),

          // 🔄 Auto-sync indicator
          if (isAutoSyncing)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                  ),
                ),
              ),
            ),

          // Water bucket info button
          IconButton(
            onPressed: _showWaterBucketDetails,
            icon: Stack(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600]),
                if (waterBuckets > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.orange[600],
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$waterBuckets',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
                          Color(0xFFFFD700)).withValues(alpha: 0.3),
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

            // Enhanced Water Button with Bucket Count and Animation
            GestureDetector(
              onTap: () async {
                // Refresh bucket count before attempting to water
                await _refreshWaterBuckets();
                await waterTree();
              },
              child: AnimatedBuilder(
                animation: _bucketPulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _bucketPulseAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: waterBuckets > 0 ? Colors.blueAccent : Colors.grey[400],
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: (waterBuckets > 0 ? Colors.blue : Colors.grey).withOpacity(0.3),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.water_drop_outlined,
                            size: 55,
                            color: Colors.white,
                          ),
                        ),
                        // Water bucket count at bottom right
                        if (waterBuckets > 0)
                          Positioned(
                            right: -8,
                            bottom: -8,
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange[600],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_drink,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  AnimatedSwitcher(
                                    duration: Duration(milliseconds: 300),
                                    child: Text(
                                      '$waterBuckets',
                                      key: ValueKey(waterBuckets),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
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
                    minHeight: 8,
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
                        hasActiveGoal ? 'Missions in Progress' : 'Mission in Progress',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (pinnedGoals.isNotEmpty) ...[
                    ...pinnedGoals.map((goalTitle) => Container(
                      margin: EdgeInsets.symmetric(vertical: 2),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            color: Colors.amber,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              goalTitle,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ] else
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

            // Enhanced Water Bucket Info
            if (waterBuckets > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[100]!, Colors.orange[50]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_drink, color: Colors.orange[700], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'You have $waterBuckets water bucket${waterBuckets == 1 ? '' : 's'}!',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_florist, color: Colors.green[600], size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Tap the water drop to grow your tree (5% per bucket)',
                          style: TextStyle(
                            color: Colors.orange[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_drop_outlined, color: Colors.grey[600], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'No water buckets available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Complete assignments (+4) or tutorials (+1) to earn buckets!',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SetGoalPage(
                            onGoalPinned: (String starredGoal) {
                              updateGoal(starredGoal);
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      shadowColor: Colors.blue.withOpacity(0.3),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flag, size: 18),
                        SizedBox(width: 6),
                        Text('Set Goal'),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _viewBadges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      shadowColor: Colors.green.withOpacity(0.3),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, size: 18),
                        SizedBox(width: 6),
                        Text('View Badges'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}