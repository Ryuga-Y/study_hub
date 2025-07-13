import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum TreeLevel { bronze, silver, gold }

class GoalProgressService {
  static final GoalProgressService _instance = GoalProgressService._internal();
  factory GoalProgressService() => _instance;
  GoalProgressService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔒 GLOBAL LOCK: Prevent ANY concurrent operations for same user
  static final Map<String, bool> _userLocks = {};

  // 🔒 SUBMISSION LOCK: Prevent duplicate processing of same submission
  static final Set<String> _processedSubmissions = {};

  // Verify user is a student before any goal operations
  Future<bool> _verifyStudentAccess() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      return userData['role'] == 'student' && userData['isActive'] == true;
    } catch (e) {
      print('❌ Error verifying student access: $e');
      return false;
    }
  }

  // 🔄 RECALCULATE: Sync water buckets with actual submission rewards
  Future<Map<String, dynamic>> recalculateWaterBuckets() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !await _verifyStudentAccess()) {
      return {'error': 'Access denied'};
    }

    // Check for user lock
    if (_userLocks[userId] == true) {
      print('⚠️ User operations in progress - cannot recalculate right now');
      return {'error': 'Operations in progress'};
    }

    try {
      _userLocks[userId] = true;
      print('🔄 Recalculating water buckets from submission rewards...');

      Map<String, dynamic> result = {};

      await _firestore.runTransaction((transaction) async {
        // Get current progress
        final progressDocRef = _firestore.collection('goalProgress').doc(userId);
        final progressDoc = await transaction.get(progressDocRef);

        if (!progressDoc.exists) {
          print('❌ No goal progress found');
          result = {'error': 'No goal progress found'};
          return;
        }

        final currentProgress = progressDoc.data()!;
        final oldBucketCount = currentProgress['waterBuckets'] ?? 0;

        // Get all remaining submission rewards
        final rewardsSnapshot = await _firestore
            .collection('goalProgress')
            .doc(userId)
            .collection('submissionRewards')
            .get();

        // Recalculate total buckets from remaining rewards
        int newBucketCount = 0;
        int assignmentCount = 0;
        int tutorialCount = 0;
        List<String> rewardedSubmissions = [];

        for (var doc in rewardsSnapshot.docs) {
          final data = doc.data();
          final type = data['type'] as String?;
          final buckets = data['buckets'] as int? ?? 0;
          final submissionId = data['submissionId'] as String?;

          // Validate reward data
          bool isValid = true;
          if (type == null || !['tutorial', 'assignment'].contains(type)) isValid = false;
          if (type == 'tutorial' && buckets != 1) isValid = false;
          if (type == 'assignment' && buckets != 4) isValid = false;
          if (submissionId == null || submissionId.isEmpty) isValid = false;

          if (isValid) {
            newBucketCount += buckets;
            rewardedSubmissions.add(submissionId!); // Use ! since we already validated it's not null

            if (type == 'assignment') {
              assignmentCount++;
            } else if (type == 'tutorial') {
              tutorialCount++;
            }
          } else {
            print('⚠️ Found invalid reward: ${doc.id} - will be ignored');
          }
        }

        // Update main progress document with correct bucket count
        final updatedProgress = {
          ...currentProgress,
          'waterBuckets': newBucketCount,
          'lastRecalculated': FieldValue.serverTimestamp(),
          'recalculationReason': 'Manual recalculation requested',
        };

        transaction.update(progressDocRef, updatedProgress);

        result = {
          'success': true,
          'oldBucketCount': oldBucketCount,
          'newBucketCount': newBucketCount,
          'bucketDifference': newBucketCount - oldBucketCount,
          'totalAssignments': assignmentCount,
          'totalTutorials': tutorialCount,
          'totalRewards': rewardsSnapshot.docs.length,
          'rewardedSubmissions': rewardedSubmissions,
          'recalculatedAt': DateTime.now().millisecondsSinceEpoch,
        };

        print('✅ Recalculation completed:');
        print('   Old bucket count: $oldBucketCount');
        print('   New bucket count: $newBucketCount');
        print('   Difference: ${newBucketCount - oldBucketCount}');
        print('   Assignments: $assignmentCount, Tutorials: $tutorialCount');
      });

      return result;
    } catch (e) {
      print('❌ Error during recalculation: $e');
      return {'error': e.toString()};
    } finally {
      _userLocks.remove(userId);
    }
  }

  // 🔄 AUTO-SYNC: Automatically check and sync bucket count (call this periodically)
  Future<bool> autoSyncWaterBuckets() async {
    try {
      final result = await recalculateWaterBuckets();

      if (result['success'] == true) {
        final difference = result['bucketDifference'] as int;

        if (difference != 0) {
          print('🔄 Auto-sync detected bucket count mismatch - corrected by $difference buckets');
          return true; // Buckets were corrected
        }
      }

      return false; // No changes needed
    } catch (e) {
      print('❌ Error during auto-sync: $e');
      return false;
    }
  }

  // Get current goal progress as a future
  Future<Map<String, dynamic>?> getGoalProgress() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    final doc = await _firestore.collection('goalProgress').doc(userId).get();

    if (doc.exists) {
      // Auto-sync buckets when loading progress
      await autoSyncWaterBuckets();

      // Return fresh data after sync
      final freshDoc = await _firestore.collection('goalProgress').doc(userId).get();
      return freshDoc.data();
    } else {
      await initializeGoalProgress();
      return await getGoalProgress();
    }
  }

  // Get current goal progress with real-time updates
  Stream<DocumentSnapshot> getGoalProgressStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore.collection('goalProgress').doc(userId).snapshots();
  }

  // 🎯 TUTORIAL SUBMISSION: Awards exactly 1 water bucket (5% tree growth)
  // ✅ ABSOLUTE GUARANTEE: This submission will NEVER be rewarded more than once
  Future<void> awardTutorialSubmission(String submissionId, String materialId, {String? materialName}) async {
    await _awardSubmissionOnceAbsolute(
      submissionId: submissionId,
      itemId: materialId,
      itemName: materialName ?? 'Tutorial',
      type: 'tutorial',
      buckets: 1,
    );
  }

  // 🎯 ASSIGNMENT SUBMISSION: Awards exactly 4 water buckets (20% tree growth)
  // ✅ ABSOLUTE GUARANTEE: This submission will NEVER be rewarded more than once
  Future<void> awardAssignmentSubmission(String submissionId, String assignmentId, {String? assignmentName}) async {
    await _awardSubmissionOnceAbsolute(
      submissionId: submissionId,
      itemId: assignmentId,
      itemName: assignmentName ?? 'Assignment',
      type: 'assignment',
      buckets: 4,
    );
  }

  // 🛡️ ULTIMATE PROTECTION: Triple-layer duplicate prevention system
  Future<void> _awardSubmissionOnceAbsolute({
    required String submissionId,
    required String itemId,
    required String itemName,
    required String type,
    required int buckets,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('❌ No authenticated user - cannot award buckets');
      return;
    }

    // 🔒 LAYER 1: Global user lock (prevents any concurrent operations)
    if (_userLocks[userId] == true) {
      print('⚠️ User $userId already has operations in progress - BLOCKED');
      return;
    }

    // 🔒 LAYER 2: Submission processing lock (prevents same submission twice)
    final submissionKey = '${userId}_${submissionId}';
    if (_processedSubmissions.contains(submissionKey)) {
      print('⚠️ Submission $submissionId already processed - DUPLICATE PREVENTED');
      return;
    }

    try {
      // Verify student access
      if (!await _verifyStudentAccess()) {
        print('❌ User is not a student - cannot award buckets');
        return;
      }

      // 🔒 LAYER 3: Acquire locks
      _userLocks[userId] = true;
      _processedSubmissions.add(submissionKey);

      print('🎯 Processing reward for $type submission: $submissionId ($itemName)');

      // 🔒 LAYER 4: Firebase transaction with ABSOLUTE duplicate prevention
      await _firestore.runTransaction((transaction) async {
        // 🔒 LAYER 5: Check if reward already exists using submissionId as document ID
        final rewardDocRef = _firestore
            .collection('goalProgress')
            .doc(userId)
            .collection('submissionRewards')
            .doc(submissionId); // Using submissionId as document ID = PRIMARY KEY

        final existingReward = await transaction.get(rewardDocRef);

        if (existingReward.exists) {
          print('✋ DUPLICATE ABSOLUTELY PREVENTED: Submission $submissionId already exists in Firebase');
          return; // Exit transaction - ZERO changes made
        }

        // 🔒 LAYER 6: Double-check with query (extra paranoid protection)
        final queryCheck = await _firestore
            .collection('goalProgress')
            .doc(userId)
            .collection('submissionRewards')
            .where('submissionId', isEqualTo: submissionId)
            .limit(1)
            .get();

        if (queryCheck.docs.isNotEmpty) {
          print('✋ DUPLICATE ABSOLUTELY PREVENTED: Found existing reward via query for $submissionId');
          return; // Exit transaction - ZERO changes made
        }

        // 🔒 LAYER 7: Check by unique constraint (triple protection)
        final uniqueKey = '${userId}_${submissionId}_${type}';
        final uniqueCheck = await _firestore
            .collection('goalProgress')
            .doc(userId)
            .collection('submissionRewards')
            .where('uniqueKey', isEqualTo: uniqueKey)
            .limit(1)
            .get();

        if (uniqueCheck.docs.isNotEmpty) {
          print('✋ DUPLICATE ABSOLUTELY PREVENTED: Found existing reward via uniqueKey for $submissionId');
          return; // Exit transaction - ZERO changes made
        }

        // Get current progress document
        final progressDocRef = _firestore.collection('goalProgress').doc(userId);
        final progressDoc = await transaction.get(progressDocRef);

        Map<String, dynamic> currentProgress;
        if (progressDoc.exists) {
          currentProgress = progressDoc.data()!;
        } else {
          // Initialize if doesn't exist
          currentProgress = _getDefaultProgress();
        }

        // Calculate new bucket count
        int currentBuckets = currentProgress['waterBuckets'] ?? 0;
        int newBucketCount = currentBuckets + buckets;

        // 🔒 LAYER 8: Create reward record with MAXIMUM constraints
        final rewardData = {
          'submissionId': submissionId,        // PRIMARY identifier
          'itemId': itemId,                    // Assignment/material ID
          'itemName': itemName,                // Human readable name (Tutorial 1, Assignment 2, etc.)
          'type': type,                        // 'tutorial' or 'assignment'
          'buckets': buckets,                  // 1 for tutorial, 4 for assignment
          'studentId': userId,                 // Student who earned it
          'awardedAt': FieldValue.serverTimestamp(),
          'status': 'awarded',
          // 🔒 ABSOLUTE UNIQUE CONSTRAINT: Triple key prevents ANY duplicates
          'uniqueKey': uniqueKey,
          // 🔒 VERIFICATION HASH: Extra layer for data integrity
          'verificationHash': _generateVerificationHash(userId, submissionId, type, buckets),
          // 🔒 PROCESSING TIMESTAMP: For audit trail
          'processedAt': DateTime.now().millisecondsSinceEpoch,
        };

        // 🔒 LAYER 9: Update progress with new bucket count
        final updatedProgress = {
          ...currentProgress,
          'waterBuckets': newBucketCount,
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastRewardType': type,
          'lastRewardBuckets': buckets,
          'lastRewardSubmission': submissionId,
          'lastRewardItemName': itemName,
        };

        // 🔒 LAYER 10: Atomic write - both operations succeed or both fail
        transaction.set(progressDocRef, updatedProgress);
        transaction.set(rewardDocRef, rewardData);

        print('✅ SUCCESS: Awarded $buckets buckets for $type: "$itemName" (submission: $submissionId)');
        print('💧 Total buckets now: $newBucketCount');
        print('🎯 Growth available: ${newBucketCount * 5}%');
      });

    } catch (e) {
      print('❌ Error awarding buckets for submission $submissionId: $e');
      // Don't rethrow - this shouldn't break submission process
    } finally {
      // 🔒 LAYER 11: Always release locks (critical for preventing deadlocks)
      _userLocks.remove(userId);
      _processedSubmissions.remove(submissionKey);

      // Clear old processed submissions to prevent memory leaks
      if (_processedSubmissions.length > 1000) {
        _processedSubmissions.clear();
      }
    }
  }

  // Generate verification hash for data integrity
  String _generateVerificationHash(String userId, String submissionId, String type, int buckets) {
    final dataString = '${userId}_${submissionId}_${type}_${buckets}_${DateTime.now().day}';
    return dataString.hashCode.abs().toString();
  }

  // 🔍 CHECK: Verify if a submission has been rewarded (multiple methods)
  Future<bool> isSubmissionRewarded(String submissionId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !await _verifyStudentAccess()) return false;

    try {
      // Method 1: Check using document ID (fastest)
      final rewardDoc = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('submissionRewards')
          .doc(submissionId)
          .get();

      if (rewardDoc.exists) {
        print('✅ Submission $submissionId already rewarded (document exists)');
        return true;
      }

      // Method 2: Check using query (backup verification)
      final queryCheck = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('submissionRewards')
          .where('submissionId', isEqualTo: submissionId)
          .limit(1)
          .get();

      if (queryCheck.docs.isNotEmpty) {
        print('✅ Submission $submissionId already rewarded (found via query)');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error checking if submission $submissionId is rewarded: $e');
      return false; // If we can't check, assume not rewarded (safer)
    }
  }

  // 🔍 SCAN: Check for any unrewarded submissions and award them
  Future<void> scanAndRewardMissedSubmissions() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !await _verifyStudentAccess()) return;

    print('🔍 Scanning for missed submission rewards...');

    try {
      // Get user's organization
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final orgCode = userData['organizationCode'];
      if (orgCode == null) return;

      // Get all enrolled courses
      final enrollmentsSnapshot = await _firestore
          .collectionGroup('enrollments')
          .where('studentId', isEqualTo: userId)
          .get();

      print('📚 Checking ${enrollmentsSnapshot.docs.length} enrolled courses...');

      int newRewards = 0;

      for (var enrollment in enrollmentsSnapshot.docs) {
        final courseRef = enrollment.reference.parent.parent;
        if (courseRef == null) continue;

        // Check assignment submissions
        newRewards += await _scanCourseAssignments(courseRef.id, orgCode, userId);

        // Check tutorial submissions
        newRewards += await _scanCourseTutorials(courseRef.id, orgCode, userId);
      }

      print('✅ Scan completed. Found and rewarded $newRewards missed submissions.');

      // Auto-sync after scanning
      if (newRewards > 0) {
        await autoSyncWaterBuckets();
      }
    } catch (e) {
      print('❌ Error during missed submissions scan: $e');
    }
  }

  // 🔍 SCAN: Check assignments in a course for unrewarded submissions
  Future<int> _scanCourseAssignments(String courseId, String orgCode, String userId) async {
    int newRewards = 0;

    try {
      final assignmentsSnapshot = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('assignments')
          .get();

      for (var assignment in assignmentsSnapshot.docs) {
        final assignmentData = assignment.data();
        final assignmentName = assignmentData['title'] ?? assignmentData['name'] ?? 'Assignment';

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
          final isRewarded = await isSubmissionRewarded(submission.id);

          if (!isRewarded) {
            await awardAssignmentSubmission(submission.id, assignment.id, assignmentName: assignmentName);
            newRewards++;
            print('🎉 Awarded missed assignment reward: ${submission.id} ($assignmentName)');
          }
        }
      }
    } catch (e) {
      print('❌ Error scanning assignments: $e');
    }

    return newRewards;
  }

  // 🔍 SCAN: Check tutorials in a course for unrewarded submissions
  Future<int> _scanCourseTutorials(String courseId, String orgCode, String userId) async {
    int newRewards = 0;

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
        final materialData = material.data();
        final materialName = materialData['title'] ?? materialData['name'] ?? 'Tutorial';

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
          final isRewarded = await isSubmissionRewarded(submission.id);

          if (!isRewarded) {
            await awardTutorialSubmission(submission.id, material.id, materialName: materialName);
            newRewards++;
            print('🎉 Awarded missed tutorial reward: ${submission.id} ($materialName)');
          }
        }
      }
    } catch (e) {
      print('❌ Error scanning tutorials: $e');
    }

    return newRewards;
  }

  // Use a water bucket with validation
  Future<bool> useWaterBucket() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    print('🌱 Attempting to use water bucket...');

    // Verify user is a student
    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    // Auto-sync buckets before using
    await autoSyncWaterBuckets();

    // Check for user lock
    if (_userLocks[userId] == true) {
      print('⚠️ User operations in progress - cannot use bucket right now');
      return false;
    }

    try {
      _userLocks[userId] = true;
      bool success = false;

      await _firestore.runTransaction((transaction) async {
        final progressDocRef = _firestore.collection('goalProgress').doc(userId);
        final progressDoc = await transaction.get(progressDocRef);

        if (!progressDoc.exists) {
          print('❌ No goal progress found - initializing first');
          await initializeGoalProgress();
          success = false;
          return;
        }

        final currentProgress = progressDoc.data()!;
        int waterBuckets = currentProgress['waterBuckets'] ?? 0;
        int wateringCount = currentProgress['wateringCount'] ?? 0;
        double treeGrowth = (currentProgress['treeGrowth'] ?? 0.0).toDouble();

        // Check if we have water buckets and tree is not complete
        if (waterBuckets <= 0) {
          print('❌ No water buckets available');
          success = false;
          return;
        }

        if (treeGrowth >= 1.0) {
          print('❌ Tree already fully grown');
          success = false;
          return;
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

        Map<String, dynamic> updatedProgress = {
          'waterBuckets': waterBuckets,
          'wateringCount': wateringCount,
          'treeGrowth': treeGrowth,
          'totalProgress': totalProgress,
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastWatered': FieldValue.serverTimestamp(),
        };

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
          updatedProgress.addAll({
            'wateringCount': 0,
            'treeGrowth': 0.0,
            'currentTreeLevel': currentTreeLevel,
            'completedTrees': completedTrees,
            'maxWatering': 20, // Reset max watering for new tree
            'treeCompletedAt': FieldValue.serverTimestamp(),
          });

          print('🌳 Tree completed! Level: $currentTreeLevel, Trees: $completedTrees');
        }

        // Update in transaction
        transaction.update(progressDocRef, updatedProgress);
        success = true;

        print('💧 Water bucket used successfully. Remaining: $waterBuckets, Growth: ${(treeGrowth * 100).toStringAsFixed(0)}%');
      });

      return success;
    } catch (e) {
      print('❌ Error using water bucket: $e');
      return false;
    } finally {
      _userLocks.remove(userId);
    }
  }

  // Initialize default goal progress (ONLY for students)
  Future<void> initializeGoalProgress() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    print('🌱 Initializing goal progress for student: $userId');

    final defaultProgress = _getDefaultProgress();
    defaultProgress['lastUpdated'] = FieldValue.serverTimestamp();

    await _firestore.collection('goalProgress').doc(userId).set(defaultProgress);

    print('✅ Goal progress initialized successfully');
  }

  // Update goal progress (ONLY for students)
  Future<void> updateGoalProgress(Map<String, dynamic> progress) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    progress['lastUpdated'] = FieldValue.serverTimestamp();

    await _firestore.collection('goalProgress').doc(userId).update(progress);
  }

  // Update goal text (ONLY for students)
  Future<void> updateGoal(String goalText) async {
    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    await _firestore.collection('goalProgress').doc(userId).update({
      'currentGoal': goalText,
      'hasActiveGoal': true,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Check if user has any water buckets (ONLY for students)
  Future<bool> hasWaterBuckets() async {
    if (!await _verifyStudentAccess()) {
      return false;
    }

    // Auto-sync before checking
    await autoSyncWaterBuckets();

    final progress = await getGoalProgress();
    if (progress == null) return false;
    return (progress['waterBuckets'] ?? 0) > 0;
  }

  // Get water bucket count (ONLY for students)
  Future<int> getWaterBucketCount() async {
    if (!await _verifyStudentAccess()) {
      return 0;
    }

    try {
      // Auto-sync before returning count
      await autoSyncWaterBuckets();

      final progress = await getGoalProgress();
      if (progress == null) return 0;
      return progress['waterBuckets'] ?? 0;
    } catch (e) {
      print('❌ Error getting water bucket count: $e');
      return 0;
    }
  }

  // Check if current user is a student (public method)
  Future<bool> isCurrentUserStudent() async {
    return await _verifyStudentAccess();
  }

  // 📊 DETAILED SUBMISSION STATISTICS with item names
  Future<Map<String, dynamic>> getSubmissionStatistics() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !await _verifyStudentAccess()) {
      return _getEmptyStats();
    }

    try {
      // Auto-sync before getting stats
      await autoSyncWaterBuckets();

      final rewardsSnapshot = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('submissionRewards')
          .orderBy('awardedAt', descending: true)
          .get();

      int assignmentCount = 0;
      int tutorialCount = 0;
      int totalBuckets = 0;
      List<Map<String, dynamic>> rewardedItems = [];
      Set<String> uniqueSubmissions = {};

      for (var doc in rewardsSnapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        final buckets = data['buckets'] as int? ?? 0;
        final submissionId = data['submissionId'] as String?;
        final itemName = data['itemName'] as String? ?? 'Unknown';
        final awardedAt = data['awardedAt'] as Timestamp?;

        totalBuckets += buckets;

        if (submissionId != null) {
          uniqueSubmissions.add(submissionId);

          rewardedItems.add({
            'submissionId': submissionId,
            'itemName': itemName,
            'type': type,
            'buckets': buckets,
            'awardedAt': awardedAt,
          });
        }

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
        'uniqueSubmissions': uniqueSubmissions.length,
        'rewardedItems': rewardedItems,
        'lastUpdate': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      print('❌ Error getting submission statistics: $e');
      return _getEmptyStats();
    }
  }

  // 🧹 CLEANUP: Remove any duplicate rewards and fix inconsistencies
  Future<Map<String, dynamic>> cleanupAndValidateRewards() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !await _verifyStudentAccess()) {
      return {'error': 'Access denied'};
    }

    try {
      print('🧹 Starting comprehensive cleanup and validation...');

      final rewardsSnapshot = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('submissionRewards')
          .get();

      // Group rewards by submissionId
      Map<String, List<QueryDocumentSnapshot>> submissionGroups = {};
      List<QueryDocumentSnapshot> invalidRewards = [];

      for (var doc in rewardsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final submissionId = data['submissionId'] as String?;

        if (submissionId == null || submissionId.isEmpty) {
          invalidRewards.add(doc);
          continue;
        }

        // Validate reward data
        final type = data['type'] as String?;
        final buckets = data['buckets'] as int?;

        bool isValid = true;
        if (type == null || !['tutorial', 'assignment'].contains(type)) isValid = false;
        if (type == 'tutorial' && buckets != 1) isValid = false;
        if (type == 'assignment' && buckets != 4) isValid = false;

        if (!isValid) {
          invalidRewards.add(doc);
          continue;
        }

        submissionGroups[submissionId] = submissionGroups[submissionId] ?? [];
        submissionGroups[submissionId]!.add(doc);
      }

      int duplicatesRemoved = 0;
      int invalidRemoved = 0;
      int totalBucketsRecalculated = 0;

      // Remove invalid rewards
      for (var doc in invalidRewards) {
        await doc.reference.delete();
        invalidRemoved++;
        print('🗑️ Deleted invalid reward: ${doc.id}');
      }

      // Find and remove duplicates
      for (var submissionId in submissionGroups.keys) {
        final docs = submissionGroups[submissionId]!;

        if (docs.length > 1) {
          print('⚠️ Found ${docs.length} rewards for submission: $submissionId');

          // Sort by timestamp and keep the oldest (first created)
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['awardedAt'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['awardedAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return aTime.compareTo(bTime);
          });

          // Delete all except the first one
          for (int i = 1; i < docs.length; i++) {
            await docs[i].reference.delete();
            duplicatesRemoved++;
            print('🗑️ Deleted duplicate reward: ${docs[i].id}');
          }
        }
      }

      // Recalculate total buckets
      final remainingRewards = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('submissionRewards')
          .get();

      for (var doc in remainingRewards.docs) {
        final data = doc.data();
        final buckets = data['buckets'] as int? ?? 0;
        totalBucketsRecalculated += buckets;
      }

      // Update main progress document with correct bucket count
      await _firestore.collection('goalProgress').doc(userId).update({
        'waterBuckets': totalBucketsRecalculated,
        'lastCleanup': FieldValue.serverTimestamp(),
        'lastValidated': FieldValue.serverTimestamp(),
      });

      final result = {
        'duplicatesRemoved': duplicatesRemoved,
        'invalidRemoved': invalidRemoved,
        'totalBucketsAfterCleanup': totalBucketsRecalculated,
        'uniqueSubmissions': submissionGroups.length,
        'cleanupTimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      print('✅ Cleanup completed: $result');
      return result;
    } catch (e) {
      print('❌ Error during cleanup: $e');
      return {'error': e.toString()};
    }
  }

  // Helper methods
  Map<String, dynamic> _getDefaultProgress() {
    return {
      'waterBuckets': 0,
      'wateringCount': 0,
      'treeGrowth': 0.0,
      'currentGoal': 'No goal selected - Press \'Set Goal\' to choose one',
      'hasActiveGoal': false,
      'currentTreeLevel': 'bronze',
      'completedTrees': 0,
      'totalProgress': 0,
      'maxWatering': 20,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _getEmptyStats() {
    return {
      'totalAssignments': 0,
      'totalTutorials': 0,
      'totalBuckets': 0,
      'assignmentBuckets': 0,
      'tutorialBuckets': 0,
      'uniqueSubmissions': 0,
      'rewardedItems': [],
    };
  }

  // Legacy methods for backward compatibility (with enhanced safety)
  Future<void> checkAndProcessNewSubmissions() async {
    print('🔍 Checking for new submissions...');
    await scanAndRewardMissedSubmissions();
  }

  Future<bool> hasSubmissionBeenRewarded(String submissionId) async {
    return await isSubmissionRewarded(submissionId);
  }

  Future<void> cleanupDuplicateRewards() async {
    await cleanupAndValidateRewards();
  }

  Future<Map<String, dynamic>> getSubmissionStats() async {
    return await getSubmissionStatistics();
  }

  // 🧹 CLEANUP: Remove any duplicate rewards (maintenance function)
  Future<int> removeDuplicateRewards() async {
    final result = await cleanupAndValidateRewards();
    return result['duplicatesRemoved'] ?? 0;
  }
}