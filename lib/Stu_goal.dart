import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math' as math;

void main() => runApp(MyApp());

class LeafData {
  final double x;
  final double y;
  final double angle;
  final int seed;
  final bool isVisible;

  LeafData(this.x, this.y, this.angle, this.seed, {this.isVisible = false});

  LeafData copyWith({bool? isVisible}) {
    return LeafData(x, y, angle, seed, isVisible: isVisible ?? this.isVisible);
  }
}

class BranchPoint {
  final double x;
  final double y;
  final double angle;

  BranchPoint(this.x, this.y, this.angle);
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
  int maxWatering = 49; // 8 big branches + 41 small branches

  late AnimationController _growthController;
  late AnimationController _flowerController;
  late AnimationController _leafController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _flowerBloomAnimation;
  late Animation<double> _flowerRotationAnimation;
  late Animation<double> _leafScaleAnimation;

  void waterTree() {
    if (wateringCount < maxWatering) {
      setState(() {
        wateringCount++;
        treeGrowth = wateringCount / maxWatering;
      });
      _growthController.forward(from: 0.0);
      _leafController.forward(from: 0.0);

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

    _leafController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _growthController,
      curve: Curves.elasticOut,
    ));

    _leafScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _leafController,
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
    _leafController.dispose();
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
                animation: Listenable.merge([_scaleAnimation, _flowerBloomAnimation, _flowerRotationAnimation, _leafScaleAnimation]),
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
                          leafScale: _leafScaleAnimation.value,
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
  final double leafScale;

  TreePainter({
    required this.growthLevel,
    required this.totalGrowth,
    required this.flowerBloom,
    required this.flowerRotation,
    required this.leafScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double groundY = size.height * 0.85;

    // Draw soil and ground
    _drawSoilAndGround(canvas, size, centerX, groundY);

    // Draw tree roots
    _drawTreeRoots(canvas, size, centerX, groundY);

    // Draw the tree trunk and branches exactly like in the image
    _drawRealisticTree(canvas, size, centerX, groundY);

    // Draw leaves on branch endpoints
    _drawLeavesOnBranches(canvas, size, centerX, groundY);

    // Draw flower if 100% complete
    if (totalGrowth >= 1.0) {
      _drawBloomingFlower(canvas, size, centerX, groundY);
    }
  }

  void _drawSoilAndGround(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw soil mound
    final Paint soilPaint = Paint()
      ..color = Colors.brown[400]!
      ..style = PaintingStyle.fill;

    final Path soilPath = Path();
    double soilWidth = 120;
    double soilHeight = 25;

    // Create a rounded soil mound
    soilPath.moveTo(centerX - soilWidth/2, groundY);
    soilPath.quadraticBezierTo(
        centerX - soilWidth/3, groundY - soilHeight,
        centerX, groundY - soilHeight/2
    );
    soilPath.quadraticBezierTo(
        centerX + soilWidth/3, groundY - soilHeight,
        centerX + soilWidth/2, groundY
    );
    soilPath.lineTo(centerX + soilWidth/2, groundY + 10);
    soilPath.lineTo(centerX - soilWidth/2, groundY + 10);
    soilPath.close();

    canvas.drawPath(soilPath, soilPaint);

    // Add some soil texture
    final Paint soilTexturePaint = Paint()
      ..color = Colors.brown[600]!
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      double x = centerX - soilWidth/3 + (i * 10);
      double y = groundY - 5 + (i % 3) * 3;
      canvas.drawCircle(Offset(x, y), 2, soilTexturePaint);
    }

    // Draw ground line
    final Paint groundPaint = Paint()
      ..color = Colors.brown[300]!
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      groundPaint,
    );
  }

  void _drawTreeRoots(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint rootPaint = Paint()
      ..color = Colors.brown[700]!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;

    // Main roots extending from trunk base
    List<Offset> rootDirections = [
      Offset(-1, 0.3),  // Left root
      Offset(1, 0.3),   // Right root
      Offset(-0.6, 0.5), // Left-center root
      Offset(0.6, 0.5),  // Right-center root
    ];

    for (int i = 0; i < rootDirections.length; i++) {
      Offset direction = rootDirections[i];
      _drawSingleRoot(canvas, centerX, groundY, direction, rootPaint);
    }

    // Smaller secondary roots
    rootPaint.strokeWidth = 3;
    List<Offset> smallRootDirections = [
      Offset(-1.2, 0.2),
      Offset(1.2, 0.2),
      Offset(-0.3, 0.6),
      Offset(0.3, 0.6),
    ];

    for (int i = 0; i < smallRootDirections.length; i++) {
      Offset direction = smallRootDirections[i];
      _drawSingleRoot(canvas, centerX, groundY, direction, rootPaint, isSmall: true);
    }
  }

  void _drawSingleRoot(Canvas canvas, double startX, double startY, Offset direction, Paint paint, {bool isSmall = false}) {
    double length = isSmall ? 30 : 50;

    Path rootPath = Path();
    rootPath.moveTo(startX, startY);

    // Create curved root
    double midX = startX + direction.dx * length * 0.5;
    double midY = startY + direction.dy * length * 0.5;
    double endX = startX + direction.dx * length;
    double endY = startY + direction.dy * length;

    rootPath.quadraticBezierTo(midX, midY, endX, endY);
    canvas.drawPath(rootPath, paint);

    // Add root branches
    if (!isSmall) {
      Paint branchPaint = Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2;

      // Small root branches
      for (int i = 0; i < 2; i++) {
        double branchAngle = (i == 0) ? -0.5 : 0.5;
        double branchLength = 15;
        double branchStartX = endX - direction.dx * 10;
        double branchStartY = endY - direction.dy * 10;

        canvas.drawLine(
          Offset(branchStartX, branchStartY),
          Offset(
              branchStartX + branchLength * math.cos(branchAngle),
              branchStartY + branchLength * math.sin(branchAngle) + 5
          ),
          branchPaint,
        );
      }
    }
  }

  void _drawRealisticTree(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw trunk with natural tapering exactly like the image
    _drawImageStyleTrunk(canvas, size, centerX, groundY);

    // Draw branches exactly matching the image pattern
    _drawImageStyleBranches(canvas, size, centerX, groundY);
  }

  void _drawImageStyleTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint trunkPaint = Paint()
      ..color = Color(0xFF8B4513) // Saddle brown like the image
      ..style = PaintingStyle.fill;

    double trunkHeight = size.height * 0.48;
    double trunkBase = groundY;
    double trunkTop = groundY - trunkHeight;

    // Create trunk shape matching the image - wider at base, narrower at top
    final Path trunkPath = Path();

    double baseWidth = 28;
    double midWidth = 22;
    double upperMidWidth = 18;
    double topWidth = 14;

    // Create realistic trunk with multiple sections like the image
    trunkPath.moveTo(centerX - baseWidth/2, trunkBase);

    // Left side with natural organic curves
    trunkPath.quadraticBezierTo(
        centerX - midWidth/2 - 1, trunkBase - trunkHeight * 0.25,
        centerX - midWidth/2, trunkBase - trunkHeight * 0.4
    );
    trunkPath.quadraticBezierTo(
        centerX - upperMidWidth/2 + 1, trunkBase - trunkHeight * 0.65,
        centerX - upperMidWidth/2, trunkBase - trunkHeight * 0.8
    );
    trunkPath.quadraticBezierTo(
        centerX - topWidth/2, trunkBase - trunkHeight * 0.9,
        centerX - topWidth/2, trunkTop
    );

    // Top of trunk
    trunkPath.lineTo(centerX + topWidth/2, trunkTop);

    // Right side with natural organic curves
    trunkPath.quadraticBezierTo(
        centerX + topWidth/2, trunkBase - trunkHeight * 0.9,
        centerX + upperMidWidth/2, trunkBase - trunkHeight * 0.8
    );
    trunkPath.quadraticBezierTo(
        centerX + upperMidWidth/2 - 1, trunkBase - trunkHeight * 0.65,
        centerX + midWidth/2, trunkBase - trunkHeight * 0.4
    );
    trunkPath.quadraticBezierTo(
        centerX + midWidth/2 + 1, trunkBase - trunkHeight * 0.25,
        centerX + baseWidth/2, trunkBase
    );

    trunkPath.close();
    canvas.drawPath(trunkPath, trunkPaint);

    // Add realistic bark texture like the image
    _drawRealisticBarkTexture(canvas, centerX, groundY, trunkHeight, baseWidth, topWidth);
  }

  void _drawRealisticBarkTexture(Canvas canvas, double centerX, double groundY, double trunkHeight, double baseWidth, double topWidth) {
    // Vertical bark lines like the image
    final Paint darkBarkPaint = Paint()
      ..color = Color(0xFF654321) // Dark brown
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint lightBarkPaint = Paint()
      ..color = Color(0xFFA0522D) // Sienna
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Main vertical bark ridges
    for (int i = 0; i < 8; i++) {
      double x = centerX - 12 + (i * 3.5);
      double topY = groundY - trunkHeight + 15;
      double bottomY = groundY - 5;

      // Create organic vertical bark lines
      Path barkLine = Path();
      barkLine.moveTo(x, bottomY);

      int segments = 12;
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 2 * math.sin(j * 0.8 + i * 0.5) * (1 - j/segments);
        barkLine.lineTo(x + offset, segmentY);
      }

      canvas.drawPath(barkLine, darkBarkPaint);

      // Add lighter secondary lines
      Path lightLine = Path();
      lightLine.moveTo(x + 1.5, bottomY);
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 1.5 * math.sin(j * 0.6 + i * 0.3) * (1 - j/segments);
        lightLine.lineTo(x + 1.5 + offset, segmentY);
      }
      canvas.drawPath(lightLine, lightBarkPaint);
    }

    // Horizontal bark texture rings
    final Paint ringPaint = Paint()
      ..color = Color(0xFF5D4037) // Brown
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 10; i++) {
      double y = groundY - (trunkHeight * 0.1 * i) - 15;
      double width = baseWidth - (baseWidth - topWidth) * (i / 10.0);

      // Create natural bark rings
      Path ringPath = Path();
      ringPath.moveTo(centerX - width/2 + 2, y);

      int ringSegments = 16;
      for (int j = 1; j <= ringSegments; j++) {
        double angle = (j / ringSegments) * math.pi;
        double radius = width/2 - 2;
        double x = centerX + radius * math.cos(angle - math.pi/2);
        double ringY = y + 2 * math.sin(j * 0.4);
        ringPath.lineTo(x, ringY);
      }

      canvas.drawPath(ringPath, ringPaint);
    }

    // Add bark texture patches
    final Paint patchPaint = Paint()
      ..color = Color(0xFF8B7355) // Light brown
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 15; i++) {
      double x = centerX - 10 + (i % 5) * 5 + (math.Random().nextDouble() - 0.5) * 8;
      double y = groundY - 20 - (i * 12) + (math.Random().nextDouble() - 0.5) * 10;

      // Small bark texture patches
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 3 + (i % 3),
          height: 2 + (i % 2),
        ),
        patchPaint,
      );
    }
  }

  void _drawImageStyleBranches(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.48;
    double trunkTop = groundY - trunkHeight;

    final Paint mainBranchPaint = Paint()
      ..color = Color(0xFF8B4513) // Same brown as trunk
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw branches in layers like the image - thick to thin
    _drawMainBranchLayer(canvas, centerX, trunkTop, mainBranchPaint);
    _drawSecondaryBranchLayer(canvas, centerX, trunkTop, mainBranchPaint);
    _drawDetailBranchLayer(canvas, centerX, trunkTop, mainBranchPaint);
    _drawFineBranchLayer(canvas, centerX, trunkTop, mainBranchPaint);
  }

  void _drawMainBranchLayer(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 10; // Thick main branches

    // Main left branch system
    _drawBranchPath(canvas, paint, [
      Offset(centerX - 3, trunkTop + 25),
      Offset(centerX - 20, trunkTop + 5),
      Offset(centerX - 45, trunkTop - 15),
      Offset(centerX - 75, trunkTop - 35),
      Offset(centerX - 95, trunkTop - 45),
    ]);

    // Main right branch system
    _drawBranchPath(canvas, paint, [
      Offset(centerX + 3, trunkTop + 20),
      Offset(centerX + 25, trunkTop),
      Offset(centerX + 50, trunkTop - 20),
      Offset(centerX + 80, trunkTop - 35),
      Offset(centerX + 105, trunkTop - 45),
    ]);

    // Upper left main branch
    _drawBranchPath(canvas, paint, [
      Offset(centerX - 2, trunkTop + 10),
      Offset(centerX - 15, trunkTop - 15),
      Offset(centerX - 35, trunkTop - 40),
      Offset(centerX - 50, trunkTop - 65),
    ]);

    // Upper right main branch
    _drawBranchPath(canvas, paint, [
      Offset(centerX + 2, trunkTop + 5),
      Offset(centerX + 18, trunkTop - 10),
      Offset(centerX + 40, trunkTop - 35),
      Offset(centerX + 55, trunkTop - 60),
    ]);

    // Central upper branches
    _drawBranchPath(canvas, paint, [
      Offset(centerX - 1, trunkTop),
      Offset(centerX - 8, trunkTop - 25),
      Offset(centerX - 12, trunkTop - 50),
      Offset(centerX - 15, trunkTop - 75),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX + 1, trunkTop - 5),
      Offset(centerX + 10, trunkTop - 30),
      Offset(centerX + 15, trunkTop - 55),
      Offset(centerX + 18, trunkTop - 80),
    ]);
  }

  void _drawSecondaryBranchLayer(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 6; // Medium branches

    // Secondary branches from main left branch
    _drawBranchPath(canvas, paint, [
      Offset(centerX - 45, trunkTop - 15),
      Offset(centerX - 60, trunkTop - 25),
      Offset(centerX - 75, trunkTop - 20),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX - 75, trunkTop - 35),
      Offset(centerX - 90, trunkTop - 25),
      Offset(centerX - 110, trunkTop - 30),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX - 95, trunkTop - 45),
      Offset(centerX - 105, trunkTop - 35),
      Offset(centerX - 120, trunkTop - 40),
    ]);

    // Secondary branches from main right branch
    _drawBranchPath(canvas, paint, [
      Offset(centerX + 50, trunkTop - 20),
      Offset(centerX + 65, trunkTop - 30),
      Offset(centerX + 85, trunkTop - 25),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX + 80, trunkTop - 35),
      Offset(centerX + 95, trunkTop - 25),
      Offset(centerX + 115, trunkTop - 30),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX + 105, trunkTop - 45),
      Offset(centerX + 120, trunkTop - 35),
      Offset(centerX + 130, trunkTop - 40),
    ]);

    // Upper secondary branches
    _drawBranchPath(canvas, paint, [
      Offset(centerX - 35, trunkTop - 40),
      Offset(centerX - 45, trunkTop - 55),
      Offset(centerX - 40, trunkTop - 70),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX - 50, trunkTop - 65),
      Offset(centerX - 65, trunkTop - 75),
      Offset(centerX - 70, trunkTop - 90),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX + 40, trunkTop - 35),
      Offset(centerX + 50, trunkTop - 50),
      Offset(centerX + 45, trunkTop - 65),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX + 55, trunkTop - 60),
      Offset(centerX + 70, trunkTop - 70),
      Offset(centerX + 75, trunkTop - 85),
    ]);
  }

  void _drawDetailBranchLayer(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 4; // Detailed branches

    // Add many small branches throughout the tree
    List<List<Offset>> detailBranches = [
      // Left side details
      [Offset(centerX - 60, trunkTop - 25), Offset(centerX - 70, trunkTop - 15), Offset(centerX - 80, trunkTop - 10)],
      [Offset(centerX - 75, trunkTop - 20), Offset(centerX - 85, trunkTop - 15), Offset(centerX - 95, trunkTop - 10)],
      [Offset(centerX - 90, trunkTop - 25), Offset(centerX - 100, trunkTop - 35), Offset(centerX - 105, trunkTop - 45)],
      [Offset(centerX - 110, trunkTop - 30), Offset(centerX - 120, trunkTop - 20), Offset(centerX - 130, trunkTop - 25)],

      // Right side details
      [Offset(centerX + 65, trunkTop - 30), Offset(centerX + 75, trunkTop - 20), Offset(centerX + 85, trunkTop - 15)],
      [Offset(centerX + 85, trunkTop - 25), Offset(centerX + 95, trunkTop - 15), Offset(centerX + 105, trunkTop - 10)],
      [Offset(centerX + 95, trunkTop - 25), Offset(centerX + 105, trunkTop - 35), Offset(centerX + 115, trunkTop - 45)],
      [Offset(centerX + 115, trunkTop - 30), Offset(centerX + 125, trunkTop - 20), Offset(centerX + 135, trunkTop - 25)],

      // Upper area details
      [Offset(centerX - 45, trunkTop - 55), Offset(centerX - 35, trunkTop - 65), Offset(centerX - 30, trunkTop - 75)],
      [Offset(centerX - 40, trunkTop - 70), Offset(centerX - 50, trunkTop - 80), Offset(centerX - 55, trunkTop - 90)],
      [Offset(centerX - 15, trunkTop - 75), Offset(centerX - 25, trunkTop - 85), Offset(centerX - 30, trunkTop - 95)],
      [Offset(centerX + 50, trunkTop - 50), Offset(centerX + 40, trunkTop - 60), Offset(centerX + 35, trunkTop - 70)],
      [Offset(centerX + 45, trunkTop - 65), Offset(centerX + 55, trunkTop - 75), Offset(centerX + 60, trunkTop - 85)],
      [Offset(centerX + 18, trunkTop - 80), Offset(centerX + 28, trunkTop - 90), Offset(centerX + 33, trunkTop - 100)],
    ];

    for (var branch in detailBranches) {
      _drawBranchPath(canvas, paint, branch);
    }
  }

  void _drawFineBranchLayer(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 2; // Fine branches and twigs

    // Generate many fine branches at the endpoints
    List<Offset> endpoints = [
      // Left side endpoints
      Offset(centerX - 80, trunkTop - 10), Offset(centerX - 95, trunkTop - 10), Offset(centerX - 105, trunkTop - 45),
      Offset(centerX - 130, trunkTop - 25), Offset(centerX - 120, trunkTop - 40), Offset(centerX - 30, trunkTop - 75),
      Offset(centerX - 55, trunkTop - 90), Offset(centerX - 30, trunkTop - 95), Offset(centerX - 70, trunkTop - 90),

      // Right side endpoints
      Offset(centerX + 85, trunkTop - 15), Offset(centerX + 105, trunkTop - 10), Offset(centerX + 115, trunkTop - 45),
      Offset(centerX + 135, trunkTop - 25), Offset(centerX + 125, trunkTop - 20), Offset(centerX + 35, trunkTop - 70),
      Offset(centerX + 60, trunkTop - 85), Offset(centerX + 33, trunkTop - 100), Offset(centerX + 75, trunkTop - 85),

      // Additional scattered endpoints
      Offset(centerX - 100, trunkTop - 35), Offset(centerX - 85, trunkTop - 15), Offset(centerX + 100, trunkTop - 35),
      Offset(centerX + 90, trunkTop - 15), Offset(centerX - 25, trunkTop - 85), Offset(centerX + 28, trunkTop - 90),
    ];

    for (int i = 0; i < endpoints.length && i < growthLevel; i++) {
      Offset endpoint = endpoints[i];

      // Draw 2-3 small twigs from each endpoint
      for (int j = 0; j < 3; j++) {
        double angle = (j - 1) * 0.6 + (i * 0.1);
        double length = 12 + j * 3;

        Offset twigEnd = Offset(
          endpoint.dx + length * math.cos(angle),
          endpoint.dy + length * math.sin(angle) - 8,
        );

        canvas.drawLine(endpoint, twigEnd, paint);

        // Add tiny sub-twigs
        if (j == 1) { // Only on middle twig
          for (int k = 0; k < 2; k++) {
            double subAngle = angle + (k == 0 ? 0.4 : -0.4);
            double subLength = 6;
            Offset subTwigEnd = Offset(
              twigEnd.dx + subLength * math.cos(subAngle),
              twigEnd.dy + subLength * math.sin(subAngle),
            );
            canvas.drawLine(twigEnd, subTwigEnd, paint);
          }
        }
      }
    }
  }

  void _drawBranchPath(Canvas canvas, Paint paint, List<Offset> points) {
    if (points.length < 2) return;

    Path path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      if (i == points.length - 1) {
        // Last point - straight line
        path.lineTo(points[i].dx, points[i].dy);
      } else {
        // Curved connection
        Offset current = points[i];
        Offset next = points[i + 1];
        Offset controlPoint = Offset(
          current.dx + (next.dx - current.dx) * 0.3,
          current.dy + (next.dy - current.dy) * 0.3,
        );
        path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, current.dx, current.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  List<BranchPoint> _getBranchEndpoints(double centerX, double trunkTop) {
    List<BranchPoint> endpoints = [];

    // Generate endpoints based on the realistic tree structure
    List<Offset> allEndpoints = [
      // Left side branch endpoints
      Offset(centerX - 80, trunkTop - 10),
      Offset(centerX - 95, trunkTop - 10),
      Offset(centerX - 105, trunkTop - 45),
      Offset(centerX - 130, trunkTop - 25),
      Offset(centerX - 120, trunkTop - 40),
      Offset(centerX - 30, trunkTop - 75),
      Offset(centerX - 55, trunkTop - 90),
      Offset(centerX - 30, trunkTop - 95),
      Offset(centerX - 70, trunkTop - 90),
      Offset(centerX - 100, trunkTop - 35),
      Offset(centerX - 85, trunkTop - 15),
      Offset(centerX - 25, trunkTop - 85),

      // Right side branch endpoints
      Offset(centerX + 85, trunkTop - 15),
      Offset(centerX + 105, trunkTop - 10),
      Offset(centerX + 115, trunkTop - 45),
      Offset(centerX + 135, trunkTop - 25),
      Offset(centerX + 125, trunkTop - 20),
      Offset(centerX + 35, trunkTop - 70),
      Offset(centerX + 60, trunkTop - 85),
      Offset(centerX + 33, trunkTop - 100),
      Offset(centerX + 75, trunkTop - 85),
      Offset(centerX + 100, trunkTop - 35),
      Offset(centerX + 90, trunkTop - 15),
      Offset(centerX + 28, trunkTop - 90),

      // Additional scattered endpoints for full coverage
      Offset(centerX - 75, trunkTop - 20),
      Offset(centerX + 75, trunkTop - 20),
    ];

    for (int i = 0; i < allEndpoints.length && i < 25; i++) {
      Offset point = allEndpoints[i];
      double angle = math.atan2(point.dy - trunkTop, point.dx - centerX);
      endpoints.add(BranchPoint(point.dx, point.dy, angle));
    }

    return endpoints;
  }

  void _drawLeavesOnBranches(Canvas canvas, Size size, double centerX, double groundY) {
    if (growthLevel == 0) return;

    double trunkHeight = size.height * 0.48;
    double trunkTop = groundY - trunkHeight;

    List<BranchPoint> branchEndpoints = _getBranchEndpoints(centerX, trunkTop);

    // Draw leaves based on growth level, one at each branch endpoint
    for (int i = 0; i < growthLevel && i < branchEndpoints.length; i++) {
      BranchPoint point = branchEndpoints[i];
      _drawRealisticLeafAtPoint(canvas, point, i);
    }
  }

  void _drawRealisticLeafAtPoint(Canvas canvas, BranchPoint point, int index) {
    canvas.save();
    canvas.translate(point.x, point.y);
    canvas.scale(leafScale); // Apply leaf scale animation

    // Realistic leaf colors like the image
    Color leafColor = index % 5 == 0 ? Color(0xFF228B22) : // Forest green
    index % 5 == 1 ? Color(0xFF32CD32) : // Lime green
    index % 5 == 2 ? Color(0xFF90EE90) : // Light green
    index % 5 == 3 ? Color(0xFF006400) : // Dark green
    Color(0xFF9ACD32); // Yellow green

    Paint leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    double leafSize = 9 + (index % 4) * 2;

    // Draw realistic leaf shape
    Path leafPath = Path();
    leafPath.moveTo(0, -leafSize);
    leafPath.quadraticBezierTo(leafSize * 0.8, -leafSize * 0.5, leafSize * 0.4, 0);
    leafPath.quadraticBezierTo(leafSize * 0.6, leafSize * 0.3, 0, leafSize * 0.4);
    leafPath.quadraticBezierTo(-leafSize * 0.6, leafSize * 0.3, -leafSize * 0.4, 0);
    leafPath.quadraticBezierTo(-leafSize * 0.8, -leafSize * 0.5, 0, -leafSize);

    canvas.drawPath(leafPath, leafPaint);

    // Add realistic leaf veins
    Paint veinPaint = Paint()
      ..color = Color(0xFF006400) // Dark green veins
      ..strokeWidth = 1.2;

    // Main center vein
    canvas.drawLine(
      Offset(0, -leafSize * 0.9),
      Offset(0, leafSize * 0.3),
      veinPaint,
    );

    // Side veins
    veinPaint.strokeWidth = 0.8;
    for (int i = 0; i < 3; i++) {
      double veinY = -leafSize * 0.6 + (i * leafSize * 0.4);
      double veinLength = leafSize * 0.4 * (1 - i * 0.2);

      // Left side vein
      canvas.drawLine(
        Offset(0, veinY),
        Offset(-veinLength, veinY + veinLength * 0.3),
        veinPaint,
      );

      // Right side vein
      canvas.drawLine(
        Offset(0, veinY),
        Offset(veinLength, veinY + veinLength * 0.3),
        veinPaint,
      );
    }

    canvas.restore();
  }

  void _drawBloomingFlower(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.48;
    double trunkTop = groundY - trunkHeight;
    double flowerCenterX = centerX + 15;
    double flowerCenterY = trunkTop - 80;

    // Flower center
    final Paint centerPaint = Paint()
      ..color = Color(0xFFFFD700) // Gold
      ..style = PaintingStyle.fill;

    // Flower petals with realistic colors
    final Paint petalPaint = Paint()
      ..color = Color(0xFFFF69B4) // Hot pink
      ..style = PaintingStyle.fill;

    final Paint petalOutlinePaint = Paint()
      ..color = Color(0xFFDC143C) // Crimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw petals with blooming animation
    for (int i = 0; i < 8; i++) {
      double angle = (i * 2 * math.pi / 8) + flowerRotation * 0.1;
      double petalLength = 20 * flowerBloom;
      double petalWidth = 14 * flowerBloom;

      canvas.save();
      canvas.translate(flowerCenterX, flowerCenterY);
      canvas.rotate(angle);

      // Draw realistic petal shape
      final Path petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(petalWidth/2, -petalLength/3, petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(0, -petalLength * 0.8, -petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(-petalWidth/2, -petalLength/3, 0, 0);

      canvas.drawPath(petalPath, petalPaint);
      canvas.drawPath(petalPath, petalOutlinePaint);
      canvas.restore();
    }

    // Draw flower center with gradient effect
    canvas.drawCircle(Offset(flowerCenterX, flowerCenterY), 10 * flowerBloom, centerPaint);

    // Inner center detail
    canvas.drawCircle(
        Offset(flowerCenterX, flowerCenterY),
        6 * flowerBloom,
        Paint()
          ..color = Color(0xFFFFA500) // Orange
          ..style = PaintingStyle.fill
    );

    // Center dots for realism
    final Paint dotPaint = Paint()
      ..color = Color(0xFF8B4513) // Saddle brown
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      double dotAngle = i * 2 * math.pi / 5;
      double dotDistance = 3 * flowerBloom;
      canvas.drawCircle(
        Offset(
            flowerCenterX + dotDistance * math.cos(dotAngle),
            flowerCenterY + dotDistance * math.sin(dotAngle)
        ),
        1 * flowerBloom,
        dotPaint,
      );
    }

    // Add sparkle effect when fully bloomed
    if (flowerBloom > 0.8) {
      _drawSparkles(canvas, flowerCenterX, flowerCenterY);
    }
  }

  void _drawSparkles(Canvas canvas, double centerX, double centerY) {
    final Paint sparklePaint = Paint()
      ..color = Colors.yellow[300]!
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      double angle = i * math.pi / 3 + flowerRotation;
      double distance = 30 + 5 * math.sin(flowerRotation * 2);
      double x = centerX + distance * math.cos(angle);
      double y = centerY + distance * math.sin(angle);

      // Draw sparkle stars
      canvas.drawLine(Offset(x - 4, y), Offset(x + 4, y), sparklePaint);
      canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), sparklePaint);

      // Add diagonal lines for star effect
      canvas.drawLine(Offset(x - 3, y - 3), Offset(x + 3, y + 3), sparklePaint);
      canvas.drawLine(Offset(x - 3, y + 3), Offset(x + 3, y - 3), sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is TreePainter &&
        (oldDelegate.growthLevel != growthLevel ||
            oldDelegate.totalGrowth != totalGrowth ||
            oldDelegate.flowerBloom != flowerBloom ||
            oldDelegate.flowerRotation != flowerRotation ||
            oldDelegate.leafScale != leafScale);
  }
}