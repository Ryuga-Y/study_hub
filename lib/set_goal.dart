import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Goal {
  String id;
  String title;
  String description;
  bool isCompleted;
  bool isPinned; // Changed from isStarred
  DateTime createdDate;
  DateTime? targetDate;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.isPinned = false, // Changed from isStarred
    required this.createdDate,
    this.targetDate,
  });

  // Factory constructor to create Goal from Firebase data
  factory Goal.fromMap(Map<String, dynamic> data) {
    return Goal(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      isPinned: data['isPinned'] ?? false,
      createdDate: data['createdDate'] ?? DateTime.now(),
      targetDate: data['targetDate'],
    );
  }
}

class SetGoalPage extends StatefulWidget {
  final Function(String)? onGoalPinned; // Changed from onGoalStarred

  const SetGoalPage({Key? key, this.onGoalPinned}) : super(key: key);

  @override
  _SetGoalPageState createState() => _SetGoalPageState();
}

class _SetGoalPageState extends State<SetGoalPage> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Goal> goals = [];
  bool isLoading = true;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedTargetDate;
  String? _editingGoalId;

  // Get current user ID
  String? get userId => _auth.currentUser?.uid;

  // Get reference to user's goals subcollection
  CollectionReference get _goalsRef {
    if (userId == null) throw Exception('User not authenticated');
    return _firestore
        .collection('goalProgress')
        .doc(userId)
        .collection('goals');
  }

  // Get reference to goal progress document
  DocumentReference get _goalProgressRef {
    if (userId == null) throw Exception('User not authenticated');
    return _firestore.collection('goalProgress').doc(userId);
  }

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  // Load goals from Firebase
  Future<void> _loadGoals() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Listen to goals stream
      _goalsRef
          .orderBy('createdDate', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            goals = snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;

              // Convert Timestamp to DateTime if exists
              if (data['createdDate'] != null && data['createdDate'] is Timestamp) {
                data['createdDate'] = (data['createdDate'] as Timestamp).toDate();
              }
              if (data['targetDate'] != null && data['targetDate'] is Timestamp) {
                data['targetDate'] = (data['targetDate'] as Timestamp).toDate();
              }

              return Goal.fromMap(data);
            }).toList();
            isLoading = false;
          });
        }
      });
    } catch (e) {
      print('Error loading goals: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showAddEditGoalDialog({Goal? goal}) {
    // Reset form
    _titleController.clear();
    _descriptionController.clear();
    _selectedTargetDate = null;
    _editingGoalId = null;

    // If editing, populate form with existing data
    if (goal != null) {
      _titleController.text = goal.title;
      _descriptionController.text = goal.description;
      _selectedTargetDate = goal.targetDate;
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
      if (_editingGoalId != null) {
        // Update existing goal in Firebase
        await _goalsRef.doc(_editingGoalId).update({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'targetDate': _selectedTargetDate != null ? Timestamp.fromDate(_selectedTargetDate!) : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new goal to Firebase
        final goalId = _goalsRef.doc().id;

        await _goalsRef.doc(goalId).set({
          'id': goalId,
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'isCompleted': false,
          'isPinned': false,
          'createdDate': FieldValue.serverTimestamp(),
          'targetDate': _selectedTargetDate != null ? Timestamp.fromDate(_selectedTargetDate!) : null,
          'createdBy': userId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingGoalId != null ? 'Goal updated successfully!' : 'Goal added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving goal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _togglePinned(String goalId) async {
    try {
      // Find the goal
      Goal? goalToPin = goals.firstWhere((g) => g.id == goalId);

      if (goalToPin != null) {
        // Start a batch write
        final batch = _firestore.batch();

        // First, unpin all goals
        final allGoals = await _goalsRef.get();
        for (var doc in allGoals.docs) {
          batch.update(doc.reference, {'isPinned': false});
        }

        // Pin the selected goal
        batch.update(_goalsRef.doc(goalId), {'isPinned': true});

        // Update the main goal progress document
        batch.update(_goalProgressRef, {
          'currentGoal': goalToPin.title,
          'hasActiveGoal': true,
        });

        // Commit the batch
        await batch.commit();

        // Call the callback function to update main page
        if (widget.onGoalPinned != null) {
          widget.onGoalPinned!(goalToPin.title);
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${goalToPin.title} is now your mission in progress! 📌'),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error pinning goal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleGoalCompletion(String goalId) async {
    try {
      Goal goal = goals.firstWhere((g) => g.id == goalId);
      await _goalsRef.doc(goalId).update({
        'isCompleted': !goal.isCompleted,
        'completedAt': !goal.isCompleted ? FieldValue.serverTimestamp() : null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!goal.isCompleted ? 'Goal completed! 🎉' : 'Goal marked as incomplete'),
          backgroundColor: !goal.isCompleted ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating goal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
                  // Check if this goal is pinned
                  final goalDoc = await _goalsRef.doc(goalId).get();
                  if (goalDoc.exists && goalDoc.data() != null) {
                    final data = goalDoc.data() as Map<String, dynamic>;
                    if (data['isPinned'] == true) {
                      // If it's pinned, remove it from the main goal progress
                      await _goalProgressRef.update({
                        'currentGoal': 'No goal selected - Press \'Set Goal\' to choose one',
                        'hasActiveGoal': false,
                      });
                    }
                  }

                  // Delete the goal
                  await _goalsRef.doc(goalId).delete();

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Goal deleted successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting goal: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
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
    return '${date.day}/${date.month}/${date.year}';
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
          // Header section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blueAccent.withOpacity(0.1), Colors.blue.withOpacity(0.05)],
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

          // Goals list
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
                              // Checkbox
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

                              // Pin icon (changed from star)
                              GestureDetector(
                                onTap: () => _togglePinned(goal.id),
                                child: Icon(
                                  goal.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                  color: goal.isPinned ? Colors.amber : Colors.grey[400],
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 8),

                              // Action buttons
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

                          // Date and status info
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

          // Bottom section with add button and return to main
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Add Goal Button
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

                // Return to main with completed goal only
                if (goals.any((g) => g.isCompleted))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Find the most recently completed goal or first completed goal
                        Goal? completedGoal = goals.where((g) => g.isCompleted).first;
                        print('Using completed goal: ${completedGoal.title}'); // Debug print
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