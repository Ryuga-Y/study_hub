import 'package:flutter/material.dart';
import 'dart:math' as math;

class BranchPoint {
  final double x;
  final double y;
  final double angle;

  BranchPoint(this.x, this.y, this.angle);
}

class SilverTreePainter extends CustomPainter {
  final int growthLevel;
  final double totalGrowth;
  final double flowerBloom;
  final double flowerRotation;
  final double leafScale;
  final double waterDropAnimation;

  SilverTreePainter({
    required this.growthLevel,
    required this.totalGrowth,
    required this.flowerBloom,
    required this.flowerRotation,
    required this.leafScale,
    this.waterDropAnimation = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // IMPORTANT: Always use consistent center point
    final double centerX = size.width / 2;
    final double groundY = size.height * 0.9;

    // Draw water drop animation
    if (waterDropAnimation > 0) {
      _drawWaterDropAnimation(canvas, size, centerX, groundY);
    }

    // Draw ground line only
    _drawGroundLine(canvas, size, groundY);

    // Draw the silver tree
    _drawSilverTree(canvas, size, centerX, groundY);

    // Draw silver leaves based on growth
    _drawSilverLeavesOnBranches(canvas, size, centerX, groundY);

    // Draw silver flowers if 100% complete
    if (totalGrowth >= 1.0) {
      _drawMultipleSilverFlowers(canvas, size, centerX, groundY);
    }
  }

  void _drawWaterDropAnimation(Canvas canvas, Size size, double centerX, double groundY) {
    double dropY = 30 + (waterDropAnimation * (groundY - 80));
    double opacity = 1.0 - (waterDropAnimation * 0.7);

    Paint dropPaint = Paint()
      ..color = Colors.lightBlue[300]!.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Draw water drop with silver tint
    canvas.drawCircle(Offset(centerX, dropY), 9 * (1 - waterDropAnimation * 0.3), dropPaint);

    // Draw splash effect with silver sparkles
    if (waterDropAnimation > 0.8) {
      double splashRadius = 25 * (waterDropAnimation - 0.8) * 5;
      Paint splashPaint = Paint()
        ..color = Colors.lightBlue[200]!.withOpacity(0.4 * (1 - (waterDropAnimation - 0.8) * 5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(Offset(centerX, groundY), splashRadius, splashPaint);

      // Add silver sparkles at fixed positions
      Paint sparklePaint = Paint()
        ..color = Color(0xFFC0C0C0).withOpacity(0.6 * (1 - (waterDropAnimation - 0.8) * 5))
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 6; i++) {
        double angle = i * math.pi / 3;
        double sparkleDistance = splashRadius * 0.8;
        double x = centerX + sparkleDistance * math.cos(angle);
        double y = groundY + sparkleDistance * math.sin(angle);
        canvas.drawCircle(Offset(x, y), 2, sparklePaint);
      }
    }
  }

  void _drawGroundLine(Canvas canvas, Size size, double groundY) {
    // Silver-tinted ground
    final Paint groundPaint = Paint()
      ..color = Color(0xFF708090)
      ..strokeWidth = 4;

    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      groundPaint,
    );

    // Add silver accent line
    final Paint silverAccent = Paint()
      ..color = Color(0xFFC0C0C0)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, groundY - 2),
      Offset(size.width, groundY - 2),
      silverAccent,
    );

    // Add enhanced grass with silver tips at fixed positions
    final Paint grassPaint = Paint()
      ..color = Colors.green[600]!
      ..strokeWidth = 2.5;

    final Paint silverGrassTip = Paint()
      ..color = Color(0xFFB0C4DE)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 25; i++) {
      double x = (i / 25) * size.width;
      double grassHeight = 8 + (i % 4) * 3; // Fixed pattern

      // Main grass blade
      canvas.drawLine(
        Offset(x, groundY),
        Offset(x + 2, groundY - grassHeight),
        grassPaint,
      );

      // Silver tip
      canvas.drawLine(
        Offset(x + 2, groundY - grassHeight),
        Offset(x + 2.5, groundY - grassHeight - 3),
        silverGrassTip,
      );

      // Second blade
      canvas.drawLine(
        Offset(x + 4, groundY),
        Offset(x + 6, groundY - grassHeight * 0.8),
        grassPaint,
      );
    }
  }

  void _drawSilverTree(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw trunk based on growth
    _drawSilverGrowingTrunk(canvas, size, centerX, groundY);

    // Draw branches based on growth level
    if (growthLevel > 0) {
      _drawSilverGrowingBranches(canvas, size, centerX, groundY);
    }
  }

  void _drawSilverGrowingTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint trunkPaint = Paint()
      ..color = Color(0xFF708090)
      ..style = PaintingStyle.fill;

    // Calculate trunk height based on growth - taller than bronze
    double maxTrunkHeight = size.height * 0.52;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 8) / 25.0);

    double trunkBase = groundY;
    double trunkTop = groundY - currentTrunkHeight;

    // Create trunk shape that grows - wider than bronze
    final Path trunkPath = Path();

    double baseWidth = 30 * math.min(1.0, (growthLevel + 3) / 15.0);
    double topWidth = 24 * math.min(1.0, (growthLevel + 3) / 15.0);

    trunkPath.moveTo(centerX - baseWidth/2, trunkBase);
    trunkPath.lineTo(centerX - topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + baseWidth/2, trunkBase);
    trunkPath.close();

    canvas.drawPath(trunkPath, trunkPaint);

    // Add silver highlights
    if (growthLevel > 3) {
      final Paint silverHighlight = Paint()
        ..color = Color(0xFFC0C0C0)
        ..style = PaintingStyle.fill;

      final Path highlightPath = Path();
      highlightPath.moveTo(centerX - baseWidth/2 + 3, trunkBase);
      highlightPath.lineTo(centerX - topWidth/2 + 2, trunkTop);
      highlightPath.lineTo(centerX - topWidth/2 + 8, trunkTop);
      highlightPath.lineTo(centerX - baseWidth/2 + 9, trunkBase);
      highlightPath.close();

      canvas.drawPath(highlightPath, silverHighlight);
    }

    // Add silver bark texture if trunk is developed enough
    if (growthLevel > 8) {
      _drawSilverBarkTexture(canvas, centerX, groundY, currentTrunkHeight, baseWidth, topWidth);
    }
  }

  void _drawSilverBarkTexture(Canvas canvas, double centerX, double groundY, double trunkHeight, double baseWidth, double topWidth) {
    final Paint darkBarkPaint = Paint()
      ..color = Color(0xFF2F4F4F)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final Paint silverBarkPaint = Paint()
      ..color = Color(0xFFC0C0C0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Enhanced bark lines
    int numLines = math.min(12, growthLevel ~/ 2);
    for (int i = 0; i < numLines; i++) {
      double x = centerX - baseWidth/2 + 3 + (i * (baseWidth - 6) / 12);
      double topY = groundY - trunkHeight + 20;
      double bottomY = groundY - 5;

      Path barkLine = Path();
      barkLine.moveTo(x, bottomY);

      int segments = 12;
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 2 * math.sin(j * 1.0 + i * 0.6) * (1 - j/segments);
        barkLine.lineTo(x + offset, segmentY);
      }

      canvas.drawPath(barkLine, darkBarkPaint);

      // Add silver accent
      if (i % 2 == 0) {
        Path silverLine = Path();
        silverLine.moveTo(x + 1, bottomY);
        for (int j = 1; j <= segments; j++) {
          double segmentY = bottomY - (bottomY - topY) * (j / segments);
          double offset = 1.5 * math.sin(j * 0.8 + i * 0.4) * (1 - j/segments);
          silverLine.lineTo(x + 1 + offset, segmentY);
        }
        canvas.drawPath(silverLine, silverBarkPaint);
      }
    }
  }

  void _drawSilverGrowingBranches(Canvas canvas, Size size, double centerX, double groundY) {
    double maxTrunkHeight = size.height * 0.52;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 8) / 25.0);
    double trunkTop = groundY - currentTrunkHeight;

    final Paint branchPaint = Paint()
      ..color = Color(0xFF708090)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw branches progressively - more elaborate than bronze
    if (growthLevel >= 3) _drawSilverMainBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
    if (growthLevel >= 12) _drawSilverSecondaryBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
    if (growthLevel >= 22) _drawSilverDetailBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
    if (growthLevel >= 32) _drawSilverFineBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
  }

  void _drawSilverMainBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 10;

    List<List<Offset>> mainBranches = [];

    // Fixed branch positions
    if (growth >= 3) {
      mainBranches.addAll([
        [Offset(centerX - 4, trunkTop + 20), Offset(centerX - 20, trunkTop + 8), Offset(centerX - 40, trunkTop - 12)],
        [Offset(centerX + 4, trunkTop + 20), Offset(centerX + 20, trunkTop + 8), Offset(centerX + 40, trunkTop - 12)],
      ]);
    }

    if (growth >= 6) {
      mainBranches.addAll([
        [Offset(centerX - 40, trunkTop - 12), Offset(centerX - 60, trunkTop - 25), Offset(centerX - 80, trunkTop - 35)],
        [Offset(centerX + 40, trunkTop - 12), Offset(centerX + 60, trunkTop - 25), Offset(centerX + 80, trunkTop - 35)],
      ]);
    }

    if (growth >= 9) {
      mainBranches.addAll([
        [Offset(centerX - 3, trunkTop + 8), Offset(centerX - 15, trunkTop - 20), Offset(centerX - 30, trunkTop - 45)],
        [Offset(centerX + 3, trunkTop + 8), Offset(centerX + 15, trunkTop - 20), Offset(centerX + 30, trunkTop - 45)],
        [Offset(centerX, trunkTop), Offset(centerX - 5, trunkTop - 30), Offset(centerX - 10, trunkTop - 60)],
        [Offset(centerX, trunkTop), Offset(centerX + 5, trunkTop - 30), Offset(centerX + 10, trunkTop - 60)],
      ]);
    }

    for (var branch in mainBranches) {
      _drawSilverBranchPath(canvas, paint, branch);
    }
  }

  void _drawSilverSecondaryBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 7;

    List<List<Offset>> secondaryBranches = [];

    if (growth >= 12) {
      secondaryBranches.addAll([
        [Offset(centerX - 60, trunkTop - 25), Offset(centerX - 75, trunkTop - 35), Offset(centerX - 90, trunkTop - 40)],
        [Offset(centerX + 60, trunkTop - 25), Offset(centerX + 75, trunkTop - 35), Offset(centerX + 90, trunkTop - 40)],
      ]);
    }

    if (growth >= 16) {
      secondaryBranches.addAll([
        [Offset(centerX - 80, trunkTop - 35), Offset(centerX - 95, trunkTop - 30), Offset(centerX - 110, trunkTop - 25)],
        [Offset(centerX + 80, trunkTop - 35), Offset(centerX + 95, trunkTop - 30), Offset(centerX + 110, trunkTop - 25)],
        [Offset(centerX - 30, trunkTop - 45), Offset(centerX - 45, trunkTop - 55), Offset(centerX - 55, trunkTop - 65)],
        [Offset(centerX + 30, trunkTop - 45), Offset(centerX + 45, trunkTop - 55), Offset(centerX + 55, trunkTop - 65)],
      ]);
    }

    if (growth >= 20) {
      secondaryBranches.addAll([
        [Offset(centerX - 10, trunkTop - 60), Offset(centerX - 20, trunkTop - 70), Offset(centerX - 25, trunkTop - 80)],
        [Offset(centerX + 10, trunkTop - 60), Offset(centerX + 20, trunkTop - 70), Offset(centerX + 25, trunkTop - 80)],
      ]);
    }

    for (var branch in secondaryBranches) {
      _drawSilverBranchPath(canvas, paint, branch);
    }
  }

  void _drawSilverDetailBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 4;

    List<List<Offset>> detailBranches = [];

    if (growth >= 22) {
      detailBranches.addAll([
        [Offset(centerX - 90, trunkTop - 40), Offset(centerX - 100, trunkTop - 45), Offset(centerX - 105, trunkTop - 50)],
        [Offset(centerX + 90, trunkTop - 40), Offset(centerX + 100, trunkTop - 45), Offset(centerX + 105, trunkTop - 50)],
      ]);
    }

    if (growth >= 27) {
      detailBranches.addAll([
        [Offset(centerX - 110, trunkTop - 25), Offset(centerX - 120, trunkTop - 20), Offset(centerX - 130, trunkTop - 18)],
        [Offset(centerX + 110, trunkTop - 25), Offset(centerX + 120, trunkTop - 20), Offset(centerX + 130, trunkTop - 18)],
        [Offset(centerX - 55, trunkTop - 65), Offset(centerX - 65, trunkTop - 70), Offset(centerX - 70, trunkTop - 75)],
        [Offset(centerX + 55, trunkTop - 65), Offset(centerX + 65, trunkTop - 70), Offset(centerX + 70, trunkTop - 75)],
        [Offset(centerX - 25, trunkTop - 80), Offset(centerX - 35, trunkTop - 85), Offset(centerX - 40, trunkTop - 90)],
        [Offset(centerX + 25, trunkTop - 80), Offset(centerX + 35, trunkTop - 85), Offset(centerX + 40, trunkTop - 90)],
      ]);
    }

    for (var branch in detailBranches) {
      _drawSilverBranchPath(canvas, paint, branch);
    }
  }

  void _drawSilverFineBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 2.5;

    List<Offset> endpoints = [
      Offset(centerX - 105, trunkTop - 50),
      Offset(centerX - 130, trunkTop - 18),
      Offset(centerX - 70, trunkTop - 75),
      Offset(centerX - 40, trunkTop - 90),
      Offset(centerX + 105, trunkTop - 50),
      Offset(centerX + 130, trunkTop - 18),
      Offset(centerX + 70, trunkTop - 75),
      Offset(centerX + 40, trunkTop - 90),
    ];

    int numTwigs = math.min(endpoints.length, (growth - 31) * 2);

    for (int i = 0; i < numTwigs && i < endpoints.length; i++) {
      Offset endpoint = endpoints[i];

      // Draw more elaborate twigs
      for (int j = 0; j < 4; j++) {
        double angle = (j - 1.5) * 0.4;
        double length = 12 + j * 3;

        Offset twigEnd = Offset(
          endpoint.dx + length * math.cos(angle),
          endpoint.dy + length * math.sin(angle) - 8,
        );

        canvas.drawLine(endpoint, twigEnd, paint);

        // Add sub-twigs
        if (j == 1 || j == 2) {
          for (int k = 0; k < 2; k++) {
            double subAngle = angle + (k == 0 ? 0.3 : -0.3);
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

  void _drawSilverBranchPath(Canvas canvas, Paint paint, List<Offset> points) {
    if (points.length < 2) return;

    // Draw main branch
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

    // Add silver highlight
    Paint silverHighlight = Paint()
      ..color = Color(0xFFB0C4DE)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = paint.strokeWidth * 0.3;

    Path highlightPath = Path();
    highlightPath.moveTo(points[0].dx - 1, points[0].dy - 1);

    for (int i = 1; i < points.length; i++) {
      if (i == points.length - 1) {
        highlightPath.lineTo(points[i].dx - 1, points[i].dy - 1);
      } else {
        Offset current = Offset(points[i].dx - 1, points[i].dy - 1);
        Offset next = Offset(points[i + 1].dx - 1, points[i + 1].dy - 1);
        Offset controlPoint = Offset(
          current.dx + (next.dx - current.dx) * 0.3,
          current.dy + (next.dy - current.dy) * 0.3,
        );
        highlightPath.quadraticBezierTo(controlPoint.dx, controlPoint.dy, current.dx, current.dy);
      }
    }

    canvas.drawPath(highlightPath, silverHighlight);
  }

  List<BranchPoint> _getSilverBranchEndpoints(double centerX, double trunkTop) {
    List<BranchPoint> endpoints = [];

    // Enhanced fixed leaf positions for silver tree
    List<Offset> leafPositions = [
      // Early leaves (growth 1-10)
      Offset(centerX - 40, trunkTop - 12),
      Offset(centerX + 40, trunkTop - 12),
      Offset(centerX - 60, trunkTop - 25),
      Offset(centerX + 60, trunkTop - 25),
      Offset(centerX - 30, trunkTop - 45),
      Offset(centerX + 30, trunkTop - 45),
      Offset(centerX - 10, trunkTop - 60),
      Offset(centerX + 10, trunkTop - 60),

      // Mid leaves (growth 11-25)
      Offset(centerX - 80, trunkTop - 35),
      Offset(centerX + 80, trunkTop - 35),
      Offset(centerX - 90, trunkTop - 40),
      Offset(centerX + 90, trunkTop - 40),
      Offset(centerX - 110, trunkTop - 25),
      Offset(centerX + 110, trunkTop - 25),
      Offset(centerX - 55, trunkTop - 65),
      Offset(centerX + 55, trunkTop - 65),
      Offset(centerX - 25, trunkTop - 80),
      Offset(centerX + 25, trunkTop - 80),
      Offset(centerX - 45, trunkTop - 55),
      Offset(centerX + 45, trunkTop - 55),

      // Late leaves (growth 26-49)
      Offset(centerX - 100, trunkTop - 45),
      Offset(centerX + 100, trunkTop - 45),
      Offset(centerX - 105, trunkTop - 50),
      Offset(centerX + 105, trunkTop - 50),
      Offset(centerX - 120, trunkTop - 20),
      Offset(centerX + 120, trunkTop - 20),
      Offset(centerX - 130, trunkTop - 18),
      Offset(centerX + 130, trunkTop - 18),
      Offset(centerX - 70, trunkTop - 75),
      Offset(centerX + 70, trunkTop - 75),
      Offset(centerX - 40, trunkTop - 90),
      Offset(centerX + 40, trunkTop - 90),
      Offset(centerX - 75, trunkTop - 35),
      Offset(centerX + 75, trunkTop - 35),
      Offset(centerX - 95, trunkTop - 30),
      Offset(centerX + 95, trunkTop - 30),
    ];

    int numEndpoints = math.min(growthLevel, leafPositions.length);

    for (int i = 0; i < numEndpoints; i++) {
      Offset point = leafPositions[i];
      double angle = math.atan2(point.dy - trunkTop, point.dx - centerX);
      endpoints.add(BranchPoint(point.dx, point.dy, angle));
    }

    return endpoints;
  }

  void _drawSilverLeavesOnBranches(Canvas canvas, Size size, double centerX, double groundY) {
    if (growthLevel == 0) return;

    double maxTrunkHeight = size.height * 0.52;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 8) / 25.0);
    double trunkTop = groundY - currentTrunkHeight;

    List<BranchPoint> branchEndpoints = _getSilverBranchEndpoints(centerX, trunkTop);

    for (int i = 0; i < branchEndpoints.length; i++) {
      BranchPoint point = branchEndpoints[i];
      _drawSilverLeafAtPoint(canvas, point, i);
    }
  }

  void _drawSilverLeafAtPoint(Canvas canvas, BranchPoint point, int index) {
    canvas.save();
    canvas.translate(point.x, point.y);

    // Animate newest leaf
    double scale = leafScale;
    if (index == growthLevel - 1) {
      scale = leafScale * 0.8 + 0.2;
    }
    canvas.scale(scale);

    // Silver-themed leaf colors - fixed pattern
    Color leafColor = [
      Color(0xFF228B22),
      Color(0xFF32CD32),
      Color(0xFF90EE90),
      Color(0xFF006400),
      Color(0xFF9ACD32),
      Color(0xFF8FBC8F),
      Color(0xFF98FB98),
    ][index % 7];

    Paint leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    double leafSize = 14 + (index % 4) * 2;

    // Draw enhanced leaf shape
    Path leafPath = Path();
    leafPath.moveTo(0, -leafSize);
    leafPath.quadraticBezierTo(leafSize * 1.0, -leafSize * 0.7, leafSize * 0.6, 0);
    leafPath.quadraticBezierTo(leafSize * 0.8, leafSize * 0.5, 0, leafSize * 0.6);
    leafPath.quadraticBezierTo(-leafSize * 0.8, leafSize * 0.5, -leafSize * 0.6, 0);
    leafPath.quadraticBezierTo(-leafSize * 1.0, -leafSize * 0.7, 0, -leafSize);

    canvas.drawPath(leafPath, leafPaint);

    // Add silver shimmer
    Paint shimmerPaint = Paint()
      ..color = Color(0xFFE6E6FA).withOpacity(0.4)
      ..style = PaintingStyle.fill;

    Path shimmerPath = Path();
    shimmerPath.moveTo(0, -leafSize * 0.8);
    shimmerPath.quadraticBezierTo(leafSize * 0.3, -leafSize * 0.4, leafSize * 0.2, -leafSize * 0.1);
    shimmerPath.quadraticBezierTo(leafSize * 0.1, leafSize * 0.1, 0, leafSize * 0.2);
    shimmerPath.quadraticBezierTo(-leafSize * 0.1, leafSize * 0.1, -leafSize * 0.2, -leafSize * 0.1);
    shimmerPath.quadraticBezierTo(-leafSize * 0.3, -leafSize * 0.4, 0, -leafSize * 0.8);

    canvas.drawPath(shimmerPath, shimmerPaint);

    // Enhanced veins
    Paint veinPaint = Paint()
      ..color = Color(0xFF2F4F4F)
      ..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(0, -leafSize * 1.0),
      Offset(0, leafSize * 0.5),
      veinPaint,
    );

    // Side veins
    for (int i = 0; i < 4; i++) {
      double veinY = -leafSize * 0.8 + (i * leafSize * 0.35);
      double veinLength = leafSize * 0.5 * (1 - i * 0.15);

      canvas.drawLine(
        Offset(0, veinY),
        Offset(-veinLength, veinY + veinLength * 0.4),
        veinPaint,
      );
      canvas.drawLine(
        Offset(0, veinY),
        Offset(veinLength, veinY + veinLength * 0.4),
        veinPaint,
      );
    }

    canvas.restore();
  }

  void _drawMultipleSilverFlowers(Canvas canvas, Size size, double centerX, double groundY) {
    double maxTrunkHeight = size.height * 0.52;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 8) / 25.0);
    double trunkTop = groundY - currentTrunkHeight;

    // Get branch endpoints for flower positions
    List<BranchPoint> branchEndpoints = _getSilverBranchEndpoints(centerX, trunkTop);

    // Select 6 branch endpoints for flowers
    List<int> flowerIndices = [
      branchEndpoints.length - 1,
      branchEndpoints.length - 3,
      branchEndpoints.length - 5,
      branchEndpoints.length - 7,
      branchEndpoints.length - 9,
      branchEndpoints.length - 11,
    ];

    // Draw each flower at branch endpoints
    for (int i = 0; i < flowerIndices.length; i++) {
      if (flowerIndices[i] >= 0 && flowerIndices[i] < branchEndpoints.length) {
        BranchPoint branch = branchEndpoints[flowerIndices[i]];
        double individualRotation = flowerRotation + (i * 0.6);
        _drawSilverFlowerAtPosition(canvas, Offset(branch.x, branch.y), individualRotation, i);
      }
    }
  }

  void _drawSilverFlowerAtPosition(Canvas canvas, Offset position, double rotation, int flowerIndex) {
    double flowerCenterX = position.dx;
    double flowerCenterY = position.dy;

    // Silver flower colors
    final Paint petalPaint = Paint()
      ..color = Color(0xFFE6E6FA)
      ..style = PaintingStyle.fill;

    final Paint petalOutlinePaint = Paint()
      ..color = Color(0xFF9370DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw 10 petals for silver
    for (int i = 0; i < 10; i++) {
      double angle = (i * 2 * math.pi / 10) + rotation * 0.12;
      double petalLength = 20 * flowerBloom;
      double petalWidth = 14 * flowerBloom;

      canvas.save();
      canvas.translate(flowerCenterX, flowerCenterY);
      canvas.rotate(angle);

      final Path petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(petalWidth/2, -petalLength/3, petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(0, -petalLength * 0.85, -petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(-petalWidth/2, -petalLength/3, 0, 0);

      canvas.drawPath(petalPath, petalPaint);
      canvas.drawPath(petalPath, petalOutlinePaint);

      // Add white highlights
      final Paint petalHighlight = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.fill;

      final Path highlightPath = Path();
      highlightPath.moveTo(0, 0);
      highlightPath.quadraticBezierTo(petalWidth/4, -petalLength/4, petalWidth/6, -petalLength/2);
      highlightPath.quadraticBezierTo(0, -petalLength * 0.6, -petalWidth/6, -petalLength/2);
      highlightPath.quadraticBezierTo(-petalWidth/4, -petalLength/4, 0, 0);

      canvas.drawPath(highlightPath, petalHighlight);
      canvas.restore();
    }

    // Silver flower center
    final Paint centerPaint = Paint()
      ..color = Color(0xFFC0C0C0)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(flowerCenterX, flowerCenterY), 10 * flowerBloom, centerPaint);

    // Inner center
    canvas.drawCircle(
        Offset(flowerCenterX, flowerCenterY),
        7 * flowerBloom,
        Paint()
          ..color = Color(0xFF9370DB)
          ..style = PaintingStyle.fill
    );

    // Add sparkle effect
    if (flowerBloom > 0.8) {
      _drawSilverSparkles(canvas, flowerCenterX, flowerCenterY, rotation);
    }
  }

  void _drawSilverSparkles(Canvas canvas, double centerX, double centerY, double rotation) {
    final Paint sparklePaint = Paint()
      ..color = Color(0xFFE6E6FA)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final Paint silverSparklePaint = Paint()
      ..color = Color(0xFFC0C0C0)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      double angle = i * math.pi / 4 + rotation;
      double distance = 35 + 6 * math.sin(rotation * 2.5);
      double x = centerX + distance * math.cos(angle);
      double y = centerY + distance * math.sin(angle);

      Paint currentPaint = i % 2 == 0 ? sparklePaint : silverSparklePaint;

      canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), currentPaint);
      canvas.drawLine(Offset(x, y - 5), Offset(x, y + 5), currentPaint);
      canvas.drawLine(Offset(x - 4, y - 4), Offset(x + 4, y + 4), currentPaint);
      canvas.drawLine(Offset(x - 4, y + 4), Offset(x + 4, y - 4), currentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is SilverTreePainter &&
        (oldDelegate.growthLevel != growthLevel ||
            oldDelegate.totalGrowth != totalGrowth ||
            oldDelegate.flowerBloom != flowerBloom ||
            oldDelegate.flowerRotation != flowerRotation ||
            oldDelegate.leafScale != leafScale ||
            oldDelegate.waterDropAnimation != waterDropAnimation);
  }
}