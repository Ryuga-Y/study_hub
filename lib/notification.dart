import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;
import 'dart:async';
import '../Student/student_assignment_details.dart';
import '../Student/student_course.dart';
import '../Student/student_submit_view.dart';
import '../Student/student_tutorial.dart';
import '../Student/calendar.dart';
import '../Student/student_quiz.dart';
import 'Stu_goal.dart';
import 'set_goal.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controllers
  final StreamController<int> _notificationCountController = StreamController<int>.broadcast();
  Stream<int> get notificationCountStream => _notificationCountController.stream;

  final StreamController<List<NotificationModel>> _notificationsController =
  StreamController<List<NotificationModel>>.broadcast();
  Stream<List<NotificationModel>> get notificationsStream => _notificationsController.stream;

  // Real-time listeners
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _calendarEventsSubscription;
  Timer? _checkTimer;

  String? _userOrgCode;
  String? _userRole;
  bool _isInitialized = false;

// Getter for organization code
  String? get userOrgCode => _userOrgCode;

  // FIXED: Get notification badge icon widgets
  Widget getNotificationBadgeIcon({VoidCallback? onTap}) {
    return StreamBuilder<int>(
      stream: notificationCountStream,
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: Colors.black87),
              onPressed: onTap ?? () {
                showDialog(
                  context: context,
                  builder: (context) => NotificationDialog(),
                );
              },
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // FIXED: Initialize method with better error handling
  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ NotificationService already initialized');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user found');
      _setEmptyState();
      return;
    }

    try {
      print('🔍 Initializing NotificationService for user: ${user.uid}');

      // Cancel existing subscriptions
      await _dispose();

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print('❌ User document not found');
        _setEmptyState();
        return;
      }

      final userData = userDoc.data()!;
      _userOrgCode = userData['organizationCode'];
      _userRole = userData['role'];

      print('✅ User data loaded:');
      print('   - Organization: $_userOrgCode');
      print('   - Role: $_userRole');

      if (_userOrgCode == null) {
        print('❌ No organization code found');
        _setEmptyState();
        return;
      }

      // FIXED: Allow any authenticated user with valid role
      if (_userRole != null) {
        print(
            '✅ Starting notification services for user with role: $_userRole');

        // Start real-time notification listener first
        _startNotificationListener();

        // Add this after _startNotificationListener()
        await _cleanupDuplicateNotifications();

        // Load initial notifications
        await _loadNotifications();

        // Start other services
        _startDeadlineChecker();
        _startCalendarEventListener();

        _isInitialized = true;
        print('✅ NotificationService fully initialized');
      } else {
        print('❌ User has no valid role: $_userRole');
        _setEmptyState();
      }
    } catch (e) {
      print('❌ Error initializing notification service: $e');
      _setEmptyState();
    }
  }

  // Helper to set empty state
  void _setEmptyState() {
    _notificationsController.add([]);
    _notificationCountController.add(0);
  }

  // FIXED: Start real-time notification listener
  void _startNotificationListener() {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole == null) {
      print('❌ Cannot start notification listener: missing user, org code, or role');
      _setEmptyState();
      return;
    }

    final notificationPath = 'organizations/$_userOrgCode/students/${user.uid}/notifications';
    print('📍 Setting up notification listener at: $notificationPath');

    _notificationSubscription = _firestore
        .collection('organizations')
        .doc(_userOrgCode!)
        .collection('students')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      print('📬 Real-time notification received: ${snapshot.docs.length} notifications');

      List<NotificationModel> notifications = [];
      int unreadCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Skip test notifications
          if (data['type'] == 'test' || data['title']?.toString().toLowerCase().contains('test') == true) {
            continue;
          }

          final notification = NotificationModel.fromMap(doc.id, data);
          notifications.add(notification);

          if (!notification.isRead) {
            unreadCount++;
          }
        } catch (e) {
          print('❌ Error processing notification ${doc.id}: $e');
        }
      }

        // Update streams
        _notificationsController.add(notifications);
        _notificationCountController.add(unreadCount);
        print('✅ Updated: ${notifications.length} notifications, $unreadCount unread');
      },
      onError: (error) {
        print('❌ Error in notification listener: $error');
        _setEmptyState();
      },
    );
  }

  // Load notifications manually (fallback)
  Future<void> _loadNotifications() async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole == null) return;

    try {
      print('📱 Loading notifications manually for user: ${user.uid}');

      final snapshot = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      print('📋 Found ${snapshot.docs.length} notifications');

      List<NotificationModel> notifications = [];
      int unreadCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final notification = NotificationModel.fromMap(doc.id, data);
          notifications.add(notification);

          if (!notification.isRead) {
            unreadCount++;
          }
        } catch (e) {
          print('❌ Error processing notification ${doc.id}: $e');
        }
      }

      // Update streams only if no real-time listener
      if (_notificationSubscription == null) {
        _notificationsController.add(notifications);
        _notificationCountController.add(unreadCount);
      }

      print('📊 Loaded $unreadCount unread notifications');
    } catch (e) {
      print('❌ Error loading notifications: $e');
    }
  }

  // FIXED: Start calendar event listener for deadline notifications
  void _startCalendarEventListener() {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole == null) return;

    print('📅 Starting calendar event listener');

    // Listen to ALL calendar events to catch reminder updates
    _calendarEventsSubscription = _firestore
        .collection('organizations')
        .doc(_userOrgCode)
        .collection('students')
        .doc(user.uid)
        .collection('calendar_events')
        .snapshots()
        .listen((snapshot) {
      print('📅 Calendar events updated: ${snapshot.docs.length} total events');

      // Process ALL events immediately when listener starts
      for (var doc in snapshot.docs) {
        final eventData = doc.data();
        final eventTime = (eventData['startTime'] as Timestamp).toDate();
        final now = DateTime.now();

        // Process events that are in the future or very recently past (within 5 minutes)
        if (eventTime.isAfter(now.subtract(Duration(minutes: 5)))) {
          _checkAndCreateNotificationForEvent(doc.id, eventData);
        }
      }

      // Also check for any document changes
      // Also check for any document changes
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final eventData = change.doc.data() as Map<String, dynamic>;
          final eventTime = (eventData['startTime'] as Timestamp).toDate();
          final now = DateTime.now();

          // For modified events, clean up all existing reminders first
          if (change.type == DocumentChangeType.modified) {
            _cleanupExistingReminders(change.doc.id);
          }

          if (eventTime.isAfter(now.subtract(Duration(minutes: 5)))) {
            _checkAndCreateNotificationForEvent(change.doc.id, eventData);
          }
        }
      }
    });
  }

  // Check and create notification for calendar events
  Future<void> _checkAndCreateNotificationForEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      final eventTime = (eventData['startTime'] as Timestamp).toDate();
      final now = DateTime.now();
      final reminderMinutes = eventData['reminderMinutes'] ?? 15;
      final sourceType = eventData['sourceType'] ?? '';

      // Skip if no reminder is set (-1 means no reminder)
      if (reminderMinutes == -1) {
        print('   ⏩ Skipping - no reminder set for event: ${eventData['title']}');
        return;
      }

      // Check existing reminder notifications for this event
      final existingNotifications = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(_auth.currentUser!.uid)
          .collection('notifications')
          .where('eventId', isEqualTo: eventId)
          .where('type', whereIn: ['NotificationType.assignment', 'NotificationType.tutorial', 'NotificationType.reminder'])
          .get();

      // Track what reminder types have been sent
      Set<String> sentReminders = {};
      for (var doc in existingNotifications.docs) {
        final data = doc.data();
        if (data['reminderType'] != null) {
          sentReminders.add(data['reminderType']);
        }
      }

      // Use user's selected reminder time only
      await _handleEventReminder(eventId, eventData, reminderMinutes, sentReminders, sourceType);

    } catch (e) {
      print('❌ Error checking event for notification: $e');
    }
  }

  // NEW: Handle event reminders based on user selection
  Future<void> _handleEventReminder(String eventId, Map<String, dynamic> eventData, int reminderMinutes, Set<String> sentReminders, String sourceType) async {
    final eventTime = (eventData['startTime'] as Timestamp).toDate();
    final now = DateTime.now();
    final eventTitle = eventData['title'] ?? 'Event';

    if (reminderMinutes == 0) {
      // "On time" - only send 1 reminder exactly at event time
      final secondsUntilEvent = eventTime.difference(now).inSeconds;

      if (secondsUntilEvent <= 30 && secondsUntilEvent >= -30 && !sentReminders.contains('ontime')) {
        String title = sourceType == 'assignment' ? '📝 Assignment Due Now!'
            : sourceType == 'tutorial' ? '📚 Tutorial Due Now!'
            : '⏰ Event Starting Now!';

        await _createReminderNotification(
          eventId: eventId,
          eventData: eventData,
          reminderType: 'ontime',
          title: title,
          body: '$eventTitle is ${sourceType.isNotEmpty ? 'due' : 'starting'} now!',
          minutesUntil: 0,
        );
      }
    } else {
      // User selected a specific time before - send 2 reminders
      final minutesUntilDue = eventTime.difference(now).inMinutes;

      // 1. Reminder at the selected time before
      if (minutesUntilDue <= reminderMinutes && minutesUntilDue > (reminderMinutes - 5) && !sentReminders.contains('before_reminder')) {
        String reminderText = _formatReminderTime(reminderMinutes);
        String title = sourceType == 'assignment' ? '📝 Assignment Due Soon'
            : sourceType == 'tutorial' ? '📚 Tutorial Due Soon'
            : '📅 Calendar Reminder';

        await _createReminderNotification(
          eventId: eventId,
          eventData: eventData,
          reminderType: 'before_reminder',
          title: title,
          body: '$eventTitle is ${sourceType.isNotEmpty ? 'due' : 'starting'} $reminderText!',
          minutesUntil: minutesUntilDue,
        );
      }

      // 2. Reminder exactly at event time
      if (minutesUntilDue <= 1 && minutesUntilDue >= 0 && !sentReminders.contains('ontime')) {
        String title = sourceType == 'assignment' ? '📝 Assignment Due Now!'
            : sourceType == 'tutorial' ? '📚 Tutorial Due Now!'
            : '⏰ Event Starting Now!';

        await _createReminderNotification(
          eventId: eventId,
          eventData: eventData,
          reminderType: 'ontime',
          title: title,
          body: '$eventTitle is ${sourceType.isNotEmpty ? 'due' : 'starting'} now!',
          minutesUntil: minutesUntilDue,
        );
      }
    }
  }

// NEW: Helper method to format reminder time text
  String _formatReminderTime(int minutes) {
    if (minutes >= 1440) {
      final days = (minutes / 1440).round();
      return days == 1 ? 'tomorrow' : 'in $days days';
    } else if (minutes >= 60) {
      final hours = (minutes / 60).round();
      return 'in $hours hour${hours == 1 ? '' : 's'}';
    } else {
      return 'in $minutes minute${minutes == 1 ? '' : 's'}';
    }
  }

  // Start periodic deadline checker
  void _startDeadlineChecker() {
    _checkTimer?.cancel();

    // Check every 15 seconds for more precise reminder timing for personal notes
    _checkTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      _checkUpcomingDeadlines();
      _checkPersonalCalendarReminders();
    });

    // Also check immediately and after a short delay
    _checkUpcomingDeadlines();
    _checkPersonalCalendarReminders();

    // Additional check after 5 seconds to catch any initialization delays
    Future.delayed(Duration(seconds: 5), () {
      _checkPersonalCalendarReminders();
    });
  }

  // Check for upcoming deadlines (24 hours before)
  Future<void> _checkUpcomingDeadlines() async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole == null) return;

    try {
      final now = DateTime.now();
      final twoDaysFromNow = now.add(Duration(days: 2)); // Extended range

      // Get all upcoming calendar events
      final eventsSnapshot = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .where('startTime', isGreaterThan: Timestamp.fromDate(now))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(twoDaysFromNow))
          .get();

      // Get existing reminder notifications to track what's already been sent
      final existingNotifications = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .where('type', whereIn: ['NotificationType.assignment', 'NotificationType.tutorial'])
          .get();

      // Track sent reminders: eventId -> Set of reminder types sent
      Map<String, Set<String>> sentReminders = {};
      for (var doc in existingNotifications.docs) {
        final data = doc.data();
        if (data['eventId'] != null && data['reminderType'] != null) {
          final eventId = data['eventId'] as String;
          final reminderType = data['reminderType'] as String;
          sentReminders.putIfAbsent(eventId, () => {}).add(reminderType);
        }
      }

      // Process each event for reminder notifications
      for (var eventDoc in eventsSnapshot.docs) {
        final eventData = eventDoc.data();
        final eventId = eventDoc.id;
        final eventTime = (eventData['startTime'] as Timestamp).toDate();
        final minutesUntilDue = eventTime.difference(now).inMinutes;
        final sourceType = eventData['sourceType'] ?? '';
        final eventTitle = eventData['title'] ?? 'Event';
        final alreadySent = sentReminders[eventId] ?? <String>{};

        // Check for 1-day reminder (1440 minutes = 24 hours)
        // Check for 1-day reminder (1440 minutes = 24 hours)
        if (minutesUntilDue <= 1440 && minutesUntilDue > 1430 && !alreadySent.contains('1day')) {
          await _createReminderNotification(
            eventId: eventId,
            eventData: eventData,
            reminderType: '1day',
            title: sourceType == 'assignment'
                ? '📝 Assignment Due Tomorrow'
                : '📚 Tutorial Due Tomorrow',
            body: '$eventTitle is due tomorrow!',
            minutesUntil: minutesUntilDue,
          );
        }

// Check for 10-minute reminder
        if (minutesUntilDue <= 10 && minutesUntilDue > 0 && !alreadySent.contains('10min')) {
          await _createReminderNotification(
            eventId: eventId,
            eventData: eventData,
            reminderType: '10min',
            title: sourceType == 'assignment'
                ? '📝 Assignment Due in 10 Minutes!'
                : '📚 Tutorial Due in 10 Minutes!',
            body: '$eventTitle is due in ${minutesUntilDue} minutes!',
            minutesUntil: minutesUntilDue,
          );
        }
      }
    } catch (e) {
      print('❌ Error checking deadlines: $e');
    }
  }

  // Check for personal calendar note reminders with precise timing
  Future<void> _checkPersonalCalendarReminders() async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole == null) return;

    try {
      final now = DateTime.now();
      final pastRange = now.subtract(Duration(minutes: 2));
      final futureRange = now.add(Duration(hours: 24));

      final eventsSnapshot = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .where('startTime', isGreaterThan: Timestamp.fromDate(pastRange))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(futureRange))
          .get();

      for (var eventDoc in eventsSnapshot.docs) {
        final eventData = eventDoc.data();
        await _checkAndCreateNotificationForEvent(eventDoc.id, eventData);
      }
    } catch (e) {
      print('❌ Error checking personal calendar reminders: $e');
    }
  }

  // Create notification for new items with integrated calendar creation
  // AFTER: Replace the _createNewItemStudentNotification method
  Future<void> _createNewItemStudentNotification({
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
      default:
        notificationTitle = '📢 New Item Posted';
        notificationBody = '$itemTitle has been posted';
    }

    print('📬 Creating enhanced notification for student: $studentId');
    print('📍 Path: organizations/$organizationCode/students/$studentId/notifications');

    // CREATE ENHANCED NOTIFICATION WITH COMPLETE NAVIGATION DATA
    await _firestore
        .collection('organizations')
        .doc(organizationCode)
        .collection('students')
        .doc(studentId)
        .collection('notifications')
        .add({
      'title': notificationTitle,
      'body': notificationBody,
      'type': 'NotificationType.$itemType',
      'sourceId': sourceId,
      'sourceType': itemType,
      'courseId': courseId,                  // ✅ CRITICAL: Always include courseId
      'courseName': courseName,              // ✅ ENHANCED: Add course name
      'organizationCode': organizationCode,  // ✅ CRITICAL: Always include org code
      'itemTitle': itemTitle,                // ✅ ENHANCED: Add item title for reference
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      // ✅ ENHANCED: Add navigation hints
      'navigationData': {
        'sourceId': sourceId,
        'courseId': courseId,
        'orgCode': organizationCode,
        'type': itemType,
        'title': itemTitle,
      },
    });

    print('✅ Created enhanced notification for student: $studentId');
  }

  // Method to create calendar events for students
  Future<void> _createCalendarEvent({
    required String organizationCode,
    required String studentId,
    required String itemTitle,
    required DateTime dueDate,
    required String itemType,
    required String sourceId,
    String? courseId,
  }) async {
    try {
      print('📅 Creating calendar event for student: $studentId');
      print('📍 Path: organizations/$organizationCode/students/$studentId/calendar_events');

      await _firestore
          .collection('organizations')
          .doc(organizationCode)
          .collection('students')
          .doc(studentId)
          .collection('calendar_events')
          .add({
        'title': itemTitle, // Just use the title directly
        'description': _getCalendarEventDescription(itemType),
        'startTime': Timestamp.fromDate(dueDate),
        'endTime': Timestamp.fromDate(dueDate),
        'color': _getCalendarEventColor(itemType),
        'calendar': _getCalendarCategory(itemType),
        'eventType': 0, // EventType.normal.index
        'recurrenceType': 0, // RecurrenceType.none.index
        'reminderMinutes': 1440, // 24 hours before
        'location': '',
        'isRecurring': false,
        'originalEventId': '',
        'sourceId': sourceId,
        'sourceType': itemType,
        'courseId': courseId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Created calendar event for student: $studentId');
    } catch (e) {
      print('❌ Error creating calendar event: $e');
    }
  }

  String _getCalendarEventDescription(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'assignment':
        return 'Assignment deadline';
      case 'tutorial':
        return 'Tutorial deadline';
      default:
        return 'Item deadline';
    }
  }

  int _getCalendarEventColor(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'assignment':
        return Colors.red.value; // RED for assignments
      case 'tutorial':
        return Colors.red.value; // RED for tutorials
      default:
        return Colors.purple.value;
    }
  }

  String _getCalendarCategory(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'assignment':
        return 'assignments';
      case 'tutorial':
        return 'tutorials';
      default:
        return 'general';
    }
  }

  // FIXED: Complete notification data with organizationCode
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
    if (_userOrgCode == null) return;

    try {
      Map<String, dynamic> notificationData = {
        'title': title,
        'body': body,
        'type': type.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'organizationCode': _userOrgCode,  // ✅ ADDED: Critical for navigation
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
      print('❌ Error creating student notification: $e');
    }
  }

  Future<void> _createReminderNotification({
    required String eventId,
    required Map<String, dynamic> eventData,
    required String reminderType,
    required String title,
    required String body,
    required int minutesUntil,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null) return;

    try {
      // Check if this exact reminder already exists to prevent duplicates
      // For edited events, clean up old reminders first
      final existingReminders = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .where('eventId', isEqualTo: eventId)
          .where('reminderType', isEqualTo: reminderType)
          .get();

// Delete existing reminders for this event and reminder type
      final batch = _firestore.batch();
      for (var doc in existingReminders.docs) {
        batch.delete(doc.reference);
      }

      if (existingReminders.docs.isNotEmpty) {
        await batch.commit();
        print('🗑️ Cleaned up ${existingReminders.docs.length} old reminders for edited event');
      }

      String notificationType;
      if (eventData['sourceType'] == 'assignment') {
        notificationType = 'NotificationType.assignment';
      } else if (eventData['sourceType'] == 'tutorial') {
        notificationType = 'NotificationType.tutorial';
      } else {
        notificationType = 'NotificationType.reminder';
      }

      await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': notificationType,
        'eventId': eventId,
        'reminderType': reminderType, // '1day' or '10min'
        'sourceId': eventData['sourceId'],
        'sourceType': eventData['sourceType'] ?? '', // Handle null sourceType
        'courseId': eventData['courseId'],
        'organizationCode': _userOrgCode,
        'minutesUntilDue': minutesUntil,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('✅ Created $reminderType reminder for ${eventData['sourceType'] ?? 'personal'}: ${eventData['title']}');
    } catch (e) {
      print('❌ Error creating reminder notification: $e');
    }
  }


  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole == null) return;

    try {
      await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole == null) return;

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
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null || _userRole == null) return;

    try {
      await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  // Force reload notifications
  Future<void> forceReload() async {
    print('🔄 Force reloading notifications...');
    _isInitialized = false;
    await initialize();
  }

  // Dispose method
  Future<void> _dispose() async {
    _checkTimer?.cancel();
    await _calendarEventsSubscription?.cancel();
    await _notificationSubscription?.cancel();
  }

  // Public dispose method
  void dispose() {
    _dispose();
    _notificationCountController.close();
    _notificationsController.close();
  }

  // UPDATED: Find course ID from content - Made PUBLIC for dialog access
  Future<String?> findCourseIdFromContent(String orgCode, String sourceId, String sourceType) async {
    try {
      print('🔍 Searching for courseId in organization: $orgCode');
      print('📍 Looking for sourceId: $sourceId of type: $sourceType');

      // Search all courses for the content
      final coursesSnapshot = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .get();

      print('📚 Found ${coursesSnapshot.docs.length} courses to search');

      for (var courseDoc in coursesSnapshot.docs) {
        final courseId = courseDoc.id;
        print('🔍 Searching in course: $courseId');

        // Check assignments
        if (sourceType == 'assignment') {
          final assignmentDoc = await _firestore
              .collection('organizations')
              .doc(orgCode)
              .collection('courses')
              .doc(courseId)
              .collection('assignments')
              .doc(sourceId)
              .get();

          if (assignmentDoc.exists) {
            print('✅ Found assignment in course: $courseId');
            return courseId;
          }
        }

        // Check materials/tutorials
        if (sourceType == 'tutorial' || sourceType == 'learning') {
          final materialDoc = await _firestore
              .collection('organizations')
              .doc(orgCode)
              .collection('courses')
              .doc(courseId)
              .collection('materials')
              .doc(sourceId)
              .get();

          if (materialDoc.exists) {
            print('✅ Found material in course: $courseId');
            return courseId;
          }
        }
      }

      print('❌ Content not found in any course');
      return null;
    } catch (e) {
      print('❌ Error finding course ID: $e');
      return null;
    }
  }

  // NEW: Find course ID from event ID - Made PUBLIC for dialog access
  Future<String?> findCourseIdFromEventId(String orgCode, String eventId) async {
    try {
      print('🔍 Searching for courseId from eventId: $eventId');

      final user = _auth.currentUser;
      if (user == null) return null;

      // Get the calendar event first
      final eventDoc = await _firestore
          .collection('organizations')
          .doc(orgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .doc(eventId)
          .get();

      if (!eventDoc.exists) {
        print('❌ Calendar event not found');
        return null;
      }

      final eventData = eventDoc.data()!;
      final courseId = eventData['courseId'] as String?;

      if (courseId != null) {
        print('✅ Found courseId from event: $courseId');
        return courseId;
      }

      // If no direct courseId, try to find from sourceId and sourceType
      final sourceId = eventData['sourceId'] as String?;
      final sourceType = eventData['sourceType'] as String?;

      if (sourceId != null && sourceType != null) {
        print('🔍 Trying to find courseId from sourceId: $sourceId');
        return await findCourseIdFromContent(orgCode, sourceId, sourceType);
      }

      print('❌ No courseId found from event');
      return null;
    } catch (e) {
      print('❌ Error finding course ID from event: $e');
      return null;
    }
  }

  // Clean up existing test notifications in Firestore
  // This method is correct - keep it as is
  Future<void> cleanupTestNotifications() async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null) return;

    try {
      // Delete all test notifications
      final testNotifications = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .where('type', isEqualTo: 'test')
          .get();

      final batch = _firestore.batch();
      for (var doc in testNotifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('✅ Cleaned up ${testNotifications.docs.length} test notifications');
    } catch (e) {
      print('❌ Error cleaning up test notifications: $e');
    }
  }

  // Clean up duplicate notifications
  Future<void> _cleanupDuplicateNotifications() async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null) return;

    try {
      final notifications = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .get();

      // Group notifications by eventId + reminderType
      Map<String, List<QueryDocumentSnapshot>> grouped = {};

      for (var doc in notifications.docs) {
        final data = doc.data();
        final eventId = data['eventId'] as String?;
        final reminderType = data['reminderType'] as String?;

        if (eventId != null && reminderType != null) {
          final key = '${eventId}_$reminderType';
          grouped[key] = grouped[key] ?? [];
          grouped[key]!.add(doc);
        }
      }

      // Delete duplicates (keep only the first one)
      final batch = _firestore.batch();
      int deleteCount = 0;

      grouped.forEach((key, docs) {
        if (docs.length > 1) {
          // Sort by creation time and keep the first, delete the rest
          // Sort by creation time and keep the first, delete the rest
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return aTime.compareTo(bTime);
          });

          // Delete duplicates (skip the first one)
          for (int i = 1; i < docs.length; i++) {
            batch.delete(docs[i].reference);
            deleteCount++;
          }
        }
      });

      if (deleteCount > 0) {
        await batch.commit();
        print('🧹 Cleaned up $deleteCount duplicate notifications');
      }
    } catch (e) {
      print('❌ Error cleaning up duplicates: $e');
    }
  }

  // Clean up existing reminders for an event (add this method)
  Future<void> _cleanupExistingReminders(String eventId) async {
    final user = _auth.currentUser;
    if (user == null || _userOrgCode == null) return;

    try {
      final existingReminders = await _firestore
          .collection('organizations')
          .doc(_userOrgCode)
          .collection('students')
          .doc(user.uid)
          .collection('notifications')
          .where('eventId', isEqualTo: eventId)
          .get();

      if (existingReminders.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in existingReminders.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print('🗑️ Cleaned up ${existingReminders.docs.length} old reminders for modified event $eventId');
      }
    } catch (e) {
      print('❌ Error cleaning up existing reminders: $e');
    }
  }

  // Getters
  String? get userRole => _userRole;
  bool get isInitialized => _isInitialized;
}

// Notification types enum should be OUTSIDE the class
enum NotificationType {
  assignment,
  tutorial,
  quiz,              // ADD THIS LINE
  goal,
  reminder,
  announcement,
  learning,
  milestone,
  achievement,
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
  final String? courseName;
  final String? organizationCode;  // ADD THIS LINE
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
    this.courseName,
    this.organizationCode,  // ADD THIS LINE
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
      courseName: data['courseName'],              // ADD THIS LINE
      organizationCode: data['organizationCode'],  // ADD THIS LINE
      dueDate: data['dueDate'] != null ? (data['dueDate'] as Timestamp).toDate() : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    if (type == null) return NotificationType.reminder;

    String cleanType = type.toLowerCase();
    if (cleanType.contains('.')) {
      cleanType = cleanType.split('.').last;
    }

    switch (cleanType) {
      case 'assignment':
        return NotificationType.assignment;
      case 'tutorial':
        return NotificationType.tutorial;
      case 'quiz':                        // ADD THIS CASE
        return NotificationType.quiz;
      case 'goal':
        return NotificationType.goal;
      case 'announcement':
        return NotificationType.announcement;
      case 'reminder':
        return NotificationType.reminder;
      case 'learning':
        return NotificationType.learning;
      case 'milestone':
        return NotificationType.milestone;
      case 'achievement':
        return NotificationType.achievement;
      default:
        return NotificationType.reminder;
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
      case NotificationType.learning:
        return Colors.teal;
      case NotificationType.milestone:
        return Colors.amber;
      case NotificationType.achievement:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.assignment:
        return Icons.assignment;
      case NotificationType.tutorial:
        return Icons.book;
      case NotificationType.quiz:           // ADD THIS CASE
        return Icons.psychology;
      case NotificationType.goal:
        return Icons.flag;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.learning:
        return Icons.school;
      case NotificationType.milestone:
        return Icons.local_florist;
      case NotificationType.achievement:
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }
}

// FIXED: Notification dialog widgets
class NotificationDialog extends StatefulWidget {
  @override
  _NotificationDialogState createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Ensure notification service is initialized when dialog opens
    if (!_notificationService.isInitialized) {
      _notificationService.initialize();
    }
  }

  // DEBUG: Helper method to debug notification data
  void _debugNotificationData(NotificationModel notification) {
    print('🔍 DEBUG NOTIFICATION DATA:');
    print('   - ID: ${notification.id}');
    print('   - Title: ${notification.title}');
    print('   - Body: ${notification.body}');
    print('   - SourceId: ${notification.sourceId}');
    print('   - SourceType: ${notification.sourceType}');
    print('   - CourseId: ${notification.courseId}');
    print('   - CourseName: ${notification.courseName}');
    print('   - OrganizationCode: ${notification.organizationCode}');
    print('   - EventId: ${notification.eventId}');
    print('   - IsRead: ${notification.isRead}');
    print('   - Type: ${notification.type}');
  }

  // AFTER: Replace the entire _navigateToSource method in notification.dart
  Future<void> _navigateToSource(BuildContext context,
      NotificationModel notification) async {
    print(
        '🔍 Navigating to: ${notification.sourceType} - ${notification.title}');

    // Mark as read
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
    }

    // Get organization code
    String? orgCode = notification.organizationCode ??
        _notificationService.userOrgCode;
    if (orgCode == null) {
      _showNavigationError(context, 'Organization code missing');
      return;
    }

    // Close notification dialog first - but keep context reference for error handling
    Navigator.pop(context);

    // Get the main app context for error messages
    final scaffoldContext = Navigator
        .of(context, rootNavigator: true)
        .context;

    try {
      // FIXED: Handle different notification types more specifically

      // 1. Handle "New Material" or "New Tutorial" notifications specifically
      // 1. Handle "New Material" or "New Tutorial" notifications specifically
      if (notification.title.toLowerCase().contains('new material') ||
          notification.title.toLowerCase().contains('new tutorial')) {
        print('🔍 Detected new material notification');

        // Check if it's actually a quiz by looking at the sourceType or getting material data
        if (notification.sourceType == 'quiz') {
          print('🔍 New material is actually a quiz');
          await _navigateToQuiz(scaffoldContext, notification, orgCode);
          return;
        } else {
          // Check material type from Firestore if sourceType is not available
          try {
            final materialDoc = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(orgCode)
                .collection('courses')
                .doc(notification.courseId!)
                .collection('materials')
                .doc(notification.sourceId!)
                .get();

            if (materialDoc.exists) {
              final materialData = materialDoc.data()!;
              if (materialData['materialType'] == 'quiz') {
                print('🔍 Confirmed: New material is a quiz');
                await _navigateToQuiz(scaffoldContext, notification, orgCode);
                return;
              }
            }
          } catch (e) {
            print('❌ Error checking material type: $e');
          }

          // Default to tutorial navigation
          await _navigateToTutorialDirectly(
              scaffoldContext, notification, orgCode);
          return;
        }
      }

      // 2. Handle assignment due notifications
      if (notification.title.toLowerCase().contains('assignment due')) {
        print('🔍 Detected assignment due notification');
        await _navigateToAssignmentWithStatusCheck(
            scaffoldContext, notification, orgCode);
        return;
      }

      // 3. Handle based on notification type
      // 3. Handle "New Goal Set" notifications BEFORE type-based switching
      if (notification.title.toLowerCase().contains('new goal set')) {
        print('🔍 Detected new goal set notification');
        await _navigateToSetGoalsPage(scaffoldContext, notification);
        return;
      }

      switch (notification.type) {
        case NotificationType.assignment:
          await _navigateToAssignmentWithStatusCheck(
              scaffoldContext, notification, orgCode);
          break;

        case NotificationType.tutorial:
          await _navigateToTutorialDirectly(
              scaffoldContext, notification, orgCode);
          break;

        case NotificationType.quiz:                    // ADD THIS CASE
          await _navigateToQuiz(scaffoldContext, notification, orgCode);
          break;

        case NotificationType.learning:
          await _navigateToLearningMaterial(
              scaffoldContext, notification, orgCode);
          break;

        case NotificationType.reminder:
          await _handleReminderNavigation(
              scaffoldContext, notification, orgCode);
          break;

        case NotificationType.goal:
        case NotificationType.milestone:
        case NotificationType.achievement:
          await _navigateToGoalPage(scaffoldContext, notification);
          break;

        default:
        // Handle based on sourceType as fallback
          if (notification.sourceType == 'assignment' &&
              notification.sourceId != null) {
            await _navigateToAssignmentWithStatusCheck(
                scaffoldContext, notification, orgCode);
          } else if (notification.sourceType == 'tutorial' &&
              notification.sourceId != null) {
            await _navigateToTutorialDirectly(
                scaffoldContext, notification, orgCode);
          } else if (notification.sourceType == 'learning' &&
              notification.sourceId != null) {
            await _navigateToLearningMaterial(
                scaffoldContext, notification, orgCode);
          } else if (notification.sourceType == 'quiz' &&
              notification.sourceId != null) {
            await _navigateToQuiz(scaffoldContext, notification, orgCode);
          } else if (notification.sourceType == 'goal' ||

              notification.sourceType == 'tree_goal' ||
              notification.title.toLowerCase().contains('halfway') ||
              notification.title.toLowerCase().contains('level up') ||
              notification.title.toLowerCase().contains('congratulations') ||
              notification.title.toLowerCase().contains('tree') ||
              notification.title.toLowerCase().contains('milestone') ||
              notification.title.toLowerCase().contains('achievement')) {
            // Handle tree/goal notifications that might not have the correct type
            await _navigateToGoalPage(scaffoldContext, notification);
          } else {
            _showNavigationError(
                scaffoldContext, 'Cannot open this notification type');
          }
      }
    } catch (e) {
      print('❌ Navigation error: $e');
      _showNavigationError(scaffoldContext, 'Navigation failed: $e');
    }
  }

  // Navigate to course page with tutorial modal
  Future<void> _navigateToTutorialDirectly(BuildContext context,
      NotificationModel notification, String orgCode) async {
    try {
      print('🔍 Direct tutorial navigation for: ${notification.sourceId}');

      // Find course ID if missing
      String? courseId = notification.courseId;
      if (courseId == null && notification.sourceId != null) {
        courseId = await _notificationService.findCourseIdFromContent(
            orgCode, notification.sourceId!, 'tutorial');
      }

      if (courseId == null) {
        _showNavigationError(context, 'Tutorial course not found');
        return;
      }

      // Load course data
      final courseDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .get();

      if (!courseDoc.exists) {
        _showNavigationError(context, 'Course not found');
        return;
      }

      final courseData = {'id': courseId, ...courseDoc.data()!};

      // Navigate to course page with highlighted material
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              StudentCoursePage(
                courseId: courseId!,
                courseData: courseData,
                highlightMaterialId: notification
                    .sourceId, // This passes the tutorial ID
              ),
        ),
      );

      print(
          '✅ Successfully navigated to course page with tutorial highlighted');
    } catch (e) {
      print('❌ Error in direct tutorial navigation: $e');
      _showNavigationError(context, 'Failed to load tutorial: $e');
    }
  }

  // Add this new method for navigating to calendar events
  Future<void> _navigateToCalendarEvent(BuildContext context,
      NotificationModel notification, String orgCode) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showNavigationError(context, 'User not authenticated');
        return;
      }

      // Get the calendar event
      final eventDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .doc(notification.eventId!)
          .get();

      if (!eventDoc.exists) {
        _showNavigationError(context, 'Calendar event not found');
        return;
      }

      final eventData = eventDoc.data()!;
      final eventDateTime = (eventData['startTime'] as Timestamp).toDate();

      // Create CalendarEvent object for the event details
      final calendarEvent = CalendarEvent.fromMap(
          notification.eventId!, eventData);

      // Navigate to calendar page with the specific date selected
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CalendarPage(
                selectedDate: eventDateTime,
                autoShowEventId: notification
                    .eventId, // Pass the event ID to auto-show
              ),
        ),
      );
    } catch (e) {
      _showNavigationError(context, 'Failed to navigate to calendar event: $e');
    }
  }

  // NEW: Navigate to goal page for tree rewards and milestones
  Future<void> _navigateToGoalPage(BuildContext context,
      NotificationModel notification) async {
    try {
      print('🌳 Navigating to goal page for: ${notification.title}');

      // Import the goal page
      // Note: You'll need to add this import at the top of notification.dart
      // import '../Stu_goal.dart';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StuGoal(),
        ),
      );

      print('✅ Successfully navigated to goal page');
    } catch (e) {
      print('❌ Error navigating to goal page: $e');
      _showNavigationError(context, 'Failed to open goal page: $e');
    }
  }

  // Navigate to Set Goals page for goal management notifications
  Future<void> _navigateToSetGoalsPage(BuildContext context,
      NotificationModel notification) async {
    try {
      print('🎯 Navigating to Set Goals page for: ${notification.title}');

      // Import the set goals page
      // Note: You'll need to add this import at the top of notification.dart
      // import '../set_goal.dart';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SetGoalPage(),
        ),
      );

      print('✅ Successfully navigated to Set Goals page');
    } catch (e) {
      print('❌ Error navigating to Set Goals page: $e');
      _showNavigationError(context, 'Failed to open Set Goals page: $e');
    }
  }

  // NEW: Handle reminder notifications
  Future<void> _handleReminderNavigation(BuildContext context,
      NotificationModel notification, String orgCode) async {
    try {
      if (notification.eventId != null) {
        // Check if it's a personal calendar event (no sourceType or sourceId)
        if (notification.sourceType == null || notification.sourceType == '') {
          await _navigateToCalendarEvent(context, notification, orgCode);
          return;
        }

        // Handle assignment/tutorial reminders
        final courseId = await _notificationService.findCourseIdFromEventId(
            orgCode, notification.eventId!);
        if (courseId != null && notification.sourceId != null) {
          final updatedNotification = NotificationModel(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            type: notification.type,
            eventId: notification.eventId,
            sourceId: notification.sourceId,
            sourceType: notification.sourceType,
            courseId: courseId,
            organizationCode: orgCode,
            dueDate: notification.dueDate,
            createdAt: notification.createdAt,
            isRead: notification.isRead,
          );

          if (notification.sourceType == 'assignment') {
            await _navigateToAssignmentWithStatusCheck(
                context, updatedNotification, orgCode);
          } else if (notification.sourceType == 'tutorial') {
            await _navigateToTutorialDirectly(
                context, updatedNotification, orgCode);
          }
        } else {
          _showNavigationError(context, 'Cannot find related content');
        }
      } else {
        _showNavigationError(context, 'Cannot open reminder notification');
      }
    } catch (e) {
      _showNavigationError(context, 'Failed to handle reminder: $e');
    }
  }

  Future<void> _navigateToAssignmentWithStatusCheck(BuildContext context,
      NotificationModel notification, String orgCode) async {
    try {
      if (!mounted) return;

      // Find course ID if missing
      String? courseId = notification.courseId;
      if (courseId == null) {
        if (notification.sourceId != null) {
          courseId = await _notificationService.findCourseIdFromContent(
              orgCode, notification.sourceId!, 'assignment');
        }
        if (courseId == null && notification.eventId != null) {
          courseId = await _notificationService.findCourseIdFromEventId(
              orgCode, notification.eventId!);
        }
        if (courseId == null) {
          _showNavigationError(context, 'Assignment not found');
          return;
        }
      }

      String? assignmentId = notification.sourceId;
      if (assignmentId == null && notification.eventId != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final eventDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(orgCode)
              .collection('students')
              .doc(user.uid)
              .collection('calendar_events')
              .doc(notification.eventId!)
              .get();

          if (eventDoc.exists) {
            assignmentId = eventDoc.data()?['sourceId'];
          }
        }
      }

      if (assignmentId == null) {
        _showNavigationError(context, 'Assignment ID not found');
        return;
      }

      // Check assignment status by looking at submissions
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final submissionSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(courseId)
            .collection('assignments')
            .doc(assignmentId)
            .collection('submissions')
            .where('studentId', isEqualTo: user.uid)
            .get();

        bool isCompleted = false;
        if (submissionSnapshot.docs.isNotEmpty) {
          // Sort manually to avoid composite index
          final sortedDocs = submissionSnapshot.docs.toList();
          sortedDocs.sort((a, b) {
            final aTime = a.data()['submittedAt'] as Timestamp?;
            final bTime = b.data()['submittedAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          final submission = sortedDocs.first.data();
          isCompleted =
              submission['grade'] != null; // Check if graded (completed)
        }

        if (isCompleted) {
          // Navigate to My Submissions page (completed assignment)
          final assignmentDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(orgCode)
              .collection('courses')
              .doc(courseId)
              .collection('assignments')
              .doc(assignmentId)
              .get();

          if (assignmentDoc.exists && mounted) {
            final assignmentData = {
              'id': assignmentDoc.id,
              ...assignmentDoc.data()!
            };

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    StudentSubmissionView(
                      courseId: courseId!,
                      assignmentId: assignmentId!,
                      assignmentData: assignmentData,
                      organizationCode: orgCode,
                    ),
              ),
            );
            return;
          }
        }
      }

      // If not completed or no submission, navigate to assignment details (pending)
      await _navigateToAssignment(context, notification, orgCode);
    } catch (e) {
      if (mounted) {
        _showNavigationError(context, 'Failed to check assignment status');
      }
    }
  }

  Future<void> _navigateToAssignment(BuildContext context,
      NotificationModel notification, String orgCode) async {
    try {
      // Find course ID if missing
      String? courseId = notification.courseId;
      if (courseId == null) {
        courseId = await _notificationService.findCourseIdFromContent(
            orgCode, notification.sourceId!, 'assignment');
        if (courseId == null) {
          _showNavigationError(context, 'Assignment not found');
          return;
        }
      }

      // Load assignment and course data
      final assignmentDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('assignments')
          .doc(notification.sourceId!)
          .get();

      final courseDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .get();

      if (!assignmentDoc.exists || !courseDoc.exists) {
        _showNavigationError(context, 'Assignment or course not found');
        return;
      }

      final assignmentData = {'id': assignmentDoc.id, ...assignmentDoc.data()!};
      final courseData = {'id': courseId, ...courseDoc.data()!};

      // Check if user has submitted and if it's graded
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final submissionSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(courseId)
            .collection('assignments')
            .doc(notification.sourceId!)
            .collection('submissions')
            .where('studentId', isEqualTo: user.uid)
            .get();

        if (submissionSnapshot.docs.isNotEmpty) {
          final submission = submissionSnapshot.docs.first.data();
          final isGraded = submission['grade'] != null;

          if (isGraded) {
            // Navigate to My Submissions page if graded
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    StudentSubmissionView(
                      courseId: courseId!,
                      assignmentId: notification.sourceId!,
                      assignmentData: assignmentData,
                      organizationCode: orgCode,
                    ),
              ),
            );
            return;
          }
        }
      }

      // Navigate to assignment details page if not graded or not submitted
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              StudentAssignmentDetailsPage(
                assignment: assignmentData,
                courseId: courseId!,
                courseData: courseData,
                organizationCode: orgCode,
              ),
        ),
      );
    } catch (e) {
      _showNavigationError(context, 'Failed to load assignment');
    }
  }

  Future<void> _navigateToLearningMaterial(BuildContext context,
      NotificationModel notification, String orgCode) async {
    try {
      // Find course ID if missing
      String? courseId = notification.courseId;
      if (courseId == null) {
        courseId = await _notificationService.findCourseIdFromContent(
            orgCode, notification.sourceId!, 'learning');
        if (courseId == null) {
          _showNavigationError(context, 'Learning material not found');
          return;
        }
      }

      // Load course data
      final courseDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .get();

      if (!courseDoc.exists) {
        _showNavigationError(context, 'Course not found');
        return;
      }

      final courseData = {'id': courseId, ...courseDoc.data()!};

      // Navigate to course page (materials tab)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              StudentCoursePage(
                courseId: courseId!,
                courseData: courseData,
              ),
        ),
      );
    } catch (e) {
      _showNavigationError(context, 'Failed to load learning material');
    }
  }

  Future<void> _navigateToTutorial(BuildContext context,
      NotificationModel notification, String orgCode) async {
    try {
      // Find course ID if missing
      String? courseId = notification.courseId;
      if (courseId == null) {
        courseId = await _notificationService.findCourseIdFromContent(
            orgCode, notification.sourceId!, 'tutorial');
        if (courseId == null) {
          _showNavigationError(context, 'Tutorial not found');
          return;
        }
      }

      // Load the material data first to determine if it's a tutorial
      final materialDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('materials')
          .doc(notification.sourceId!)
          .get();

      if (!materialDoc.exists) {
        _showNavigationError(context, 'Tutorial not found');
        return;
      }

      final materialData = {'id': materialDoc.id, ...materialDoc.data()!};

      // Check if this is actually a tutorial
      if (materialData['materialType'] == 'tutorial') {
        // For tutorials, navigate directly to the tutorial submission view
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StudentTutorialSubmissionView(
                  courseId: courseId!,
                  materialId: notification.sourceId!,
                  materialData: materialData,
                  organizationCode: orgCode,
                ),
          ),
        );
      } else {
        // For other materials, navigate to course page
        final courseDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(courseId)
            .get();

        if (!courseDoc.exists) {
          _showNavigationError(context, 'Course not found');
          return;
        }

        final courseData = {'id': courseId, ...courseDoc.data()!};

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StudentCoursePage(
                  courseId: courseId!,
                  courseData: courseData,
                  highlightMaterialId: notification.sourceId,
                ),
          ),
        );
      }
    } catch (e) {
      _showNavigationError(context, 'Failed to load tutorial: $e');
    }
  }

// NEW: Navigate to quiz
  Future<void> _navigateToQuiz(BuildContext context, NotificationModel notification, String orgCode) async {
    try {
      print('🎯 Navigating to quiz: ${notification.sourceId}');

      // Find course ID if missing
      String? courseId = notification.courseId;
      if (courseId == null && notification.sourceId != null) {
        courseId = await _notificationService.findCourseIdFromContent(orgCode, notification.sourceId!, 'quiz');
      }

      if (courseId == null) {
        _showNavigationError(context, 'Quiz not found');
        return;
      }

      // Load quiz material data
      final materialDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('materials')
          .doc(notification.sourceId!)
          .get();

      if (!materialDoc.exists) {
        _showNavigationError(context, 'Quiz not found');
        return;
      }

      final quizData = {'id': materialDoc.id, ...materialDoc.data()!};

      // Navigate directly to quiz submission page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentQuizSubmissionPage(
            courseId: courseId!,
            quizId: notification.sourceId!,
            quizData: quizData,
            organizationCode: orgCode,
          ),
        ),
      );

      print('✅ Successfully navigated to quiz');
    } catch (e) {
      print('❌ Error navigating to quiz: $e');
      _showNavigationError(context, 'Failed to load quiz: $e');
    }
  }

// FIXED _showNavigationError method with mounted check
void _showNavigationError(BuildContext context, String message) {
    // Check if the widgets is still mounted and context is valid
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('❌ Error showing navigation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            // Replace the header Container in the NotificationDialog build method with this:

// Header - FIXED to prevent overflow
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Left side - icon and title
                  Icon(Icons.notifications, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16, // Reduced from 18
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Right side - actions with fixed spacing
                  GestureDetector(
                    onTap: () => _notificationService.markAllAsRead(),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Mark all read',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10, // Slightly larger for readability
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8), // Fixed spacing
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Notifications list
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: _notificationService.notificationsStream,
                builder: (context, snapshot) {
                  print('🔍 NotificationDialog StreamBuilder state:');
                  print('   - connectionState: ${snapshot.connectionState}');
                  print('   - hasData: ${snapshot.hasData}');
                  print('   - data length: ${snapshot.data?.length ?? 0}');
                  print('   - hasError: ${snapshot.hasError}');

                  if (snapshot.hasError) {
                    print('   - error: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            'Error loading notifications',
                            style: TextStyle(color: Colors.red),
                          ),
                          Text(
                            '${snapshot.error}',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _notificationService.forceReload(),
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading notifications...'),
                        ],
                      ),
                    );
                  }

                  // Add a retry button if no data
                  if (!snapshot.hasData && snapshot.connectionState == ConnectionState.active) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sync_problem, size: 48, color: Colors.orange),
                          SizedBox(height: 16),
                          Text('Notifications not loading'),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _notificationService.forceReload(),
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final notifications = snapshot.data ?? [];

                  if (notifications.isEmpty) {
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

                  // Show notifications list
                  return ListView.separated(
                    padding: EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return NotificationCard(
                        notification: notification,
                        onTap: () async {
                          // DEBUG: Enhanced tap logging
                          print('🔍 NOTIFICATION CARD TAPPED:');
                          print('   - Title: ${notification.title}');
                          print('   - SourceId: ${notification.sourceId}');
                          print('   - SourceType: ${notification.sourceType}');
                          print('   - CourseId: ${notification.courseId}');
                          print('   - OrgCode: ${notification.organizationCode}');

                          // Enhanced navigation call with better error handling
                          await _navigateToSource(context, notification);
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
} // ← FIXED: Missing closing brace for _NotificationDialogState class

// FIXED: NotificationCard moved OUTSIDE the class and properly structured
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
        onTap: () {
          print('🟡 NOTIFICATION CARD InkWell onTap triggered');
          onTap();
        },
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

              // Content - FIXED with Expanded
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
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
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

              // Delete button - FIXED size
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                  onPressed: onDelete,
                ),
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