import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum TreeLevel { bronze, silver, gold }

class GoalProgressService {
  static final GoalProgressService _instance = GoalProgressService._internal();
  factory GoalProgressService() => _instance;
  GoalProgressService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Verify user is a student before any goal operations
  Future<bool> _verifyStudentAccess() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      return userData['role'] == 'student' &&
          userData['isActive'] == true;
    } catch (e) {
      print('Error verifying student access: $e');
      return false;
    }
  }

  // Get current user's goal progress
  Stream<DocumentSnapshot> getGoalProgressStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('goalProgress')
        .doc(userId)
        .snapshots();
  }

  // Get current goal progress as a future
  Future<Map<String, dynamic>?> getGoalProgress() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Verify user is a student
    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    final doc = await _firestore
        .collection('goalProgress')
        .doc(userId)
        .get();

    if (doc.exists) {
      return doc.data();
    } else {
      // Initialize default progress for new student
      await initializeGoalProgress();
      return await getGoalProgress();
    }
  }

  // Initialize default goal progress (ONLY for students)
  Future<void> initializeGoalProgress() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Verify user is a student
    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    final defaultProgress = {
      'waterBuckets': 0,
      'wateringCount': 0,
      'treeGrowth': 0.0,
      'currentGoal': 'No goal selected - Press \'Set Goal\' to choose one',
      'hasActiveGoal': false,
      'currentTreeLevel': 'bronze',
      'completedTrees': 0,
      'totalProgress': 0,
      'maxWatering': 49,
      'lastUpdated': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('goalProgress')
        .doc(userId)
        .set(defaultProgress);
  }

  // Update goal progress (ONLY for students)
  Future<void> updateGoalProgress(Map<String, dynamic> progress) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Verify user is a student
    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    progress['lastUpdated'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('goalProgress')
        .doc(userId)
        .update(progress);
  }

  // Award water buckets for tutorial submission (2 buckets, 5% each)
  Future<void> awardTutorialSubmission(String submissionId, String materialId) async {
    // Verify user is a student before awarding
    if (!await _verifyStudentAccess()) {
      print('Tutorial reward skipped: User is not a student');
      return;
    }
    await _awardWaterBuckets(submissionId, 2, 'tutorial');
  }

  // Award water buckets for assignment submission (10 buckets, 10% each)
  Future<void> awardAssignmentSubmission(String submissionId, String assignmentId) async {
    // Verify user is a student before awarding
    if (!await _verifyStudentAccess()) {
      print('Assignment reward skipped: User is not a student');
      return;
    }
    await _awardWaterBuckets(submissionId, 10, 'assignment');
  }

  // Internal method to award water buckets (ONLY for students)
  Future<void> _awardWaterBuckets(String submissionId, int buckets, String type) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Double-check user is a student
    if (!await _verifyStudentAccess()) {
      throw Exception('Rewards are only available for students');
    }

    // Check if this submission has already been rewarded
    final rewardDoc = await _firestore
        .collection('submissionRewards')
        .doc(userId)
        .collection('rewards')
        .doc(submissionId)
        .get();

    if (rewardDoc.exists) {
      print('Submission $submissionId already rewarded');
      return; // Already rewarded
    }

    // Mark this submission as rewarded
    await _firestore
        .collection('submissionRewards')
        .doc(userId)
        .collection('rewards')
        .doc(submissionId)
        .set({
      'type': type,
      'buckets': buckets,
      'awardedAt': FieldValue.serverTimestamp(),
      'submissionId': submissionId,
    });

    // Get current progress
    final progressDoc = await _firestore
        .collection('goalProgress')
        .doc(userId)
        .get();

    Map<String, dynamic> currentProgress;
    if (progressDoc.exists) {
      currentProgress = progressDoc.data()!;
    } else {
      await initializeGoalProgress();
      currentProgress = (await getGoalProgress())!;
    }

    // Add water buckets
    int currentBuckets = currentProgress['waterBuckets'] ?? 0;
    currentBuckets += buckets;

    await updateGoalProgress({
      'waterBuckets': currentBuckets,
    });

    print('Awarded $buckets water buckets for $type submission. Total: $currentBuckets');
  }

  // Use a water bucket (called when watering tree) - ONLY for students
  Future<bool> useWaterBucket() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Verify user is a student
    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    final progressDoc = await _firestore
        .collection('goalProgress')
        .doc(userId)
        .get();

    if (!progressDoc.exists) {
      await initializeGoalProgress();
      return false;
    }

    final currentProgress = progressDoc.data()!;
    int waterBuckets = currentProgress['waterBuckets'] ?? 0;
    int wateringCount = currentProgress['wateringCount'] ?? 0;
    double treeGrowth = (currentProgress['treeGrowth'] ?? 0.0).toDouble();
    int maxWatering = currentProgress['maxWatering'] ?? 49;

    // Check if we have water buckets and tree is not complete
    if (waterBuckets <= 0 || wateringCount >= maxWatering) {
      return false;
    }

    // Use one water bucket
    waterBuckets--;
    wateringCount++;
    int totalProgress = currentProgress['totalProgress'] ?? 0;
    totalProgress++;
    treeGrowth = wateringCount / maxWatering;

    // Check if tree is complete
    if (wateringCount >= maxWatering) {
      // Tree completed, level up
      String currentTreeLevel = currentProgress['currentTreeLevel'] ?? 'bronze';
      int completedTrees = currentProgress['completedTrees'] ?? 0;
      completedTrees++;

      // Determine next tree level
      if (currentTreeLevel == 'bronze' && completedTrees >= 1) {
        currentTreeLevel = 'silver';
      } else if (currentTreeLevel == 'silver' && completedTrees >= 2) {
        currentTreeLevel = 'gold';
      }

      // Reset for next tree
      wateringCount = 0;
      treeGrowth = 0.0;

      await updateGoalProgress({
        'waterBuckets': waterBuckets,
        'wateringCount': wateringCount,
        'treeGrowth': treeGrowth,
        'currentTreeLevel': currentTreeLevel,
        'completedTrees': completedTrees,
        'totalProgress': totalProgress,
      });
    } else {
      await updateGoalProgress({
        'waterBuckets': waterBuckets,
        'wateringCount': wateringCount,
        'treeGrowth': treeGrowth,
        'totalProgress': totalProgress,
      });
    }

    return true;
  }

  // Update goal text (ONLY for students)
  Future<void> updateGoal(String goalText) async {
    // Verify user is a student
    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    await updateGoalProgress({
      'currentGoal': goalText,
      'hasActiveGoal': true,
    });
  }

  // Check if user has any water buckets (ONLY for students)
  Future<bool> hasWaterBuckets() async {
    if (!await _verifyStudentAccess()) {
      return false; // Non-students don't have buckets
    }

    final progress = await getGoalProgress();
    if (progress == null) return false;
    return (progress['waterBuckets'] ?? 0) > 0;
  }

  // Get water bucket count (ONLY for students)
  Future<int> getWaterBucketCount() async {
    if (!await _verifyStudentAccess()) {
      return 0; // Non-students have 0 buckets
    }

    try {
      final progress = await getGoalProgress();
      if (progress == null) return 0;
      return progress['waterBuckets'] ?? 0;
    } catch (e) {
      print('Error getting water bucket count: $e');
      return 0;
    }
  }

  // Check if current user is a student (public method)
  Future<bool> isCurrentUserStudent() async {
    return await _verifyStudentAccess();
  }
}