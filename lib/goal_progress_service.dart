// 🚀 COMPLETE GoalProgressService - All existing features + new submission methods
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum TreeLevel { bronze, silver, gold }

class GoalProgressService {
  static final GoalProgressService _instance = GoalProgressService._internal();
  factory GoalProgressService() => _instance;
  GoalProgressService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔒 GLOBAL LOCKS: Prevent concurrent operations
  static final Map<String, bool> _userLocks = {};
  static final Set<String> _processedSubmissions = {};

  // 🆕 NEW: TUTORIAL SUBMISSION + AUTOMATIC REWARD
  Future<Map<String, dynamic>> submitTutorial({
    required String courseId,
    required String materialId,
    required String orgCode,
    required Map<String, dynamic> submissionData,
    String? materialName,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      if (!await _verifyStudentAccess()) {
        return {'success': false, 'error': 'Only students can submit tutorials'};
      }

      print('📚 Creating tutorial submission for material: $materialId');

      // Check if already submitted
      final alreadySubmitted = await _hasUserSubmitted(
        courseId: courseId,
        itemId: materialId,
        itemType: 'tutorial',
        orgCode: orgCode,
      );

      if (alreadySubmitted) {
        return {'success': false, 'error': 'You have already submitted this tutorial'};
      }

      // Prepare submission data
      final completeSubmissionData = {
        ...submissionData,
        'studentId': userId,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'submitted',
        'type': 'tutorial',
        'materialId': materialId,
        'courseId': courseId,
        'organizationCode': orgCode,
      };

      String submissionId = '';

      // Create submission in Firebase
      await _firestore.runTransaction((transaction) async {
        final submissionRef = _firestore
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(courseId)
            .collection('materials')
            .doc(materialId)
            .collection('submissions')
            .doc();

        submissionId = submissionRef.id;
        completeSubmissionData['submissionId'] = submissionId;

        transaction.set(submissionRef, completeSubmissionData);
        print('✅ Tutorial submission created: $submissionId');
      });

      // ⭐ AUTOMATIC REWARD: Award 1 water bucket
      await _awardSubmissionOnceAbsolute(
        submissionId: submissionId,
        itemId: materialId,
        itemName: materialName ?? 'Tutorial',
        type: 'tutorial',
        buckets: 1,
      );

      return {
        'success': true,
        'submissionId': submissionId,
        'message': 'Tutorial submitted successfully! You earned 1 water bucket! 💧',
        'rewardBuckets': 1,
      };

    } catch (e) {
      print('❌ Error submitting tutorial: $e');
      return {'success': false, 'error': 'Failed to submit tutorial: $e'};
    }
  }

  // 🆕 NEW: ASSIGNMENT SUBMISSION + AUTOMATIC REWARD
  Future<Map<String, dynamic>> submitAssignment({
    required String courseId,
    required String assignmentId,
    required String orgCode,
    required Map<String, dynamic> submissionData,
    String? assignmentName,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      if (!await _verifyStudentAccess()) {
        return {'success': false, 'error': 'Only students can submit assignments'};
      }

      print('📝 Creating assignment submission for assignment: $assignmentId');

      // Check if already submitted
      final alreadySubmitted = await _hasUserSubmitted(
        courseId: courseId,
        itemId: assignmentId,
        itemType: 'assignment',
        orgCode: orgCode,
      );

      if (alreadySubmitted) {
        return {'success': false, 'error': 'You have already submitted this assignment'};
      }

      // Prepare submission data
      final completeSubmissionData = {
        ...submissionData,
        'studentId': userId,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'submitted',
        'type': 'assignment',
        'assignmentId': assignmentId,
        'courseId': courseId,
        'organizationCode': orgCode,
      };

      String submissionId = '';

      // Create submission in Firebase
      await _firestore.runTransaction((transaction) async {
        final submissionRef = _firestore
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(courseId)
            .collection('assignments')
            .doc(assignmentId)
            .collection('submissions')
            .doc();

        submissionId = submissionRef.id;
        completeSubmissionData['submissionId'] = submissionId;

        transaction.set(submissionRef, completeSubmissionData);
        print('✅ Assignment submission created: $submissionId');
      });

      // ⭐ AUTOMATIC REWARD: Award 4 water buckets
      await _awardSubmissionOnceAbsolute(
        submissionId: submissionId,
        itemId: assignmentId,
        itemName: assignmentName ?? 'Assignment',
        type: 'assignment',
        buckets: 4,
      );

      return {
        'success': true,
        'submissionId': submissionId,
        'message': 'Assignment submitted successfully! You earned 4 water buckets! 💧💧💧💧',
        'rewardBuckets': 4,
      };

    } catch (e) {
      print('❌ Error submitting assignment: $e');
      return {'success': false, 'error': 'Failed to submit assignment: $e'};
    }
  }

  // 🆕 NEW: Check if user already submitted
  Future<bool> _hasUserSubmitted({
    required String courseId,
    required String itemId,
    required String itemType,
    required String orgCode,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      String collection = itemType == 'tutorial' ? 'materials' : 'assignments';

      final submissionsSnapshot = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection(collection)
          .doc(itemId)
          .collection('submissions')
          .where('studentId', isEqualTo: userId)
          .limit(1)
          .get();

      return submissionsSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking submission status: $e');
      return false;
    }
  }

  // 🆕 NEW: Get user's submission
  Future<Map<String, dynamic>?> getUserSubmission({
    required String courseId,
    required String itemId,
    required String itemType,
    required String orgCode,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      String collection = itemType == 'tutorial' ? 'materials' : 'assignments';

      final submissionsSnapshot = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection(collection)
          .doc(itemId)
          .collection('submissions')
          .where('studentId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();

      if (submissionsSnapshot.docs.isNotEmpty) {
        final doc = submissionsSnapshot.docs.first;
        return {
          'submissionId': doc.id,
          ...doc.data(),
        };
      }

      return null;
    } catch (e) {
      print('❌ Error getting user submission: $e');
      return null;
    }
  }

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

  // Use a water bucket with validation and consumption tracking
  Future<bool> useWaterBucket() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    print('🌱 Attempting to use water bucket...');

    // Verify user is a student
    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

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

        // Create water consumption record for tracking
        final consumptionId = DateTime.now().millisecondsSinceEpoch.toString();
        final waterConsumptionRef = _firestore
            .collection('goalProgress')
            .doc(userId)
            .collection('waterConsumption')
            .doc(consumptionId);

        final consumptionData = {
          'bucketsUsed': 1,
          'progressIncrease': 5, // 5% growth
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'goalId': currentProgress['currentGoal'] ?? 'default',
          'treeLevel': currentProgress['currentTreeLevel'] ?? 'bronze',
          'consumedAt': FieldValue.serverTimestamp(),
        };

        // Update both progress and consumption in single transaction
        transaction.update(progressDocRef, updatedProgress);
        transaction.set(waterConsumptionRef, consumptionData);

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

  // 🔄 RECALCULATE: Sync water buckets with actual submission rewards MINUS consumed buckets
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
      print('🔄 Recalculating water buckets from submission rewards and consumption...');

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

        // Get all submission rewards (buckets earned)
        final rewardsSnapshot = await _firestore
            .collection('goalProgress')
            .doc(userId)
            .collection('submissionRewards')
            .get();

        // Calculate total buckets earned from rewards
        int totalEarnedBuckets = 0;
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
            totalEarnedBuckets += buckets;
            rewardedSubmissions.add(submissionId!);

            if (type == 'assignment') {
              assignmentCount++;
            } else if (type == 'tutorial') {
              tutorialCount++;
            }
          } else {
            print('⚠️ Found invalid reward: ${doc.id} - will be ignored');
          }
        }

        // Get all water consumption records (buckets used)
        final consumptionSnapshot = await _firestore
            .collection('goalProgress')
            .doc(userId)
            .collection('waterConsumption')
            .get();

        int totalConsumedBuckets = 0;
        for (var doc in consumptionSnapshot.docs) {
          final data = doc.data();
          final bucketsUsed = data['bucketsUsed'] as int? ?? 0;
          totalConsumedBuckets += bucketsUsed;
        }

        // Calculate available buckets = earned - consumed
        int newBucketCount = totalEarnedBuckets - totalConsumedBuckets;

        // Ensure bucket count is not negative
        if (newBucketCount < 0) {
          print('⚠️ Negative bucket count detected, setting to 0');
          newBucketCount = 0;
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
          'totalEarnedBuckets': totalEarnedBuckets,
          'totalConsumedBuckets': totalConsumedBuckets,
          'totalAssignments': assignmentCount,
          'totalTutorials': tutorialCount,
          'totalRewards': rewardsSnapshot.docs.length,
          'rewardedSubmissions': rewardedSubmissions,
          'recalculatedAt': DateTime.now().millisecondsSinceEpoch,
        };

        print('✅ Recalculation completed:');
        print('   Earned buckets: $totalEarnedBuckets');
        print('   Consumed buckets: $totalConsumedBuckets');
        print('   Available buckets: $newBucketCount');
        print('   Old count: $oldBucketCount -> New count: $newBucketCount');
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

  // 🔄 AUTO-SYNC: Modified to be less aggressive and only sync on significant discrepancies
  Future<bool> autoSyncWaterBuckets() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null || !await _verifyStudentAccess()) return false;

      // Don't auto-sync if user operations are in progress
      if (_userLocks[userId] == true) {
        return false;
      }

      // Get current bucket count
      final progressDoc = await _firestore.collection('goalProgress').doc(userId).get();
      if (!progressDoc.exists) return false;

      final currentBuckets = progressDoc.data()!['waterBuckets'] ?? 0;

      // Calculate what the bucket count should be
      final rewardsSnapshot = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('submissionRewards')
          .get();

      int totalEarned = 0;
      for (var doc in rewardsSnapshot.docs) {
        final data = doc.data();
        final buckets = data['buckets'] as int? ?? 0;
        final type = data['type'] as String?;

        // Only count valid rewards
        if (type == 'tutorial' && buckets == 1) totalEarned += buckets;
        if (type == 'assignment' && buckets == 4) totalEarned += buckets;
      }

      final consumptionSnapshot = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('waterConsumption')
          .get();

      int totalConsumed = 0;
      for (var doc in consumptionSnapshot.docs) {
        final data = doc.data();
        totalConsumed += (data['bucketsUsed'] as int? ?? 0);
      }

      int expectedBuckets = totalEarned - totalConsumed;
      if (expectedBuckets < 0) expectedBuckets = 0;

      // Only sync if there's a significant discrepancy (more than 2 buckets difference)
      final difference = (currentBuckets - expectedBuckets).abs();
      if (difference > 2) {
        print('🔄 Large discrepancy detected ($difference buckets) - auto-syncing...');
        await recalculateWaterBuckets();
        return true;
      }

      return false; // No sync needed
    } catch (e) {
      print('❌ Error during auto-sync: $e');
      return false;
    }
  }

  // 🔍 DEBUG: Manual bucket count verification
  Future<Map<String, dynamic>> verifyBucketCount() async {
    try {
      print('🔍 Verifying bucket count...');

      final breakdown = await getDetailedBucketBreakdown();

      if (breakdown['error'] != null) {
        return breakdown;
      }

      final currentBuckets = breakdown['currentBuckets'] as int;
      final calculatedBuckets = breakdown['calculatedBuckets'] as int;
      final discrepancy = breakdown['discrepancy'] as int;

      print('📊 Bucket Count Verification:');
      print('   Current in Firebase: $currentBuckets');
      print('   Calculated (earned - consumed): $calculatedBuckets');
      print('   Discrepancy: $discrepancy');
      print('   Total earned: ${breakdown['totalEarned']}');
      print('   Total consumed: ${breakdown['totalConsumed']}');
      print('   Rewards count: ${breakdown['rewardsCount']}');
      print('   Consumptions count: ${breakdown['consumptionsCount']}');

      return {
        'success': true,
        'isCorrect': discrepancy == 0,
        'discrepancy': discrepancy,
        'currentBuckets': currentBuckets,
        'calculatedBuckets': calculatedBuckets,
        'totalEarned': breakdown['totalEarned'],
        'totalConsumed': breakdown['totalConsumed'],
        'message': discrepancy == 0
            ? 'Bucket count is correct!'
            : 'Bucket count discrepancy detected: $discrepancy buckets',
      };
    } catch (e) {
      print('❌ Error verifying bucket count: $e');
      return {'error': e.toString()};
    }
  }

  // 🔍 DEBUG: Get detailed bucket breakdown
  Future<Map<String, dynamic>> getDetailedBucketBreakdown() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !await _verifyStudentAccess()) {
      return {'error': 'Access denied'};
    }

    try {
      // Get current progress
      final progressDoc = await _firestore.collection('goalProgress').doc(userId).get();
      final currentBuckets = progressDoc.exists ? (progressDoc.data()!['waterBuckets'] ?? 0) : 0;

      // Get all submission rewards
      final rewardsSnapshot = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('submissionRewards')
          .get();

      int totalEarned = 0;
      List<Map<String, dynamic>> rewards = [];

      for (var doc in rewardsSnapshot.docs) {
        final data = doc.data();
        final buckets = data['buckets'] as int? ?? 0;
        final type = data['type'] as String? ?? 'unknown';

        totalEarned += buckets;
        rewards.add({
          'submissionId': data['submissionId'],
          'type': type,
          'buckets': buckets,
          'itemName': data['itemName'],
          'awardedAt': data['awardedAt'],
        });
      }

      // Get all water consumption records
      final consumptionSnapshot = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('waterConsumption')
          .get();

      int totalConsumed = 0;
      List<Map<String, dynamic>> consumptions = [];

      for (var doc in consumptionSnapshot.docs) {
        final data = doc.data();
        final bucketsUsed = data['bucketsUsed'] as int? ?? 0;

        totalConsumed += bucketsUsed;
        consumptions.add({
          'consumptionId': doc.id,
          'bucketsUsed': bucketsUsed,
          'progressIncrease': data['progressIncrease'],
          'timestamp': data['timestamp'],
          'consumedAt': data['consumedAt'],
        });
      }

      int calculatedBuckets = totalEarned - totalConsumed;

      return {
        'currentBuckets': currentBuckets,
        'totalEarned': totalEarned,
        'totalConsumed': totalConsumed,
        'calculatedBuckets': calculatedBuckets,
        'discrepancy': currentBuckets - calculatedBuckets,
        'rewards': rewards,
        'consumptions': consumptions,
        'rewardsCount': rewards.length,
        'consumptionsCount': consumptions.length,
      };
    } catch (e) {
      print('❌ Error getting detailed breakdown: $e');
      return {'error': e.toString()};
    }
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

  // 🎯 Get all submission rewards for display in badges view
  Future<List<Map<String, dynamic>>> getSubmissionRewards() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || !await _verifyStudentAccess()) return [];

    try {
      final rewardsSnapshot = await _firestore
          .collection('goalProgress')
          .doc(userId)
          .collection('submissionRewards')
          .orderBy('awardedAt', descending: true)
          .get();

      return rewardsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting submission rewards: $e');
      return [];
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
      // Get ALL materials first
      final materialsSnapshot = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('materials')
          .get();

      for (var material in materialsSnapshot.docs) {
        final materialData = material.data();

        // Check if this is a tutorial (not a regular material)
        final materialType = materialData['materialType'] as String?;
        if (materialType != 'tutorial') {
          continue; // Skip non-tutorial materials
        }

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

  // Get current goal progress as a future
  Future<Map<String, dynamic>?> getGoalProgress() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    if (!await _verifyStudentAccess()) {
      throw Exception('Goal system is only available for students');
    }

    final doc = await _firestore.collection('goalProgress').doc(userId).get();

    if (doc.exists) {
      // Auto-sync before returning data
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
        final itemId = data['itemId'] as String?;

        totalBuckets += buckets;

        if (submissionId != null) {
          uniqueSubmissions.add(submissionId);

          rewardedItems.add({
            'submissionId': submissionId,
            'itemId': itemId,
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

  // Legacy methods for backward compatibility
  Future<void> checkAndProcessNewSubmissions() async {
    print('🔍 Checking for new submissions...');
    await scanAndRewardMissedSubmissions();
  }

  Future<bool> hasSubmissionBeenRewarded(String submissionId) async {
    return await isSubmissionRewarded(submissionId);
  }

  // Helper methods
  Map<String, dynamic> _getDefaultProgress() {
    return {
      'waterBuckets': 0,
      'wateringCount': 0,
      'treeGrowth': 0.0,
      'currentGoal': 'No goal selected - Press \'Set Goal\' to choose one',
      'pinnedGoals': [], // New field for multiple pinned goals
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
}