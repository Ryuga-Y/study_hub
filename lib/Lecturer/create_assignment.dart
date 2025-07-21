import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Authentication/custom_widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:async';
import '../notification.dart';


// Enum definitions
enum EventType { normal, recurring, holiday }
enum RecurrenceType { none, daily, weekly, monthly, yearly }

// NotificationService class for centralized notification management
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // MERGED: Create notification for new items with integrated calendar creation
  Future<void> createNewItemNotification({
    required String itemType,
    required String itemTitle,
    required DateTime dueDate,
    required String sourceId,
    String? courseId,
    String? courseName,
    String? organizationCode,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get organization code if not provided
      String? orgCode = organizationCode;
      if (orgCode == null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        orgCode = userDoc.data()?['organizationCode'];
      }

      if (orgCode == null) {
        throw Exception('Organization code not found');
      }

      // Get enrolled students if this is a course-related item
      if (courseId != null) {
        final enrollmentsSnapshot = await _firestore
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(courseId)
            .collection('enrollments')
            .get();

        // Create notifications for all enrolled students
        for (var enrollment in enrollmentsSnapshot.docs) {
          final studentId = enrollment.data()['studentId'];

          await _createStudentNotification(
            organizationCode: orgCode,
            studentId: studentId,
            itemType: itemType,
            itemTitle: itemTitle,
            sourceId: sourceId,
            courseId: courseId,
            courseName: courseName,
          );
        }
      } else {
        // For personal items (like goals), create notification for current user
        await _createStudentNotification(
          organizationCode: orgCode,
          studentId: currentUser.uid,
          itemType: itemType,
          itemTitle: itemTitle,
          sourceId: sourceId,
        );
      }

      print('✅ Created notifications for $itemType: $itemTitle');

      // MERGED: Create calendar events after notifications
      if (courseId != null) {
        await createCalendarEventsForEnrolledStudents(
          sourceId: sourceId,
          itemTitle: itemTitle,
          dueDate: dueDate,
          itemType: itemType,
          courseId: courseId,
          organizationCode: orgCode,
        );
      }
    } catch (e) {
      print('Error creating notifications: $e');
    }
  }

  // Helper method to create individual student notification
  Future<void> _createStudentNotification({
    required String organizationCode,
    required String studentId,
    required String itemType,
    required String itemTitle,
    required String sourceId,
    String? courseId,
    String? courseName,
  }) async {
    // Determine notification title and body based on item type
    String notificationTitle;
    String notificationBody;

    switch (itemType.toLowerCase()) {
      case 'assignment':
        notificationTitle = '📝 New Assignment Posted';
        notificationBody = courseName != null
            ? '$itemTitle has been posted in $courseName'
            : '$itemTitle assignment has been posted';
        break;
      case 'tutorial':
        notificationTitle = '📚 New Tutorial Posted';
        notificationBody = courseName != null
            ? '$itemTitle has been posted in $courseName'
            : '$itemTitle tutorial has been posted';
        break;
      case 'learning':
        notificationTitle = '📖 New Learning Material Posted';
        notificationBody = courseName != null
            ? '$itemTitle has been posted in $courseName'
            : '$itemTitle learning material has been posted';
        break;
      default:
        notificationTitle = '📢 New Item Posted';
        notificationBody = '$itemTitle has been posted';
    }

    // NEW CODE in _createStudentNotification method
    // FIXED: Include all required fields for notification navigation
    await _firestore
        .collection('organizations')
        .doc(organizationCode)
        .collection('students')
        .doc(studentId)
        .collection('notifications')
        .add({
      'title': notificationTitle,
      'body': notificationBody,
      'type': 'NotificationType.$itemType',
      'sourceId': sourceId,
      'sourceType': itemType,
      'courseId': courseId,
      'courseName': courseName,
      'organizationCode': organizationCode,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // Method to create calendar events for enrolled students
  Future<void> createCalendarEventsForEnrolledStudents({
    required String sourceId,
    required String itemTitle,
    required DateTime dueDate,
    required String itemType,
    required String courseId,
    String? organizationCode,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get organization code if not provided
      String? orgCode = organizationCode;
      if (orgCode == null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        orgCode = userDoc.data()?['organizationCode'];
      }

      if (orgCode == null) return;

      final enrollmentsSnapshot = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('enrollments')
          .get();

      for (var enrollment in enrollmentsSnapshot.docs) {
        final studentId = enrollment.data()['studentId'];

        final calendarEventRef = await _firestore
            .collection('organizations')
            .doc(orgCode)
            .collection('students')
            .doc(studentId)
            .collection('calendar_events')
            .add({
          'title': _getCalendarEventTitle(itemType, itemTitle),
          'description': _getCalendarEventDescription(itemType),
          'startTime': Timestamp.fromDate(dueDate),
          'endTime': Timestamp.fromDate(dueDate),
          'color': _getCalendarEventColor(itemType),
          'calendar': _getCalendarCategory(itemType),
          'eventType': EventType.normal.index,
          'recurrenceType': RecurrenceType.none.index,
          'reminderMinutes': [1440, 10], // Both 24 hours and 10 minutes before
          'location': '',
          'isRecurring': false,
          'originalEventId': '',
          'sourceId': sourceId,
          'sourceType': itemType,
          'courseId': courseId,
          'createdAt': FieldValue.serverTimestamp(),
          'reminderScheduled': false, // Track if reminders have been scheduled
        });

// Schedule initial reminder check for this event
        final eventData = {
          'title': _getCalendarEventTitle(itemType, itemTitle),
          'startTime': Timestamp.fromDate(dueDate),
          'sourceId': sourceId,
          'sourceType': itemType,
          'courseId': courseId,
        };

// Trigger reminder check (this will be handled by the deadline checker)
        print('📅 Calendar event created, reminders will be scheduled automatically');
      }

      print('✅ Created calendar events for $itemType: $itemTitle');
    } catch (e) {
      print('Error creating calendar events: $e');
    }
  }

  String _getCalendarEventTitle(String itemType, String itemTitle) {
    switch (itemType.toLowerCase()) {
      case 'assignment':
        return itemTitle; // Changed from '📝 Assignment: $itemTitle Due'
      case 'tutorial':
        return itemTitle; // Changed from '📚 Tutorial: $itemTitle Due'
      case 'goal':
        return itemTitle; // Changed from '🎯 Goal: $itemTitle Due'
      default:
        return itemTitle; // Changed from '📅 $itemTitle Due'
    }
  }

  String _getCalendarEventDescription(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'assignment':
        return 'Assignment deadline';
      case 'tutorial':
        return 'Tutorial deadline';
      case 'goal':
        return 'Goal deadline';
      default:
        return 'Item deadline';
    }
  }

  // Change the return type from Object to int
  int _getCalendarEventColor(String itemType) {  // Change Object to int
    switch (itemType.toLowerCase()) {
      case 'assignment':
        return Colors.red.value;     // Add .value
      case 'tutorial':
        return Colors.red.value;     // Add .value
      case 'goal':
        return Colors.green.value;   // Add .value
      default:
        return Colors.purple.value;  // Add .value
    }
  }

  String _getCalendarCategory(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'assignment':
        return 'assignments';
      case 'tutorial':
        return 'tutorials';
      case 'goal':
        return 'goals';
      default:
        return 'general';
    }
  }
}

class CreateAssignmentPage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final bool editMode;
  final String? assignmentId;
  final Map<String, dynamic>? assignmentData;

  const CreateAssignmentPage({
    Key? key,
    required this.courseId,
    required this.courseData,
    this.editMode = false,
    this.assignmentId,
    this.assignmentData,
  }) : super(key: key);

  @override
  _CreateAssignmentPageState createState() => _CreateAssignmentPageState();
}

class _CreateAssignmentPageState extends State<CreateAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _isLoading = false;
  List<PlatformFile> _selectedFiles = [];
  List<Map<String, dynamic>> _existingFiles = [];
  double _uploadProgress = 0;
  String _uploadStatus = '';
  StreamSubscription? _uploadSubscription;
  StreamSubscription? _eventsSubscription; // Added for events listener

  // Initialize NotificationService
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();

    // If in edit mode, populate the fields with existing data
    if (widget.editMode && widget.assignmentData != null) {
      _titleController.text = widget.assignmentData!['title'] ?? '';
      _descriptionController.text = widget.assignmentData!['description'] ?? '';
      _pointsController.text = (widget.assignmentData!['points'] ?? 0).toString();

      // Set due date if exists
      if (widget.assignmentData!['dueDate'] != null) {
        final dueDateTime = (widget.assignmentData!['dueDate'] as Timestamp).toDate();
        _dueDate = DateTime(dueDateTime.year, dueDateTime.month, dueDateTime.day);
        _dueTime = TimeOfDay(hour: dueDateTime.hour, minute: dueDateTime.minute);
      }

      // Handle existing attachments
      if (widget.assignmentData!['attachments'] != null &&
          widget.assignmentData!['attachments'] is List &&
          (widget.assignmentData!['attachments'] as List).isNotEmpty) {
        _existingFiles = List<Map<String, dynamic>>.from(
          (widget.assignmentData!['attachments'] as List).map((attachment) => {
            'url': attachment['url'] ?? '',
            'name': attachment['name'] ?? 'Unknown file',
            'size': attachment['size'] is int ? attachment['size'] : int.tryParse(attachment['size']?.toString() ?? '0') ?? 0,
            'uploadedAt': attachment['uploadedAt'] ?? Timestamp.now(),
            'storagePath': attachment['storagePath'] ?? '',
          }),
        );
      }
    }

    // MERGED: Start events listener when page initializes
    _startEventsListener();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _uploadSubscription?.cancel();
    _eventsSubscription?.cancel(); // Cancel events subscription
    super.dispose();
  }

  // MERGED: Real-time events listener method from document 1
  void _startEventsListener() {
    final user = FirebaseAuth.instance.currentUser; // Updated to use FirebaseAuth.instance
    if (user == null) {
      print('❌ No user found');
      setState(() => _isLoading = false);
      return;
    }

    // Get user data to retrieve organization code
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((userDoc) {
      if (!userDoc.exists) {
        print('❌ No user data found');
        setState(() => _isLoading = false);
        return;
      }

      final userData = userDoc.data();
      if (userData == null) {
        print('❌ No user data found');
        setState(() => _isLoading = false);
        return;
      }

      final orgCode = userData['organizationCode'];
      if (orgCode == null) {
        print('❌ No organization code found');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Starting real-time event listener for user: ${user.uid}, org: $orgCode');
      print('📍 Path: organizations/$orgCode/students/${user.uid}/calendar_events');

      // Set up real-time listener for calendar events
      _eventsSubscription = FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .snapshots()
          .listen(
            (snapshot) {
          print('📅 Calendar events updated: ${snapshot.docs.length} events');
          // Handle real-time updates here if needed
          // For example, you could update UI state or show notifications
        },
        onError: (error) {
          print('❌ Error listening to calendar events: $error');
        },
      );
    }).catchError((error) {
      print('❌ Error getting user data: $error');
      setState(() => _isLoading = false);
    });
  }

  Future<void> _selectFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png', 'zip', 'xls', 'xlsx'],
        withData: true, // Important for web
        withReadStream: false,
      );

      if (result != null) {
        List<PlatformFile> validFiles = [];

        for (var file in result.files) {
          // Check file size
          if (file.size > 10 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${file.name} exceeds 10MB limit'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            continue;
          }

          // Ensure we have bytes data
          if (kIsWeb) {
            if (file.bytes == null) {
              continue;
            }
          } else if (file.bytes == null && file.path != null) {
            // For mobile, read bytes from path
            try {
              final fileBytes = await File(file.path!).readAsBytes();
              file = PlatformFile(
                name: file.name,
                size: file.size,
                bytes: fileBytes,
                path: file.path,
              );
            } catch (e) {
              continue;
            }
          }

          validFiles.add(file);
        }

        if (mounted) {
          setState(() {
            _selectedFiles = validFiles;
          });

          if (validFiles.isEmpty && result.files.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No valid files selected. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _uploadFiles() async {
    List<Map<String, dynamic>> uploadedFilesList = [];

    // Verify authentication
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User must be authenticated to upload files');
    }

    for (int i = 0; i < _selectedFiles.length; i++) {
      final file = _selectedFiles[i];

      if (file.bytes != null) {
        try {
          if (mounted) {
            setState(() {
              _uploadStatus = 'Uploading ${file.name}...';
            });
          }

          // Create a unique file name
          String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          String storagePath = 'assignments/${widget.courseId}/$fileName';

          // Create file reference
          final ref = FirebaseStorage.instance.ref().child(storagePath);

          // Set metadata
          final metadata = SettableMetadata(
            contentType: _getContentType(file.extension ?? ''),
            customMetadata: {
              'uploadedBy': currentUser.uid,
              'originalName': file.name,
              'courseId': widget.courseId,
              'type': 'assignment_attachment',
            },
          );

          // Upload file with metadata
          final uploadTask = ref.putData(file.bytes!, metadata);

          // Monitor upload progress
          _uploadSubscription?.cancel();
          _uploadSubscription = uploadTask.snapshotEvents.listen(
                (TaskSnapshot snapshot) {
              if (mounted) {
                setState(() {
                  _uploadProgress = (i + snapshot.bytesTransferred / snapshot.totalBytes) / _selectedFiles.length;
                });
              }
            },
            onError: (error) {
              // Handle error silently
            },
          );

          // Wait for upload to complete
          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();

          // Add to uploaded files list
          uploadedFilesList.add({
            'url': downloadUrl,
            'name': file.name,
            'size': file.size,
            'uploadedAt': Timestamp.now(),
            'storagePath': ref.fullPath,
          });

        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload ${file.name}: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          throw Exception('Failed to upload ${file.name}: $e');
        }
      }
    }

    return uploadedFilesList;
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

  // MERGED: Simplified save assignment method using NotificationService
  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a due date for the assignment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
      _uploadStatus = '';
    });

    try {
      // Upload new files if any
      List<Map<String, dynamic>> newlyUploadedFiles = [];
      if (_selectedFiles.isNotEmpty) {
        newlyUploadedFiles = await _uploadFiles();
      }

      // Combine existing and new files
      final List<Map<String, dynamic>> allFiles = [
        ..._existingFiles,
        ...newlyUploadedFiles,
      ];

      // Prepare due date time
      final dueDateTime = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        _dueTime?.hour ?? 23,
        _dueTime?.minute ?? 59,
      );

      // Get organization code - ADD NULL CHECK
      final organizationCode = widget.courseData['organizationCode'];
      if (organizationCode == null || organizationCode.isEmpty) {
        print('❌ Organization code is null or empty in courseData');
        throw Exception('Organization code not found in course data');
      }

      // Prepare assignment data
      final assignmentData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'points': int.tryParse(_pointsController.text.trim()) ?? 0,
        'dueDate': Timestamp.fromDate(dueDateTime),
        'courseId': widget.courseId,
        'courseName': widget.courseData['title'] ?? widget.courseData['name'],
        'courseCode': widget.courseData['code'] ?? '',
        'lecturerId': FirebaseAuth.instance.currentUser?.uid,
        'lecturerName': widget.courseData['lecturerName'],
        'updatedAt': FieldValue.serverTimestamp(),
        'attachments': allFiles.map((file) => {
          'url': file['url'],
          'name': file['name'],
          'size': file['size'],
          'uploadedAt': file['uploadedAt'],
          'storagePath': file['storagePath'] ?? '',
        }).toList(),
      };

      // If creating new assignment, add creation fields
      if (!widget.editMode) {
        assignmentData['createdAt'] = FieldValue.serverTimestamp();
        assignmentData['submissionCount'] = 0;
        assignmentData['isActive'] = true;
      }

      // Save or update assignment in Firestore
      String? assignmentId;
      if (widget.editMode && widget.assignmentId != null) {
        // Update existing assignment
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .update(assignmentData);

        assignmentId = widget.assignmentId;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assignment updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new assignment
        final docRef = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .add(assignmentData);

        assignmentId = docRef.id;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assignment created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // MERGED: Use NotificationService for both notifications and calendar events
      // This single call handles everything: notifications + calendar events with RED color for assignments
      await _notificationService.createNewItemNotification(
        itemType: 'assignment', // or 'tutorial'
        itemTitle: _titleController.text.trim(),
        dueDate: dueDateTime,
        sourceId: assignmentId!,
        courseId: widget.courseId,
        courseName: widget.courseData['title'] ?? widget.courseData['name'],
        organizationCode: organizationCode,
      );

      print('✅ Created notification for assignment: ${_titleController.text.trim()}');

      // Navigate back
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${widget.editMode ? 'updating' : 'creating'} assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<void> _selectDueDate() async {
    // Determine the first selectable date based on edit mode
    DateTime firstSelectableDate;

    if (widget.editMode && _dueDate != null) {
      // In edit mode, allow selecting from the original due date or 1 year ago, whichever is earlier
      firstSelectableDate = _dueDate!.isBefore(DateTime.now().subtract(Duration(days: 365)))
          ? _dueDate!
          : DateTime.now().subtract(Duration(days: 365));
    } else {
      // For new assignments, only allow future dates
      firstSelectableDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(Duration(days: 7)),
      firstDate: firstSelectableDate,
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _selectDueTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay(hour: 23, minute: 59),
    );

    if (picked != null && mounted) {
      setState(() {
        _dueTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.editMode ? 'Edit Assignment' : 'Create Assignment',
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Info Card
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.library_books, color: Colors.purple[600], size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.courseData['title'] ?? widget.courseData['name'] ?? 'Course',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.purple[800],
                            ),
                          ),
                          Text(
                            widget.courseData['code'] ?? '',
                            style: TextStyle(
                              color: Colors.purple[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Assignment Type Info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.assignment, color: Colors.orange[700], size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.editMode ? 'Edit Assignment' : 'Assignment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.orange[700],
                            ),
                          ),
                          Text(
                            widget.editMode
                                ? 'Update the assignment details below'
                                : 'Students must submit their work before the due date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Assignment Details Card
              Container(
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
                    Text(
                      'Assignment Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[600],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g., Assignment 1: Data Structures',
                        prefixIcon: Icon(Icons.title, color: Colors.purple[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.purple[400]!, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Brief description of the assignment',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.description, color: Colors.purple[400]),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.purple[400]!, width: 2),
                        ),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Points
                    TextFormField(
                      controller: _pointsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Points',
                        hintText: '100',
                        prefixIcon: Icon(Icons.grade, color: Colors.purple[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.purple[400]!, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter points';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Due Date and Time
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDueDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Due Date',
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.purple[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _dueDate == null
                                    ? 'Select date'
                                    : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _dueDate == null ? Colors.grey[600] : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _selectDueTime,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Due Time',
                                prefixIcon: Icon(Icons.access_time, color: Colors.purple[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _dueTime == null
                                    ? '11:59 PM'
                                    : _dueTime!.format(context),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // File Upload Section
              Container(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reference Materials',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[600],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _selectFiles,
                          icon: Icon(Icons.attach_file),
                          label: Text('Add Files'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.purple[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Optional: Attach reference materials or examples (Max 10MB per file)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Existing Files (if in edit mode)
                    if (widget.editMode && _existingFiles.isNotEmpty) ...[
                      Text(
                        'Existing Files',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      ..._existingFiles.map((file) => Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getFileIcon(file['name'] ?? ''),
                              color: Colors.blue[600],
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file['name'] ?? 'File',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Existing file',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  _existingFiles.remove(file);
                                });
                              },
                              color: Colors.red[400],
                            ),
                          ],
                        ),
                      )).toList(),
                      if (_selectedFiles.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          'New Files to Upload',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                    ],

                    // Selected Files List
                    if (_selectedFiles.isEmpty && _existingFiles.isEmpty)
                      Container(
                        padding: EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No files attached',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_selectedFiles.isNotEmpty)
                      ...(_selectedFiles.map((file) => Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getFileIcon(file.extension ?? ''),
                              color: Colors.purple[400],
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _formatFileSize(file.size),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  _selectedFiles.remove(file);
                                });
                              },
                              color: Colors.red[400],
                            ),
                          ],
                        ),
                      ))),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Upload Progress
              if (_isLoading && (_uploadProgress > 0 || _uploadStatus.isNotEmpty))
                Container(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _uploadStatus.isNotEmpty ? _uploadStatus : 'Processing...',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_uploadProgress > 0) ...[
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              SizedBox(height: 32),

              // Create/Update Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _isLoading
                      ? (widget.editMode ? 'Updating...' : 'Creating...')
                      : (widget.editMode ? 'Update Assignment' : 'Create Assignment'),
                  onPressed: _isLoading ? () {} : _saveAssignment,
                  isLoading: _isLoading,
                ),
              ),
              SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.purple[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.purple[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    // Check if extension contains the file name
    String ext = extension.toLowerCase();
    if (ext.contains('.')) {
      ext = ext.split('.').last;
    }

    switch (ext) {
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
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}