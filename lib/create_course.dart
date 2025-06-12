import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateCoursePage extends StatelessWidget {
  final String lecturerUid;
  final TextEditingController _courseIdController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  CreateCoursePage({required this.lecturerUid});

  Future<void> _createCourse(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(lecturerUid)
          .collection('courses')
          .add({
        'courseId': _courseIdController.text.trim(),
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'uid': lecturerUid,
      });

      // After creating the course, go back to the LecturerHomePage
      Navigator.pop(context);
    } catch (e) {
      // Handle errors, show error messages
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating course: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Course'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _courseIdController,
              decoration: InputDecoration(labelText: 'Course ID'),
            ),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Course Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Course Description'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _createCourse(context),
              child: Text('Create Course'),
            ),
          ],
        ),
      ),
    );
  }
}
