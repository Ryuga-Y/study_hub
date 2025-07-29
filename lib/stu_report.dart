import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Authentication/auth_services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'dart:io';

class StudentReportPage extends StatefulWidget {
  const StudentReportPage({Key? key}) : super(key: key);

  @override
  _StudentReportPageState createState() => _StudentReportPageState();
}

class _StudentReportPageState extends State<StudentReportPage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  bool isLoading = true;
  String? organizationCode;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _organizationData;

  // Data structures
  List<Map<String, dynamic>> assignmentResults = [];
  List<Map<String, dynamic>> tutorialResults = [];
  Map<String, dynamic> overallStats = {
    'totalAssignments': 0,
    'completedAssignments': 0,
    'totalTutorials': 0,
    'completedTutorials': 0,
    'overallGPA': 0.0,
    'totalCredits': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return;

      setState(() {
        _userData = userData;
      });

      organizationCode = userData['organizationCode'];
      if (organizationCode == null) return;

// Load organization data
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .get();

      if (orgDoc.exists) {
        setState(() {
          _organizationData = orgDoc.data();
        });
      }

// Load all enrolled courses
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('enrollments')
          .where('studentId', isEqualTo: user.uid)
          .get();

      List<Map<String, dynamic>> tempAssignments = [];
      List<Map<String, dynamic>> tempTutorials = [];

      for (var enrollment in enrollmentsSnapshot.docs) {
        final courseRef = enrollment.reference.parent.parent;
        if (courseRef == null) continue;

        final courseDoc = await courseRef.get();
        if (!courseDoc.exists) continue;

        final courseData = courseDoc.data() as Map<String, dynamic>;
        final courseId = courseDoc.id;

        // Load assignments for this course
        await _loadAssignmentResults(
            courseId,
            courseData,
            user.uid,
            tempAssignments
        );

        // Load tutorials for this course
        await _loadTutorialResults(
            courseId,
            courseData,
            user.uid,
            tempTutorials
        );
      }

      // Sort by date (most recent first)
      tempAssignments.sort((a, b) {
        final aTime = a['evaluatedAt'] ?? a['submittedAt'];
        final bTime = b['evaluatedAt'] ?? b['submittedAt'];
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      tempTutorials.sort((a, b) {
        final aTime = a['submittedAt'];
        final bTime = b['submittedAt'];
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      // Calculate overall statistics
      _calculateOverallStats(tempAssignments, tempTutorials);

      setState(() {
        assignmentResults = tempAssignments;
        tutorialResults = tempTutorials;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading report data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadAssignmentResults(
      String courseId,
      Map<String, dynamic> courseData,
      String studentId,
      List<Map<String, dynamic>> results,
      ) async {
    try {
      // Get all assignments for this course
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(courseId)
          .collection('assignments')
          .get();

      for (var assignmentDoc in assignmentsSnapshot.docs) {
        final assignmentData = assignmentDoc.data();
        final assignmentId = assignmentDoc.id;

        // Check if student has submission
        final submissionsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(courseId)
            .collection('assignments')
            .doc(assignmentId)
            .collection('submissions')
            .where('studentId', isEqualTo: studentId)
            .orderBy('submittedAt', descending: true)
            .limit(1)
            .get();

        if (submissionsSnapshot.docs.isEmpty) continue;

        final submissionDoc = submissionsSnapshot.docs.first;
        final submissionData = submissionDoc.data();

        // Check for evaluation
        final evaluationDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(courseId)
            .collection('assignments')
            .doc(assignmentId)
            .collection('submissions')
            .doc(submissionDoc.id)
            .collection('evaluations')
            .doc('current')
            .get();

        Map<String, dynamic>? evaluationData;
        Map<String, dynamic>? rubricData;

        if (evaluationDoc.exists) {
          evaluationData = evaluationDoc.data();

          // Load rubric if used
          if (evaluationData?['rubricUsed'] == true) {
            final rubricDoc = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(organizationCode)
                .collection('courses')
                .doc(courseId)
                .collection('assignments')
                .doc(assignmentId)
                .collection('rubric')
                .doc('main')
                .get();

            if (rubricDoc.exists) {
              rubricData = rubricDoc.data();
            }
          }
        }

        results.add({
          'type': 'assignment',
          'courseId': courseId,
          'courseName': courseData['title'] ?? courseData['name'] ?? 'Unknown Course',
          'courseCode': courseData['code'] ?? '',
          'itemId': assignmentId,
          'itemName': assignmentData['title'] ?? 'Assignment',
          'dueDate': assignmentData['dueDate'],
          'points': assignmentData['points'] ?? 100,
          'submittedAt': submissionData['submittedAt'],
          'isLate': submissionData['isLate'] ?? false,
          'grade': submissionData['grade'] ?? evaluationData?['grade'],
          'letterGrade': submissionData['letterGrade'] ?? evaluationData?['letterGrade'],
          'percentage': submissionData['percentage'] ?? evaluationData?['percentage'],
          'feedback': submissionData['feedback'] ?? evaluationData?['feedback'],
          'evaluatedAt': submissionData['gradedAt'] ?? evaluationData?['evaluatedAt'],
          'rubric': rubricData,
          'criteriaScores': evaluationData?['criteriaScores'],
        });
      }
    } catch (e) {
      print('Error loading assignment results: $e');
    }
  }

  Future<void> _loadTutorialResults(
      String courseId,
      Map<String, dynamic> courseData,
      String studentId,
      List<Map<String, dynamic>> results,
      ) async {
    try {
      // Get all tutorials (materials with type 'tutorial')
      final materialsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(courseId)
          .collection('materials')
          .where('materialType', isEqualTo: 'tutorial')
          .get();

      for (var materialDoc in materialsSnapshot.docs) {
        final materialData = materialDoc.data();
        final materialId = materialDoc.id;

        // Check if student has submission
        final submissionsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(courseId)
            .collection('materials')
            .doc(materialId)
            .collection('submissions')
            .where('studentId', isEqualTo: studentId)
            .orderBy('submittedAt', descending: true)
            .limit(1)
            .get();

        if (submissionsSnapshot.docs.isEmpty) continue;

        final submissionDoc = submissionsSnapshot.docs.first;
        final submissionData = submissionDoc.data();

        // Check for feedback
        Map<String, dynamic>? feedbackData;
        final feedbackDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(courseId)
            .collection('materials')
            .doc(materialId)
            .collection('submissions')
            .doc(submissionDoc.id)
            .collection('feedback')
            .doc('main')
            .get();

        if (feedbackDoc.exists) {
          feedbackData = feedbackDoc.data();
        }

        results.add({
          'type': 'tutorial',
          'courseId': courseId,
          'courseName': courseData['title'] ?? courseData['name'] ?? 'Unknown Course',
          'courseCode': courseData['code'] ?? '',
          'itemId': materialId,
          'itemName': materialData['title'] ?? 'Tutorial',
          'dueDate': materialData['dueDate'],
          'submittedAt': submissionData['submittedAt'],
          'isLate': submissionData['isLate'] ?? false,
          'status': submissionData['status'] ?? 'submitted',
          'comments': submissionData['comments'],
          'feedback': feedbackData,
          'files': submissionData['files'] ?? [],
        });
      }
    } catch (e) {
      print('Error loading tutorial results: $e');
    }
  }

  void _calculateOverallStats(
      List<Map<String, dynamic>> assignments,
      List<Map<String, dynamic>> tutorials,
      ) {
    int totalAssignments = assignments.length;
    int completedAssignments = assignments.where((a) => a['grade'] != null).length;
    int totalTutorials = tutorials.length;
    int completedTutorials = tutorials.where((t) => t['feedback'] != null).length;

    // Calculate GPA (using letter grades)
    double totalGradePoints = 0;
    int totalGradedItems = 0;

    for (var assignment in assignments) {
      if (assignment['letterGrade'] != null) {
        totalGradePoints += _getGradePoint(assignment['letterGrade']);
        totalGradedItems++;
      }
    }

    double gpa = totalGradedItems > 0 ? totalGradePoints / totalGradedItems : 0.0;

    setState(() {
      overallStats = {
        'totalAssignments': totalAssignments,
        'completedAssignments': completedAssignments,
        'totalTutorials': totalTutorials,
        'completedTutorials': completedTutorials,
        'overallGPA': gpa,
        'totalCredits': totalGradedItems,
      };
    });
  }

  double _getGradePoint(String letterGrade) {
    switch (letterGrade) {
      case 'A+': return 4.0;
      case 'A': return 4.0;
      case 'A-': return 3.7;
      case 'B+': return 3.3;
      case 'B': return 3.0;
      case 'B-': return 2.7;
      case 'C+': return 2.3;
      case 'C': return 2.0;
      case 'F': return 0.0;
      default: return 0.0;
    }
  }

  Future<void> _generateAndSharePDF() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      final pdf = pw.Document();

      // Add page to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Academic Transcript',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),

              // Student Info
              pw.Text(
                'Student: ${_userData?['fullName'] ?? 'N/A'}',
                style: pw.TextStyle(fontSize: 16),
              ),
              pw.Text(
                'Organization: ${_organizationData?['name'] ?? 'N/A'}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 20),

              // Overall Statistics
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Academic Performance',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text('GPA: ${overallStats['overallGPA'].toStringAsFixed(2)}'),
                        pw.Text('Assignments: ${overallStats['completedAssignments']}/${overallStats['totalAssignments']}'),
                        pw.Text('Tutorials: ${overallStats['completedTutorials']}/${overallStats['totalTutorials']}'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Assignments Section
              if (assignmentResults.isNotEmpty) ...[
                pw.Text('Assignments',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Course', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Assignment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Grade', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Points', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    // Data rows
                    ...assignmentResults.take(10).map((assignment) => pw.TableRow(
                      children: [
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(assignment['courseCode'] ?? '')),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(assignment['itemName'] ?? '')),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(assignment['letterGrade'] ?? 'N/A')),
                        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${assignment['grade'] ?? 'N/A'}/${assignment['points'] ?? 'N/A'}')),
                      ],
                    )),
                  ],
                ),
              ],

              pw.SizedBox(height: 20),

              // Footer
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Generated on ${DateTime.now().toString().split(' ')[0]}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ];
          },
        ),
      );

      // Close loading dialog
      Navigator.pop(context);

      // Save PDF to device first
      final output = await getApplicationDocumentsDirectory();
      final file = File("${output.path}/academic_transcript_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());

      // Show options dialog instead of directly sharing
      _showPDFOptionsDialog(file);

    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPDFOptionsDialog(File pdfFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.purple[600], size: 28),
              SizedBox(width: 12),
              Text('PDF Generated', style: TextStyle(fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your academic transcript has been generated successfully.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'What would you like to do?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            Column(
              children: [
                // Download button
                // Download button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _downloadAndOpenPDF(pdfFile);
                    },
                    icon: Icon(Icons.download),
                    label: Text('Download & Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // Share button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Share.shareXFiles([XFile(pdfFile.path)], text: 'Academic Transcript');
                    },
                    icon: Icon(Icons.share),
                    label: Text('Share Only'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // Download and Share button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      // First download
                      await _downloadPDFFromFile(pdfFile);
                      // Then share
                      await Share.shareXFiles([XFile(pdfFile.path)], text: 'Academic Transcript');
                    },
                    icon: Icon(Icons.download_done),
                    label: Text('Download & Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadPDFFromFile(File sourceFile) async {
    try {
      // Request storage permission first
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), use different permission
        PermissionStatus status;
        if (await Permission.manageExternalStorage.isGranted) {
          status = PermissionStatus.granted;
        } else if (await Permission.storage.isGranted) {
          status = PermissionStatus.granted;
        } else {
          // Try requesting storage permission
          status = await Permission.storage.request();
          if (!status.isGranted) {
            // For Android 13+, try manage external storage
            status = await Permission.manageExternalStorage.request();
          }
        }

        if (!status.isGranted) {
          throw Exception('Storage permission denied');
        }
      }

      // For Android, save to public Downloads folder
      Directory? directory;
      if (Platform.isAndroid) {
        // This gets the public Downloads directory
        directory = Directory('/storage/emulated/0/Download');
        // Check if it exists, if not try alternative path
        if (!await directory.exists()) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            directory = Directory('${externalDir.path.split('Android')[0]}Download');
          }
        }
      } else {
        // For iOS, use documents directory
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Cannot access storage');
      }

      final downloadFile = File("${directory.path}/academic_transcript_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await sourceFile.copy(downloadFile.path);

      // Debug: Print the file path and check if file exists
      print('PDF saved at: ${downloadFile.path}');
      print('File exists: ${await downloadFile.exists()}');
      print('File size: ${await downloadFile.length()} bytes');

      // Show success message and directly open PDF
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF download successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );

      // Instead of using OpenFile, use Share to handle the PDF
      await Share.shareXFiles(
        [XFile(downloadFile.path)],
        text: 'Academic Transcript - Saved to Downloads',
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadAndOpenPDF(File sourceFile) async {
    try {
      // Use getApplicationDocumentsDirectory for better compatibility
      final directory = await getApplicationDocumentsDirectory();

      final downloadFile = File("${directory.path}/academic_transcript_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await sourceFile.copy(downloadFile.path);

      // Debug: Print the file path and check if file exists
      print('PDF saved at: ${downloadFile.path}');
      print('File exists: ${await downloadFile.exists()}');
      print('File size: ${await downloadFile.length()} bytes');

      // Show success message with Open button
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF downloaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () async {
              await _openPDFFile(downloadFile.path);
            },
          ),
        ),
      );

      // Try to automatically open the PDF file
      try {
        final result = await OpenFile.open(downloadFile.path);
        if (result.type != ResultType.done) {
          print('Auto-open failed: ${result.message}');
          // Don't show error immediately, user can use the Open button
        }
      } catch (e) {
        print('Auto-open error: $e');
        // Don't show error immediately, user can use the Open button
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openPDFFile(String filePath) async {
    try {
      // Use Share instead of OpenFile
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Academic Transcript',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOpenPDFDialog(File pdfFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Open PDF?'),
          content: Text('Would you like to open the downloaded PDF?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final result = await OpenFile.open(pdfFile.path);
                  if (result.type != ResultType.done) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cannot open PDF: ${result.message}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error opening PDF: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Open'),
            ),
          ],
        );
      },
    );
  }

  void _showPDFPreview(File pdfFile) {
    TextEditingController _nameController = TextEditingController(
        text: 'academic_transcript_${_userData?['fullName']?.replaceAll(' ', '_') ?? 'student'}'
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.all(10),
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.purple[600]),
                      SizedBox(width: 8),
                      Text(
                        'PDF Ready',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // PDF Name Input
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Name:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixText: '.pdf',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),

                // PDF Preview Section
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        // Preview Header
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.preview, color: Colors.purple[600], size: 16),
                              SizedBox(width: 8),
                              Text(
                                'PDF Preview',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Simulated PDF Content Preview
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Document Title
                                Center(
                                  child: Text(
                                    'Academic Transcript',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),

                                // Student Info Preview
                                Text(
                                  'Student: ${_userData?['fullName'] ?? 'N/A'}',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Organization: ${_organizationData?['name'] ?? 'N/A'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                SizedBox(height: 16),

                                // Academic Performance Preview
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Academic Performance',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'GPA: ${overallStats['overallGPA'].toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              'Assignments: ${overallStats['completedAssignments']}/${overallStats['totalAssignments']}',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Center(
                                        child: Text(
                                          'Tutorials: ${overallStats['completedTutorials']}/${overallStats['totalTutorials']}',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),

                                // Assignments Table Preview
                                if (assignmentResults.isNotEmpty) ...[
                                  Text(
                                    'Assignments',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Column(
                                      children: [
                                        // Table Header
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(4),
                                              topRight: Radius.circular(4),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(child: Text('Course', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                              Expanded(child: Text('Assignment', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                              Expanded(child: Text('Grade', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                            ],
                                          ),
                                        ),
                                        // Sample Rows
                                        ...assignmentResults.take(5).map((assignment) => Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            border: Border(top: BorderSide(color: Colors.grey[300]!)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(child: Text(assignment['courseCode'] ?? '', style: TextStyle(fontSize: 9))),
                                              Expanded(child: Text(assignment['itemName'] ?? '', style: TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis)),
                                              Expanded(child: Text(assignment['letterGrade'] ?? 'N/A', style: TextStyle(fontSize: 9))),
                                            ],
                                          ),
                                        )),
                                        if (assignmentResults.length > 5)
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            child: Text(
                                              '... and ${assignmentResults.length - 5} more assignments',
                                              style: TextStyle(fontSize: 9, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],

                                SizedBox(height: 20),

                                // Ready indicator
                                Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'PDF Ready',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _downloadPDFWithName(pdfFile, _nameController.text);
                          },
                          icon: Icon(Icons.download),
                          label: Text('Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _sharePDFWithName(pdfFile, _nameController.text);
                          },
                          icon: Icon(Icons.share),
                          label: Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadPDFWithName(File sourceFile, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadFile = File("${directory.path}/${fileName}.pdf");
      await sourceFile.copy(downloadFile.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF downloaded as ${fileName}.pdf'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () async {
              await Share.shareXFiles([XFile(downloadFile.path)], text: 'Academic Transcript');
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sharePDFWithName(File sourceFile, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final shareFile = File("${directory.path}/${fileName}.pdf");
      await sourceFile.copy(shareFile.path);

      await Share.shareXFiles([XFile(shareFile.path)], text: 'Academic Transcript');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing PDF: $e'),
          backgroundColor: Colors.red,
        ),
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Report',
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
            icon: Icon(Icons.picture_as_pdf, color: Colors.purple[600]),
            onPressed: () async {
              try {
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(child: CircularProgressIndicator()),
                );

                final pdf = pw.Document();

                // Add page to PDF (using existing PDF generation code)
                pdf.addPage(
                  pw.MultiPage(
                    pageFormat: PdfPageFormat.a4,
                    margin: pw.EdgeInsets.all(32),
                    build: (pw.Context context) {
                      return [
                        // Header
                        pw.Header(
                          level: 0,
                          child: pw.Text(
                            'Academic Transcript',
                            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.SizedBox(height: 20),

                        // Student Info
                        pw.Text(
                          'Student: ${_userData?['fullName'] ?? 'N/A'}',
                          style: pw.TextStyle(fontSize: 16),
                        ),
                        pw.Text(
                          'Organization: ${_organizationData?['name'] ?? 'N/A'}',
                          style: pw.TextStyle(fontSize: 14),
                        ),
                        pw.SizedBox(height: 20),

                        // Overall Statistics
                        pw.Container(
                          padding: pw.EdgeInsets.all(16),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Academic Performance',
                                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 10),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                                children: [
                                  pw.Text('GPA: ${overallStats['overallGPA'].toStringAsFixed(2)}'),
                                  pw.Text('Assignments: ${overallStats['completedAssignments']}/${overallStats['totalAssignments']}'),
                                  pw.Text('Tutorials: ${overallStats['completedTutorials']}/${overallStats['totalTutorials']}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 30),

                        // Assignments Section
                        if (assignmentResults.isNotEmpty) ...[
                          pw.Text('Assignments',
                              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Table(
                            border: pw.TableBorder.all(),
                            children: [
                              // Header
                              pw.TableRow(
                                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                                children: [
                                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Course', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Assignment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Grade', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Points', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                ],
                              ),
                              // Data rows
                              ...assignmentResults.take(10).map((assignment) => pw.TableRow(
                                children: [
                                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(assignment['courseCode'] ?? '')),
                                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(assignment['itemName'] ?? '')),
                                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(assignment['letterGrade'] ?? 'N/A')),
                                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${assignment['grade'] ?? 'N/A'}/${assignment['points'] ?? 'N/A'}')),
                                ],
                              )),
                            ],
                          ),
                        ],

                        pw.SizedBox(height: 20),

                        // Footer
                        pw.Align(
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            'Generated on ${DateTime.now().toString().split(' ')[0]}',
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                          ),
                        ),
                      ];
                    },
                  ),
                );

                // Close loading dialog
                Navigator.pop(context);

                // Save PDF to device
                final output = await getApplicationDocumentsDirectory();
                final file = File("${output.path}/academic_transcript_${DateTime.now().millisecondsSinceEpoch}.pdf");
                await file.writeAsBytes(await pdf.save());

                // Show PDF preview with rename option
                _showPDFPreview(file);

              } catch (e) {
                // Close loading dialog if open
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error generating PDF: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            tooltip: 'Generate PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          // Overall Statistics Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[600]!, Colors.purple[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.assessment, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'Academic Performance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'GPA',
                      overallStats['overallGPA'].toStringAsFixed(2),
                      Colors.white,
                    ),
                    _buildStatItem(
                      'Assignments',
                      '${overallStats['completedAssignments']}/${overallStats['totalAssignments']}',
                      Colors.white,
                    ),
                    _buildStatItem(
                      'Tutorials',
                      '${overallStats['completedTutorials']}/${overallStats['totalTutorials']}',
                      Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Bar
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
              indicatorColor: Colors.purple[400],
              indicatorWeight: 3,
              labelColor: Colors.purple[600],
              unselectedLabelColor: Colors.grey[600],
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Assignments'),
                Tab(text: 'Tutorials'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAssignmentsTab(),
                _buildTutorialsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsTab() {
    if (assignmentResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No assignment results yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: assignmentResults.length,
      itemBuilder: (context, index) {
        return _buildAssignmentResultCard(assignmentResults[index]);
      },
    );
  }

  Widget _buildAssignmentResultCard(Map<String, dynamic> result) {
    final hasGrade = result['grade'] != null;
    final grade = result['grade'];
    final letterGrade = result['letterGrade'];
    final maxPoints = result['points'];
    final percentage = result['percentage'] ??
        (hasGrade ? ((grade / maxPoints) * 100) : null);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: hasGrade ? () => _showAssignmentDetails(result) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course and Assignment Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result['courseCode'] + ' - ' + result['courseName'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          result['itemName'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasGrade) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getGradeColor(letterGrade ?? ''),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            letterGrade ?? _calculateLetterGrade(percentage ?? 0),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$grade/$maxPoints',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12),

              // Submission Info
              // Submission Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    'Due: ${_formatDate(result['dueDate'])}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.upload_file, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            'Submitted: ${_formatDate(result['submittedAt'])}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (result['isLate'] == true) ...[
                        SizedBox(height: 2),
                        Container(
                          margin: EdgeInsets.only(left: 18), // Align with submitted text
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'LATE',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // Percentage Bar (if graded)
              if (hasGrade && percentage != null) ...[
                SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Score',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getGradeColor(letterGrade ?? ''),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getGradeColor(letterGrade ?? ''),
                      ),
                    ),
                  ],
                ),
              ],

              // View Details (if graded with rubric)
              if (hasGrade && result['rubric'] != null) ...[
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showAssignmentDetails(result),
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('View Details'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.purple[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialsTab() {
    if (tutorialResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No tutorial submissions yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: tutorialResults.length,
      itemBuilder: (context, index) {
        return _buildTutorialResultCard(tutorialResults[index]);
      },
    );
  }

  Widget _buildTutorialResultCard(Map<String, dynamic> result) {
    final hasFeedback = result['feedback'] != null;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course and Tutorial Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['courseCode'] + ' - ' + result['courseName'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        result['itemName'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasFeedback ? Colors.green[100] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasFeedback ? 'Reviewed' : 'Submitted',
                    style: TextStyle(
                      color: hasFeedback ? Colors.green[700] : Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Submission Info
            Row(
              children: [
                if (result['dueDate'] != null) ...[
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    'Due: ${_formatDate(result['dueDate'])}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 16),
                ],
                Icon(Icons.upload_file, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Submitted: ${_formatDate(result['submittedAt'])}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (result['isLate'] == true) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'LATE',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Files submitted
            if (result['files'] != null && (result['files'] as List).isNotEmpty) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attachment, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    '${(result['files'] as List).length} file(s) submitted',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],

            // Student Comments
            if (result['comments'] != null && result['comments'].toString().isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Comments:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      result['comments'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Lecturer Feedback
            if (hasFeedback) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, size: 14, color: Colors.blue[700]),
                        SizedBox(width: 4),
                        Text(
                          'Lecturer Feedback:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      result['feedback']['comment'] ?? 'No comment',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAssignmentDetails(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                border: Border(
                  bottom: BorderSide(color: Colors.purple[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result['itemName'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          result['courseCode'] + ' - ' + result['courseName'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grade Summary
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Grade',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                result['letterGrade'] ?? _calculateLetterGrade(
                                    ((result['grade'] ?? 0) / (result['points'] ?? 100)) * 100
                                ),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _getGradeColor(result['letterGrade'] ?? ''),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Points',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${result['grade']}/${result['points']}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Percentage',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${(((result['grade'] ?? 0) / (result['points'] ?? 100)) * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Feedback
                    if (result['feedback'] != null) ...[
                      SizedBox(height: 20),
                      Text(
                        'Instructor Feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          result['feedback'] ?? 'No feedback provided',
                          style: TextStyle(
                            color: Colors.blue[900],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    // Rubric Details
                    if (result['rubric'] != null && result['criteriaScores'] != null) ...[
                      SizedBox(height: 20),
                      Text(
                        'Rubric Evaluation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      ..._buildRubricDetails(result['rubric'], result['criteriaScores']),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRubricDetails(
      Map<String, dynamic> rubric,
      Map<String, dynamic> criteriaScores,
      ) {
    final criteria = rubric['criteria'] as List;
    List<Widget> widgets = [];

    for (var criterion in criteria) {
      final criterionId = criterion['id'];
      final score = criteriaScores[criterionId];

      if (score == null) continue;

      widgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          criterion['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (criterion['description'] != null) ...[
                          SizedBox(height: 4),
                          Text(
                            criterion['description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple[400],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${score['points']} pts',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Weight: ${criterion['weight']}%',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.purple[600], size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Level: ${score['levelId']}',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Color _getGradeColor(String? letterGrade) {
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

  String _calculateLetterGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 75) return 'A-';
    if (percentage >= 70) return 'B+';
    if (percentage >= 65) return 'B';
    if (percentage >= 60) return 'B-';
    if (percentage >= 55) return 'C+';
    if (percentage >= 50) return 'C';
    return 'F';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'N/A';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}