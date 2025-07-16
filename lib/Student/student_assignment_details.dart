import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Authentication/auth_services.dart';
import 'student_submit_view.dart';
import '../goal_progress_service.dart';

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
  final GoalProgressService _goalService = GoalProgressService();

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
      if (user == null) {
        _showErrorDialog('Authentication Error',
            'Please log in to view assignment details.');
        return;
      }

      // Verify user data and permissions
      final userData = await _authService.getUserData(user.uid);
      if (userData == null) {
        _showErrorDialog('User Data Error',
            'Could not retrieve user information. Please try logging in again.');
        return;
      }

      if (userData['role'] != 'student') {
        _showErrorDialog(
            'Permission Error', 'Only students can view assignment details.');
        return;
      }

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
      _showErrorDialog(
          'Loading Error', 'Failed to load assignment details: $e');
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
          rubricData = rubricDoc.data() as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      print('Error loading rubric: $e');
      // Don't show error for rubric loading failure - it's optional
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
          latestSubmission = <String, dynamic>{
            'id': sortedDocs.first.id,
            ...(sortedDocs.first.data() as Map<String, dynamic>),
          };
        });
      }
    } catch (e) {
      print('Error checking submission status: $e');
      // Don't show error for submission check failure - user might not have submitted yet
    }
  }

  Future<void> _submitAssignment() async {
    final user = _authService.currentUser;
    if (user == null) {
      _showErrorDialog(
          'Authentication Error', 'Please log in to submit assignments.');
      return;
    }

    // Verify user data first
    final userData = await _authService.getUserData(user.uid);
    if (userData == null) {
      _showErrorDialog('User Data Error',
          'Could not retrieve user information. Please try logging in again.');
      return;
    }

    // Verify user is a student
    if (userData['role'] != 'student') {
      _showErrorDialog(
          'Permission Error', 'Only students can submit assignments.');
      return;
    }

    // Verify organization membership
    if (userData['organizationCode'] != widget.organizationCode) {
      _showErrorDialog(
          'Organization Error', 'You are not enrolled in this organization.');
      return;
    }

    // Check if assignment has been graded
    if (latestSubmission != null && latestSubmission!['grade'] != null) {
      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.block, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text('Submission Not Allowed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This assignment has already been graded.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.grade, color: Colors.green[700], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grade: ${latestSubmission!['grade']}/${widget
                                    .assignment['points'] ?? 100}',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (latestSubmission!['letterGrade'] != null)
                                Text(
                                  'Letter Grade: ${latestSubmission!['letterGrade']}',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No further submissions are allowed once an assignment has been graded.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
      );
      return;
    }

    // Check due date
    final dueDate = widget.assignment['dueDate'] as Timestamp?;
    final isLate = dueDate != null && dueDate.toDate().isBefore(DateTime.now());

    // Show confirmation dialog
    final isResubmit = hasSubmitted && latestSubmission?['grade'] == null;
    final confirmationTitle = isResubmit
        ? 'Confirm Resubmission'
        : 'Confirm Submission';
    final confirmationMessage = isResubmit
        ? 'Are you sure you want to resubmit this assignment? Your previous submission will be replaced.'
        : 'Are you sure you want to submit this assignment?';

    // Add late submission warning if applicable
    String fullMessage = confirmationMessage;
    if (isLate) {
      fullMessage +=
      '\n\n⚠️ Note: This assignment is past due and will be marked as late.';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isResubmit ? Icons.refresh : Icons.upload_file,
                  color: Colors.orange[600],
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(confirmationTitle),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullMessage),
                if (isResubmit && latestSubmission?['fileName'] != null) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[600],
                            size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current submission:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                latestSubmission!['fileName'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLate ? Colors.orange : Colors.orange[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isResubmit ? 'Resubmit' : 'Submit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'jpg',
          'jpeg',
          'png',
          'zip',
          'ppt',
          'pptx'
        ],
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

        final studentName = userData['fullName'] ?? 'Unknown Student';

        // Delete old file if resubmitting
        if (isResubmit && latestSubmission!['storagePath'] != null) {
          try {
            setState(() {
              uploadStatus = 'Removing previous file...';
            });
            await FirebaseStorage.instance
                .ref(latestSubmission!['storagePath'])
                .delete();
          } catch (e) {
            print('Error deleting old file: $e');
            // Continue even if delete fails
          }
        }

        // Upload file to Firebase Storage
        final fileName = '${DateTime
            .now()
            .millisecondsSinceEpoch}_${result.files.single.name}';
        final storagePath = 'submissions/${widget.courseId}/${widget
            .assignment['id']}/$fileName';

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
            uploadStatus =
            'Uploading... ${(uploadProgress * 100).toStringAsFixed(0)}%';
          });
        });

        final snapshot = await uploadTask;
        final fileUrl = await snapshot.ref.getDownloadURL();

        setState(() {
          uploadStatus = 'Saving submission...';
        });

        if (isResubmit) {
          // Update existing submission - NO NEW REWARD
          await FirebaseFirestore.instance
              .collection('organizations')
              .doc(widget.organizationCode)
              .collection('courses')
              .doc(widget.courseId)
              .collection('assignments')
              .doc(widget.assignment['id'])
              .collection('submissions')
              .doc(latestSubmission!['id'])
              .update({
            'fileUrl': fileUrl,
            'fileName': result.files.single.name,
            'fileSize': result.files.single.size,
            'storagePath': storagePath,
            'resubmittedAt': FieldValue.serverTimestamp(),
            'submissionVersion': FieldValue.increment(1),
            'isLate': isLate,
            'status': 'submitted',
          });

          // Update local state
          latestSubmission!['fileUrl'] = fileUrl;
          latestSubmission!['fileName'] = result.files.single.name;
          latestSubmission!['fileSize'] = result.files.single.size;
          latestSubmission!['storagePath'] = storagePath;
          latestSubmission!['submissionVersion'] =
              (latestSubmission!['submissionVersion'] ?? 1) + 1;
          latestSubmission!['isLate'] = isLate;
          latestSubmission!['status'] = 'submitted';
        } else {
          // Create new submission with comprehensive data structure for security rules
          final submissionData = <String, dynamic>{
            'studentId': user.uid,
            // CRITICAL: This must match auth.uid for security rules
            'studentName': studentName,
            'studentEmail': userData['email'] ?? '',
            'submittedAt': FieldValue.serverTimestamp(),
            'fileUrl': fileUrl,
            'fileName': result.files.single.name,
            'fileSize': result.files.single.size,
            'storagePath': storagePath,
            'status': 'submitted',
            'grade': null,
            'feedback': null,
            'isLate': isLate,
            'submissionVersion': 1,
            'assignmentId': widget.assignment['id'],
            'courseId': widget.courseId,
            'organizationCode': widget.organizationCode,
            // Additional metadata for tracking
            'submissionType': 'assignment',
            'createdAt': FieldValue.serverTimestamp(),
            'lastModified': FieldValue.serverTimestamp(),
          };

          // Create submission with proper error handling
          DocumentReference submissionRef;
          try {
            submissionRef = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(widget.organizationCode)
                .collection('courses')
                .doc(widget.courseId)
                .collection('assignments')
                .doc(widget.assignment['id'])
                .collection('submissions')
                .add(submissionData);

            print('✅ Submission created successfully: ${submissionRef.id}');
          } catch (firestoreError) {
            setState(() {
              isUploading = false;
              uploadProgress = 0.0;
              uploadStatus = '';
            });

            print('❌ Firestore submission error: $firestoreError');

            // Show specific error dialog
            _showFirestoreErrorDialog(firestoreError);
            return;
          }

          // Wait for the submission to be written
          await Future.delayed(Duration(seconds: 1));

          // Fetch the created submission document to ensure we have the latest data
          final submissionDoc = await submissionRef.get();
          final submissionDocData = <String, dynamic>{
            'id': submissionDoc.id,
            ...(submissionDoc.data() as Map<String, dynamic>? ??
                <String, dynamic>{}),
          };

          // 🎯 AWARD WATER BUCKETS: 4 buckets for assignment submission
          try {
            await _goalService.awardAssignmentSubmission(
                submissionRef.id,
                widget.assignment['id'],
                assignmentName: widget.assignment['title'] ?? 'Assignment'
            );
            print('✅ Awarded 4 water buckets for assignment: ${widget
                .assignment['title']}');
          } catch (e) {
            print('❌ Error awarding water buckets: $e');
            // Don't fail the submission if reward fails
          }

          setState(() {
            hasSubmitted = true;
            latestSubmission = submissionDocData;
          });
        }

        setState(() {
          isUploading = false;
          uploadProgress = 0.0;
          uploadStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text(isResubmit
                    ? 'Assignment resubmitted successfully'
                    : 'Assignment submitted successfully!')),
                if (!isResubmit) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_drink, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('+4', style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Navigate to submission view after successful submission
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  StudentSubmissionView(
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

      print('❌ General submission error: $e');
      _showErrorDialog('Submission Error', 'Failed to submit assignment: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Troubleshooting Steps:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('1. Check your internet connection',
                          style: TextStyle(fontSize: 12)),
                      Text('2. Make sure you\'re logged in as a student',
                          style: TextStyle(fontSize: 12)),
                      Text('3. Verify you\'re enrolled in this course',
                          style: TextStyle(fontSize: 12)),
                      Text(
                          '4. Contact your instructor if the problem continues',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  void _showFirestoreErrorDialog(dynamic error) {
    String errorMessage = 'Unknown database error occurred.';
    String troubleshootingSteps = '';

    if (error.toString().contains('permission-denied')) {
      errorMessage =
      'Permission denied. You don\'t have permission to submit assignments.';
      troubleshootingSteps = '''
This usually happens when:
• Database security rules haven't been properly configured
• Your account doesn't have student permissions
• The course enrollment is incomplete
• You're not part of the correct organization

Please contact your instructor or administrator to resolve this issue.
      ''';
    } else if (error.toString().contains('not-found')) {
      errorMessage = 'Assignment or course not found in the database.';
      troubleshootingSteps = '''
This might happen when:
• The assignment has been deleted
• The course has been removed
• There's a database synchronization issue

Please refresh the page and try again.
      ''';
    } else if (error.toString().contains('unavailable')) {
      errorMessage =
      'Database is temporarily unavailable. Please try again later.';
      troubleshootingSteps = '''
This is usually a temporary issue:
• Check your internet connection
• Wait a few minutes and try again
• Contact support if the problem persists
      ''';
    } else if (error.toString().contains('failed-precondition')) {
      errorMessage =
      'Data validation failed. Please check your submission details.';
      troubleshootingSteps = '''
This happens when:
• Required fields are missing
• Data format is incorrect
• Security validation failed

Please try submitting again or contact support.
      ''';
    }

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text('Database Error'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errorMessage,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What to do:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          troubleshootingSteps.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Retry the submission
                  _submitAssignment();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Try Again', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
              ),
              SizedBox(height: 16),
              Text(
                'Loading assignment details...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dueDate = widget.assignment['dueDate'] as Timestamp?;
    final isOverdue = dueDate != null &&
        dueDate.toDate().isBefore(DateTime.now());

    return Stack(
      children: [
        Scaffold(
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
                        builder: (context) =>
                            StudentSubmissionView(
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
              // Refresh button
              IconButton(
                onPressed: _loadData,
                icon: Icon(Icons.refresh, color: Colors.grey[600]),
                tooltip: 'Refresh',
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
                          color: Colors.orange.withValues(alpha: 0.3),
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
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.assignment, size: 16,
                                      color: Colors.white),
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.3),
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  latestSubmission?['grade'] != null
                                      ? 'Graded'
                                      : 'Submitted',
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
                            Icon(Icons.library_books,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.courseData['code'] ?? ''} - ${widget
                                    .courseData['title'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.9),
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
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (!hasSubmitted) ...[
                            // Submit button
                            Container(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _submitAssignment,
                                icon: Icon(
                                    Icons.upload_file, color: Colors.white),
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
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            // Reward info
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.local_drink,
                                      color: Colors.orange[600], size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Submit this assignment to earn 4 water buckets for your tree!',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            if (latestSubmission?['grade'] == null) ...[
                              // Submitted but not graded - show resubmit option
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.blue[700], size: 20),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                            'Assignment Submitted',
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'You can resubmit until graded',
                                            style: TextStyle(
                                              color: Colors.blue[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _submitAssignment,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[600],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              8),
                                        ),
                                      ),
                                      child: Text('Resubmit', style: TextStyle(
                                          color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                        ],
                      ),
                    )
                  else
                  // Graded - show final grade
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700],
                                size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Assignment Completed',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Grade: ${latestSubmission!['grade']}/${widget
                                            .assignment['points'] ?? 100}',
                                        style: TextStyle(
                                          color: Colors.green[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (latestSubmission!['letterGrade'] !=
                                          null) ...[
                                        SizedBox(width: 12),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getLetterGradeColor(
                                                latestSubmission!['letterGrade']),
                                            borderRadius: BorderRadius.circular(
                                                12),
                                          ),
                                          child: Text(
                                            latestSubmission!['letterGrade'],
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        StudentSubmissionView(
                                          courseId: widget.courseId,
                                          assignmentId: widget.assignment['id'],
                                          assignmentData: widget.assignment,
                                          organizationCode: widget
                                              .organizationCode,
                                        ),
                                  ),
                                ).then((_) {
                                  _loadData();
                                });
                              },
                              child: Text('View Details'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
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
                          color: Colors.grey.withValues(alpha: 0.1),
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
                            Icon(Icons.info_outline, color: Colors.orange[600],
                                size: 24),
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
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Text(
                            widget.assignment['description'] ??
                                'No description provided.',
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
                            color: Colors.grey.withValues(alpha: 0.1),
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
                              Icon(Icons.rule, color: Colors.purple[600],
                                  size: 24),
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
                            ...(rubricData!['criteria'] as List).map((
                                criterion) {
                              final weight = criterion['weight'] ?? 0;
                              final levels = criterion['levels'] as List? ?? [];

                              return Container(
                                margin: EdgeInsets.only(bottom: 12),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.purple[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.purple[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment
                                          .spaceBetween,
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
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.purple[600],
                                            borderRadius: BorderRadius.circular(
                                                12),
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
                                        criterion['description']
                                            .toString()
                                            .isNotEmpty) ...[
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
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                                20),
                                            border: Border.all(
                                                color: Colors.purple[300]!),
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
                            color: Colors.grey.withValues(alpha: 0.1),
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
                              Icon(Icons.attach_file, color: Colors.purple[600],
                                  size: 24),
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
                          ...(widget.assignment['attachments'] as List).map((
                              attachment) {
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
                                    border: Border.all(
                                        color: Colors.grey[300]!),
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
                                            decoration: TextDecoration
                                                .underline,
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
        ),
        // Upload progress overlay
        if (isUploading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        value: uploadProgress > 0 ? uploadProgress : null,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.orange[600]!),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 20),
                      Text(
                        uploadStatus,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (uploadProgress > 0) ...[
                        SizedBox(height: 16),
                        Container(
                          height: 8,
                          width: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: uploadProgress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.orange[600],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${(uploadProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[600],
                          ),
                        ),
                      ],
                      SizedBox(height: 12),
                      Text(
                        hasSubmitted
                            ? 'Updating your submission...'
                            : 'Processing your submission...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
    final extension = fileName
        .split('.')
        .last
        .toLowerCase();
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
    String timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute
        .toString().padLeft(2, '0')}';

    if (difference.inDays == 0 && date.day == now.day) {
      return 'Today at $timeStr';
    } else if (difference.inDays == 1 ||
        (difference.inDays == 0 && date.day != now.day)) {
      return 'Yesterday at $timeStr';
    } else {
      return '$dateStr at $timeStr';
    }
  }

  Color _getLetterGradeColor(String? letterGrade) {
    if (letterGrade == null) return Colors.grey[600]!;

    switch (letterGrade) {
      case 'A+':
      case 'A':
      case 'A-':
        return Colors.green[600]!;
      case 'B+':
      case 'B':
      case 'B-':
        return Colors.blue[600]!;
      case 'C+':
      case 'C':
        return Colors.orange[600]!;
      case 'F':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
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