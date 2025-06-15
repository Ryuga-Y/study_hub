import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AssignmentDetailPage extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final String courseId;
  final Map<String, dynamic> courseData;
  final bool isLecturer;

  const AssignmentDetailPage({
    Key? key,
    required this.assignment,
    required this.courseId,
    required this.courseData,
    required this.isLecturer,
  }) : super(key: key);

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'No due date';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'No due date';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Assignment Details',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment, color: Colors.blue, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          assignment['title'] ?? 'Assignment',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Due: ${_formatDate(assignment['dueDate'])}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Description',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              assignment['description'] ?? 'No description available',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 24),
            Text(
              'Instructions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                assignment['instructions'] ?? 'No instructions provided',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            if (assignment['attachments'] != null &&
                (assignment['attachments'] as List).isNotEmpty) ...[
              SizedBox(height: 24),
              Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              ...((assignment['attachments'] as List).map((attachment) =>
                  ListTile(
                    leading: Icon(Icons.attach_file, color: Colors.blue),
                    title: Text('Attachment'),
                    trailing: Icon(Icons.download),
                    onTap: () {
                      // TODO: Implement download
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Download not implemented yet')),
                      );
                    },
                  ),
              )),
            ],
            if (!isLecturer) ...[
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement submission
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Submission not implemented yet')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text(
                  'Submit Assignment',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}