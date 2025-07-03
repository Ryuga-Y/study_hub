import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'create_material.dart';
import '../Authentication/auth_services.dart';

class MaterialDetailPage extends StatefulWidget {
  final Map<String, dynamic> material;
  final String courseId;
  final Map<String, dynamic> courseData;
  final bool isLecturer;

  const MaterialDetailPage({
    Key? key,
    required this.material,
    required this.courseId,
    required this.courseData,
    required this.isLecturer,
  }) : super(key: key);

  @override
  _MaterialDetailPageState createState() => _MaterialDetailPageState();
}

class _MaterialDetailPageState extends State<MaterialDetailPage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late Map<String, dynamic> materialData;
  late TabController? _tabController;
  bool isLoading = true;
  String? organizationCode;
  List<Map<String, dynamic>> submissions = [];

  @override
  void initState() {
    super.initState();
    materialData = Map<String, dynamic>.from(widget.material);

    // Initialize tab controller only for tutorial type and lecturer
    if (materialData['materialType'] == 'tutorial' && widget.isLecturer) {
      _tabController = TabController(length: 2, vsync: this);
    }

    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final userData = await _authService.getUserData(user.uid);
        if (userData != null) {
          organizationCode = userData['organizationCode'];

          // Load submissions if it's a tutorial and user is lecturer
          if (materialData['materialType'] == 'tutorial' && widget.isLecturer) {
            await _loadSubmissions();
          }
        }
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadSubmissions() async {
    if (organizationCode == null) return;

    try {
      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .doc(materialData['id'])
          .collection('submissions')
          .orderBy('submittedAt', descending: true)
          .get();

      List<Map<String, dynamic>> loadedSubmissions = [];

      for (var doc in submissionsSnapshot.docs) {
        final submissionData = doc.data();

        // Get student details
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(submissionData['studentId'])
            .get();

        if (studentDoc.exists) {
          loadedSubmissions.add({
            'id': doc.id,
            ...submissionData,
            'studentName': studentDoc.data()?['fullName'] ?? 'Unknown Student',
            'studentEmail': studentDoc.data()?['email'] ?? '',
            'studentId': studentDoc.data()?['studentId'] ?? '',
          });
        }
      }

      setState(() {
        submissions = loadedSubmissions;
      });
    } catch (e) {
      print('Error loading submissions: $e');
    }
  }

  IconData _getMaterialIcon() {
    switch (materialData['materialType']) {
      case 'tutorial':
        return Icons.quiz;
      case 'learning':
      default:
        return Icons.menu_book;
    }
  }

  Color _getMaterialColor() {
    switch (materialData['materialType']) {
      case 'tutorial':
        return Colors.blue;
      case 'learning':
      default:
        return Colors.green;
    }
  }

  void _navigateToEditMaterial() async {
    if (organizationCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Organization code not found. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );

      // Try to load organization code again
      await _loadData();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMaterialPage(
          courseId: widget.courseId,
          courseData: {
            ...widget.courseData,
            'organizationCode': organizationCode,
            'organizationId': organizationCode, // Add both for compatibility
          },
          editMode: true,
          materialId: materialData['id'],
          materialData: materialData,
        ),
      ),
    );

    if (result == true) {
      await _reloadMaterialData();
    }
  }

  Future<void> _reloadMaterialData() async {
    if (organizationCode == null) {
      await _loadData();
      if (organizationCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to reload data. Organization code not found.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      final materialDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .doc(materialData['id'])
          .get();

      if (materialDoc.exists) {
        setState(() {
          materialData = {
            'id': materialDoc.id,
            ...materialDoc.data()!,
          };
        });

        // Reload submissions if it's a tutorial
        if (materialData['materialType'] == 'tutorial' && widget.isLecturer) {
          await _loadSubmissions();
        }
      }
    } catch (e) {
      print('Error reloading material: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reloading material data'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteMaterial() async {
    if (organizationCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete. Organization code not found.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Delete Material'),
        content: Text('Are you sure you want to delete this material? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .doc(materialData['id'])
            .delete();

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
          ),
        ),
      );
    }

    final color = _getMaterialColor();
    final dueDate = materialData['dueDate'] as Timestamp?;
    final files = materialData['files'] as List<dynamic>? ?? [];
    final isTutorial = materialData['materialType'] == 'tutorial';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Material Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isLecturer)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _navigateToEditMaterial();
                    break;
                  case 'delete':
                    _deleteMaterial();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit Material'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Material'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Material Header
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
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
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getMaterialIcon(), size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            isTutorial ? 'Tutorial' : 'Learning Material',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dueDate != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Due: ${_formatDate(dueDate)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  materialData['title'] ?? 'Material',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.library_books, color: Colors.white.withOpacity(0.9), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.courseData['code'] ?? ''} - ${widget.courseData['title'] ?? widget.courseData['name'] ?? ''}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Bar (only for tutorials and lecturers)
          if (isTutorial && widget.isLecturer)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.blue[400],
                indicatorWeight: 3,
                labelColor: Colors.blue[600],
                unselectedLabelColor: Colors.grey[600],
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Details'),
                  Tab(text: 'Submissions (${submissions.length})'),
                ],
              ),
            ),

          // Tab Content
          Expanded(
            child: isTutorial && widget.isLecturer
                ? TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(files),
                _buildSubmissionsTab(),
              ],
            )
                : _buildDetailsTab(files),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(List<dynamic> files) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Material Info Card
          Container(
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
                    Icon(Icons.info_outline, color: _getMaterialColor(), size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Material Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Description
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  materialData['description'] ?? 'No description provided.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),

                // Instructions (for tutorials)
                if (materialData['materialType'] == 'tutorial' &&
                    materialData['instructions'] != null &&
                    materialData['instructions'].toString().isNotEmpty) ...[
                  SizedBox(height: 20),
                  Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      materialData['instructions'],
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),

          // Files Section
          if (files.isNotEmpty)
            Container(
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
                      Icon(Icons.attach_file, color: Colors.purple[600], size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Material Files (${files.length})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ...files.map((file) {
                    final fileName = file['name'] ?? 'File';
                    final fileUrl = file['url'] ?? '';
                    final fileSize = file['size'];

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _launchUrl(fileUrl),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getFileIcon(fileName),
                                color: Colors.purple[400],
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (fileSize != null) ...[
                                      SizedBox(height: 2),
                                      Text(
                                        _formatFileSize(fileSize is int ? fileSize : int.tryParse(fileSize.toString()) ?? 0),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.download,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

          // Submission Statistics (for tutorial and lecturer)
          if (materialData['materialType'] == 'tutorial' && widget.isLecturer) ...[
            SizedBox(height: 16),
            Container(
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
                      Icon(Icons.analytics, color: Colors.orange[600], size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Submission Summary',
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
                        child: _buildStatCard(
                          'Total Submissions',
                          submissions.length.toString(),
                          Icons.upload_file,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'On Time',
                          _countOnTimeSubmissions().toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmissionsTab() {
    if (submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No submissions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Students haven\'t submitted their work',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: submissions.length,
      itemBuilder: (context, index) {
        final submission = submissions[index];
        return _buildSubmissionCard(submission);
      },
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final submittedAt = submission['submittedAt'] as Timestamp?;
    final isLate = _isLateSubmission(submittedAt);
    final files = submission['files'] as List<dynamic>? ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showSubmissionDetails(submission),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      submission['studentName'].substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission['studentName'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'ID: ${submission['studentId']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLate ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isLate ? Colors.red[300]! : Colors.green[300]!,
                      ),
                    ),
                    child: Text(
                      isLate ? 'Late' : 'On Time',
                      style: TextStyle(
                        color: isLate ? Colors.red[700] : Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    'Submitted: ${_formatDateTime(submittedAt)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (files.isNotEmpty) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attachment, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      '${files.length} file(s) attached',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              if (submission['comments'] != null && submission['comments'].toString().isNotEmpty) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          submission['comments'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSubmissionDetails(Map<String, dynamic> submission) {
    final files = submission['files'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submission Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),

              // Student info
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      submission['studentName'].substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission['studentName'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        submission['studentEmail'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Submission time
              Text(
                'Submitted: ${_formatDateTime(submission['submittedAt'] as Timestamp?)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),

              // Comments
              if (submission['comments'] != null && submission['comments'].toString().isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Comments:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  submission['comments'],
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],

              // Files
              if (files.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Attached Files:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                ...files.map((file) {
                  return InkWell(
                    onTap: () => _launchUrl(file['url'] ?? ''),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 4),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getFileIcon(file['name'] ?? ''),
                            size: 20,
                            color: Colors.blue[600],
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file['name'] ?? 'File',
                              style: TextStyle(
                                color: Colors.blue[600],
                                decoration: TextDecoration.underline,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.download,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],

              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  int _countOnTimeSubmissions() {
    final dueDate = materialData['dueDate'] as Timestamp?;
    if (dueDate == null) return submissions.length;

    int count = 0;
    for (var submission in submissions) {
      final submittedAt = submission['submittedAt'] as Timestamp?;
      if (submittedAt != null && submittedAt.toDate().isBefore(dueDate.toDate())) {
        count++;
      }
    }
    return count;
  }

  bool _isLateSubmission(Timestamp? submittedAt) {
    final dueDate = materialData['dueDate'] as Timestamp?;
    if (dueDate == null || submittedAt == null) return false;

    return submittedAt.toDate().isAfter(dueDate.toDate());
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    String dateStr = '${date.day}/${date.month}/${date.year}';
    String timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0) {
      return 'Today at $timeStr';
    } else if (difference.inDays == 1) {
      return 'Yesterday at $timeStr';
    } else {
      return '$dateStr at $timeStr';
    }
  }
}