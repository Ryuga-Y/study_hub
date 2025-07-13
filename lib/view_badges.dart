import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../goal_progress_service.dart';
import '../Authentication/auth_services.dart';

class ViewBadgesPage extends StatefulWidget {
  @override
  _ViewBadgesPageState createState() => _ViewBadgesPageState();
}

class _ViewBadgesPageState extends State<ViewBadgesPage> with TickerProviderStateMixin {
  final GoalProgressService _goalService = GoalProgressService();
  final AuthService _authService = AuthService();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Data
  Map<String, dynamic> submissionStats = {};
  List<Map<String, dynamic>> rewardHistory = [];
  Map<String, dynamic> goalProgress = {};
  bool isLoading = true;
  String? errorMessage;

  // Tree progression data
  int totalBuckets = 0;
  int treesCompleted = 0;
  String currentTreeLevel = 'bronze';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBadgeData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadBadgeData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Check if user is a student
      final isStudent = await _goalService.isCurrentUserStudent();
      if (!isStudent) {
        setState(() {
          errorMessage = 'Badge system is only available for students';
          isLoading = false;
        });
        return;
      }

      // Load submission statistics
      final stats = await _goalService.getSubmissionStatistics();

      // Load goal progress
      final progress = await _goalService.getGoalProgress();

      // Get enhanced reward history with submission details
      final enhancedRewardHistory = await _getEnhancedRewardHistory(stats['rewardedItems'] ?? []);

      setState(() {
        submissionStats = stats;
        rewardHistory = enhancedRewardHistory;
        goalProgress = progress ?? {};

        // Extract summary data
        totalBuckets = stats['totalBuckets'] ?? 0;
        treesCompleted = progress?['completedTrees'] ?? 0;
        currentTreeLevel = progress?['currentTreeLevel'] ?? 'bronze';

        isLoading = false;
      });

      // Sort reward history by date (newest first)
      rewardHistory.sort((a, b) {
        final aTime = a['submittedAt'] as Timestamp? ?? a['awardedAt'] as Timestamp?;
        final bTime = b['submittedAt'] as Timestamp? ?? b['awardedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

    } catch (e) {
      setState(() {
        errorMessage = 'Error loading badge data: $e';
        isLoading = false;
      });
    }
  }

  // Enhanced method to get submission details with due dates and submission times
  Future<List<Map<String, dynamic>>> _getEnhancedRewardHistory(List<dynamic> rewardItems) async {
    List<Map<String, dynamic>> enhancedHistory = [];

    // Get user data to find organization
    final user = _authService.currentUser;
    if (user == null) return [];

    final userData = await _authService.getUserData(user.uid);
    if (userData == null) return [];

    final orgCode = userData['organizationCode'];
    if (orgCode == null) return [];

    for (var reward in rewardItems) {
      Map<String, dynamic> enhancedReward = Map<String, dynamic>.from(reward);

      try {
        final submissionId = reward['submissionId'] as String?;
        final itemId = reward['itemId'] as String?;
        final type = reward['type'] as String?;

        if (submissionId != null && itemId != null && type != null) {
          // Get submission details and material/assignment info
          final submissionDetails = await _getSubmissionDetails(
              orgCode,
              submissionId,
              itemId,
              type,
              user.uid
          );

          if (submissionDetails != null) {
            enhancedReward.addAll(submissionDetails);
          }
        }
      } catch (e) {
        print('Error enhancing reward ${reward['submissionId']}: $e');
        // Keep original reward data if enhancement fails
      }

      enhancedHistory.add(enhancedReward);
    }

    return enhancedHistory;
  }

  // Get detailed submission information including due dates
  Future<Map<String, dynamic>?> _getSubmissionDetails(
      String orgCode,
      String submissionId,
      String itemId,
      String type,
      String userId
      ) async {
    try {
      // First, find the course and submission
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .get();

      for (var courseDoc in coursesSnapshot.docs) {
        final courseId = courseDoc.id;

        if (type == 'assignment') {
          // Look in assignments
          final submissionDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(orgCode)
              .collection('courses')
              .doc(courseId)
              .collection('assignments')
              .doc(itemId)
              .collection('submissions')
              .doc(submissionId)
              .get();

          if (submissionDoc.exists) {
            // Get assignment details
            final assignmentDoc = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(orgCode)
                .collection('courses')
                .doc(courseId)
                .collection('assignments')
                .doc(itemId)
                .get();

            if (assignmentDoc.exists) {
              final submissionData = submissionDoc.data()!;
              final assignmentData = assignmentDoc.data()!;

              return {
                'submittedAt': submissionData['submittedAt'],
                'dueDate': assignmentData['dueDate'],
                'isLate': submissionData['isLate'] ?? false,
                'courseName': courseDoc.data()['title'] ?? 'Unknown Course',
                'courseCode': courseDoc.data()['code'] ?? '',
              };
            }
          }
        } else if (type == 'tutorial') {
          // Look in materials (tutorials)
          final submissionDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(orgCode)
              .collection('courses')
              .doc(courseId)
              .collection('materials')
              .doc(itemId)
              .collection('submissions')
              .doc(submissionId)
              .get();

          if (submissionDoc.exists) {
            // Get material details
            final materialDoc = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(orgCode)
                .collection('courses')
                .doc(courseId)
                .collection('materials')
                .doc(itemId)
                .get();

            if (materialDoc.exists) {
              final submissionData = submissionDoc.data()!;
              final materialData = materialDoc.data()!;

              return {
                'submittedAt': submissionData['submittedAt'],
                'dueDate': materialData['dueDate'],
                'isLate': submissionData['isLate'] ?? false,
                'courseName': courseDoc.data()['title'] ?? 'Unknown Course',
                'courseCode': courseDoc.data()['code'] ?? '',
              };
            }
          }
        }
      }
    } catch (e) {
      print('Error getting submission details: $e');
    }

    return null;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.amber[600], size: 28),
          SizedBox(width: 12),
          Text(
            'My Achievements',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.purple[600]),
          onPressed: _loadBadgeData,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your achievements...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Oops!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBadgeData,
              child: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBadgeData,
      color: Colors.purple[400],
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Achievement Summary Header
                _buildAchievementSummary(),
                SizedBox(height: 24),

                // Tree Progress Section
                _buildTreeProgress(),
                SizedBox(height: 24),

                // Achievement Categories
                _buildAchievementCategories(),
                SizedBox(height: 24),

                // Reward History
                _buildRewardHistory(),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementSummary() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[600]!, Colors.purple[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: Colors.amber[300], size: 32),
              SizedBox(width: 12),
              Text(
                'Achievement Summary',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.local_drink,
                  value: '$totalBuckets',
                  label: 'Water Buckets\nEarned',
                  color: Colors.orange[300]!,
                ),
              ),
              Container(
                height: 60,
                width: 1,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.park,
                  value: '$treesCompleted',
                  label: 'Trees\nCompleted',
                  color: Colors.green[300]!,
                ),
              ),
              Container(
                height: 60,
                width: 1,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.assignment_turned_in,
                  value: '${submissionStats['totalAssignments'] ?? 0}',
                  label: 'Assignments\nSubmitted',
                  color: Colors.blue[300]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildTreeProgress() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_florist, color: Colors.green[600], size: 24),
              SizedBox(width: 12),
              Text(
                'Tree Garden Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Current tree level
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getTreeLevelColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getTreeLevelColor().withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: _getTreeLevelColor(), size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTreeLevelName(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getTreeLevelColor(),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Current Tree Level',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$treesCompleted',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _getTreeLevelColor(),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Tree level progression
          Text(
            'Tree Achievements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),

          // Bronze Tree
          _buildTreeAchievement(
            'Bronze Tree Master',
            'Complete your first tree',
            treesCompleted >= 1,
            Color(0xFFCD7F32),
            Icons.emoji_events,
          ),

          // Silver Tree
          _buildTreeAchievement(
            'Silver Tree Guardian',
            'Complete 2 trees total',
            treesCompleted >= 2,
            Color(0xFFC0C0C0),
            Icons.emoji_events,
          ),

          // Gold Tree
          _buildTreeAchievement(
            'Gold Tree Legend',
            'Complete 3 trees total',
            treesCompleted >= 3,
            Color(0xFFFFD700),
            Icons.emoji_events,
          ),
        ],
      ),
    );
  }

  Widget _buildTreeAchievement(String title, String description, bool achieved, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: achieved ? color.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: achieved ? color.withOpacity(0.3) : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: achieved ? color : Colors.grey[400],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: achieved ? color : Colors.grey[600],
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (achieved)
            Icon(Icons.check_circle, color: Colors.green[600], size: 24)
          else
            Icon(Icons.lock_outline, color: Colors.grey[400], size: 24),
        ],
      ),
    );
  }

  Widget _buildAchievementCategories() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: Colors.blue[600], size: 24),
              SizedBox(width: 12),
              Text(
                'Achievement Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  title: 'Assignments',
                  count: submissionStats['totalAssignments'] ?? 0,
                  icon: Icons.assignment,
                  color: Colors.purple,
                  reward: '4 buckets each',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildCategoryCard(
                  title: 'Tutorials',
                  count: submissionStats['totalTutorials'] ?? 0,
                  icon: Icons.quiz,
                  color: Colors.blue,
                  reward: '1 bucket each',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String reward,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 4),
          Text(
            reward,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardHistory() {
    if (rewardHistory.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Rewards Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Complete assignments and tutorials to start earning water buckets!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.green[600], size: 24),
              SizedBox(width: 12),
              Text(
                'Reward History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rewardHistory.length} rewards',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          ...rewardHistory.asMap().entries.map((entry) {
            final index = entry.key;
            final reward = entry.value;
            final isLast = index == rewardHistory.length - 1;

            return _buildRewardItem(reward, !isLast);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRewardItem(Map<String, dynamic> reward, bool showDivider) {
    final type = reward['type'] as String? ?? 'unknown';
    final buckets = reward['buckets'] as int? ?? 0;
    final itemName = reward['itemName'] as String? ?? 'Unknown Item';
    final awardedAt = reward['awardedAt'] as Timestamp?;
    final submittedAt = reward['submittedAt'] as Timestamp?;
    final dueDate = reward['dueDate'] as Timestamp?;
    final isLate = reward['isLate'] as bool? ?? false;
    final courseName = reward['courseName'] as String?;
    final courseCode = reward['courseCode'] as String?;

    final isAssignment = type == 'assignment';
    final color = isAssignment ? Colors.purple : Colors.blue;
    final icon = isAssignment ? Icons.assignment : Icons.quiz;

    // Calculate if submitted on time
    bool submittedOnTime = true;
    if (dueDate != null && submittedAt != null) {
      submittedOnTime = submittedAt.toDate().isBefore(dueDate.toDate()) ||
          submittedAt.toDate().isAtSameMomentAs(dueDate.toDate());
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              // Main row with icon, details, and reward
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isAssignment ? 'Assignment' : 'Tutorial',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (courseName != null && courseName.isNotEmpty) ...[
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  courseCode != null && courseCode.isNotEmpty
                                      ? '$courseCode - $courseName'
                                      : courseName,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[600],
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_drink, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '+$buckets',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Enhanced submission details section
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    // Submission time
                    if (submittedAt != null)
                      _buildDetailRow(
                        icon: Icons.upload,
                        label: 'Submitted',
                        value: _formatDetailedDateTime(submittedAt),
                        color: Colors.blue[600]!,
                      ),

                    // Due date
                    if (dueDate != null)
                      _buildDetailRow(
                        icon: Icons.schedule,
                        label: 'Due Date',
                        value: _formatDetailedDateTime(dueDate),
                        color: Colors.orange[600]!,
                      ),

                    // Status indicator
                    if (submittedAt != null && dueDate != null)
                      _buildDetailRow(
                        icon: submittedOnTime ? Icons.check_circle : Icons.warning,
                        label: 'Status',
                        value: submittedOnTime ? 'On Time' : 'Late Submission',
                        color: submittedOnTime ? Colors.green[600]! : Colors.red[600]!,
                      )
                    else if (awardedAt != null)
                      _buildDetailRow(
                        icon: Icons.emoji_events,
                        label: 'Rewarded',
                        value: _formatDetailedDateTime(awardedAt),
                        color: Colors.green[600]!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) SizedBox(height: 12),
      ],
    );
  }

  // Helper method to build detail rows
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced date formatting with time
  String _formatDetailedDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    String dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    String timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0) {
      return 'Today at $timeStr';
    } else if (difference.inDays == 1) {
      return 'Yesterday at $timeStr';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago at $timeStr';
    } else {
      return '$dateStr at $timeStr';
    }
  }

  // Helper methods
  Color _getTreeLevelColor() {
    switch (currentTreeLevel) {
      case 'bronze':
        return Color(0xFFCD7F32);
      case 'silver':
        return Color(0xFFC0C0C0);
      case 'gold':
        return Color(0xFFFFD700);
      default:
        return Colors.grey[600]!;
    }
  }

  String _getTreeLevelName() {
    switch (currentTreeLevel) {
      case 'bronze':
        return '🥉 Bronze Tree';
      case 'silver':
        return '🥈 Silver Tree';
      case 'gold':
        return '🥇 Gold Tree';
      default:
        return 'Tree Garden';
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}