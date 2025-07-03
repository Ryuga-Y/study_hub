import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Authentication/custom_widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:async';

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
  final _instructionsController = TextEditingController();
  final _pointsController = TextEditingController();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _isLoading = false;
  List<PlatformFile> _selectedFiles = [];
  List<Map<String, dynamic>> _existingFiles = [];
  double _uploadProgress = 0;
  String _uploadStatus = '';
  StreamSubscription? _uploadSubscription;

  @override
  void initState() {
    super.initState();

    // If in edit mode, populate the fields with existing data
    if (widget.editMode && widget.assignmentData != null) {
      _titleController.text = widget.assignmentData!['title'] ?? '';
      _descriptionController.text = widget.assignmentData!['description'] ?? '';
      _instructionsController.text = widget.assignmentData!['instructions'] ?? '';
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _pointsController.dispose();
    _uploadSubscription?.cancel();
    super.dispose();
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

      // Get organization code - standardize on 'organizationCode'
      final organizationCode = widget.courseData['organizationCode'];

      if (organizationCode == null) {
        throw Exception('Organization code not found');
      }

      // Prepare assignment data
      final assignmentData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
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
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .add(assignmentData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assignment created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(Duration(days: 7)),
      firstDate: DateTime.now(),
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
                      color: Colors.grey.withOpacity(0.1),
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

                    // Instructions
                    TextFormField(
                      controller: _instructionsController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Instructions',
                        hintText: 'Provide detailed instructions for completing this assignment',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 80),
                          child: Icon(Icons.list_alt, color: Colors.purple[400]),
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
                          return 'Please enter instructions';
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
                        color: Colors.grey.withOpacity(0.1),
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