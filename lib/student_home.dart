import 'package:flutter/material.dart';

class StudentHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFf0f4f7), // Light blue background for the app bar
        title: Text('StudyHub', style: TextStyle(color: Color(0xFF3E4A89))),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Color(0xFF3E4A89)),
            onPressed: () {
              // Handle notification button press
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // To-do section
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFf0f4f7), // Light blue background
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To do:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text('0', style: TextStyle(color: Color(0xFF3E4A89), fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(' Work', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      Row(
                        children: [
                          Text('0', style: TextStyle(color: Color(0xFF3E4A89), fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(' Missed', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      // Handle 'View History' button press
                    },
                    child: Text('View History', style: TextStyle(color: Color(0xFF3E4A89), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),

            // Course section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFf0f4f7),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FCC01735 ARTIFICIAL INTELLIGENCE',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E4A89)),
                  ),
                  SizedBox(height: 10),
                  Text('CHING PANG GOH', style: TextStyle(fontSize: 16, color: Color(0xFF3E4A89))),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      // Handle Join button press
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Color(0xFF3E4A89),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Join'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom navigation bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFFF0F4F7),
        selectedItemColor: Color(0xFF3E4A89),
        unselectedItemColor: Colors.grey,
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
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
