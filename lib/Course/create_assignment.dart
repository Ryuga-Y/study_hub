import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Authentication/custom_widgets.dart';

class CreateAssignmentPage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const CreateAssignmentPage({
    Key? key,
    required this.courseId,
    required this.courseData,
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
  List<Map<String, String>> _uploadedFiles = [];
  double _uploadProgress = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _selectFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png', 'zip', 'xls', 'xlsx'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadFiles() async {
    _uploadedFiles.clear();

    for (int i = 0; i < _selectedFiles.length; i++) {
      final file = _selectedFiles[i];

      if (file.bytes != null) {
        try {
          // Create file reference
          final ref = FirebaseStorage.instance
              .ref()
              .child('assignments')
              .child(widget.courseId)
              .child('${DateTime.now().millisecondsSinceEpoch}_${file.name}');

          // Upload file
          final uploadTask = ref.putData(file.bytes!);

          // Monitor upload progress
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            setState(() {
              _uploadProgress = (i + snapshot.bytesTransferred / snapshot.totalBytes) / _selectedFiles.length;
            });
          });

          // Wait for upload to complete
          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();

          _uploadedFiles.add({
            'url': downloadUrl,
            'name': file.name,
            'size': file.size.toString(),
          });
        } catch (e) {
          throw Exception('Failed to upload ${file.name}: $e');
        }
      }
    }
  }

  Future<void> _createAssignment() async {
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
    });

    try {
      // Upload files if any
      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles();
      }

      // Prepare due date time
      final dueDateTime = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        _dueTime?.hour ?? 23,
        _dueTime?.minute ?? 59,
      );

      // Get organization code
      final organizationCode = widget.courseData['organizationCode'] ?? widget.courseData['organizationId'];

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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'attachments': _uploadedFiles,
        'submissionCount': 0,
        'isActive': true,
      };

      // Create assignment document
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .add(assignmentData);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assignment created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _selectDueTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 23, minute: 59),
    );

    if (picked != null) {
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
          'Create Assignment',
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
                            'Assignment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.orange[700],
                            ),
                          ),
                          Text(
                            'Students must submit their work before the due date',
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

                    // Points and Due Date Row
                    Row(
                      children: [
                        // Points
                        Expanded(
                          child: TextFormField(
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
                        ),
                        SizedBox(width: 12),
                      ],
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
                      'Optional: Attach reference materials or examples',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Selected Files List
                    if (_selectedFiles.isEmpty)
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
                    else
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
              if (_isLoading && _uploadProgress > 0)
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
                        'Uploading files...',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                  ),
                ),

              SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _isLoading ? 'Creating...' : 'Create Assignment',
                  onPressed: _isLoading ? () {} : _createAssignment,
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
    switch (extension.toLowerCase()) {
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
}