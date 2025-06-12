import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Stu_course extends StatefulWidget {
  @override
  _Stu_courseState createState() => _Stu_courseState();
}

class _Stu_courseState extends State<Stu_course> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int workCount = 3; // Hardcoded example for "work" count
  int missedCount = 1; // Hardcoded example for "missed" count

  @override
  void initState() {
    super.initState();
    getStudentData();
  }

  // Placeholder function to simulate fetching student data
  void getStudentData() async {
    User? user = _auth.currentUser;

    if (user != null) {
      // You can add Firebase Authentication user data fetching here if needed
      setState(() {
        // Use user's data or adjust the counts if needed
      });
    }
  }

  // Handle classroom joining logic (this can be extended to actual functionality)
  void joinClass(String courseId) {
    // Add actual logic to join the class, e.g., storing joined courses in Firebase Realtime Database or any other solution
    print('Joined class: $courseId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('StudyHub', style: TextStyle(fontSize: 24)),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            // Open side menu (or drawer)
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              // Handle notifications here
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // To-Do List Section
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('To Do List:', style: TextStyle(fontSize: 18)),
                Column(
                  children: [
                    Text('Work: $workCount', style: TextStyle(fontSize: 16)),
                    Text('Missed: $missedCount', style: TextStyle(fontSize: 16)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to history screen
                    print("View History Clicked");
                  },
                  child: Text('View History'),
                ),
              ],
            ),
          ),

          // List of Classrooms (This part is also hardcoded for now)
          Expanded(
            child: ListView.builder(
              itemCount: 5, // Example number of classrooms
              itemBuilder: (context, index) {
                // Hardcoded classroom data
                String courseName = 'Course ${index + 1}';
                String lecturerName = 'Lecturer ${index + 1}';
                String courseId = 'courseId${index + 1}';

                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(courseName),
                    subtitle: Text('Instructor: $lecturerName'),
                    trailing: ElevatedButton(
                      onPressed: () {
                        joinClass(courseId);
                      },
                      child: Text('Join'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
