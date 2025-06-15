import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateMaterialPage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const CreateMaterialPage({
    Key? key,
    required this.courseId,
    required this.courseData,
  }) : super(key: key);

  @override
  _CreateMaterialPageState createState() => _CreateMaterialPageState();
}

class _CreateMaterialPageState extends State<CreateMaterialPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _materialType = 'document';
  List<String> _fileUrls = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // TODO: Implement file picker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File picker not implemented yet')),
    );
  }

  Future<void> _createMaterial() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.courseData['lecturerUid'])
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _materialType,
        'files': _fileUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser!.uid,
      });

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Material created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating material: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Create Material',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 1,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Material Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter material title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _materialType,
                decoration: InputDecoration(
                  labelText: 'Material Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  DropdownMenuItem(value: 'document', child: Text('Document')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'presentation', child: Text('Presentation')),
                  DropdownMenuItem(value: 'link', child: Text('Link')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _materialType = value!;
                  });
                },
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: Icon(Icons.upload_file),
                label: Text('Upload Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              if (_fileUrls.isNotEmpty) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uploaded Files:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ..._fileUrls.map((url) => Text('• $url')),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createMaterial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Create Material',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}