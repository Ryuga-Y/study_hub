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

  // Get current user's goal progress with real-time updates
  Stream<DocumentSnapshot> getGoalProgressStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('goalProgress')
        .doc(userId)
        .snapshots();
  }

  // Listen for new submissions and award buckets automatically
  Stream<List<DocumentSnapshot>> listenForNewSubmissions() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Listen to the user's submission rewards collection under goalProgress
    return _firestore
        .collection('goalProgress')
        .doc(userId)
        .collection('submissionRewards')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Check and process any new submissions that haven't been rewarded yet
  Future<void> checkAndProcessNewSubmissions() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !await _verifyStudentAccess()) return;

    try {
      // Get user's organization and courses
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final orgCode = userData['organizationCode'];
      if (orgCode == null) return;

      // Get all courses this student is enrolled in
      final enrollmentsSnapshot = await _firestore
          .collectionGroup('enrollments')
          .where('studentId', isEqualTo: userId)
          .get();

      // Check for new assignment submissions
      for (var enrollment in enrollmentsSnapshot.docs) {
        final courseRef = enrollment.reference.parent.parent;
        if (courseRef == null) continue;

        // Check assignment submissions
        await _checkCourseAssignmentSubmissions(courseRef.id, orgCode, userId);

        // Check tutorial submissions
        await _checkCourseTutorialSubmissions(courseRef.id, orgCode, userId);
      }
    } catch (e) {
      print('Error checking new submissions: $e');
    }
  }

  // Check for new assignment submissions in a course
  Future<void> _checkCourseAssignmentSubmissions(String courseId, String orgCode, String userId) async {
    try {
      final assignmentsSnapshot = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('assignments')
          .get();

      for (var assignment in assignmentsSnapshot.docs) {
        final submissionsSnapshot = await _firestore
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(courseId)
            .collection('assignments')
            .doc(assignment.id)
            .collection('submissions')
            .where('studentId', isEqualTo: userId)
            .get();

        for (var submission in submissionsSnapshot.docs) {
          // Check if this submission has been rewarded (NEW PATH)
          final rewardDoc = await _firestore
              .collection('goalProgress')
              .doc(userId)
              .collection('submissionRewards')
              .doc(submission.id)
              .get();

          if (!rewardDoc.exists) {
            // Award buckets for this new submission
            await awardAssignmentSubmission(submission.id, assignment.id);
            print('Awarded 4 buckets for assignment submission: ${submission.id}');
          }
        }
      }
    } catch (e) {
      print('Error checking assignment submissions: $e');
    }
  }

  // Check for new tutorial submissions in a course
  Future<void> _checkCourseTutorialSubmissions(String courseId, String orgCode, String userId) async {
    try {
      final materialsSnapshot = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('materials')
          .where('materialType', isEqualTo: 'tutorial')
          .get();

      for (var material in materialsSnapshot.docs) {
        final submissionsSnapshot = await _firestore
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(courseId)
            .collection('materials')
            .doc(material.id)
            .collection('submissions')
            .where('studentId', isEqualTo: userId)
            .get();

        for (var submission in submissionsSnapshot.docs) {
          // Check if this submission has been rewarded (NEW PATH)
          final rewardDoc = await _firestore
              .collection('goalProgress')
              .doc(userId)
              .collection('submissionRewards')
              .doc(submission.id)
              .get();

          if (!rewardDoc.exists) {
            // Award buckets for this new submission
            await awardTutorialSubmission(submission.id, material.id);
            print('Awarded 1 bucket for tutorial submission: ${submission.id}');
          }
        }
      }
    } catch (e) {
      print('Error checking tutorial submissions: $e');
    }
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
      'maxWatering': 20, // Changed to 20 since each bucket = 5% (20 buckets = 100%)
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

  // Award water buckets for tutorial submission (1 bucket = 5% growth potential)
  Future<void> awardTutorialSubmission(String submissionId, String materialId) async {
    // Verify user is a student before awarding
    if (!await _verifyStudentAccess()) {
      print('Tutorial reward skipped: User is not a student');
      return;
    }
    await _awardWaterBuckets(submissionId, 1, 'tutorial');
  }

  // Award water buckets for assignment submission (4 buckets = 20% growth potential)
  Future<void> awardAssignmentSubmission(String submissionId, String assignmentId) async {
    // Verify user is a student before awarding
    if (!await _verifyStudentAccess()) {
      print('Assignment reward skipped: User is not a student');
      return;
    }
    await _awardWaterBuckets(submissionId, 4, 'assignment');
  }

  // Internal method to award water buckets (ONLY for students)
  Future<void> _awardWaterBuckets(String submissionId, int buckets, String type) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Double-check user is a student
    if (!await _verifyStudentAccess()) {
      throw Exception('Rewards are only available for students');
    }

    // Check if this submission has already been rewarded (NEW PATH)
    final rewardDoc = await _firestore
        .collection('goalProgress')
        .doc(userId)
        .collection('submissionRewards')
        .doc(submissionId)
        .get();

    if (rewardDoc.exists) {
      print('Submission $submissionId already rewarded');
      return; // Already rewarded
    }

    // Mark this submission as rewarded (NEW PATH)
    await _firestore
        .collection('goalProgress')
        .doc(userId)
        .collection('submissionRewards')
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
  // Each bucket increases growth by 5%
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
    int maxWatering = currentProgress['maxWatering'] ?? 20;

    // Check if we have water buckets and tree is not complete
    if (waterBuckets <= 0 || treeGrowth >= 1.0) {
      return false;
    }

    // Use one water bucket and increase growth by 5%
    waterBuckets--;
    wateringCount++;
    treeGrowth += 0.05; // Each bucket = 5% growth

    // Ensure treeGrowth doesn't exceed 1.0
    if (treeGrowth > 1.0) {
      treeGrowth = 1.0;
    }

    int totalProgress = currentProgress['totalProgress'] ?? 0;
    totalProgress++;

    // Check if tree is complete (100% growth)
    if (treeGrowth >= 1.0) {
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
        'maxWatering': 20, // Reset max watering for new tree
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

  // Get detailed submission statistics for water buckets
  Future<Map<String, dynamic>> getSubmissionStats() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !await _verifyStudentAccess()) {
      return {
        'totalAssignments': 0,
        'totalTutorials': 0,
        'totalBuckets': 0,
        'assignmentBuckets': 0,
        'tutorialBuckets': 0,
      };
    }

    try {
      // Get submission rewards from the new path
      final rewardsSnapshot = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('submissionRewards')
          .get();

      int assignmentCount = 0;
      int tutorialCount = 0;
      int totalBuckets = 0;

      for (var doc in rewardsSnapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        final buckets = data['buckets'] as int? ?? 0;

        totalBuckets += buckets;

        if (type == 'assignment') {
          assignmentCount++;
        } else if (type == 'tutorial') {
          tutorialCount++;
        }
      }

      return {
        'totalAssignments': assignmentCount,
        'totalTutorials': tutorialCount,
        'totalBuckets': totalBuckets,
        'assignmentBuckets': assignmentCount * 4,
        'tutorialBuckets': tutorialCount * 1,
      };
    } catch (e) {
      print('Error getting submission stats: $e');
      return {
        'totalAssignments': 0,
        'totalTutorials': 0,
        'totalBuckets': 0,
        'assignmentBuckets': 0,
        'tutorialBuckets': 0,
      };
    }
  }
}