import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Authentication/custom_widgets.dart';

class EvaluationRubricPage extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final Map<String, dynamic> assignmentData;
  final String organizationCode;

  const EvaluationRubricPage({
    Key? key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentData,
    required this.organizationCode,
  }) : super(key: key);

  @override
  _EvaluationRubricPageState createState() => _EvaluationRubricPageState();
}

class _EvaluationRubricPageState extends State<EvaluationRubricPage> {
  bool isLoading = true;
  Map<String, dynamic>? existingRubric;
  List<Map<String, dynamic>> criteriaList = [];
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadRubric();
  }

  Future<void> _loadRubric() async {
    try {
      final rubricDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('rubric')
          .doc('main')
          .get();

      if (rubricDoc.exists) {
        setState(() {
          existingRubric = rubricDoc.data();
          criteriaList = List<Map<String, dynamic>>.from(
            existingRubric!['criteria'] ?? [],
          );
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading rubric: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _addCriterion() {
    setState(() {
      criteriaList.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': '',
        'description': '',
        'weight': 0,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': ''},
          {'name': 'Good', 'points': 3, 'description': ''},
          {'name': 'Satisfactory', 'points': 2, 'description': ''},
          {'name': 'Needs Improvement', 'points': 1, 'description': ''},
        ],
      });
      isEditing = true;
    });
  }

  void _removeCriterion(int index) {
    setState(() {
      criteriaList.removeAt(index);
      isEditing = true;
    });
  }

  Future<void> _saveRubric() async {
    // Validate rubric
    if (criteriaList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one criterion')),
      );
      return;
    }

    // Check if all criteria have names and valid weights
    double totalWeight = 0;
    for (var criterion in criteriaList) {
      if (criterion['name'].toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All criteria must have names')),
        );
        return;
      }
      totalWeight += (criterion['weight'] ?? 0).toDouble();
    }

    if (totalWeight != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Total weight must equal 100% (currently ${totalWeight.toStringAsFixed(1)}%)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final rubricData = {
        'criteria': criteriaList,
        'totalPoints': widget.assignmentData['points'] ?? 100,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      };

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('rubric')
          .doc('main')
          .set(rubricData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rubric saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        isEditing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving rubric: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Evaluation Rubric',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isEditing)
            TextButton.icon(
              onPressed: _saveRubric,
              icon: Icon(Icons.save),
              label: Text('Save'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.purple[600],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assignment Info Card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment, color: Colors.orange[700], size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.assignmentData['title'] ?? 'Assignment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.orange[800],
                          ),
                        ),
                        Text(
                          'Total Points: ${widget.assignmentData['points'] ?? 100}',
                          style: TextStyle(
                            color: Colors.orange[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Rubric Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Evaluation Criteria',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addCriterion,
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text('Add Criterion', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Weight Summary
            if (criteriaList.isNotEmpty) _buildWeightSummary(),

            // Criteria List
            if (criteriaList.isEmpty)
              Container(
                padding: EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.rule,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No evaluation criteria defined',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Click "Add Criterion" to create your rubric',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...criteriaList.asMap().entries.map((entry) {
                final index = entry.key;
                final criterion = entry.value;
                return _buildCriterionCard(criterion, index);
              }).toList(),

            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSummary() {
    double totalWeight = 0;
    for (var criterion in criteriaList) {
      totalWeight += (criterion['weight'] ?? 0).toDouble();
    }

    final isValid = totalWeight == 100;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? Colors.green[50] : Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid ? Colors.green[300]! : Colors.amber[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.warning,
            color: isValid ? Colors.green[700] : Colors.amber[700],
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Total Weight: ${totalWeight.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isValid ? Colors.green[700] : Colors.amber[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!isValid) ...[
            SizedBox(width: 8),
            Text(
              '(Must equal 100%)',
              style: TextStyle(
                color: Colors.amber[700],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriterionCard(Map<String, dynamic> criterion, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.purple[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Criterion name',
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                onChanged: (value) {
                  setState(() {
                    criterion['name'] = value;
                    isEditing = true;
                  });
                },
                controller: TextEditingController(text: criterion['name']),
              ),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Weight',
                  suffix: Text('%'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  setState(() {
                    criterion['weight'] = double.tryParse(value) ?? 0;
                    isEditing = true;
                  });
                },
                controller: TextEditingController(
                  text: criterion['weight'].toString(),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red[400]),
              onPressed: () => _removeCriterion(index),
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe what this criterion evaluates',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    setState(() {
                      criterion['description'] = value;
                      isEditing = true;
                    });
                  },
                  controller: TextEditingController(
                    text: criterion['description'],
                  ),
                ),
                SizedBox(height: 16),

                // Performance Levels
                Text(
                  'Performance Levels',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 12),
                ...(criterion['levels'] as List).asMap().entries.map((levelEntry) {
                  final levelIndex = levelEntry.key;
                  final level = levelEntry.value;
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: 'Level Name',
                                  hintText: 'e.g., Excellent',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    level['name'] = value;
                                    isEditing = true;
                                  });
                                },
                                controller: TextEditingController(
                                  text: level['name'],
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: 'Points',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                onChanged: (value) {
                                  setState(() {
                                    level['points'] = int.tryParse(value) ?? 0;
                                    isEditing = true;
                                  });
                                },
                                controller: TextEditingController(
                                  text: level['points'].toString(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Describe performance at this level',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          maxLines: 2,
                          onChanged: (value) {
                            setState(() {
                              level['description'] = value;
                              isEditing = true;
                            });
                          },
                          controller: TextEditingController(
                            text: level['description'],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}