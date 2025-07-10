import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Authentication/auth_services.dart';
import 'student_submit_view.dart';

class StudentAssignmentDetailsPage extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final String courseId;
  final Map<String, dynamic> courseData;
  final String organizationCode;

  const StudentAssignmentDetailsPage({
    Key? key,
    required this.assignment,
    required this.courseId,
    required this.courseData,
    required this.organizationCode,
  }) : super(key: key);

  @override
  _StudentAssignmentDetailsPageState createState() => _StudentAssignmentDetailsPageState();
}

class _StudentAssignmentDetailsPageState extends State<StudentAssignmentDetailsPage> {
  final AuthService _authService = AuthService();

  bool isLoading = true;
  Map<String, dynamic>? rubricData;
  Map<String, dynamic>? latestSubmission;
  bool hasSubmitted = false;

  // Upload state
  bool isUploading = false;
  double uploadProgress = 0.0;
  String uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final user = _authService.currentUser;
      if (user == null) return;

      // Load rubric if exists
      await _loadRubric();

      // Check if student has submitted
      await _checkSubmissionStatus(user.uid);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadRubric() async {
    try {
      final rubricDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignment['id'])
          .collection('rubric')
          .doc('main')
          .get();

      if (rubricDoc.exists) {
        setState(() {
          rubricData = rubricDoc.data();
        });
      }
    } catch (e) {
      print('Error loading rubric: $e');
    }
  }

  Future<void> _checkSubmissionStatus(String studentId) async {
    try {
      // Query without orderBy first, then sort manually
      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignment['id'])
          .collection('submissions')
          .where('studentId', isEqualTo: studentId)
          .get();

      if (submissionsSnapshot.docs.isNotEmpty) {
        // Sort documents manually by submittedAt
        final sortedDocs = submissionsSnapshot.docs.toList();
        sortedDocs.sort((a, b) {
          final aTime = a.data()['submittedAt'] as Timestamp?;
          final bTime = b.data()['submittedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending order
        });

        setState(() {
          hasSubmitted = true;
          latestSubmission = {
            'id': sortedDocs.first.id,
            ...sortedDocs.first.data(),
          };
        });
      }
    } catch (e) {
      print('Error checking submission status: $e');
    }
  }

  Future<void> _submitAssignment() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final dueDate = widget.assignment['dueDate'] as Timestamp?;
    if (dueDate != null && dueDate.toDate().isBefore(DateTime.now())) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Past Due Date'),
          content: Text('This assignment is past due. Do you still want to submit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Submit Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'zip', 'ppt', 'pptx'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        // Check file size
        if (result.files.single.size > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File size exceeds 10MB limit'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          isUploading = true;
          uploadProgress = 0.0;
          uploadStatus = 'Preparing upload...';
        });

        final userData = await _authService.getUserData(user.uid);
        final studentName = userData?['fullName'] ?? 'Unknown Student';

        // Upload file to Firebase Storage
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final storagePath = 'submissions/${widget.courseId}/${widget.assignment['id']}/$fileName';

        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final metadata = SettableMetadata(
          contentType: _getContentType(result.files.single.extension ?? ''),
          customMetadata: {
            'studentId': user.uid,
            'studentName': studentName,
            'assignmentId': widget.assignment['id'],
            'originalName': result.files.single.name,
          },
        );

        setState(() {
          uploadStatus = 'Uploading file...';
        });

        final uploadTask = ref.putData(result.files.single.bytes!, metadata);

        // Monitor upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            uploadStatus = 'Uploading... ${(uploadProgress * 100).toStringAsFixed(0)}%';
          });
        });

        final snapshot = await uploadTask;
        final fileUrl = await snapshot.ref.getDownloadURL();

        setState(() {
          uploadStatus = 'Saving submission...';
        });

        // Save submission to Firestore
        final submissionRef = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignment['id'])
            .collection('submissions')
            .add({
          'studentId': user.uid,
          'studentName': studentName,
          'studentEmail': userData?['email'] ?? '',
          'submittedAt': FieldValue.serverTimestamp(),
          'fileUrl': fileUrl,
          'fileName': result.files.single.name,
          'fileSize': result.files.single.size,
          'storagePath': storagePath,
          'status': 'submitted',
          'grade': null,
          'feedback': null,
          'isLate': dueDate != null && DateTime.now().isAfter(dueDate.toDate()),
        });

        // Wait for the submission to be written
        await Future.delayed(Duration(seconds: 1));

        // Fetch the created submission document to ensure we have the latest data
        final submissionDoc = await submissionRef.get();
        final submissionData = {
          'id': submissionDoc.id,
          ...submissionDoc.data() ?? {},
        };

        setState(() {
          hasSubmitted = true;
          latestSubmission = submissionData;
          isUploading = false;
          uploadProgress = 0.0;
          uploadStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to submission view after successful submission
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentSubmissionView(
                courseId: widget.courseId,
                assignmentId: widget.assignment['id'],
                assignmentData: widget.assignment,
                organizationCode: widget.organizationCode,
              ),
            ),
          ).then((_) {
            // Reload data when returning from submission view
            _loadData();
          });
        }
      }
    } catch (e) {
      setState(() {
        isUploading = false;
        uploadProgress = 0.0;
        uploadStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadFile(String fileUrl, String fileName) async {
    try {
      final Uri url = Uri.parse(fileUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
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

    final dueDate = widget.assignment['dueDate'] as Timestamp?;
    final isOverdue = dueDate != null && dueDate.toDate().isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Assignment Details',
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
          if (hasSubmitted)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentSubmissionView(
                      courseId: widget.courseId,
                      assignmentId: widget.assignment['id'],
                      assignmentData: widget.assignment,
                      organizationCode: widget.organizationCode,
                    ),
                  ),
                ).then((_) {
                  // Reload data when returning from submission view
                  _loadData();
                });
              },
              icon: Icon(Icons.assignment_turned_in),
              label: Text('View Submission'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.purple[600],
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Colors.purple[400],
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Assignment Header
              Container(
                width: double.infinity,
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
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
                              Icon(Icons.assignment, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Assignment',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOverdue) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Overdue',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        if (hasSubmitted) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              latestSubmission?['grade'] != null ? 'Graded' : 'Submitted',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      widget.assignment['title'] ?? 'Assignment',
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
                            '${widget.courseData['code'] ?? ''} - ${widget.courseData['title'] ?? ''}',
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

              // Quick Actions
              if (!hasSubmitted || (latestSubmission?['grade'] == null))
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(16),
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
                  child: Column(
                    children: [
                      if (!hasSubmitted) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isUploading ? null : _submitAssignment,
                            icon: Icon(Icons.upload_file, color: Colors.white),
                            label: Text(
                              'Submit Assignment',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Assignment Submitted',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (latestSubmission != null) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        'Submitted: ${_formatDateTime(latestSubmission!['submittedAt'])}',
                                        style: TextStyle(
                                          color: Colors.green[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StudentSubmissionView(
                                        courseId: widget.courseId,
                                        assignmentId: widget.assignment['id'],
                                        assignmentData: widget.assignment,
                                        organizationCode: widget.organizationCode,
                                      ),
                                    ),
                                  ).then((_) {
                                    _loadData();
                                  });
                                },
                                child: Text('View'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Upload Progress
                      if (isUploading) ...[
                        SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              uploadStatus,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: uploadProgress,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              // Assignment Details
              Container(
                margin: EdgeInsets.all(16),
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
                        Icon(Icons.info_outline, color: Colors.orange[600], size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Assignment Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Due Date and Points
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.calendar_today,
                            label: 'Due Date',
                            value: _formatDateTime(dueDate),
                            color: Colors.orange,
                            isOverdue: isOverdue,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.grade,
                            label: 'Points',
                            value: '${widget.assignment['points'] ?? 0}',
                            color: Colors.green,
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
                      widget.assignment['description'] ?? 'No description provided.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Instructions
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
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        widget.assignment['instructions'] ?? 'No specific instructions provided.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Rubric Preview
              if (rubricData != null)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
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
                          Icon(Icons.rule, color: Colors.purple[600], size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Evaluation Rubric',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Your work will be evaluated based on the following criteria:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Rubric criteria
                      if (rubricData!['criteria'] != null) ...[
                        ...(rubricData!['criteria'] as List).map((criterion) {
                          final weight = criterion['weight'] ?? 0;
                          final levels = criterion['levels'] as List? ?? [];

                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        criterion['name'] ?? 'Criterion',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.purple[800],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.purple[600],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$weight%',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (criterion['description'] != null &&
                                    criterion['description'].toString().isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    criterion['description'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                SizedBox(height: 8),

                                // Performance levels
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: levels.map<Widget>((level) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.purple[300]!),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            level['name'] ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.purple[100],
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${level['points'] ?? 0}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),

              // Reference Materials
              if (widget.assignment['attachments'] != null &&
                  (widget.assignment['attachments'] as List).isNotEmpty)
                Container(
                  margin: EdgeInsets.all(16),
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
                            'Reference Materials',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      ...(widget.assignment['attachments'] as List).map((attachment) {
                        final name = attachment['name'] ?? 'File';
                        final url = attachment['url'] ?? '';

                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _downloadFile(url, name),
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
                                    _getFileIcon(name),
                                    color: Colors.purple[400],
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      ),
                                      overflow: TextOverflow.ellipsis,
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

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isOverdue = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isOverdue ? Colors.red : Colors.grey[800],
            ),
          ),
          if (isOverdue)
            Text(
              'OVERDUE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
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

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'N/A';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    String dateStr = '${date.day}/${date.month}/${date.year}';
    String timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0 && date.day == now.day) {
      return 'Today at $timeStr';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && date.day != now.day)) {
      return 'Yesterday at $timeStr';
    } else {
      return '$dateStr at $timeStr';
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}