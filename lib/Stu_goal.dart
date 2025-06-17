import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math' as math;

void main() => runApp(MyApp());

class LeafData {
  final double x;
  final double y;
  final double angle;
  final int seed;

  LeafData(this.x, this.y, this.angle, this.seed);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StuGoal(),
    );
  }
}

class StuGoal extends StatefulWidget {
  @override
  _StuGoalState createState() => _StuGoalState();
}

class _StuGoalState extends State<StuGoal> with TickerProviderStateMixin {
  int wateringCount = 0;
  double treeGrowth = 0.0;
  String goal = "Complete five quizzes this week";
  double maxGrowth = 1.0;
  int maxWatering = 25; // 25 leaves total

  late AnimationController _growthController;
  late AnimationController _flowerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _flowerBloomAnimation;
  late Animation<double> _flowerRotationAnimation;

  void waterTree() {
    if (wateringCount < maxWatering) {
      setState(() {
        wateringCount++;
        treeGrowth = wateringCount / maxWatering;
      });
      _growthController.forward(from: 0.0);

      // Start flower blooming animation when 100% complete
      if (treeGrowth >= 1.0) {
        _flowerController.forward();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _growthController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _flowerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _growthController,
      curve: Curves.elasticOut,
    ));

    _flowerBloomAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flowerController,
      curve: Curves.elasticOut,
    ));

    _flowerRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _flowerController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _growthController.dispose();
    _flowerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('StudyHub')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _flowerBloomAnimation, _flowerRotationAnimation]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 300,
                      height: 350,
                      child: CustomPaint(
                        painter: TreePainter(
                          growthLevel: wateringCount,
                          totalGrowth: treeGrowth,
                          flowerBloom: _flowerBloomAnimation.value,
                          flowerRotation: _flowerRotationAnimation.value,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),

            GestureDetector(
              onTap: waterTree,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.water_drop_outlined,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 20),

            LinearProgressIndicator(
              value: treeGrowth,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 10),
            Text(
              "${(treeGrowth * 100).toInt()}% grown",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Goal Setting',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    goal,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      // Handle save goal action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blueAccent,
                    ),
                    child: Text('Save Goal'),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Handle view badges action
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: Text('View Badges'),
            ),
          ],
        ),
      ),
    );
  }
}

class TreePainter extends CustomPainter {
  final int growthLevel;
  final double totalGrowth;
  final double flowerBloom;
  final double flowerRotation;

  TreePainter({
    required this.growthLevel,
    required this.totalGrowth,
    required this.flowerBloom,
    required this.flowerRotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double groundY = size.height * 0.9;

    // Draw ground line
    final Paint groundPaint = Paint()
      ..color = Colors.brown[300]!
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      groundPaint,
    );

    // Draw the tree trunk like in your image
    _drawTreeTrunk(canvas, size, centerX, groundY);

    // Draw leaves on the trunk
    _drawLeavesOnTrunk(canvas, size, centerX, groundY);

    // Draw flower if 100% complete
    if (totalGrowth >= 1.0) {
      _drawBloomingFlower(canvas, size, centerX, groundY);
    }
  }

  void _drawTreeTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint trunkPaint = Paint()
      ..color = Colors.brown[700]!
      ..style = PaintingStyle.fill;

    // Create a path for the tree trunk similar to your image
    final Path trunkPath = Path();

    // Start from the base (wider)
    double baseWidth = 30;
    double topWidth = 20;
    double trunkHeight = size.height * 0.5;
    double trunkTop = groundY - trunkHeight;

    // Draw trunk with curved sides
    trunkPath.moveTo(centerX - baseWidth/2, groundY);
    trunkPath.quadraticBezierTo(
        centerX - topWidth/2 - 5, groundY - trunkHeight * 0.3,
        centerX - topWidth/2, trunkTop + 20
    );
    trunkPath.lineTo(centerX - topWidth/2, trunkTop);

    // Add main branches at the top
    _addBranchesToPath(trunkPath, centerX, trunkTop, size);

    // Complete the trunk outline
    trunkPath.lineTo(centerX + topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + topWidth/2, trunkTop + 20);
    trunkPath.quadraticBezierTo(
        centerX + topWidth/2 + 5, groundY - trunkHeight * 0.3,
        centerX + baseWidth/2, groundY
    );
    trunkPath.close();

    canvas.drawPath(trunkPath, trunkPaint);

    // Add bark texture
    _addBarkTexture(canvas, centerX, groundY, trunkHeight, baseWidth, topWidth);
  }

  void _addBranchesToPath(Path path, double centerX, double trunkTop, Size size) {
    // Add multiple branches like in your image
    double branchLength = 40;

    // Left branches
    path.lineTo(centerX - branchLength, trunkTop - 20);
    path.lineTo(centerX - branchLength + 5, trunkTop - 25);
    path.lineTo(centerX - branchLength - 10, trunkTop - 30);
    path.lineTo(centerX - branchLength - 5, trunkTop - 35);
    path.lineTo(centerX - branchLength + 15, trunkTop - 40);
    path.lineTo(centerX - branchLength + 20, trunkTop - 45);

    // Top branches
    path.lineTo(centerX - 10, trunkTop - 50);
    path.lineTo(centerX - 5, trunkTop - 60);
    path.lineTo(centerX, trunkTop - 65);
    path.lineTo(centerX + 5, trunkTop - 60);
    path.lineTo(centerX + 10, trunkTop - 50);

    // Right branches
    path.lineTo(centerX + branchLength - 20, trunkTop - 45);
    path.lineTo(centerX + branchLength - 15, trunkTop - 40);
    path.lineTo(centerX + branchLength + 5, trunkTop - 35);
    path.lineTo(centerX + branchLength + 10, trunkTop - 30);
    path.lineTo(centerX + branchLength - 5, trunkTop - 25);
    path.lineTo(centerX + branchLength, trunkTop - 20);
  }

  void _addBarkTexture(Canvas canvas, double centerX, double groundY, double trunkHeight, double baseWidth, double topWidth) {
    final Paint barkPaint = Paint()
      ..color = Colors.brown[800]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Add horizontal bark lines
    for (int i = 0; i < 8; i++) {
      double y = groundY - (trunkHeight * 0.1 * i);
      double width = baseWidth - (baseWidth - topWidth) * (i / 8.0);
      canvas.drawLine(
        Offset(centerX - width/2 + 5, y),
        Offset(centerX + width/2 - 5, y),
        barkPaint,
      );
    }
  }

  void _drawLeavesOnTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    if (growthLevel == 0) return;

    final Paint leafPaint = Paint()
      ..color = Colors.green[600]!
      ..style = PaintingStyle.fill;

    // Define positions for leaves around the trunk and branches
    List<LeafData> leafPositions = _generateLeafPositions(centerX, groundY, size);

    // Draw leaves based on growth level
    for (int i = 0; i < growthLevel && i < leafPositions.length; i++) {
      _drawLeaf(canvas, leafPositions[i], leafPaint);
    }
  }

  List<LeafData> _generateLeafPositions(double centerX, double groundY, Size size) {
    List<LeafData> positions = [];
    double trunkHeight = size.height * 0.5;
    double trunkTop = groundY - trunkHeight;

    // Generate 25 leaf positions around the trunk and branches
    for (int i = 0; i < 25; i++) {
      double angle = (i * 2 * math.pi / 25) + (i * 0.5); // Distribute around
      double radius = 15 + (i % 3) * 5; // Vary distance from trunk
      double height = trunkTop + (i * 3) - 50; // Vary height

      double x = centerX + radius * math.cos(angle);
      double y = height + (i % 4) * 5; // Add some vertical variation

      positions.add(LeafData(x, y, angle, i));
    }

    return positions;
  }

  void _drawLeaf(Canvas canvas, LeafData leafData, Paint paint) {
    final Path leafPath = Path();

    // Create a realistic leaf shape
    double leafSize = 8 + (leafData.seed % 3) * 2;

    leafPath.moveTo(leafData.x, leafData.y - leafSize);
    leafPath.quadraticBezierTo(
        leafData.x + leafSize * 0.8,
        leafData.y - leafSize * 0.3,
        leafData.x,
        leafData.y + leafSize * 0.3
    );
    leafPath.quadraticBezierTo(
        leafData.x - leafSize * 0.8,
        leafData.y - leafSize * 0.3,
        leafData.x,
        leafData.y - leafSize
    );

    canvas.drawPath(leafPath, paint);

    // Add leaf vein
    final Paint veinPaint = Paint()
      ..color = Colors.green[800]!
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(leafData.x, leafData.y - leafSize),
      Offset(leafData.x, leafData.y + leafSize * 0.3),
      veinPaint,
    );
  }

  void _drawBloomingFlower(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.5;
    double trunkTop = groundY - trunkHeight;
    double flowerCenterX = centerX;
    double flowerCenterY = trunkTop - 70;

    // Flower center
    final Paint centerPaint = Paint()
      ..color = Colors.yellow[600]!
      ..style = PaintingStyle.fill;

    // Flower petals
    final Paint petalPaint = Paint()
      ..color = Colors.pink[300]!
      ..style = PaintingStyle.fill;

    // Draw petals with blooming animation
    for (int i = 0; i < 8; i++) {
      double angle = (i * 2 * math.pi / 8) + flowerRotation * 0.1;
      double petalLength = 20 * flowerBloom;
      double petalWidth = 12 * flowerBloom;

      canvas.save();
      canvas.translate(flowerCenterX, flowerCenterY);
      canvas.rotate(angle);

      // Draw petal
      final Path petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(petalWidth/2, -petalLength/2, 0, -petalLength);
      petalPath.quadraticBezierTo(-petalWidth/2, -petalLength/2, 0, 0);

      canvas.drawPath(petalPath, petalPaint);
      canvas.restore();
    }

    // Draw flower center
    canvas.drawCircle(
      Offset(flowerCenterX, flowerCenterY),
      8 * flowerBloom,
      centerPaint,
    );

    // Add sparkle effect when fully bloomed
    if (flowerBloom > 0.8) {
      _drawSparkles(canvas, flowerCenterX, flowerCenterY);
    }
  }

  void _drawSparkles(Canvas canvas, double centerX, double centerY) {
    final Paint sparklePaint = Paint()
      ..color = Colors.yellow[300]!
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      double angle = i * math.pi / 3 + flowerRotation;
      double distance = 30 + 5 * math.sin(flowerRotation * 2);
      double x = centerX + distance * math.cos(angle);
      double y = centerY + distance * math.sin(angle);

      // Draw sparkle lines
      canvas.drawLine(
        Offset(x - 3, y),
        Offset(x + 3, y),
        sparklePaint,
      );
      canvas.drawLine(
        Offset(x, y - 3),
        Offset(x, y + 3),
        sparklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is TreePainter &&
        (oldDelegate.growthLevel != growthLevel ||
            oldDelegate.totalGrowth != totalGrowth ||
            oldDelegate.flowerBloom != flowerBloom ||
            oldDelegate.flowerRotation != flowerRotation);
  }
}