import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controller for notification count
  final StreamController<int> _notificationCountController = StreamController<int>.broadcast();
  Stream<int> get notificationCountStream => _notificationCountController.stream;

  // Stream controller for notifications list
  final StreamController<List<NotificationModel>> _notificationsController =
  StreamController<List<NotificationModel>>.broadcast();
  Stream<List<NotificationModel>> get notificationsStream => _notificationsController.stream;

  Timer? _checkTimer;
  String? _userOrgCode;
  String? _userRole;

  // Real-time listeners
  StreamSubscription<QuerySnapshot>? _calendarEventsSubscription;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  // Get notification badge icon widget
  Widget getNotificationBadgeIcon({VoidCallback? onTap}) {
    return StreamBuilder<int>(
      stream: notificationCountStream,
      initialData: 0,
      builder: (context, snapshot) {
        return badges.Badge(
          badgeContent: Text(
            snapshot.data.toString(),
            style: TextStyle(color: Colors.white),
          ),
          showBadge: snapshot.data! > 0,
          child: IconButton(
            icon: Icon(Icons.notifications),
            onPressed: onTap ??
                    () => showDialog(
                  context: context,
                  builder: (context) => NotificationDialog(),
                ),
          ),
        );
      },
    );
  }

  // Initialize notification service
  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Get user's organization code and role
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    _userOrgCode = userData['organizationCode'];
    _userRole = userData['role'];

    if (_userOrgCode == null) return;

    // Only start deadline checking for students
    if (_userRole == 'student') {
      // Start checking for upcoming deadlines
      _startDeadlineChecker();

      // Start real-time calendar event listener
      _startCalendarEventListener();

      // Load existing notifications
      await _loadNotifications();

      // Start real-time notification listener
      _startNotificationListener();
    }
  }

  // Start real-time calendar event listener (Students only)
  void _startCalendarEventListener() {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole != 'student') return;

    // Listen to calendar events for real-time updates
    _calendarEventsSubscription = _firestore
        .collection('organizations')
        .doc(_userOrgCode)
        .collection('students')
        .doc(user.uid)
        .collection('calendar_events')
        .where('startTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .snapshots()
        .listen((snapshot) {
      // Check for new events that need notifications
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final eventData = change.doc.data() as Map<String, dynamic>;
          _checkAndCreateNotificationForEvent(change.doc.id, eventData);
        }
      }
    });
  }

  // Start real-time notification listener
  void _startNotificationListener() {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null) return;

    // Different listener path based on user role
    Query notificationQuery;

    if (_userRole == 'student') {
      notificationQuery = _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications');
    } else {
      // For lecturers, they would have their own notification system
      return;
    }

    _notificationSubscription = notificationQuery
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      List<NotificationModel> notifications = [];
      int unreadCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final notification = NotificationModel.fromMap(doc.id, data);
        notifications.add(notification);

        if (!notification.isRead) {
          unreadCount++;
        }
      }

      // Update streams
      _notificationsController.add(notifications);
      _notificationCountController.add(unreadCount);
    });
  }

  // Check and create notification for a calendar event
  Future<void> _checkAndCreateNotificationForEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      final eventTime = (eventData['startTime'] as Timestamp).toDate();
      final now = DateTime.now();
      final hoursUntilDue = eventTime.difference(now).inHours;

      // Create notification if event is within 24 hours
      if (hoursUntilDue <= 24 && hoursUntilDue > 0) {
        // Check if notification already exists
        final existingNotifications = await _firestore
            .collection('organizations')
            .doc(_userOrgCode)
            .collection('students')
            .doc(_auth.currentUser!.uid)
            .collection('notifications')
            .where('eventId', isEqualTo: eventId)
            .get();

        if (existingNotifications.docs.isEmpty) {
          String title = '';
          String body = '';
          NotificationType type = NotificationType.reminder;

          final sourceType = eventData['sourceType'] ?? '';
          final eventTitle = eventData['title'] ?? 'Event';

          switch (sourceType) {
            case 'assignment':
              title = '📝 Assignment Due Soon';
              body = '$eventTitle is due in $hoursUntilDue hours!';
              type = NotificationType.assignment;
              break;
            case 'tutorial':
              title = '📚 Tutorial Due Soon';
              body = '$eventTitle is due in $hoursUntilDue hours!';
              type = NotificationType.tutorial;
              break;
            case 'goal':
              title = '🎯 Goal Target Date Approaching';
              body = '$eventTitle target date is in $hoursUntilDue hours!';
              type = NotificationType.goal;
              break;
            default:
              title = '📅 Event Reminder';
              body = '$eventTitle is in $hoursUntilDue hours!';
          }

          await _createStudentNotification(
            studentId: _auth.currentUser!.uid,
            title: title,
            body: body,
            type: type,
            eventId: eventId,
            sourceId: eventData['sourceId'],
            sourceType: sourceType,
            dueDate: eventTime,
          );
        }
      }
    } catch (e) {
      print('Error checking event for notification: $e');
    }
  }

  // Create immediate notification and calendar event for new assignments/tutorials/goals
  Future<void> createNewItemNotification({
    required String itemType,
    required String itemTitle,
    DateTime? dueDate,
    required String sourceId,
    String? courseId,
    String? studentId, // If null, send to all students in course
  }) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null) return;

    try {
      String title = '';
      String body = '';
      NotificationType type = NotificationType.announcement;

      if (itemType == 'assignment') {
        title = '📝 New Assignment Posted';
        body = '$itemTitle has been posted.';
        if (dueDate != null) {
          body += ' Due: ${_formatDate(dueDate)}';
        }
        type = NotificationType.assignment;
      } else if (itemType == 'tutorial') {
        title = '📚 New Tutorial Posted';
        body = '$itemTitle has been posted.';
        if (dueDate != null) {
          body += ' Due: ${_formatDate(dueDate)}';
        }
        type = NotificationType.tutorial;
      } else if (itemType == 'goal') {
        title = '🎯 New Goal Created';
        body = '$itemTitle has been set as your new goal.';
        if (dueDate != null) {
          body += ' Target: ${_formatDate(dueDate)}';
        }
        type = NotificationType.goal;
      }

      if (studentId != null) {
        // Send to specific student
        await _createStudentNotification(
          studentId: studentId,
          title: title,
          body: body,
          type: type,
          sourceId: sourceId,
          sourceType: itemType,
          dueDate: dueDate,
          courseId: courseId,
        );

        // Create calendar event for specific student
        if (dueDate != null && (itemType == 'assignment' || itemType == 'tutorial')) {
          await _createCalendarEvent(
            studentId: studentId,
            title: itemTitle,
            dueDate: dueDate,
            sourceId: sourceId,
            sourceType: itemType,
            courseId: courseId,
          );
        }
      } else if (courseId != null) {
        // Send to all students enrolled in the course
        await _sendNotificationToAllStudentsInCourse(
          courseId: courseId,
          title: title,
          body: body,
          type: type,
          sourceId: sourceId,
          sourceType: itemType,
          dueDate: dueDate,
        );

        // Create calendar events for all students in the course
        if (dueDate != null && (itemType == 'assignment' || itemType == 'tutorial')) {
          final enrollmentsSnapshot = await _firestore
              .collection('organizations')
              .doc(_userOrgCode)
              .collection('courses')
              .doc(courseId)
              .collection('enrollments')
              .get();

          for (var enrollmentDoc in enrollmentsSnapshot.docs) {
            final enrollmentData = enrollmentDoc.data();
            final studentId = enrollmentData['studentId'];

            if (studentId != null) {
              await _createCalendarEvent(
                studentId: studentId,
                title: itemTitle,
                dueDate: dueDate,
                sourceId: sourceId,
                sourceType: itemType,
                courseId: courseId,
              );
            }
          }
        }
      } else {
        // For goals, send to current user
        await _createStudentNotification(
          studentId: user.uid,
          title: title,
          body: body,
          type: type,
          sourceId: sourceId,
          sourceType: itemType,
          dueDate: dueDate,
        );

        // Calendar event for goals is handled in set_goal.dart
      }

      print('✅ Created notification for new $itemType: $itemTitle');
    } catch (e) {
      print('Error creating new item notification: $e');
    }
  }

  // Create calendar event for a student
  Future<void> _createCalendarEvent({
    required String studentId,
    required String title,
    required DateTime dueDate,
    required String sourceId,
    required String sourceType,
    String? courseId,
  }) async {
    try {
      await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(studentId)
          .collection('calendar_events')
          .add({
        'title': sourceType == 'assignment' ? '📝 Assignment: $title Due' : '📚 Tutorial: $title Due',
        'description': '$title deadline',
        'startTime': Timestamp.fromDate(dueDate),
        'endTime': Timestamp.fromDate(dueDate),
        'color': sourceType == 'assignment' ? Colors.orange.value : Colors.blue.value,
        'calendar': sourceType,
        'eventType': EventType.normal.index,
        'recurrenceType': RecurrenceType.none.index,
        'reminderMinutes': 1440, // 24 hours before
        'location': '',
        'isRecurring': false,
        'originalEventId': '',
        'sourceId': sourceId,
        'sourceType': sourceType,
        'courseId': courseId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Created calendar event for $sourceType: $title for student $studentId');
    } catch (e) {
      print('Error creating calendar event: $e');
    }
  }

  // Send notification to all students in a course
  Future<void> _sendNotificationToAllStudentsInCourse({
    required String courseId,
    required String title,
    required String body,
    required NotificationType type,
    String? sourceId,
    String? sourceType,
    DateTime? dueDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null) return;

    try {
      // Get all enrollments for the course
      final enrollmentsSnapshot = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('courses')
          .doc(courseId)
          .collection('enrollments')
          .get();

      // Create notifications for each enrolled student
      final batch = _firestore.batch();

      for (var enrollmentDoc in enrollmentsSnapshot.docs) {
        final enrollmentData = enrollmentDoc.data();
        final studentId = enrollmentData['studentId'];

        if (studentId != null) {
          final notificationRef = _firestore
              .collection('organizations')
              .doc(_userOrgCode)
              .collection('students')
              .doc(studentId)
              .collection('notifications')
              .doc();

          batch.set(notificationRef, {
            'title': title,
            'body': body,
            'type': type.toString(),
            'sourceId': sourceId,
            'sourceType': sourceType,
            'courseId': courseId,
            'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      await batch.commit();
      print('✅ Sent notifications to all students in course $courseId');
    } catch (e) {
      print('Error sending notifications to course students: $e');
    }
  }

  // Create notification for a specific student
  Future<void> _createStudentNotification({
    required String studentId,
    required String title,
    required String body,
    required NotificationType type,
    String? eventId,
    String? sourceId,
    String? sourceType,
    DateTime? dueDate,
    String? courseId,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null) return;

    try {
      Map<String, dynamic> notificationData = {
        'title': title,
        'body': body,
        'type': type.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Add optional fields
      if (eventId != null) notificationData['eventId'] = eventId;
      if (sourceId != null) notificationData['sourceId'] = sourceId;
      if (sourceType != null) notificationData['sourceType'] = sourceType;
      if (dueDate != null) notificationData['dueDate'] = Timestamp.fromDate(dueDate);
      if (courseId != null) notificationData['courseId'] = courseId;

      await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(studentId)
          .collection('notifications')
          .add(notificationData);

      print('✅ Created notification for student $studentId: $title');
    } catch (e) {
      print('Error creating student notification: $e');
    }
  }

  // Start periodic deadline checker
  void _startDeadlineChecker() {
    // Cancel existing timer
    _checkTimer?.cancel();

    // Check every hour
    _checkTimer = Timer.periodic(Duration(hours: 1), (timer) {
      _checkUpcomingDeadlines();
    });

    // Also check immediately
    _checkUpcomingDeadlines();
  }

  // Check for upcoming deadlines (24 hours before)
  Future<void> _checkUpcomingDeadlines() async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole != 'student') return;

    try {
      final now = DateTime.now();
      final tomorrow = now.add(Duration(days: 1));

      // Get all calendar events for the user
      final eventsSnapshot = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .where('startTime', isGreaterThan: Timestamp.fromDate(now))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(tomorrow))
          .get();

      // Get existing notifications to avoid duplicates
      final existingNotifications = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      Set<String> existingEventIds = {};
      for (var doc in existingNotifications.docs) {
        final data = doc.data();
        if (data['eventId'] != null) {
          existingEventIds.add(data['eventId']);
        }
      }

      // Create notifications for events due tomorrow
      for (var eventDoc in eventsSnapshot.docs) {
        final eventData = eventDoc.data();
        final eventId = eventDoc.id;

        // Skip if notification already exists
        if (existingEventIds.contains(eventId)) continue;

        // Check if it's within 24 hours
        final eventTime = (eventData['startTime'] as Timestamp).toDate();
        final hoursUntilDue = eventTime.difference(now).inHours;

        if (hoursUntilDue <= 24 && hoursUntilDue > 0) {
          String title = '';
          String body = '';
          NotificationType type = NotificationType.reminder;

          // Customize notification based on source type
          final sourceType = eventData['sourceType'] ?? '';
          final eventTitle = eventData['title'] ?? 'Event';

          switch (sourceType) {
            case 'assignment':
              title = '📝 Assignment Due Tomorrow';
              body = '$eventTitle is due in $hoursUntilDue hours!';
              type = NotificationType.assignment;
              break;
            case 'tutorial':
              title = '📚 Tutorial Due Tomorrow';
              body = '$eventTitle is due in $hoursUntilDue hours!';
              type = NotificationType.tutorial;
              break;
            case 'goal':
              title = '🎯 Goal Target Date Tomorrow';
              body = '$eventTitle target date is in $hoursUntilDue hours!';
              type = NotificationType.goal;
              break;
            default:
              title = '📅 Event Tomorrow';
              body = '$eventTitle is in $hoursUntilDue hours!';
          }

          // Create notification
          await _createStudentNotification(
            studentId: user.uid,
            title: title,
            body: body,
            type: type,
            eventId: eventId,
            sourceId: eventData['sourceId'],
            sourceType: sourceType,
            dueDate: eventTime,
          );
        }
      }

      // Reload notifications if using timer-based checking
      if (_notificationSubscription == null) {
        await _loadNotifications();
      }
    } catch (e) {
      print('Error checking deadlines: $e');
    }
  }

  // Load notifications
  Future<void> _loadNotifications() async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole != 'student') return;

    try {
      final snapshot = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      List<NotificationModel> notifications = [];
      int unreadCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final notification = NotificationModel.fromMap(doc.id, data);
        notifications.add(notification);

        if (!notification.isRead) {
          unreadCount++;
        }
      }

      // Update streams
      _notificationsController.add(notifications);
      _notificationCountController.add(unreadCount);
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole != 'student') return;

    try {
      await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      // Reload notifications if not using real-time listener
      if (_notificationSubscription == null) {
        await _loadNotifications();
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole != 'student') return;

    try {
      final batch = _firestore.batch();

      final unreadNotifications = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      // Reload notifications if not using real-time listener
      if (_notificationSubscription == null) {
        await _loadNotifications();
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole != 'student') return;

    try {
      await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      // Reload notifications if not using real-time listener
      if (_notificationSubscription == null) {
        await _loadNotifications();
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Send custom announcement (Lecturer functionality)
  Future<void> sendAnnouncementToStudents({
    required String courseId,
    required String title,
    required String message,
    List<String>? specificStudentIds,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole != 'lecturer') return;

    try {
      if (specificStudentIds != null) {
        // Send to specific students
        for (String studentId in specificStudentIds) {
          await _createStudentNotification(
            studentId: studentId,
            title: title,
            body: message,
            type: NotificationType.announcement,
            courseId: courseId,
          );
        }
      } else {
        // Send to all students in course
        await _sendNotificationToAllStudentsInCourse(
          courseId: courseId,
          title: title,
          body: message,
          type: NotificationType.announcement,
        );
      }

      print('✅ Sent announcement to students in course $courseId');
    } catch (e) {
      print('Error sending announcement: $e');
    }
  }

  // Format date helper
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Get user role
  String? get userRole => _userRole;

  // Dispose
  void dispose() {
    _checkTimer?.cancel();
    _calendarEventsSubscription?.cancel();
    _notificationSubscription?.cancel();
    _notificationCountController.close();
    _notificationsController.close();
  }
}

// Notification types
enum NotificationType {
  assignment,
  tutorial,
  goal,
  reminder,
  announcement,
}

// Event types (for calendar events)
enum EventType {
  normal,
  important,
  urgent,
}

// Recurrence types (for calendar events)
enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

// Notification model
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? eventId;
  final String? sourceId;
  final String? sourceType;
  final String? courseId;
  final DateTime? dueDate;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.eventId,
    this.sourceId,
    this.sourceType,
    this.courseId,
    this.dueDate,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> data) {
    return NotificationModel(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: _parseNotificationType(data['type']),
      eventId: data['eventId'],
      sourceId: data['sourceId'],
      sourceType: data['sourceType'],
      courseId: data['courseId'],
      dueDate: data['dueDate'] != null ? (data['dueDate'] as Timestamp).toDate() : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    if (type == null) return NotificationType.reminder;

    try {
      return NotificationType.values.firstWhere(
            (e) => e.toString() == type,
        orElse: () => NotificationType.reminder,
      );
    } catch (e) {
      return NotificationType.reminder;
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.assignment:
        return Icons.assignment;
      case NotificationType.tutorial:
        return Icons.quiz;
      case NotificationType.goal:
        return Icons.flag;
      case NotificationType.announcement:
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.assignment:
        return Colors.orange;
      case NotificationType.tutorial:
        return Colors.blue;
      case NotificationType.goal:
        return Colors.purple;
      case NotificationType.announcement:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// Notification dialog widget
class NotificationDialog extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header with badge
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  StreamBuilder<int>(
                    stream: _notificationService.notificationCountStream,
                    initialData: 0,
                    builder: (context, snapshot) {
                      return badges.Badge(
                        badgeContent: Text(
                          snapshot.data.toString(),
                          style: TextStyle(color: Colors.white),
                        ),
                        showBadge: snapshot.data! > 0,
                        child: Icon(Icons.notifications, color: Colors.white, size: 24),
                      );
                    },
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      _notificationService.markAllAsRead();
                    },
                    child: Text(
                      'Mark all as read',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Notifications list
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: _notificationService.notificationsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final notifications = snapshot.data!;

                  return ListView.separated(
                    padding: EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];

                      return NotificationCard(
                        notification: notification,
                        onTap: () {
                          if (!notification.isRead) {
                            _notificationService.markAsRead(notification.id);
                          }
                        },
                        onDelete: () {
                          _notificationService.deleteNotification(notification.id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Notification card widget
class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NotificationCard({
    Key? key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[300]! : Colors.blue[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notification.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}

// Announcement composer widget for lecturers
class AnnouncementComposer extends StatefulWidget {
  final String courseId;
  final String courseName;

  const AnnouncementComposer({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  _AnnouncementComposerState createState() => _AnnouncementComposerState();
}

class _AnnouncementComposerState extends State<AnnouncementComposer> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Send Announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send to all students in ${widget.courseName}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Announcement Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_titleController.text.isNotEmpty && _messageController.text.isNotEmpty) {
              await _notificationService.sendAnnouncementToStudents(
                courseId: widget.courseId,
                title: _titleController.text,
                message: _messageController.text,
              );
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Announcement sent to all students!')),
              );
            }
          },
          child: Text('Send'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}