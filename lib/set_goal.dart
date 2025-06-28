import 'package:flutter/material.dart';

class Goal {
  String id;
  String title;
  String description;
  bool isCompleted;
  bool isStarred;
  DateTime createdDate;
  DateTime? targetDate;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.isStarred = false,
    required this.createdDate,
    this.targetDate,
  });
}

class SetGoalPage extends StatefulWidget {
  final Function(String)? onGoalStarred;

  const SetGoalPage({Key? key, this.onGoalStarred}) : super(key: key);

  @override
  _SetGoalPageState createState() => _SetGoalPageState();
}

class _SetGoalPageState extends State<SetGoalPage> {
  List<Goal> goals = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedTargetDate;
  String? _editingGoalId;

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
                  onPressed: () {
                    _saveGoal();
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

  void _saveGoal() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a goal title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      if (_editingGoalId != null) {
        // Update existing goal
        int index = goals.indexWhere((g) => g.id == _editingGoalId);
        if (index != -1) {
          goals[index].title = _titleController.text.trim();
          goals[index].description = _descriptionController.text.trim();
          goals[index].targetDate = _selectedTargetDate;
        }
      } else {
        // Add new goal
        goals.add(Goal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          createdDate: DateTime.now(),
          targetDate: _selectedTargetDate,
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_editingGoalId != null ? 'Goal updated successfully!' : 'Goal added successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _toggleStarred(String goalId) {
    setState(() {
      // First unstar all goals (only one can be starred at a time)
      for (var goal in goals) {
        goal.isStarred = false;
      }

      // Then star the selected goal
      int index = goals.indexWhere((g) => g.id == goalId);
      if (index != -1) {
        goals[index].isStarred = true;

        // Get the starred goal
        Goal starredGoal = goals[index];
        print('Starring goal: ${starredGoal.title}'); // Debug print

        // Call the callback function to update main page
        if (widget.onGoalStarred != null) {
          widget.onGoalStarred!(starredGoal.title);
        }

        // Show success message but don't navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${starredGoal.title} is now your mission in progress! ⭐'),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _toggleGoalCompletion(String goalId) {
    setState(() {
      int index = goals.indexWhere((g) => g.id == goalId);
      if (index != -1) {
        goals[index].isCompleted = !goals[index].isCompleted;
      }
    });

    Goal goal = goals.firstWhere((g) => g.id == goalId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(goal.isCompleted ? 'Goal completed! 🎉' : 'Goal marked as incomplete'),
        backgroundColor: goal.isCompleted ? Colors.green : Colors.orange,
      ),
    );
  }

  void _deleteGoal(String goalId) {
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
              onPressed: () {
                setState(() {
                  goals.removeWhere((g) => g.id == goalId);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Goal deleted successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
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

                              // Star icon
                              GestureDetector(
                                onTap: () => _toggleStarred(goal.id),
                                child: Icon(
                                  goal.isStarred ? Icons.star : Icons.star_border,
                                  color: goal.isStarred ? Colors.amber : Colors.grey[400],
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