import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


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

  // Template mode
  bool useTemplate = true;
  String? selectedTemplate;

  // Predefined rubric templates
  final Map<String, List<Map<String, dynamic>>> rubricTemplates = {
    'Essay': [
      {
        'name': 'Thesis & Argumentation',
        'description': 'Clear thesis statement and logical argument development',
        'weight': 30,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Compelling thesis with sophisticated argumentation'},
          {'name': 'Good', 'points': 3, 'description': 'Clear thesis with well-developed arguments'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Adequate thesis with basic arguments'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Unclear thesis or weak arguments'},
        ],
      },
      {
        'name': 'Evidence & Support',
        'description': 'Use of relevant evidence and examples',
        'weight': 25,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Strong evidence expertly integrated'},
          {'name': 'Good', 'points': 3, 'description': 'Good evidence well integrated'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Some evidence adequately used'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Insufficient or poorly used evidence'},
        ],
      },
      {
        'name': 'Organization & Structure',
        'description': 'Logical flow and paragraph organization',
        'weight': 25,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Exceptional organization with seamless transitions'},
          {'name': 'Good', 'points': 3, 'description': 'Well-organized with clear transitions'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Basic organization with some transitions'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor organization or confusing structure'},
        ],
      },
      {
        'name': 'Writing & Grammar',
        'description': 'Writing quality, grammar, and style',
        'weight': 20,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Exceptional writing with no errors'},
          {'name': 'Good', 'points': 3, 'description': 'Good writing with minimal errors'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Adequate writing with some errors'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor writing with many errors'},
        ],
      },
    ],
    'Programming': [
      {
        'name': 'Functionality',
        'description': 'Code works correctly and meets requirements',
        'weight': 40,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'All features work perfectly, exceeds requirements'},
          {'name': 'Good', 'points': 3, 'description': 'All required features work correctly'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Most features work with minor issues'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Major functionality issues'},
        ],
      },
      {
        'name': 'Code Quality',
        'description': 'Clean, readable, and well-structured code',
        'weight': 30,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Exceptional code quality and structure'},
          {'name': 'Good', 'points': 3, 'description': 'Clean and well-organized code'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Acceptable code quality'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor code quality'},
        ],
      },
      {
        'name': 'Documentation',
        'description': 'Comments and documentation quality',
        'weight': 15,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Comprehensive documentation'},
          {'name': 'Good', 'points': 3, 'description': 'Good documentation'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Basic documentation'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor or missing documentation'},
        ],
      },
      {
        'name': 'Testing',
        'description': 'Test coverage and quality',
        'weight': 15,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Comprehensive testing'},
          {'name': 'Good', 'points': 3, 'description': 'Good test coverage'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Basic testing'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Insufficient testing'},
        ],
      },
    ],
    'Presentation': [
      {
        'name': 'Content',
        'description': 'Quality and relevance of content',
        'weight': 35,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Exceptional content, highly relevant'},
          {'name': 'Good', 'points': 3, 'description': 'Good content, well-researched'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Adequate content'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor or irrelevant content'},
        ],
      },
      {
        'name': 'Delivery',
        'description': 'Speaking skills and engagement',
        'weight': 30,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Engaging and confident delivery'},
          {'name': 'Good', 'points': 3, 'description': 'Clear and professional delivery'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Adequate delivery'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor delivery'},
        ],
      },
      {
        'name': 'Visual Aids',
        'description': 'Quality of slides/visual materials',
        'weight': 20,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Professional and effective visuals'},
          {'name': 'Good', 'points': 3, 'description': 'Good visual support'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Basic visual aids'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor or distracting visuals'},
        ],
      },
      {
        'name': 'Time Management',
        'description': 'Appropriate use of time',
        'weight': 15,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Perfect timing'},
          {'name': 'Good', 'points': 3, 'description': 'Good time management'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Acceptable timing'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor time management'},
        ],
      },
    ],
    'Lab Report': [
      {
        'name': 'Methodology',
        'description': 'Experimental design and procedures',
        'weight': 30,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Exceptional methodology'},
          {'name': 'Good', 'points': 3, 'description': 'Good methodology'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Adequate methodology'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor methodology'},
        ],
      },
      {
        'name': 'Data Analysis',
        'description': 'Analysis and interpretation of results',
        'weight': 30,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Sophisticated analysis'},
          {'name': 'Good', 'points': 3, 'description': 'Good analysis'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Basic analysis'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor analysis'},
        ],
      },
      {
        'name': 'Conclusions',
        'description': 'Drawing appropriate conclusions',
        'weight': 25,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Insightful conclusions'},
          {'name': 'Good', 'points': 3, 'description': 'Good conclusions'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Basic conclusions'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor conclusions'},
        ],
      },
      {
        'name': 'Formatting',
        'description': 'Report structure and formatting',
        'weight': 15,
        'levels': [
          {'name': 'Excellent', 'points': 4, 'description': 'Perfect formatting'},
          {'name': 'Good', 'points': 3, 'description': 'Good formatting'},
          {'name': 'Satisfactory', 'points': 2, 'description': 'Acceptable formatting'},
          {'name': 'Needs Improvement', 'points': 1, 'description': 'Poor formatting'},
        ],
      },
    ],
  };

  // Quick criteria templates
  final Map<String, Map<String, dynamic>> quickCriteria = {
    'Critical Thinking': {
      'description': 'Analysis, evaluation, and synthesis of information',
      'weight': 25,
    },
    'Research Quality': {
      'description': 'Depth and quality of research and sources',
      'weight': 20,
    },
    'Creativity': {
      'description': 'Originality and innovative thinking',
      'weight': 15,
    },
    'Collaboration': {
      'description': 'Teamwork and contribution to group work',
      'weight': 20,
    },
    'Communication': {
      'description': 'Clear and effective communication',
      'weight': 25,
    },
    'Technical Skills': {
      'description': 'Demonstration of technical competency',
      'weight': 30,
    },
  };

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
          useTemplate = false;
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

  // In _EvaluationRubricPageState class, add this method:

  Future<void> _deleteRubric() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevents accidental dismissal
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red[600],
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Delete Rubric',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this rubric?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber[700],
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will not affect already graded submissions.',
                      style: TextStyle(
                        color: Colors.amber[800],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, size: 18),
                SizedBox(width: 6),
                Text(
                  'Delete Rubric',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);

      try {
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .collection('rubric')
            .doc('main')
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Rubric deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Error deleting rubric: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void _applyTemplate(String templateName) {
    setState(() {
      selectedTemplate = templateName;
      criteriaList = rubricTemplates[templateName]!.map((criterion) {
        return {
          'id': DateTime.now().millisecondsSinceEpoch.toString() + criterion['name'].hashCode.toString(),
          ...criterion,
        };
      }).toList();
      isEditing = true;
    });
  }

  void _addQuickCriterion(String name) {
    final template = quickCriteria[name]!;
    setState(() {
      criteriaList.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'description': template['description'],
        'weight': template['weight'],
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

  void _duplicateCriterion(int index) {
    final original = criteriaList[index];
    setState(() {
      criteriaList.insert(index + 1, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': '${original['name']} (Copy)',
        'description': original['description'],
        'weight': original['weight'],
        'levels': List<Map<String, dynamic>>.from(original['levels']),
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

  void _autoDistributeWeights() {
    if (criteriaList.isEmpty) return;

    final equalWeight = 100.0 / criteriaList.length;
    setState(() {
      for (var criterion in criteriaList) {
        criterion['weight'] = equalWeight.round();
      }
      // Adjust last criterion to ensure total is 100
      final total = criteriaList.fold<int>(0, (sum, c) => sum + (c['weight'] as int));
      if (total != 100) {
        criteriaList.last['weight'] = (criteriaList.last['weight'] as int) + (100 - total);
      }
      isEditing = true;
    });
  }

  Future<void> _loadFromPreviousAssignment() async {
    // Show dialog to select previous assignment
    final assignments = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationCode)
        .collection('courses')
        .doc(widget.courseId)
        .collection('assignments')
        .where('id', isNotEqualTo: widget.assignmentId)
        .get();

    if (!mounted) return;

    final selectedAssignment = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copy Rubric From',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: assignments.docs.length,
                  itemBuilder: (context, index) {
                    final assignment = assignments.docs[index];
                    return ListTile(
                      title: Text(assignment.data()['title'] ?? 'Untitled'),
                      subtitle: Text('Points: ${assignment.data()['points'] ?? 0}'),
                      onTap: () => Navigator.pop(context, assignment.id),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedAssignment != null) {
      // Load rubric from selected assignment
      final rubricDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(selectedAssignment)
          .collection('rubric')
          .doc('main')
          .get();

      if (rubricDoc.exists) {
        setState(() {
          criteriaList = List<Map<String, dynamic>>.from(
            rubricDoc.data()!['criteria'] ?? [],
          ).map((criterion) {
            // Generate new IDs for copied criteria
            return {
              ...criterion,
              'id': DateTime.now().millisecondsSinceEpoch.toString() + criterion['name'].hashCode.toString(),
            };
          }).toList();
          isEditing = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rubric copied successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
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
        'template': selectedTemplate,
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
          if (existingRubric != null)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteRubric,
              tooltip: 'Delete Rubric',
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

            // Template Selection (if no existing rubric)
            if (criteriaList.isEmpty && useTemplate) ...[
              Text(
                'Choose a Rubric Template',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.8, // Changed from 2.5 to give more height
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: rubricTemplates.keys.map((templateName) {
                  return InkWell(
                    onTap: () => _applyTemplate(templateName),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(12), // Reduced from 16
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedTemplate == templateName
                              ? Colors.purple[400]!
                              : Colors.grey[300]!,
                          width: selectedTemplate == templateName ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min, // Add this
                        children: [
                          Flexible( // Wrap in Flexible
                            child: Icon(
                              _getTemplateIcon(templateName),
                              color: selectedTemplate == templateName
                                  ? Colors.purple[600]
                                  : Colors.grey[600],
                              size: 24, // Reduced from 28
                            ),
                          ),
                          SizedBox(height: 4), // Reduced from 8
                          Flexible( // Wrap in Flexible
                            child: Text(
                              templateName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14, // Add explicit font size
                                color: selectedTemplate == templateName
                                    ? Colors.purple[600]
                                    : Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis, // Add this
                              textAlign: TextAlign.center, // Add this
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      useTemplate = false;
                    });
                  },
                  icon: Icon(Icons.edit),
                  label: Text('Create Custom Rubric'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.purple[600],
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],

            // Rubric Builder
            if (!useTemplate || criteriaList.isNotEmpty) ...[
              // Rubric Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evaluation Criteria',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  // Action buttons in a separate row
                  Wrap( // Using Wrap for responsive layout
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (criteriaList.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: _autoDistributeWeights,
                          icon: Icon(Icons.balance, size: 18),
                          label: Text('Auto-balance'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange[600],
                            side: BorderSide(color: Colors.orange[600]!),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: _addCriterion,
                        icon: Icon(Icons.add, size: 18),
                        label: Text('Add Custom',),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[400],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showQuickAddDialog,
                        icon: Icon(Icons.flash_on, size: 18),
                        label: Text('Quick Add'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple[600],
                          side: BorderSide(color: Colors.purple[600]!),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'copy':
                              _loadFromPreviousAssignment();
                              break;
                            case 'template':
                              setState(() {
                                useTemplate = true;
                                criteriaList.clear();
                                selectedTemplate = null;
                              });
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'copy',
                            child: Row(
                              children: [
                                Icon(Icons.copy, size: 20),
                                SizedBox(width: 8),
                                Text('Copy from Another'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'template',
                            child: Row(
                              children: [
                                Icon(Icons.dashboard, size: 20),
                                SizedBox(width: 8),
                                Text('Use Template'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.more_vert, color: Colors.grey[700], size: 18),
                              SizedBox(width: 4),
                              Text('More', style: TextStyle(color: Colors.grey[700])),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                          'Add criteria or use a template to get started',
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
            ],

            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showQuickAddDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Add Criteria',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ...quickCriteria.keys.map((name) {
                return ListTile(
                  title: Text(name),
                  subtitle: Text(quickCriteria[name]!['description']),
                  trailing: Text('${quickCriteria[name]!['weight']}%'),
                  onTap: () {
                    _addQuickCriterion(name);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
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
            color: Colors.grey.withValues(alpha: 0.1),
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
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'duplicate':
                    _duplicateCriterion(index);
                    break;
                  case 'delete':
                    _removeCriterion(index);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 20),
                      SizedBox(width: 8),
                      Text('Duplicate'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Performance Levels',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showLevelPresets(criterion),
                      icon: Icon(Icons.flash_on, size: 16),
                      label: Text('Use Preset'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[600],
                      ),
                    ),
                  ],
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
                            labelText: 'Description (Optional)',
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

  void _showLevelPresets(Map<String, dynamic> criterion) {
    final presets = {
      '4-Point Scale': [
        {'name': 'Excellent', 'points': 4},
        {'name': 'Good', 'points': 3},
        {'name': 'Satisfactory', 'points': 2},
        {'name': 'Needs Improvement', 'points': 1},
      ],
      '5-Point Scale': [
        {'name': 'Outstanding', 'points': 5},
        {'name': 'Exceeds Expectations', 'points': 4},
        {'name': 'Meets Expectations', 'points': 3},
        {'name': 'Below Expectations', 'points': 2},
        {'name': 'Unsatisfactory', 'points': 1},
      ],
      '3-Point Scale': [
        {'name': 'Exceeds', 'points': 3},
        {'name': 'Meets', 'points': 2},
        {'name': 'Does Not Meet', 'points': 1},
      ],
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 350,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Level Preset',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ...presets.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  subtitle: Text(entry.value.map((l) => l['name']).join(', ')),
                  onTap: () {
                    setState(() {
                      criterion['levels'] = entry.value.map((preset) {
                        return {
                          ...preset,
                          'description': '',
                        };
                      }).toList();
                      isEditing = true;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTemplateIcon(String templateName) {
    switch (templateName) {

      case 'Essay':
        return Icons.article;
      case 'Programming':
        return Icons.code;
      case 'Presentation':
        return Icons.slideshow;
      case 'Lab Report':
        return Icons.science;
      default:
        return Icons.assignment;
    }
  }
}