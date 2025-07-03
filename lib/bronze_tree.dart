import 'package:flutter/material.dart';
import 'dart:math' as math;

class BranchPoint {
  final double x;
  final double y;
  final double angle;

  BranchPoint(this.x, this.y, this.angle);
}

class BronzeTreePainter extends CustomPainter {
  final int growthLevel;
  final double totalGrowth;
  final double flowerBloom;
  final double flowerRotation;
  final double leafScale;
  final double waterDropAnimation;

  BronzeTreePainter({
    required this.growthLevel,
    required this.totalGrowth,
    required this.flowerBloom,
    required this.flowerRotation,
    required this.leafScale,
    this.waterDropAnimation = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double groundY = size.height * 0.9;

    // Draw water drop animation
    if (waterDropAnimation > 0) {
      _drawWaterDropAnimation(canvas, size, centerX, groundY);
    }

    // Draw ground line only
    _drawGroundLine(canvas, size, groundY);

    // Draw the tree trunk and branches
    _drawBronzeTree(canvas, size, centerX, groundY);

    // Draw leaves based on growth
    _drawLeavesOnBranches(canvas, size, centerX, groundY);

    // Draw bronze flowers if 100% complete
    if (totalGrowth >= 1.0) {
      _drawMultipleBronzeFlowers(canvas, size, centerX, groundY);
    }
  }

  void _drawWaterDropAnimation(Canvas canvas, Size size, double centerX, double groundY) {
    double dropY = 30 + (waterDropAnimation * (groundY - 80));
    double opacity = 1.0 - (waterDropAnimation * 0.7);

    Paint dropPaint = Paint()
      ..color = Colors.blue.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Draw water drop
    canvas.drawCircle(Offset(centerX, dropY), 8 * (1 - waterDropAnimation * 0.3), dropPaint);

    // Draw splash effect when near ground
    if (waterDropAnimation > 0.8) {
      double splashRadius = 20 * (waterDropAnimation - 0.8) * 5;
      Paint splashPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3 * (1 - (waterDropAnimation - 0.8) * 5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset(centerX, groundY), splashRadius, splashPaint);
    }
  }

  void _drawGroundLine(Canvas canvas, Size size, double groundY) {
    final Paint groundPaint = Paint()
      ..color = Colors.brown[600]!
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      groundPaint,
    );

    // Add simple grass
    final Paint grassPaint = Paint()
      ..color = Colors.green[700]!
      ..strokeWidth = 2;

    for (int i = 0; i < size.width.toInt(); i += 15) {
      double grassHeight = 5 + math.Random(i).nextDouble() * 10;
      canvas.drawLine(
        Offset(i.toDouble(), groundY),
        Offset(i.toDouble() + 2, groundY - grassHeight),
        grassPaint,
      );
      canvas.drawLine(
        Offset(i.toDouble() + 3, groundY),
        Offset(i.toDouble() + 5, groundY - grassHeight * 0.8),
        grassPaint,
      );
    }
  }

  void _drawBronzeTree(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw trunk based on growth
    _drawGrowingTrunk(canvas, size, centerX, groundY);

    // Draw branches based on growth level
    if (growthLevel > 0) {
      _drawGrowingBranches(canvas, size, centerX, groundY);
    }
  }

  void _drawGrowingTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint trunkPaint = Paint()
      ..color = Color(0xFF8B4513)
      ..style = PaintingStyle.fill;

    // Calculate trunk height based on growth
    double maxTrunkHeight = size.height * 0.48;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 10) / 30.0);

    double trunkBase = groundY;
    double trunkTop = groundY - currentTrunkHeight;

    // Create trunk shape that grows
    final Path trunkPath = Path();

    double baseWidth = 25 * math.min(1.0, (growthLevel + 5) / 20.0);
    double topWidth = 20 * math.min(1.0, (growthLevel + 5) / 20.0);

    trunkPath.moveTo(centerX - baseWidth/2, trunkBase);
    trunkPath.lineTo(centerX - topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + baseWidth/2, trunkBase);
    trunkPath.close();

    canvas.drawPath(trunkPath, trunkPaint);

    // Add bark texture if trunk is developed enough
    if (growthLevel > 5) {
      _drawBarkTexture(canvas, centerX, groundY, currentTrunkHeight, baseWidth, topWidth);
    }
  }

  void _drawBarkTexture(Canvas canvas, double centerX, double groundY, double trunkHeight, double baseWidth, double topWidth) {
    final Paint darkBarkPaint = Paint()
      ..color = Color(0xFF654321)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint lightBarkPaint = Paint()
      ..color = Color(0xFFA0522D)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Vertical bark lines
    int numLines = math.min(8, growthLevel ~/ 3);
    for (int i = 0; i < numLines; i++) {
      double x = centerX - baseWidth/2 + 3 + (i * (baseWidth - 6) / 8);
      double topY = groundY - trunkHeight + 15;
      double bottomY = groundY - 5;

      Path barkLine = Path();
      barkLine.moveTo(x, bottomY);

      int segments = 8;
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 1.5 * math.sin(j * 0.8 + i * 0.5) * (1 - j/segments);
        barkLine.lineTo(x + offset, segmentY);
      }

      canvas.drawPath(barkLine, darkBarkPaint);
    }
  }

  void _drawGrowingBranches(Canvas canvas, Size size, double centerX, double groundY) {
    double maxTrunkHeight = size.height * 0.48;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 10) / 30.0);
    double trunkTop = groundY - currentTrunkHeight;

    final Paint branchPaint = Paint()
      ..color = Color(0xFF8B4513)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw branches progressively based on growth level
    if (growthLevel >= 5) _drawMainBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
    if (growthLevel >= 15) _drawSecondaryBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
    if (growthLevel >= 25) _drawDetailBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
    if (growthLevel >= 35) _drawFineBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
  }

  void _drawMainBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 8;

    // Draw main branches progressively
    List<List<Offset>> mainBranches = [
      // First main branches (appear at growth 5-10)
      [Offset(centerX - 3, trunkTop + 15), Offset(centerX - 15, trunkTop + 5), Offset(centerX - 30, trunkTop - 10)],
      [Offset(centerX + 3, trunkTop + 15), Offset(centerX + 15, trunkTop + 5), Offset(centerX + 30, trunkTop - 10)],
    ];

    if (growth >= 8) {
      mainBranches.addAll([
        [Offset(centerX - 30, trunkTop - 10), Offset(centerX - 45, trunkTop - 20), Offset(centerX - 60, trunkTop - 25)],
        [Offset(centerX + 30, trunkTop - 10), Offset(centerX + 45, trunkTop - 20), Offset(centerX + 60, trunkTop - 25)],
      ]);
    }

    if (growth >= 12) {
      mainBranches.addAll([
        [Offset(centerX - 2, trunkTop + 5), Offset(centerX - 10, trunkTop - 15), Offset(centerX - 20, trunkTop - 35)],
        [Offset(centerX + 2, trunkTop + 5), Offset(centerX + 10, trunkTop - 15), Offset(centerX + 20, trunkTop - 35)],
      ]);
    }

    for (var branch in mainBranches) {
      _drawBranchPath(canvas, paint, branch);
    }
  }

  void _drawSecondaryBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 5;

    List<List<Offset>> secondaryBranches = [];

    // Add secondary branches progressively
    if (growth >= 15) {
      secondaryBranches.addAll([
        [Offset(centerX - 45, trunkTop - 20), Offset(centerX - 55, trunkTop - 30), Offset(centerX - 65, trunkTop - 35)],
        [Offset(centerX + 45, trunkTop - 20), Offset(centerX + 55, trunkTop - 30), Offset(centerX + 65, trunkTop - 35)],
      ]);
    }

    if (growth >= 18) {
      secondaryBranches.addAll([
        [Offset(centerX - 60, trunkTop - 25), Offset(centerX - 70, trunkTop - 20), Offset(centerX - 80, trunkTop - 15)],
        [Offset(centerX + 60, trunkTop - 25), Offset(centerX + 70, trunkTop - 20), Offset(centerX + 80, trunkTop - 15)],
      ]);
    }

    if (growth >= 22) {
      secondaryBranches.addAll([
        [Offset(centerX - 20, trunkTop - 35), Offset(centerX - 30, trunkTop - 45), Offset(centerX - 35, trunkTop - 55)],
        [Offset(centerX + 20, trunkTop - 35), Offset(centerX + 30, trunkTop - 45), Offset(centerX + 35, trunkTop - 55)],
      ]);
    }

    for (var branch in secondaryBranches) {
      _drawBranchPath(canvas, paint, branch);
    }
  }

  void _drawDetailBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 3;

    List<List<Offset>> detailBranches = [];

    // Add detail branches progressively
    if (growth >= 25) {
      detailBranches.addAll([
        [Offset(centerX - 65, trunkTop - 35), Offset(centerX - 70, trunkTop - 40), Offset(centerX - 75, trunkTop - 45)],
        [Offset(centerX + 65, trunkTop - 35), Offset(centerX + 70, trunkTop - 40), Offset(centerX + 75, trunkTop - 45)],
      ]);
    }

    if (growth >= 30) {
      detailBranches.addAll([
        [Offset(centerX - 80, trunkTop - 15), Offset(centerX - 85, trunkTop - 10), Offset(centerX - 90, trunkTop - 8)],
        [Offset(centerX + 80, trunkTop - 15), Offset(centerX + 85, trunkTop - 10), Offset(centerX + 90, trunkTop - 8)],
        [Offset(centerX - 35, trunkTop - 55), Offset(centerX - 40, trunkTop - 60), Offset(centerX - 42, trunkTop - 65)],
        [Offset(centerX + 35, trunkTop - 55), Offset(centerX + 40, trunkTop - 60), Offset(centerX + 42, trunkTop - 65)],
      ]);
    }

    for (var branch in detailBranches) {
      _drawBranchPath(canvas, paint, branch);
    }
  }

  void _drawFineBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 2;

    // Generate fine branches at endpoints based on growth
    List<Offset> endpoints = [
      Offset(centerX - 90, trunkTop - 8),
      Offset(centerX - 75, trunkTop - 45),
      Offset(centerX - 42, trunkTop - 65),
      Offset(centerX + 90, trunkTop - 8),
      Offset(centerX + 75, trunkTop - 45),
      Offset(centerX + 42, trunkTop - 65),
    ];

    int numTwigs = math.min(endpoints.length, (growth - 34) * 2);

    for (int i = 0; i < numTwigs && i < endpoints.length; i++) {
      Offset endpoint = endpoints[i];

      // Draw small twigs
      for (int j = 0; j < 3; j++) {
        double angle = (j - 1) * 0.5;
        double length = 8 + j * 2;

        Offset twigEnd = Offset(
          endpoint.dx + length * math.cos(angle),
          endpoint.dy + length * math.sin(angle) - 5,
        );

        canvas.drawLine(endpoint, twigEnd, paint);
      }
    }
  }

  void _drawBranchPath(Canvas canvas, Paint paint, List<Offset> points) {
    if (points.length < 2) return;

    Path path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      if (i == points.length - 1) {
        path.lineTo(points[i].dx, points[i].dy);
      } else {
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

    // Define leaf positions that will be filled progressively
    List<Offset> leafPositions = [
      // Early leaves (growth 1-15)
      Offset(centerX - 30, trunkTop - 10),
      Offset(centerX + 30, trunkTop - 10),
      Offset(centerX - 45, trunkTop - 20),
      Offset(centerX + 45, trunkTop - 20),
      Offset(centerX - 20, trunkTop - 35),
      Offset(centerX + 20, trunkTop - 35),

      // Mid leaves (growth 16-30)
      Offset(centerX - 60, trunkTop - 25),
      Offset(centerX + 60, trunkTop - 25),
      Offset(centerX - 65, trunkTop - 35),
      Offset(centerX + 65, trunkTop - 35),
      Offset(centerX - 80, trunkTop - 15),
      Offset(centerX + 80, trunkTop - 15),
      Offset(centerX - 35, trunkTop - 55),
      Offset(centerX + 35, trunkTop - 55),

      // Late leaves (growth 31-49)
      Offset(centerX - 70, trunkTop - 40),
      Offset(centerX + 70, trunkTop - 40),
      Offset(centerX - 75, trunkTop - 45),
      Offset(centerX + 75, trunkTop - 45),
      Offset(centerX - 90, trunkTop - 8),
      Offset(centerX + 90, trunkTop - 8),
      Offset(centerX - 42, trunkTop - 65),
      Offset(centerX + 42, trunkTop - 65),
      Offset(centerX - 55, trunkTop - 30),
      Offset(centerX + 55, trunkTop - 30),
      Offset(centerX - 85, trunkTop - 10),
      Offset(centerX + 85, trunkTop - 10),
    ];

    // Take only the positions based on current growth
    int numEndpoints = math.min(growthLevel, leafPositions.length);

    for (int i = 0; i < numEndpoints; i++) {
      Offset point = leafPositions[i];
      double angle = math.atan2(point.dy - trunkTop, point.dx - centerX);
      endpoints.add(BranchPoint(point.dx, point.dy, angle));
    }

    return endpoints;
  }

  void _drawLeavesOnBranches(Canvas canvas, Size size, double centerX, double groundY) {
    if (growthLevel == 0) return;

    double maxTrunkHeight = size.height * 0.48;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 10) / 30.0);
    double trunkTop = groundY - currentTrunkHeight;

    List<BranchPoint> branchEndpoints = _getBranchEndpoints(centerX, trunkTop);

    // Draw leaves for each growth level
    for (int i = 0; i < branchEndpoints.length; i++) {
      BranchPoint point = branchEndpoints[i];
      _drawLeafAtPoint(canvas, point, i);
    }
  }

  void _drawLeafAtPoint(Canvas canvas, BranchPoint point, int index) {
    canvas.save();
    canvas.translate(point.x, point.y);

    // Animate newest leaf
    double scale = leafScale;
    if (index == growthLevel - 1) {
      scale = leafScale * 0.8 + 0.2; // Smooth scale-in animation
    }
    canvas.scale(scale);

    // Varied leaf colors
    Color leafColor = index % 5 == 0 ? Color(0xFF228B22) :
    index % 5 == 1 ? Color(0xFF32CD32) :
    index % 5 == 2 ? Color(0xFF90EE90) :
    index % 5 == 3 ? Color(0xFF006400) :
    Color(0xFF9ACD32);

    Paint leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    double leafSize = 12 + (index % 3) * 2;

    // Draw leaf shape
    Path leafPath = Path();
    leafPath.moveTo(0, -leafSize);
    leafPath.quadraticBezierTo(leafSize * 0.8, -leafSize * 0.5, leafSize * 0.4, 0);
    leafPath.quadraticBezierTo(leafSize * 0.6, leafSize * 0.3, 0, leafSize * 0.4);
    leafPath.quadraticBezierTo(-leafSize * 0.6, leafSize * 0.3, -leafSize * 0.4, 0);
    leafPath.quadraticBezierTo(-leafSize * 0.8, -leafSize * 0.5, 0, -leafSize);

    canvas.drawPath(leafPath, leafPaint);

    // Add leaf veins
    Paint veinPaint = Paint()
      ..color = Color(0xFF006400)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, -leafSize * 0.9),
      Offset(0, leafSize * 0.3),
      veinPaint,
    );

    canvas.restore();
  }

  void _drawMultipleBronzeFlowers(Canvas canvas, Size size, double centerX, double groundY) {
    double maxTrunkHeight = size.height * 0.48;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 10) / 30.0);
    double trunkTop = groundY - currentTrunkHeight;

    // Get branch endpoints for flower positions
    List<BranchPoint> branchEndpoints = _getBranchEndpoints(centerX, trunkTop);

    // Select 5 branch endpoints for flowers (increased from 3)
    List<int> flowerIndices = [
      branchEndpoints.length - 1,  // Top branch
      branchEndpoints.length - 3,  // Upper left
      branchEndpoints.length - 5,  // Upper right
      branchEndpoints.length - 7,  // Mid left
      branchEndpoints.length - 9,  // Mid right
    ];

    // Draw each flower at branch endpoints
    for (int i = 0; i < flowerIndices.length; i++) {
      if (flowerIndices[i] >= 0 && flowerIndices[i] < branchEndpoints.length) {
        BranchPoint branch = branchEndpoints[flowerIndices[i]];
        double individualRotation = flowerRotation + (i * 0.5);
        _drawBronzeFlowerAtPosition(canvas, Offset(branch.x, branch.y), individualRotation, i);
      }
    }
  }

  void _drawBronzeFlowerAtPosition(Canvas canvas, Offset position, double rotation, int flowerIndex) {
    double flowerCenterX = position.dx;
    double flowerCenterY = position.dy;

    // Bronze flower colors
    Color petalColor = flowerIndex % 3 == 0 ? Color(0xFFDAA520) :
    flowerIndex % 3 == 1 ? Color(0xFFFFD700) :
    Color(0xFFDEB887);

    final Paint petalPaint = Paint()
      ..color = petalColor
      ..style = PaintingStyle.fill;

    final Paint petalOutlinePaint = Paint()
      ..color = Color(0xFFB8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw petals
    for (int i = 0; i < 8; i++) {
      double angle = (i * 2 * math.pi / 8) + rotation * 0.1;
      double petalLength = 16 * flowerBloom;
      double petalWidth = 12 * flowerBloom;

      canvas.save();
      canvas.translate(flowerCenterX, flowerCenterY);
      canvas.rotate(angle);

      final Path petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(petalWidth/2, -petalLength/3, petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(0, -petalLength * 0.8, -petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(-petalWidth/2, -petalLength/3, 0, 0);

      canvas.drawPath(petalPath, petalPaint);
      canvas.drawPath(petalPath, petalOutlinePaint);
      canvas.restore();
    }

    // Draw flower center
    final Paint centerPaint = Paint()
      ..color = Color(0xFFCD7F32)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(flowerCenterX, flowerCenterY), 8 * flowerBloom, centerPaint);

    // Inner center detail
    canvas.drawCircle(
        Offset(flowerCenterX, flowerCenterY),
        5 * flowerBloom,
        Paint()
          ..color = Color(0xFFB8860B)
          ..style = PaintingStyle.fill
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is BronzeTreePainter &&
        (oldDelegate.growthLevel != growthLevel ||
            oldDelegate.totalGrowth != totalGrowth ||
            oldDelegate.flowerBloom != flowerBloom ||
            oldDelegate.flowerRotation != flowerRotation ||
            oldDelegate.leafScale != leafScale ||
            oldDelegate.waterDropAnimation != waterDropAnimation);
  }
}