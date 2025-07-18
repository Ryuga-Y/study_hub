import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Authentication/custom_widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:async';

// Add these enums if they don't exist in your project
enum EventType { normal, recurring, holiday }
enum RecurrenceType { none, daily, weekly, monthly, yearly }

// NotificationService class for centralized notification management
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create notification for new items (assignments, materials, etc.)
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
        print('❌ User not authenticated for notification creation');
        throw Exception('User not authenticated');
      }

      // Get organization code if not provided
      String? orgCode = organizationCode;
      if (orgCode == null) {
        print('🔍 Fetching organization code for user: ${currentUser.uid}');
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        orgCode = userDoc.data()?['organizationCode'];
      }

      if (orgCode == null) {
        print('❌ Organization code not found');
        throw Exception('Organization code not found');
      }

      print('✅ Starting notification creation for $itemType: $itemTitle');
      print('📍 Organization: $orgCode');

      // Get enrolled students if this is a course-related item
      if (courseId != null) {
        print('🔍 Fetching enrolled students for course: $courseId');
        final enrollmentsSnapshot = await _firestore
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(courseId)
            .collection('enrollments')
            .get();

        print('📊 Found ${enrollmentsSnapshot.docs.length} enrolled students');

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
        print('📝 Creating personal notification for user: ${currentUser.uid}');
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
      print('❌ Error creating notifications: $e');
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
      case 'goal':
        notificationTitle = '🎯 New Goal Created';
        notificationBody = '$itemTitle has been set with a deadline';
        break;
      default:
        notificationTitle = '📢 New Item Posted';
        notificationBody = '$itemTitle has been posted';
    }

    print('📬 Creating notification for student: $studentId');
    print('📍 Path: organizations/$organizationCode/students/$studentId/notifications');

    await _firestore
        .collection('organizations')
        .doc(organizationCode)
        .collection('students')
        .doc(studentId)
        .collection('notifications')
        .add({
      'title': notificationTitle,
      'body': notificationBody,
      'type': 'NotificationType.${itemType}',
      'sourceId': sourceId,
      'sourceType': itemType,
      'courseId': courseId,
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
      if (currentUser == null) {
        print('❌ User not authenticated for calendar event creation');
        return;
      }

      // Get organization code if not provided
      String? orgCode = organizationCode;
      if (orgCode == null) {
        print('🔍 Fetching organization code for calendar events');
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        orgCode = userDoc.data()?['organizationCode'];
      }

      if (orgCode == null) {
        print('❌ Organization code not found for calendar events');
        return;
      }

      print('✅ Starting calendar event creation for $itemType: $itemTitle');
      print('📅 Due date: $dueDate');

      final enrollmentsSnapshot = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('enrollments')
          .get();

      print('📊 Creating calendar events for ${enrollmentsSnapshot.docs.length} students');

      for (var enrollment in enrollmentsSnapshot.docs) {
        final studentId = enrollment.data()['studentId'];

        print('📅 Creating calendar event for student: $studentId');
        print('📍 Path: organizations/$orgCode/students/$studentId/calendar_events');

        await _firestore
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
          'reminderMinutes': 1440, // 24 hours before
          'location': '',
          'isRecurring': false,
          'originalEventId': '',
          'sourceId': sourceId,
          'sourceType': itemType,
          'courseId': courseId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Created calendar events for $itemType: $itemTitle');
    } catch (e) {
      print('❌ Error creating calendar events: $e');
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
        return Colors.orange.value;  // Add .value
      case 'tutorial':
        return Colors.red.value;     // Add .value
      case 'goal':
        return Colors.green.value;   // Add .value (was purple)
      default:
        return Colors.grey.value;    // Add .value
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

class CreateMaterialPage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final bool editMode;
  final String? materialId;
  final Map<String, dynamic>? materialData;

  const CreateMaterialPage({
    Key? key,
    required this.courseId,
    required this.courseData,
    this.editMode = false,
    this.materialId,
    this.materialData,
  }) : super(key: key);

  @override
  _CreateMaterialPageState createState() => _CreateMaterialPageState();
}

class _CreateMaterialPageState extends State<CreateMaterialPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _materialType = 'learning'; // 'learning' or 'tutorial'
  DateTime? _dueDate; // Only for tutorials
  TimeOfDay? _dueTime; // Only for tutorials
  bool _isLoading = false;
  List<PlatformFile> _selectedFiles = [];
  List<Map<String, dynamic>> _existingFiles = [];
  double _uploadProgress = 0;
  String _uploadStatus = '';
  StreamSubscription? _uploadSubscription;

  // Initialize NotificationService
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    print('🚀 Initializing CreateMaterialPage');
    print('📍 Course ID: ${widget.courseId}');
    print('🔧 Edit mode: ${widget.editMode}');

    // If in edit mode, populate the fields with existing data
    if (widget.editMode && widget.materialData != null) {
      print('📝 Loading existing material data for editing');
      _titleController.text = widget.materialData!['title'] ?? '';
      _descriptionController.text = widget.materialData!['description'] ?? '';
      _materialType = widget.materialData!['materialType'] ?? 'learning';

      // Set due date if exists (for tutorials)
      if (widget.materialData!['dueDate'] != null) {
        final dueDateTime = (widget.materialData!['dueDate'] as Timestamp).toDate();
        _dueDate = DateTime(dueDateTime.year, dueDateTime.month, dueDateTime.day);
        _dueTime = TimeOfDay(hour: dueDateTime.hour, minute: dueDateTime.minute);
        print('📅 Loaded due date: $_dueDate at $_dueTime');
      }

      // Handle existing files
      if (widget.materialData!['files'] != null &&
          widget.materialData!['files'] is List &&
          (widget.materialData!['files'] as List).isNotEmpty) {
        _existingFiles = List<Map<String, dynamic>>.from(
          (widget.materialData!['files'] as List).map((file) => {
            'url': file['url'] ?? '',
            'name': file['name'] ?? 'Unknown file',
            'size': file['size'] is int ? file['size'] : int.tryParse(file['size']?.toString() ?? '0') ?? 0,
            'uploadedAt': file['uploadedAt'] ?? Timestamp.now(),
            'storagePath': file['storagePath'] ?? '',
          }),
        );
        print('📁 Loaded ${_existingFiles.length} existing files');
      }
    }
  }

  @override
  void dispose() {
    print('🧹 Disposing CreateMaterialPage resources');
    _titleController.dispose();
    _descriptionController.dispose();
    _uploadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _selectFiles() async {
    try {
      print('📂 Starting file selection process');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png', 'zip', 'xls', 'xlsx'],
        withData: true, // Important for web
        withReadStream: false,
      );

      if (result != null) {
        print('📋 Selected ${result.files.length} files for validation');
        List<PlatformFile> validFiles = [];

        for (var file in result.files) {
          // Check file size
          if (file.size > 10 * 1024 * 1024) {
            print('❌ File ${file.name} exceeds 10MB limit');
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
              print('❌ No bytes data for web file: ${file.name}');
              continue;
            }
          } else if (file.bytes == null && file.path != null) {
            // For mobile, read bytes from path
            try {
              print('📱 Reading bytes from mobile path for: ${file.name}');
              final fileBytes = await File(file.path!).readAsBytes();
              file = PlatformFile(
                name: file.name,
                size: file.size,
                bytes: fileBytes,
                path: file.path,
              );
            } catch (e) {
              print('❌ Failed to read bytes for: ${file.name}');
              continue;
            }
          }

          validFiles.add(file);
          print('✅ File validated: ${file.name}');
        }

        if (mounted) {
          setState(() {
            _selectedFiles = validFiles;
          });

          print('📊 Final valid files count: ${validFiles.length}');

          if (validFiles.isEmpty && result.files.isNotEmpty) {
            print('⚠️ No valid files after validation');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No valid files selected. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('📂 File selection cancelled by user');
      }
    } catch (e) {
      print('❌ Error selecting files: $e');
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
      print('❌ User must be authenticated to upload files');
      throw Exception('User must be authenticated to upload files');
    }

    print('☁️ Starting file upload process for ${_selectedFiles.length} files');
    print('👤 Upload by user: ${currentUser.uid}');

    for (int i = 0; i < _selectedFiles.length; i++) {
      final file = _selectedFiles[i];

      if (file.bytes != null) {
        try {
          print('⬆️ Uploading file ${i + 1}/${_selectedFiles.length}: ${file.name}');

          if (mounted) {
            setState(() {
              _uploadStatus = 'Uploading ${file.name}...';
            });
          }

          // Create a unique file name
          String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          // Using 'materials' instead of 'assignments'
          String storagePath = 'materials/${widget.courseId}/$fileName';

          print('📍 Storage path: $storagePath');

          // Create file reference
          final ref = FirebaseStorage.instance.ref().child(storagePath);

          // Set metadata
          final metadata = SettableMetadata(
            contentType: _getContentType(file.extension ?? ''),
            customMetadata: {
              'uploadedBy': currentUser.uid,
              'originalName': file.name,
              'courseId': widget.courseId,
              'materialType': _materialType,
              'type': 'course_material',
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
              print('❌ Upload progress error: $error');
            },
          );

          // Wait for upload to complete
          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();

          print('✅ Upload complete for: ${file.name}');
          print('🔗 Download URL obtained');

          // Add to uploaded files list
          uploadedFilesList.add({
            'url': downloadUrl,
            'name': file.name,
            'size': file.size,
            'uploadedAt': Timestamp.now(),
            'storagePath': ref.fullPath,
          });

        } catch (e) {
          print('❌ Failed to upload ${file.name}: $e');
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

    print('✅ All files uploaded successfully');
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

  // Enhanced _saveMaterial method with integrated notification and calendar creation
  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    // Validate tutorial specific requirements
    if (_materialType == 'tutorial' && _dueDate == null) {
      print('❌ Tutorial due date validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a due date for the tutorial'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('💾 Starting material save process');
    print('📝 Material type: $_materialType');
    print('🔧 Edit mode: ${widget.editMode}');

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
      _uploadStatus = '';
    });

    try {
      // Upload new files if any
      List<Map<String, dynamic>> newlyUploadedFiles = [];
      if (_selectedFiles.isNotEmpty) {
        print('⬆️ Uploading ${_selectedFiles.length} new files');
        newlyUploadedFiles = await _uploadFiles();
      }

      // Combine existing and new files
      final List<Map<String, dynamic>> allFiles = [
        ..._existingFiles,
        ...newlyUploadedFiles,
      ];

      print('📁 Total files after upload: ${allFiles.length}');

      // Prepare due date time for tutorials
      DateTime? dueDateTime;
      if (_materialType == 'tutorial') {
        dueDateTime = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          _dueTime?.hour ?? 23,
          _dueTime?.minute ?? 59,
        );
        print('📅 Tutorial due date set to: $dueDateTime');
      }

      // Prepare material data
      final materialData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'materialType': _materialType,
        'courseId': widget.courseId,
        'courseName': widget.courseData['title'] ?? widget.courseData['name'],
        'courseCode': widget.courseData['code'] ?? '',
        'lecturerId': FirebaseAuth.instance.currentUser?.uid,
        'lecturerName': widget.courseData['lecturerName'],
        'updatedAt': FieldValue.serverTimestamp(),
        'files': allFiles.map((file) => {
          'url': file['url'],
          'name': file['name'],
          'size': file['size'],
          'uploadedAt': file['uploadedAt'],
          'storagePath': file['storagePath'] ?? '',
        }).toList(),
      };

      // Add tutorial-specific fields
      if (_materialType == 'tutorial') {
        materialData['dueDate'] = Timestamp.fromDate(dueDateTime!);
        materialData['requiresSubmission'] = true;
      } else {
        materialData['requiresSubmission'] = false;
        // Remove tutorial fields if changing from tutorial to learning
        if (widget.editMode) {
          materialData['dueDate'] = FieldValue.delete();
        }
      }

      // If creating new material, add creation field
      if (!widget.editMode) {
        materialData['createdAt'] = FieldValue.serverTimestamp();
        materialData['isActive'] = true;
      }

      // Standardize on organizationCode
      final organizationCode = widget.courseData['organizationCode'];

      if (organizationCode == null) {
        print('❌ Organization code not found in course data');
        throw Exception('Organization code not found');
      }

      print('🏢 Organization code: $organizationCode');

      // Save or update material in Firestore
      String? materialId;
      if (widget.editMode && widget.materialId != null) {
        // Update existing material
        print('📝 Updating existing material: ${widget.materialId}');
        print('📍 Path: organizations/$organizationCode/courses/${widget.courseId}/materials/${widget.materialId}');

        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .doc(widget.materialId)
            .update(materialData);

        materialId = widget.materialId;
        print('✅ Material updated successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Material updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new material
        print('🆕 Creating new material');
        print('📍 Path: organizations/$organizationCode/courses/${widget.courseId}/materials');

        final docRef = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .add(materialData);

        materialId = docRef.id;
        print('✅ Material created successfully with ID: $materialId');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Material created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // MERGED: Create notifications and calendar events using NotificationService
      // This now handles both notifications and calendar events in one call
      if (_materialType == 'tutorial') {
        print('📚 Creating notifications and calendar events for tutorial');
        // Create notifications and calendar events using NotificationService
        await _notificationService.createNewItemNotification(
          itemType: 'tutorial',
          itemTitle: _titleController.text.trim(),
          dueDate: dueDateTime!,
          sourceId: materialId!,
          courseId: widget.courseId,
          courseName: widget.courseData['title'] ?? widget.courseData['name'],
          organizationCode: organizationCode,
        );
      } else {
        print('📖 Creating notifications for learning material');
        // For learning materials, only send notifications (no calendar events)
        await _notificationService.createNewItemNotification(
          itemType: 'learning',
          itemTitle: _titleController.text.trim(),
          dueDate: DateTime.now(), // Dummy date for learning materials
          sourceId: materialId!,
          courseId: widget.courseId,
          courseName: widget.courseData['title'] ?? widget.courseData['name'],
          organizationCode: organizationCode,
        );
      }

      print('🎉 Material save process completed successfully');

      // Navigate back
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error ${widget.editMode ? 'updating' : 'creating'} material: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${widget.editMode ? 'updating' : 'creating'} material: $e'),
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
    print('📅 Opening due date picker');

    // Determine the first selectable date based on edit mode
    DateTime firstSelectableDate;

    if (widget.editMode && _dueDate != null) {
      // In edit mode, allow selecting from the original due date or 1 year ago, whichever is earlier
      firstSelectableDate = _dueDate!.isBefore(DateTime.now().subtract(Duration(days: 365)))
          ? _dueDate!
          : DateTime.now().subtract(Duration(days: 365));
    } else {
      // For new tutorials, only allow future dates
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
      print('✅ Due date selected: $picked');
    }
  }

  Future<void> _selectDueTime() async {
    print('⏰ Opening due time picker');

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay(hour: 23, minute: 59),
    );

    if (picked != null && mounted) {
      setState(() {
        _dueTime = picked;
      });
      print('✅ Due time selected: ${picked.format(context)}');
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
          widget.editMode ? 'Edit Material' : 'Create Material',
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

              // Material Type Selection
              Text(
                'Material Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              if (widget.editMode) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        'Material type cannot be changed in edit mode',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: widget.editMode ? null : () => setState(() => _materialType = 'learning'),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _materialType == 'learning' ? Colors.green[50] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _materialType == 'learning' ? Colors.green : Colors.grey[300]!,
                            width: _materialType == 'learning' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.menu_book,
                              color: _materialType == 'learning' ? Colors.green : Colors.grey[600],
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Learning Material',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _materialType == 'learning' ? Colors.green : Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'No submission required',
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
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: widget.editMode ? null : () => setState(() => _materialType = 'tutorial'),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _materialType == 'tutorial' ? Colors.blue[50] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _materialType == 'tutorial' ? Colors.blue : Colors.grey[300]!,
                            width: _materialType == 'tutorial' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.quiz,
                              color: _materialType == 'tutorial' ? Colors.blue : Colors.grey[600],
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tutorial',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _materialType == 'tutorial' ? Colors.blue : Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Requires submission',
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
                ],
              ),
              SizedBox(height: 24),

              // Material Details Card
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
                      'Material Details',
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
                        hintText: _materialType == 'tutorial'
                            ? 'e.g., Tutorial 1: Basic Concepts'
                            : 'e.g., Chapter 1: Introduction',
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
                        hintText: 'Brief description of the material',
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

                    // Tutorial-specific fields (Due Date and Time only)
                    if (_materialType == 'tutorial') ...[
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
                          'Attachments',
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
                      'Supported: PDF, DOC, DOCX, PPT, PPTX, TXT, Images, ZIP (Max 10MB per file)',
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
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getFileIcon(file['name'] ?? ''),
                              color: Colors.purple[600],
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
                                      color: Colors.purple[600],
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
                                'No files selected',
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
                      : (widget.editMode ? 'Update Material' : 'Create Material'),
                  onPressed: _isLoading ? () {} : _saveMaterial,
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