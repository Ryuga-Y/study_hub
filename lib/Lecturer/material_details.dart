import 'package:flutter/material.dart';

class MaterialDetailPage extends StatelessWidget {
  final Map<String, dynamic> material;
  final String courseId;
  final Map<String, dynamic> courseData;
  final bool isLecturer;

  const MaterialDetailPage({
    Key? key,
    required this.material,
    required this.courseId,
    required this.courseData,
    required this.isLecturer,
  }) : super(key: key);

  IconData _getMaterialIcon() {
    switch (material['type']) {
      case 'document':
        return Icons.description;
      case 'video':
        return Icons.video_library;
      case 'presentation':
        return Icons.slideshow;
      case 'link':
        return Icons.link;
      default:
        return Icons.folder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Material Details',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getMaterialIcon(), color: Colors.green, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          material['title'] ?? 'Material',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      material['type']?.toUpperCase() ?? 'MATERIAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Description',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              material['description'] ?? 'No description available',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            if (material['files'] != null &&
                (material['files'] as List).isNotEmpty) ...[
              SizedBox(height: 24),
              Text(
                'Files',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              ...((material['files'] as List).map((file) =>
                  Card(
                    child: ListTile(
                      leading: Icon(_getMaterialIcon(), color: Colors.green),
                      title: Text('Material File'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.visibility, color: Colors.blue),
                            onPressed: () {
                              // TODO: Implement view
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('View not implemented yet')),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.download, color: Colors.green),
                            onPressed: () {
                              // TODO: Implement download
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Download not implemented yet')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              )),
            ],
            if (!isLecturer) ...[
              SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement view
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('View not implemented yet')),
                        );
                      },
                      icon: Icon(Icons.visibility),
                      label: Text('View Material'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement download
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Download not implemented yet')),
                        );
                      },
                      icon: Icon(Icons.download),
                      label: Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}