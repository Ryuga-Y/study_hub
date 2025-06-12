import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:study_hub/Authentication/sign_in.dart';
import 'create_course.dart';

class LecturerHomePage extends StatefulWidget {
  @override
  _LecturerHomePageState createState() => _LecturerHomePageState();
}

class _LecturerHomePageState extends State<LecturerHomePage> {
  FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? lecturerUid;
  String? lecturerName;
  String? lecturerEmail;
  List<Map<String, dynamic>> courses = []; // List to store courses created by the lecturer
  String? errorMessage;
  int _currentIndex = 2; // Track the current tab index

  @override
  void initState() {
    super.initState();
    _fetchLecturerData();
  }

  // Fetch lecturer data (including courses they have created)
  Future<void> _fetchLecturerData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        lecturerUid = user.uid;
      });

      // Fetch lecturer name from Firestore
      try {
        DocumentSnapshot lecturerData = await _firestore
            .collection('users')
            .doc(lecturerUid) // Access the lecturer's document using their UID
            .get();

        if (lecturerData.exists) {
          setState(() {
            lecturerName = lecturerData['name']; // Get the lecturer's name
            lecturerEmail = lecturerData['email']; // Get the lecturer's email
          });
        }

        // Fetch courses created by this lecturer from Firestore
        var courseData = await _firestore
            .collection('users')
            .doc(lecturerUid) // Use the lecturer's UID to get their document
            .collection('courses') // Access the 'courses' subcollection
            .get(); // Get all courses created by the lecturer

        setState(() {
          courses = courseData.docs.map((doc) {
            return {
              'courseId': doc.id,  // Use document ID as courseId
              'title': doc['title'],
              'description': doc['description'],
            };
          }).toList();
        });
      } catch (e) {
        setState(() {
          errorMessage = 'Error fetching data: $e';
        });
      }
    }
  }

  // Navigate to the course creation page
  void _createCourse() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateCoursePage(lecturerUid: lecturerUid!)),
    ).then((_) {
      _fetchLecturerData(); // Reload courses after creating a new one
    });
  }

  // Log out the user
  void _logOut() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SignInPage()), // Replace with your login page
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width and height using MediaQuery for responsiveness
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'StudyHub - Lecturer',
          style: TextStyle(
            fontFamily: 'Abeezee',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // Handle notifications button action
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Color(0xFFE5E9F2),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Profile Header
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: screenWidth < 600 ? 40 : 50,
                      backgroundImage: AssetImage('assets/images/profile_pic.png'),
                    ),
                    SizedBox(height: 10),
                    Text(
                      lecturerName ?? 'Name not available',
                      style: TextStyle(color: Colors.white, fontSize: screenWidth < 600 ? 16 : 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      lecturerEmail ?? 'Email not available',
                      style: TextStyle(color: Colors.white, fontSize: screenWidth < 600 ? 12 : 14),
                    ),
                  ],
                ),
              ),

              // Drawer items
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to Edit Profile page
                        Navigator.pushNamed(context, '/editProfile');
                      },
                      child: Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.blueAccent, backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth < 600 ? 20 : 30, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to Calendar page
                        Navigator.pushNamed(context, '/calendar');
                      },
                      child: Text('Calendar'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.blueAccent, backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth < 600 ? 20 : 30, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    Divider(),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _logOut,
                      child: Text('Log Out'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, backgroundColor: Colors.redAccent,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth < 600 ? 20 : 30, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
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
      body: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heading for the courses
              Text(
                'Courses You Handle',
                style: TextStyle(fontSize: screenWidth < 600 ? 20 : 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),

              // Error message display if any
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),

              // Display courses if there are any
              Expanded(
                child: courses.isNotEmpty
                    ? ListView.builder(
                  shrinkWrap: true,
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(courses[index]['title']),
                        subtitle: Text(courses[index]['description']),
                      ),
                    );
                  },
                )
                    : Center(
                  child: Text(
                    'You have not created any courses yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCourse,
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: Theme(
        data: ThemeData(
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.red, // Set red background color here
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex, // Use the local _currentIndex
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.black,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Community',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book),
              label: 'Course',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flag),
              label: 'Goal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
