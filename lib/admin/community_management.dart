import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../community/bloc.dart';
import '../community/models.dart';
import '../community/post_card.dart';

class CommunityManagementPage extends StatefulWidget {
  final String organizationId;

  const CommunityManagementPage({Key? key, required this.organizationId}) : super(key: key);

  @override
  _CommunityManagementPageState createState() => _CommunityManagementPageState();
}

class _CommunityManagementPageState extends State<CommunityManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  void _loadData() {
    context.read<CommunityBloc>().add(LoadReportedPosts(organizationCode: widget.organizationId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityBloc, CommunityState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(24),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Make title flexible to shrink when needed
                        Flexible(
                          flex: 2,
                          child: Text(
                            'Community Management',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis, // Handle text overflow gracefully
                          ),
                        ),
                        SizedBox(width: 12), // Add some spacing
                        // Make reports container flexible
                        Flexible(
                          flex: 1,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min, // Important: minimize row size
                              children: [
                                Icon(Icons.report, size: 14, color: Colors.red[700]), // Smaller icon
                                SizedBox(width: 6), // Reduced spacing
                                Flexible( // Make text flexible
                                  child: Text(
                                    '${state.reportedPosts.where((r) => r.status == 'pending').length} Pending',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13, // Slightly smaller font
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Search bar
                    Container(
                      width: MediaQuery.of(context).size.width > 600 ? 400 : double.infinity,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search posts, users, or reports...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value.toLowerCase());
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.red,
                  labelColor: Colors.red,
                  unselectedLabelColor: Colors.grey[600],
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Critical: minimize row size
                        children: [
                          Flexible( // Make text flexible
                            child: Text(
                              'Reported Posts',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (state.reportedPosts.where((r) => r.status == 'pending').isNotEmpty) ...[
                            SizedBox(width: 6), // Reduced spacing
                            Container(
                              constraints: BoxConstraints(minWidth: 20), // Minimum width for badge
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced padding
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${state.reportedPosts.where((r) => r.status == 'pending').length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11, // Smaller font
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(text: 'Post Analytics'),
                    Tab(text: 'Moderation History'),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReportedPostsTab(state),
                    _buildAnalyticsTab(state),
                    _buildHistoryTab(state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportedPostsTab(CommunityState state) {
    final pendingReports = state.reportedPosts
        .where((report) => report.status == 'pending')
        .where((report) {
      if (_searchQuery.isEmpty) return true;
      return report.reporterName.toLowerCase().contains(_searchQuery) ||
          report.reason.toLowerCase().contains(_searchQuery) ||
          report.details.toLowerCase().contains(_searchQuery) ||
          (report.post?.caption.toLowerCase().contains(_searchQuery) ?? false);
    })
        .toList();

    if (pendingReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green[400]),
            SizedBox(height: 16),
            Text(
              'No pending reports',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'All reports have been reviewed',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(24),
      itemCount: pendingReports.length,
      itemBuilder: (context, index) {
        final report = pendingReports[index];
        return _buildReportCard(report);
      },
    );
  }

  Widget _buildReportCard(PostReport report) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: report.reporterAvatar != null
                      ? CachedNetworkImageProvider(report.reporterAvatar!)
                      : null,
                  child: report.reporterAvatar == null
                      ? Icon(Icons.person, size: 20)
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reported by ${report.reporterName}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        timeago.format(report.reportedAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildReasonChip(report.reason),
              ],
            ),
          ),

          // Report Details
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason Details:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.details.isNotEmpty ? report.details : 'No additional details provided',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          // Reported Post Preview
          if (report.post != null) ...[
            Divider(height: 1),
            Container(
              color: Colors.grey[50],
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reported Post:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 12),
                  // Mini post preview
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: PostCard(
                      post: report.post!,
                      isDetailView: false,
                      onLike: () {},
                      onComment: () {},
                      onShare: () {},
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReviewDialog(report, false),
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    label: Text('Mark as Invalid', style: TextStyle(color: Colors.grey[700])),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showReviewDialog(report, true),
                    icon: Icon(Icons.delete, color: Colors.white),
                    label: Text('Remove Post', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonChip(String reason) {
    final reasonDisplay = {
      'inappropriate': 'Inappropriate',
      'spam': 'Spam',
      'harassment': 'Harassment',
      'violence': 'Violence',
      'misinformation': 'Misinformation',
      'other': 'Other',
    };

    final reasonColors = {
      'inappropriate': Colors.orange,
      'spam': Colors.blue,
      'harassment': Colors.red,
      'violence': Colors.purple,
      'misinformation': Colors.amber,
      'other': Colors.grey,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: reasonColors[reason]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: reasonColors[reason]!),
      ),
      child: Text(
        reasonDisplay[reason] ?? reason,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: reasonColors[reason],
        ),
      ),
    );
  }

  void _showReviewDialog(PostReport report, bool isValid) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              isValid ? Icons.delete : Icons.check_circle,
              color: isValid ? Colors.red : Colors.green,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(isValid ? 'Remove Post' : 'Mark as Invalid'),
          ],
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isValid
                    ? 'Are you sure you want to remove this post?'
                    : 'Are you sure this report is invalid?',
                style: TextStyle(fontSize: 16),
              ),
              if (isValid) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[700], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action cannot be undone. The post will be permanently deleted.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Admin Notes',
                  hintText: 'Add notes about your decision...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CommunityBloc>().add(
                ReviewReport(
                  reportId: report.id,
                  postId: report.postId,
                  isValid: isValid,
                  adminNotes: notesController.text.trim(),
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isValid ? Colors.red : Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isValid ? 'Remove Post' : 'Mark Invalid',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(CommunityState state) {
    // Statistics about posts and engagement
    final totalPosts = state.feedPosts.length;
    final totalReports = state.reportedPosts.length;
    final validReports = state.reportedPosts.where((r) => r.status == 'valid').length;
    final invalidReports = state.reportedPosts.where((r) => r.status == 'invalid').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Community Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),

          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                title: 'Total Posts',
                value: totalPosts.toString(),
                icon: Icons.post_add,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: 'Total Reports',
                value: totalReports.toString(),
                icon: Icons.flag,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: 'Valid Reports',
                value: validReports.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'Invalid Reports',
                value: invalidReports.toString(),
                icon: Icons.cancel,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(CommunityState state) {
    final reviewedReports = state.reportedPosts
        .where((report) => report.status != 'pending')
        .toList()
      ..sort((a, b) => (b.reviewedAt ?? b.reportedAt).compareTo(a.reviewedAt ?? a.reportedAt));

    if (reviewedReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No moderation history',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(24),
      itemCount: reviewedReports.length,
      itemBuilder: (context, index) {
        final report = reviewedReports[index];
        return _buildHistoryCard(report);
      },
    );
  }

  Widget _buildHistoryCard(PostReport report) {
    final isValid = report.status == 'valid';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.delete : Icons.check_circle,
            color: isValid ? Colors.red : Colors.green,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report by ${report.reporterName}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${isValid ? "Post removed" : "Marked as invalid"} by ${report.reviewerName ?? "Admin"}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                if (report.adminNotes?.isNotEmpty ?? false)
                  Text(
                    'Notes: ${report.adminNotes}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
          Text(
            report.reviewedAt != null ? timeago.format(report.reviewedAt!) : '',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adjust sizes based on available space
          final availableHeight = constraints.maxHeight;
          final iconSize = availableHeight > 120 ? 30.0 : 24.0;
          final valueSize = availableHeight > 120 ? 24.0 : 20.0;
          final titleSize = availableHeight > 120 ? 12.0 : 10.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: iconSize),
              SizedBox(height: availableHeight > 120 ? 8 : 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: valueSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 2),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}