import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification.dart';

// Enums for calendar event types
enum EventType { normal, assignment, exam }
enum RecurrenceType { none, daily, weekly, monthly }

class Goal {
  String id;
  String title;
  String description;
  bool isCompleted;
  bool isPinned;
  DateTime createdDate;
  DateTime? targetDate;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.isPinned = false,
    required this.createdDate,
    this.targetDate,
  });

  factory Goal.fromMap(Map<String, dynamic> data) {
    return Goal(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      isPinned: data['isPinned'] ?? false,
      createdDate: data['createdDate'] != null && data['createdDate'] is Timestamp
          ? (data['createdDate'] as Timestamp).toDate()
          : DateTime.now(),
      targetDate: data['targetDate'] != null && data['targetDate'] is Timestamp
          ? (data['targetDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'isPinned': isPinned,
      'createdDate': Timestamp.fromDate(createdDate),
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
    };
  }
}

class SetGoalPage extends StatefulWidget {
  final Function(String)? onGoalPinned;

  const SetGoalPage({Key? key, this.onGoalPinned}) : super(key: key);

  @override
  _SetGoalPageState createState() => _SetGoalPageState();
}

class _SetGoalPageState extends State<SetGoalPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Goal> goals = [];
  bool isLoading = true;
  String? organizationCode;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedTargetDate;
  TimeOfDay? _selectedTargetTime;
  String? _editingGoalId;

  String? get userId => _auth.currentUser?.uid;

  CollectionReference get _goalsRef {
    if (userId == null) throw Exception('User not authenticated');
    return _firestore
        .collection('goalProgress')
        .doc(userId)
        .collection('goals');
  }

  DocumentReference get _goalProgressRef {
    if (userId == null) throw Exception('User not authenticated');
    return _firestore.collection('goalProgress').doc(userId);
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadGoals();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          organizationCode = userDoc.data()?['organizationCode'];
        });
      }
    }
  }

  Future<void> _loadGoals() async {
    try {
      setState(() {
        isLoading = true;
      });

      _goalsRef
          .orderBy('createdDate', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            goals = snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return Goal.fromMap(data);
            }).toList();
            isLoading = false;
          });
        }
      });
    } catch (e) {
      print('Error loading goals: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showAddEditGoalDialog({Goal? goal}) {
    _titleController.clear();
    _descriptionController.clear();
    _selectedTargetDate = null;
    _selectedTargetTime = null;
    _editingGoalId = null;

    if (goal != null) {
      _titleController.text = goal.title;
      _descriptionController.text = goal.description;
      _selectedTargetDate = goal.targetDate;
      if (goal.targetDate != null) {
        _selectedTargetTime = TimeOfDay(
          hour: goal.targetDate!.hour,
          minute: goal.targetDate!.minute,
        );
      }
      _editingGoalId = goal.id;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(goal == null ? 'Add New Goal' : 'Edit Goal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Goal Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      maxLength: 50,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      maxLength: 200,
                    ),
                    SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedTargetDate ?? DateTime.now().add(Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          setDialogState(() {
                            _selectedTargetDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.grey[600]),
                            SizedBox(width: 12),
                            Text(
                              _selectedTargetDate == null
                                  ? 'Select Target Date (Optional)'
                                  : 'Target: ${_selectedTargetDate!.day}/${_selectedTargetDate!.month}/${_selectedTargetDate!.year}',
                              style: TextStyle(
                                color: _selectedTargetDate == null ? Colors.grey[600] : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedTargetDate != null) ...[
                      SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: _selectedTargetTime ?? TimeOfDay(hour: 23, minute: 59),
                          );
                          if (pickedTime != null) {
                            setDialogState(() {
                              _selectedTargetTime = pickedTime;
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.grey[600]),
                              SizedBox(width: 12),
                              Text(
                                _selectedTargetTime == null
                                    ? '11:59 PM'
                                    : _selectedTargetTime!.format(context),
                                style: TextStyle(color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _saveGoal();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(goal == null ? 'Add Goal' : 'Update Goal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveGoal() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a goal title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      DateTime? finalTargetDateTime;
      if (_selectedTargetDate != null) {
        finalTargetDateTime = DateTime(
          _selectedTargetDate!.year,
          _selectedTargetDate!.month,
          _selectedTargetDate!.day,
          _selectedTargetTime?.hour ?? 23,
          _selectedTargetTime?.minute ?? 59,
        );
      }

      if (_editingGoalId != null) {
        // Update existing goal in Firebase
        await _goalsRef.doc(_editingGoalId).update({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'targetDate': finalTargetDateTime != null ? Timestamp.fromDate(finalTargetDateTime) : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update calendar event if target date changed
        if (finalTargetDateTime != null) {
          await _updateGoalCalendarEvent(_editingGoalId!, _titleController.text.trim(), finalTargetDateTime);
        } else {
          await _deleteGoalCalendarEvent(_editingGoalId!);
        }
      } else {
        // Add new goal to Firebase
        final goalData = {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'isCompleted': false,
          'isPinned': false,
          'createdDate': FieldValue.serverTimestamp(),
          'targetDate': finalTargetDateTime != null ? Timestamp.fromDate(finalTargetDateTime) : null,
          'createdBy': userId,
        };

        final goalRef = await _goalsRef.add(goalData);

        // Create calendar event if goal has a target date
        if (finalTargetDateTime != null) {
          await _createGoalCalendarEvent(goalRef.id, _titleController.text.trim(), finalTargetDateTime);
        }

        // Create notification for new goal
        await NotificationService().createNewItemNotification(
          itemType: 'goal',
          itemTitle: _titleController.text.trim(),
          dueDate: finalTargetDateTime,
          sourceId: goalRef.id,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingGoalId != null ? 'Goal updated successfully!' : 'Goal added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving goal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createGoalCalendarEvent(String goalId, String goalTitle, DateTime targetDate) async {
    try {
      if (organizationCode == null) {
        await _fetchUserData();
        if (organizationCode == null) return;
      }

      await _firestore
          .collection('organizations')
          .doc(organizationCode)
          .collection('students')
          .doc(userId)
          .collection('calendar_events')
          .add({
        'title': '🎯 Goal: $goalTitle',
        'description': 'Goal deadline',
        'startTime': Timestamp.fromDate(targetDate),
        'endTime': Timestamp.fromDate(targetDate),
        'color': Colors.purple.value,
        'calendar': 'goals',
        'eventType': EventType.normal.index,
        'recurrenceType': RecurrenceType.none.index,
        'reminderMinutes': 1440, // 24 hours before
        'location': '',
        'isRecurring': false,
        'originalEventId': '',
        'sourceId': goalId,
        'sourceType': 'goal',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Created calendar event for goal: $goalTitle');
    } catch (e) {
      print('Error creating goal calendar event: $e');
    }
  }

  Future<void> _updateGoalCalendarEvent(String goalId, String goalTitle, DateTime targetDate) async {
    try {
      if (organizationCode == null) return;

      final eventsQuery = await _firestore
          .collection('organizations')
          .doc(organizationCode)
          .collection('students')
          .doc(userId)
          .collection('calendar_events')
          .where('sourceId', isEqualTo: goalId)
          .where('sourceType', isEqualTo: 'goal')
          .get();

      if (eventsQuery.docs.isNotEmpty) {
        final eventDoc = eventsQuery.docs.first;
        await eventDoc.reference.update({
          'title': '🎯 Goal: $goalTitle',
          'startTime': Timestamp.fromDate(targetDate),
          'endTime': Timestamp.fromDate(targetDate),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _createGoalCalendarEvent(goalId, goalTitle, targetDate);
      }
    } catch (e) {
      print('Error updating goal calendar event: $e');
    }
  }

  Future<void> _deleteGoalCalendarEvent(String goalId) async {
    try {
      if (organizationCode == null) return;

      final eventsQuery = await _firestore
          .collection('organizations')
          .doc(organizationCode)
          .collection('students')
          .doc(userId)
          .collection('calendar_events')
          .where('sourceId', isEqualTo: goalId)
          .where('sourceType', isEqualTo: 'goal')
          .get();

      for (var doc in eventsQuery.docs) {
        await doc.reference.delete();
      }

      print('✅ Deleted calendar event for goal');
    } catch (e) {
      print('Error deleting goal calendar event: $e');
    }
  }

  Future<void> _togglePinned(String goalId) async {
    try {
      Goal? goalToToggle = goals.firstWhere((g) => g.id == goalId);

      if (goalToToggle != null) {
        bool newPinState = !goalToToggle.isPinned;

        await _goalsRef.doc(goalId).update({
          'isPinned': newPinState,
        });

        // Update the pinned goals list in goalProgress
        final pinnedGoalsSnapshot = await _goalsRef
            .where('isPinned', isEqualTo: true)
            .get();

        List<String> pinnedGoalTitles = [];
        for (var doc in pinnedGoalsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (doc.id == goalId) {
            if (newPinState) {
              pinnedGoalTitles.add(goalToToggle.title);
            }
          } else {
            pinnedGoalTitles.add(data['title'] ?? '');
          }
        }

        await _goalProgressRef.update({
          'pinnedGoals': pinnedGoalTitles,
          'hasActiveGoal': pinnedGoalTitles.isNotEmpty,
          'currentGoal': pinnedGoalTitles.isNotEmpty
              ? pinnedGoalTitles.join(' • ')
              : "No goal selected - Press 'Set Goal' to choose one",
        });

        if (widget.onGoalPinned != null && pinnedGoalTitles.isNotEmpty) {
          widget.onGoalPinned!(pinnedGoalTitles.join(' • '));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  newPinState
                      ? '${goalToToggle.title} pinned to missions! 📌'
                      : '${goalToToggle.title} unpinned from missions!'),
              backgroundColor: newPinState ? Colors.amber : Colors.grey,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling pin: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleGoalCompletion(String goalId) async {
    try {
      Goal goal = goals.firstWhere((g) => g.id == goalId);
      await _goalsRef.doc(goalId).update({
        'isCompleted': !goal.isCompleted,
        'completedAt': !goal.isCompleted ? FieldValue.serverTimestamp() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!goal.isCompleted ? 'Goal completed! 🎉' : 'Goal marked as incomplete'),
            backgroundColor: !goal.isCompleted ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating goal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteGoal(String goalId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Goal'),
          content: Text('Are you sure you want to delete this goal? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Check if goal is pinned and update goalProgress accordingly
                  final goalDoc = await _goalsRef.doc(goalId).get();
                  if (goalDoc.exists && goalDoc.data() != null) {
                    final data = goalDoc.data() as Map<String, dynamic>;
                    if (data['isPinned'] == true) {
                      await _goalProgressRef.update({
                        'currentGoal': 'No goal selected - Press \'Set Goal\' to choose one',
                        'hasActiveGoal': false,
                      });
                    }
                  }

                  // Delete the goal and its calendar event
                  await _goalsRef.doc(goalId).delete();
                  await _deleteGoalCalendarEvent(goalId);

                  Navigator.of(context).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Goal deleted successfully'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting goal: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No target date';
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  int _getDaysRemaining(DateTime? targetDate) {
    if (targetDate == null) return 0;
    return targetDate.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Set Goals'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Set Goals'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.blue.withValues(alpha: 0.05)],
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: Colors.blueAccent,
                ),
                SizedBox(height: 12),
                Text(
                  'Achieve Your Dreams!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Set goals, track progress, and celebrate success',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Goals List
          Expanded(
            child: goals.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No goals yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add your first goal to get started!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                Goal goal = goals[index];
                int daysRemaining = _getDaysRemaining(goal.targetDate);

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: goal.isCompleted ? Colors.green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Completion checkbox
                              GestureDetector(
                                onTap: () => _toggleGoalCompletion(goal.id),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: goal.isCompleted ? Colors.green : Colors.grey,
                                      width: 2,
                                    ),
                                    color: goal.isCompleted ? Colors.green : Colors.transparent,
                                  ),
                                  child: goal.isCompleted
                                      ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                      : null,
                                ),
                              ),
                              SizedBox(width: 12),

                              // Goal title
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                                    color: goal.isCompleted ? Colors.grey[600] : Colors.black,
                                  ),
                                ),
                              ),

                              // Pin button
                              GestureDetector(
                                onTap: () => _togglePinned(goal.id),
                                child: Icon(
                                  goal.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                  color: goal.isPinned ? Colors.amber : Colors.grey[400],
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 8),

                              // Menu button
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showAddEditGoalDialog(goal: goal);
                                  } else if (value == 'delete') {
                                    _deleteGoal(goal.id);
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Description
                          if (goal.description.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Text(
                              goal.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],

                          SizedBox(height: 12),

                          // Date and status row
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey[500],
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Target: ${_formatDate(goal.targetDate)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),

                              // Days remaining badge
                              if (goal.targetDate != null && !goal.isCompleted) ...[
                                SizedBox(width: 16),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: daysRemaining <= 0
                                        ? Colors.red[100]
                                        : daysRemaining <= 3
                                        ? Colors.orange[100]
                                        : Colors.blue[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    daysRemaining <= 0
                                        ? 'Overdue'
                                        : '$daysRemaining days left',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: daysRemaining <= 0
                                          ? Colors.red[700]
                                          : daysRemaining <= 3
                                          ? Colors.orange[700]
                                          : Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],

                              // Completed badge
                              if (goal.isCompleted) ...[
                                Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: Colors.green[700],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Completed',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom action buttons
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showAddEditGoalDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Add New Goal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                if (goals.any((g) => g.isCompleted))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Goal? completedGoal = goals.where((g) => g.isCompleted).first;
                        print('Using completed goal: ${completedGoal.title}');
                        Navigator.pop(context, completedGoal.title);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Use Completed Goal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}