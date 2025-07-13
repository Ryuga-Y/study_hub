import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Authentication/auth_services.dart';

class StudentTutorialSubmissionView extends StatefulWidget {
  final String courseId;
  final String materialId;
  final Map<String, dynamic> materialData;
  final String organizationCode;

  const StudentTutorialSubmissionView({
    Key? key,
    required this.courseId,
    required this.materialId,
    required this.materialData,
    required this.organizationCode,
  }) : super(key: key);

  @override
  _StudentTutorialSubmissionViewState createState() => _StudentTutorialSubmissionViewState();
}

class _StudentTutorialSubmissionViewState extends State<StudentTutorialSubmissionView> {
  final AuthService _authService = AuthService();
  bool isLoading = true;

  Map<String, dynamic>? submission;
  Map<String, dynamic>? feedback;

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
        print('No authenticated user found');
        setState(() {
          isLoading = false;
        });
        return;
      }

      print('Loading submissions for user: ${user.uid}');
      print('Organization: ${widget.organizationCode}');
      print('Course: ${widget.courseId}');
      print('Material: ${widget.materialId}');

      // Try first without orderBy (to avoid composite index requirement)
      final submissionSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .doc(widget.materialId)
          .collection('submissions')
          .where('studentId', isEqualTo: user.uid)
          .get();

      print('Found ${submissionSnapshot.docs.length} submissions');

      if (submissionSnapshot.docs.isNotEmpty) {
        // Sort manually by submittedAt
        final sortedDocs = submissionSnapshot.docs.toList();
        sortedDocs.sort((a, b) {
          final aTime = a.data()['submittedAt'] as Timestamp?;
          final bTime = b.data()['submittedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending order
        });

        final submissionDoc = sortedDocs.first;
        setState(() {
          submission = {
            'id': submissionDoc.id,
            ...submissionDoc.data(),
          };
        });

        print('Loaded submission: ${submission!['id']}');

        // Check for feedback
        final feedbackDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .doc(widget.materialId)
            .collection('submissions')
            .doc(submissionDoc.id)
            .collection('feedback')
            .doc('main')
            .get();

        if (feedbackDoc.exists) {
          setState(() {
            feedback = feedbackDoc.data();
          });
          print('Loaded feedback');
        }
      } else {
        print('No submissions found for this user');
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _resubmitTutorial() async {
    final user = _authService.currentUser;
    if (user == null) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.refresh, color: Colors.blue[600], size: 24),
            SizedBox(width: 8),
            Text('Resubmit Tutorial'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to resubmit this tutorial?'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your previous submission will be replaced',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
              backgroundColor: Colors.blue[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Resubmit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Add comment dialog
    final commentController = TextEditingController(text: submission?['comments'] ?? '');
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Comments (Optional)'),
        content: TextField(
          controller: commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any comments about your submission...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, commentController.text),
            child: Text('Continue'),
          ),
        ],
      ),
    );

    if (comment == null) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'zip', 'ppt', 'pptx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          isUploading = true;
          uploadProgress = 0.0;
          uploadStatus = 'Preparing upload...';
        });

        final userData = await _authService.getUserData(user.uid);
        final studentName = userData?['fullName'] ?? 'Unknown Student';

        List<Map<String, dynamic>> uploadedFiles = [];

        // Delete old files if any
        if (submission?['files'] != null) {
          setState(() {
            uploadStatus = 'Removing previous files...';
          });
          for (var file in submission!['files']) {
            if (file['storagePath'] != null) {
              try {
                await FirebaseStorage.instance.ref(file['storagePath']).delete();
              } catch (e) {
                print('Error deleting old file: $e');
              }
            }
          }
        }

        setState(() {
          uploadStatus = 'Uploading new files...';
        });

        for (int i = 0; i < result.files.length; i++) {
          var file = result.files[i];
          if (file.bytes != null && file.size <= 10 * 1024 * 1024) {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final storagePath = 'materials/${widget.courseId}/${widget.materialId}/submissions/$fileName';

            final ref = FirebaseStorage.instance.ref().child(storagePath);
            final metadata = SettableMetadata(
              contentType: _getContentType(file.extension ?? ''),
            );

            final uploadTask = ref.putData(file.bytes!, metadata);

            // Monitor progress
            uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
              setState(() {
                uploadProgress = (i + snapshot.bytesTransferred / snapshot.totalBytes) / result.files.length;
                uploadStatus = 'Uploading file ${i + 1} of ${result.files.length}...';
              });
            });

            final snapshot = await uploadTask;
            final fileUrl = await snapshot.ref.getDownloadURL();

            uploadedFiles.add({
              'url': fileUrl,
              'name': file.name,
              'size': file.size,
              'uploadedAt': Timestamp.now(),
              'storagePath': storagePath,
            });
          }
        }

        setState(() {
          uploadStatus = 'Saving submission...';
        });

        // Update submission
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .doc(widget.materialId)
            .collection('submissions')
            .doc(submission!['id'])
            .update({
          'files': uploadedFiles,
          'comments': comment,
          'resubmittedAt': FieldValue.serverTimestamp(),
          'submissionVersion': FieldValue.increment(1),
        });

        setState(() {
          isUploading = false;
          uploadProgress = 0.0;
          uploadStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tutorial resubmitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload data
        await _loadData();
      }
    } catch (e) {
      setState(() {
        isUploading = false;
        uploadProgress = 0.0;
        uploadStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resubmitting tutorial: $e'),
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
          ),
        ),
      );
    }

    if (submission == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Tutorial Submission',
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
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'No submission yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You haven\'t submitted this tutorial',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: Colors.white),
                label: Text(
                  'Go Back to Submit',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'Tutorial Submission',
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
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.blue[600]),
                onPressed: _loadData,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadData,
            color: Colors.blue[400],
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Tutorial Header
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              Icon(Icons.quiz, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Tutorial',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          widget.materialData['title'] ?? 'Tutorial',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.materialData['dueDate'] != null) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.white.withOpacity(0.9), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Due: ${_formatDateTime(widget.materialData['dueDate'] as Timestamp)}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Resubmit Option
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.blue[600], size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Update Submission',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You can resubmit this tutorial anytime',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _resubmitTutorial,
                          child: Text(
                            'Resubmit',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Feedback Card (if available)
                  if (feedback != null)
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
                              Icon(Icons.comment, color: Colors.blue[600], size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Instructor Feedback',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              feedback!['comment'] ?? 'No feedback provided',
                              style: TextStyle(
                                color: Colors.blue[900],
                                height: 1.5,
                              ),
                            ),
                          ),
                          if (feedback!['providedAt'] != null) ...[
                            SizedBox(height: 12),
                            Text(
                              'Provided on ${_formatDateTime(feedback!['providedAt'] as Timestamp)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Submission Details
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
                            Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Submission Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildDetailRow(
                          'Status',
                          'Submitted',
                          Icons.check_circle,
                          Colors.green,
                        ),
                        _buildDetailRow(
                          'Version',
                          '${submission!['submissionVersion'] ?? 1}',
                          Icons.layers,
                          Colors.blue,
                        ),
                        _buildDetailRow(
                          'Submitted',
                          _formatDateTime(submission!['submittedAt']),
                          Icons.access_time,
                          Colors.blue,
                        ),
                        if (submission!['resubmittedAt'] != null)
                          _buildDetailRow(
                            'Last Updated',
                            _formatDateTime(submission!['resubmittedAt']),
                            Icons.update,
                            Colors.orange,
                          ),
                        if (submission!['isLate'] == true)
                          _buildDetailRow(
                            'Submission',
                            'Late Submission',
                            Icons.warning,
                            Colors.red,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Submitted Files
                  if (submission!['files'] != null && (submission!['files'] as List).isNotEmpty)
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
                                'Submitted Files',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          ...(submission!['files'] as List).map((file) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => _downloadFile(file['url'], file['name']),
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
                                        _getFileIcon(file['name']),
                                        color: Colors.purple[400],
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              file['name'],
                                              style: TextStyle(
                                                color: Colors.blue[600],
                                                fontWeight: FontWeight.w500,
                                                decoration: TextDecoration.underline,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (file['size'] != null)
                                              Text(
                                                _formatFileSize(file['size']),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
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

                  // Comments
                  if (submission!['comments'] != null && submission!['comments'].toString().isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 16),
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
                              Icon(Icons.note, color: Colors.grey[600], size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Your Comments',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              submission!['comments'],
                              style: TextStyle(
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Upload progress overlay
        if (isUploading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
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
                                color: Colors.blue[600],
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
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
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

  String _formatFileSize(dynamic size) {
    int bytes = 0;
    if (size is int) {
      bytes = size;
    } else if (size is String) {
      bytes = int.tryParse(size) ?? 0;
    }

    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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