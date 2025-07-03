import 'package:flutter/material.dart';
import 'dart:math' as math;

class BranchPoint {
  final double x;
  final double y;
  final double angle;

  BranchPoint(this.x, this.y, this.angle);
}

class GoldTreePainter extends CustomPainter {
  final int growthLevel;
  final double totalGrowth;
  final double flowerBloom;
  final double flowerRotation;
  final double leafScale;
  final double waterDropAnimation;

  GoldTreePainter({
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

    // Draw the gold tree
    _drawGoldTree(canvas, size, centerX, groundY);

    // Draw golden leaves based on growth
    _drawGoldLeavesOnBranches(canvas, size, centerX, groundY);

    // Draw luxury gold flowers if 100% complete
    if (totalGrowth >= 1.0) {
      _drawMultipleGoldFlowers(canvas, size, centerX, groundY);
    }
  }

  void _drawWaterDropAnimation(Canvas canvas, Size size, double centerX, double groundY) {
    double dropY = 30 + (waterDropAnimation * (groundY - 80));
    double opacity = 1.0 - (waterDropAnimation * 0.7);

    // Golden water drop
    Paint dropPaint = Paint()
      ..color = Color(0xFF87CEEB).withOpacity(opacity) // Sky blue with gold tint
      ..style = PaintingStyle.fill;

    // Draw water drop with golden glow
    canvas.drawCircle(Offset(centerX, dropY), 10 * (1 - waterDropAnimation * 0.3), dropPaint);

    // Golden glow around drop
    Paint glowPaint = Paint()
      ..color = Color(0xFFFFD700).withOpacity(opacity * 0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(Offset(centerX, dropY), 15 * (1 - waterDropAnimation * 0.3), glowPaint);

    // Draw golden splash effect
    if (waterDropAnimation > 0.8) {
      double splashRadius = 30 * (waterDropAnimation - 0.8) * 5;
      Paint splashPaint = Paint()
        ..color = Color(0xFFFFD700).withOpacity(0.5 * (1 - (waterDropAnimation - 0.8) * 5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawCircle(Offset(centerX, groundY), splashRadius, splashPaint);

      // Add golden sparkles
      Paint goldSparklePaint = Paint()
        ..color = Color(0xFFFFD700).withOpacity(0.8 * (1 - (waterDropAnimation - 0.8) * 5))
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 8; i++) {
        double angle = i * math.pi / 4;
        double sparkleDistance = splashRadius * 0.9;
        double x = centerX + sparkleDistance * math.cos(angle);
        double y = groundY + sparkleDistance * math.sin(angle);
        canvas.drawCircle(Offset(x, y), 3, goldSparklePaint);

        // Add star effect
        Paint starPaint = Paint()
          ..color = Color(0xFFFFF8DC).withOpacity(0.6 * (1 - (waterDropAnimation - 0.8) * 5))
          ..strokeWidth = 1.5;

        canvas.drawLine(Offset(x - 4, y), Offset(x + 4, y), starPaint);
        canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), starPaint);
      }
    }
  }

  void _drawGroundLine(Canvas canvas, Size size, double groundY) {
    // Luxury golden ground
    final Paint groundPaint = Paint()
      ..color = Color(0xFFDAA520)
      ..strokeWidth = 5;

    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      groundPaint,
    );

    // Multiple gold accent lines
    final Paint goldAccent1 = Paint()
      ..color = Color(0xFFFFD700)
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(0, groundY - 3),
      Offset(size.width, groundY - 3),
      goldAccent1,
    );

    final Paint goldAccent2 = Paint()
      ..color = Color(0xFFFFF8DC)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(0, groundY - 6),
      Offset(size.width, groundY - 6),
      goldAccent2,
    );

    // Luxury grass with golden tips
    final Paint grassPaint = Paint()
      ..color = Colors.green[800]!
      ..strokeWidth = 3;

    final Paint goldGrassTip = Paint()
      ..color = Color(0xFFFFD700)
      ..strokeWidth = 2;

    for (int i = 0; i < size.width.toInt(); i += 10) {
      double grassHeight = 10 + math.Random(i).nextDouble() * 15;

      // Main grass blade
      canvas.drawLine(
        Offset(i.toDouble(), groundY),
        Offset(i.toDouble() + 3, groundY - grassHeight),
        grassPaint,
      );

      // Golden tip
      canvas.drawLine(
        Offset(i.toDouble() + 3, groundY - grassHeight),
        Offset(i.toDouble() + 4, groundY - grassHeight - 5),
        goldGrassTip,
      );

      // Second blade
      canvas.drawLine(
        Offset(i.toDouble() + 5, groundY),
        Offset(i.toDouble() + 7, groundY - grassHeight * 0.9),
        grassPaint,
      );

      // Golden tip
      canvas.drawLine(
        Offset(i.toDouble() + 7, groundY - grassHeight * 0.9),
        Offset(i.toDouble() + 8, groundY - grassHeight * 0.9 - 4),
        goldGrassTip,
      );
    }

    // Add small golden flowers in grass
    if (growthLevel > 40) {
      for (int i = 0; i < 5; i++) {
        double flowerX = 50 + i * 60;
        double flowerY = groundY - 15;

        Paint flowerPaint = Paint()
          ..color = Color(0xFFFFD700)
          ..style = PaintingStyle.fill;

        // Simple flower petals
        for (int j = 0; j < 5; j++) {
          double angle = j * 2 * math.pi / 5;
          double petalX = flowerX + 5 * math.cos(angle);
          double petalY = flowerY + 5 * math.sin(angle);
          canvas.drawCircle(Offset(petalX, petalY), 3, flowerPaint);
        }

        // Flower center
        canvas.drawCircle(Offset(flowerX, flowerY), 2, Paint()..color = Color(0xFFB8860B));
      }
    }
  }

  void _drawGoldTree(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw trunk based on growth
    _drawGoldGrowingTrunk(canvas, size, centerX, groundY);

    // Draw branches based on growth level
    if (growthLevel > 0) {
      _drawGoldGrowingBranches(canvas, size, centerX, groundY);
    }
  }

  void _drawGoldGrowingTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint trunkPaint = Paint()
      ..color = Color(0xFFDAA520) // Golden rod
      ..style = PaintingStyle.fill;

    // Calculate trunk height based on growth - tallest
    double maxTrunkHeight = size.height * 0.55;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 5) / 20.0);

    double trunkBase = groundY;
    double trunkTop = groundY - currentTrunkHeight;

    // Create trunk shape that grows - widest
    final Path trunkPath = Path();

    double baseWidth = 35 * math.min(1.0, (growthLevel + 2) / 12.0);
    double topWidth = 28 * math.min(1.0, (growthLevel + 2) / 12.0);

    trunkPath.moveTo(centerX - baseWidth/2, trunkBase);
    trunkPath.lineTo(centerX - topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + baseWidth/2, trunkBase);
    trunkPath.close();

    canvas.drawPath(trunkPath, trunkPaint);

    // Add multiple golden highlights
    if (growthLevel > 2) {
      final Paint goldHighlight1 = Paint()
        ..color = Color(0xFFFFD700)
        ..style = PaintingStyle.fill;

      final Path highlight1Path = Path();
      highlight1Path.moveTo(centerX - baseWidth/2 + 4, trunkBase);
      highlight1Path.lineTo(centerX - topWidth/2 + 3, trunkTop);
      highlight1Path.lineTo(centerX - topWidth/2 + 10, trunkTop);
      highlight1Path.lineTo(centerX - baseWidth/2 + 11, trunkBase);
      highlight1Path.close();

      canvas.drawPath(highlight1Path, goldHighlight1);

      final Paint goldHighlight2 = Paint()
        ..color = Color(0xFFFFF8DC)
        ..style = PaintingStyle.fill;

      final Path highlight2Path = Path();
      highlight2Path.moveTo(centerX + baseWidth/2 - 4, trunkBase);
      highlight2Path.lineTo(centerX + topWidth/2 - 3, trunkTop);
      highlight2Path.lineTo(centerX + topWidth/2 - 10, trunkTop);
      highlight2Path.lineTo(centerX + baseWidth/2 - 11, trunkBase);
      highlight2Path.close();

      canvas.drawPath(highlight2Path, goldHighlight2);
    }

    // Add luxury gold bark texture
    if (growthLevel > 6) {
      _drawGoldBarkTexture(canvas, centerX, groundY, currentTrunkHeight, baseWidth, topWidth);
    }
  }

  void _drawGoldBarkTexture(Canvas canvas, double centerX, double groundY, double trunkHeight, double baseWidth, double topWidth) {
    final Paint darkBarkPaint = Paint()
      ..color = Color(0xFFB8860B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final Paint goldBarkPaint = Paint()
      ..color = Color(0xFFFFD700)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint luxuryBarkPaint = Paint()
      ..color = Color(0xFFFFF8DC)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Luxury bark lines
    int numLines = math.min(15, growthLevel ~/ 2);
    for (int i = 0; i < numLines; i++) {
      double x = centerX - baseWidth/2 + 3 + (i * (baseWidth - 6) / 15);
      double topY = groundY - trunkHeight + 25;
      double bottomY = groundY - 5;

      Path barkLine = Path();
      barkLine.moveTo(x, bottomY);

      int segments = 15;
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 2.5 * math.sin(j * 1.1 + i * 0.7) * (1 - j/segments);
        barkLine.lineTo(x + offset, segmentY);
      }

      canvas.drawPath(barkLine, darkBarkPaint);

      // Add gold highlight
      if (i % 2 == 0) {
        Path goldLine = Path();
        goldLine.moveTo(x + 2, bottomY);
        for (int j = 1; j <= segments; j++) {
          double segmentY = bottomY - (bottomY - topY) * (j / segments);
          double offset = 2 * math.sin(j * 0.9 + i * 0.5) * (1 - j/segments);
          goldLine.lineTo(x + 2 + offset, segmentY);
        }
        canvas.drawPath(goldLine, goldBarkPaint);
      }

      // Add luxury accent
      if (i % 3 == 0) {
        Path luxuryLine = Path();
        luxuryLine.moveTo(x + 1, bottomY);
        for (int j = 1; j <= segments; j++) {
          double segmentY = bottomY - (bottomY - topY) * (j / segments);
          double offset = 1.5 * math.sin(j * 0.7 + i * 0.3) * (1 - j/segments);
          luxuryLine.lineTo(x + 1 + offset, segmentY);
        }
        canvas.drawPath(luxuryLine, luxuryBarkPaint);
      }
    }
  }

  void _drawGoldGrowingBranches(Canvas canvas, Size size, double centerX, double groundY) {
    double maxTrunkHeight = size.height * 0.55;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 5) / 20.0);
    double trunkTop = groundY - currentTrunkHeight;

    final Paint branchPaint = Paint()
      ..color = Color(0xFFDAA520)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw branches progressively - most elaborate
    if (growthLevel >= 2) _drawGoldMainBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
    if (growthLevel >= 10) _drawGoldSecondaryBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
    if (growthLevel >= 20) _drawGoldDetailBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
    if (growthLevel >= 30) _drawGoldFineBranches(canvas, centerX, trunkTop, branchPaint, growthLevel);
  }

  void _drawGoldMainBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 12; // Thickest branches

    List<List<Offset>> mainBranches = [];

    // Very early main branches
    if (growth >= 2) {
      mainBranches.addAll([
        [Offset(centerX - 5, trunkTop + 25), Offset(centerX - 25, trunkTop + 10), Offset(centerX - 50, trunkTop - 15)],
        [Offset(centerX + 5, trunkTop + 25), Offset(centerX + 25, trunkTop + 10), Offset(centerX + 50, trunkTop - 15)],
      ]);
    }

    if (growth >= 4) {
      mainBranches.addAll([
        [Offset(centerX - 50, trunkTop - 15), Offset(centerX - 75, trunkTop - 30), Offset(centerX - 100, trunkTop - 40)],
        [Offset(centerX + 50, trunkTop - 15), Offset(centerX + 75, trunkTop - 30), Offset(centerX + 100, trunkTop - 40)],
      ]);
    }

    if (growth >= 6) {
      mainBranches.addAll([
        [Offset(centerX - 4, trunkTop + 10), Offset(centerX - 20, trunkTop - 25), Offset(centerX - 40, trunkTop - 55)],
        [Offset(centerX + 4, trunkTop + 10), Offset(centerX + 20, trunkTop - 25), Offset(centerX + 40, trunkTop - 55)],
        [Offset(centerX, trunkTop + 5), Offset(centerX - 8, trunkTop - 35), Offset(centerX - 15, trunkTop - 70)],
        [Offset(centerX, trunkTop + 5), Offset(centerX + 8, trunkTop - 35), Offset(centerX + 15, trunkTop - 70)],
      ]);
    }

    if (growth >= 8) {
      mainBranches.addAll([
        [Offset(centerX - 100, trunkTop - 40), Offset(centerX - 120, trunkTop - 45), Offset(centerX - 140, trunkTop - 50)],
        [Offset(centerX + 100, trunkTop - 40), Offset(centerX + 120, trunkTop - 45), Offset(centerX + 140, trunkTop - 50)],
      ]);
    }

    for (var branch in mainBranches) {
      _drawGoldBranchPath(canvas, paint, branch);
    }
  }

  void _drawGoldSecondaryBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 9;

    List<List<Offset>> secondaryBranches = [];

    if (growth >= 10) {
      secondaryBranches.addAll([
        [Offset(centerX - 75, trunkTop - 30), Offset(centerX - 95, trunkTop - 40), Offset(centerX - 115, trunkTop - 45)],
        [Offset(centerX + 75, trunkTop - 30), Offset(centerX + 95, trunkTop - 40), Offset(centerX + 115, trunkTop - 45)],
      ]);
    }

    if (growth >= 13) {
      secondaryBranches.addAll([
        [Offset(centerX - 100, trunkTop - 40), Offset(centerX - 120, trunkTop - 35), Offset(centerX - 140, trunkTop - 30)],
        [Offset(centerX + 100, trunkTop - 40), Offset(centerX + 120, trunkTop - 35), Offset(centerX + 140, trunkTop - 30)],
        [Offset(centerX - 40, trunkTop - 55), Offset(centerX - 60, trunkTop - 65), Offset(centerX - 75, trunkTop - 75)],
        [Offset(centerX + 40, trunkTop - 55), Offset(centerX + 60, trunkTop - 65), Offset(centerX + 75, trunkTop - 75)],
      ]);
    }

    if (growth >= 16) {
      secondaryBranches.addAll([
        [Offset(centerX - 15, trunkTop - 70), Offset(centerX - 30, trunkTop - 80), Offset(centerX - 40, trunkTop - 90)],
        [Offset(centerX + 15, trunkTop - 70), Offset(centerX + 30, trunkTop - 80), Offset(centerX + 40, trunkTop - 90)],
        [Offset(centerX - 140, trunkTop - 50), Offset(centerX - 155, trunkTop - 55), Offset(centerX - 170, trunkTop - 58)],
        [Offset(centerX + 140, trunkTop - 50), Offset(centerX + 155, trunkTop - 55), Offset(centerX + 170, trunkTop - 58)],
      ]);
    }

    if (growth >= 19) {
      secondaryBranches.addAll([
        [Offset(centerX - 115, trunkTop - 45), Offset(centerX - 130, trunkTop - 50), Offset(centerX - 145, trunkTop - 55)],
        [Offset(centerX + 115, trunkTop - 45), Offset(centerX + 130, trunkTop - 50), Offset(centerX + 145, trunkTop - 55)],
      ]);
    }

    for (var branch in secondaryBranches) {
      _drawGoldBranchPath(canvas, paint, branch);
    }
  }

  void _drawGoldDetailBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 6;

    List<List<Offset>> detailBranches = [];

    if (growth >= 20) {
      detailBranches.addAll([
        [Offset(centerX - 115, trunkTop - 45), Offset(centerX - 125, trunkTop - 50), Offset(centerX - 130, trunkTop - 55)],
        [Offset(centerX + 115, trunkTop - 45), Offset(centerX + 125, trunkTop - 50), Offset(centerX + 130, trunkTop - 55)],
      ]);
    }

    if (growth >= 24) {
      detailBranches.addAll([
        [Offset(centerX - 140, trunkTop - 30), Offset(centerX - 150, trunkTop - 25), Offset(centerX - 160, trunkTop - 22)],
        [Offset(centerX + 140, trunkTop - 30), Offset(centerX + 150, trunkTop - 25), Offset(centerX + 160, trunkTop - 22)],
        [Offset(centerX - 75, trunkTop - 75), Offset(centerX - 85, trunkTop - 80), Offset(centerX - 90, trunkTop - 85)],
        [Offset(centerX + 75, trunkTop - 75), Offset(centerX + 85, trunkTop - 80), Offset(centerX + 90, trunkTop - 85)],
      ]);
    }

    if (growth >= 28) {
      detailBranches.addAll([
        [Offset(centerX - 40, trunkTop - 90), Offset(centerX - 50, trunkTop - 95), Offset(centerX - 55, trunkTop - 100)],
        [Offset(centerX + 40, trunkTop - 90), Offset(centerX + 50, trunkTop - 95), Offset(centerX + 55, trunkTop - 100)],
        [Offset(centerX - 170, trunkTop - 58), Offset(centerX - 180, trunkTop - 60), Offset(centerX - 190, trunkTop - 62)],
        [Offset(centerX + 170, trunkTop - 58), Offset(centerX + 180, trunkTop - 60), Offset(centerX + 190, trunkTop - 62)],
      ]);
    }

    for (var branch in detailBranches) {
      _drawGoldBranchPath(canvas, paint, branch);
    }
  }

  void _drawGoldFineBranches(Canvas canvas, double centerX, double trunkTop, Paint paint, int growth) {
    paint.strokeWidth = 3;

    List<Offset> endpoints = [
      Offset(centerX - 130, trunkTop - 55),
      Offset(centerX - 160, trunkTop - 22),
      Offset(centerX - 90, trunkTop - 85),
      Offset(centerX - 55, trunkTop - 100),
      Offset(centerX - 190, trunkTop - 62),
      Offset(centerX + 130, trunkTop - 55),
      Offset(centerX + 160, trunkTop - 22),
      Offset(centerX + 90, trunkTop - 85),
      Offset(centerX + 55, trunkTop - 100),
      Offset(centerX + 190, trunkTop - 62),
    ];

    int numTwigs = math.min(endpoints.length, (growth - 29) * 2);

    for (int i = 0; i < numTwigs && i < endpoints.length; i++) {
      Offset endpoint = endpoints[i];

      // Draw most elaborate twigs
      for (int j = 0; j < 5; j++) {
        double angle = (j - 2) * 0.35;
        double length = 15 + j * 4;

        Offset twigEnd = Offset(
          endpoint.dx + length * math.cos(angle),
          endpoint.dy + length * math.sin(angle) - 10,
        );

        canvas.drawLine(endpoint, twigEnd, paint);

        // Add multiple sub-twigs
        if (j >= 1 && j <= 3) {
          for (int k = 0; k < 3; k++) {
            double subAngle = angle + (k - 1) * 0.25;
            double subLength = 8;
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

  void _drawGoldBranchPath(Canvas canvas, Paint paint, List<Offset> points) {
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

    // Add gold highlight
    Paint goldHighlight = Paint()
      ..color = Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = paint.strokeWidth * 0.4;

    Path highlightPath = Path();
    highlightPath.moveTo(points[0].dx - 2, points[0].dy - 2);

    for (int i = 1; i < points.length; i++) {
      if (i == points.length - 1) {
        highlightPath.lineTo(points[i].dx - 2, points[i].dy - 2);
      } else {
        Offset current = Offset(points[i].dx - 2, points[i].dy - 2);
        Offset next = Offset(points[i + 1].dx - 2, points[i + 1].dy - 2);
        Offset controlPoint = Offset(
          current.dx + (next.dx - current.dx) * 0.3,
          current.dy + (next.dy - current.dy) * 0.3,
        );
        highlightPath.quadraticBezierTo(controlPoint.dx, controlPoint.dy, current.dx, current.dy);
      }
    }

    canvas.drawPath(highlightPath, goldHighlight);

    // Add luxury highlight
    Paint luxuryHighlight = Paint()
      ..color = Color(0xFFFFF8DC)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = paint.strokeWidth * 0.2;

    Path luxuryPath = Path();
    luxuryPath.moveTo(points[0].dx - 1, points[0].dy - 1);

    for (int i = 1; i < points.length; i++) {
      if (i == points.length - 1) {
        luxuryPath.lineTo(points[i].dx - 1, points[i].dy - 1);
      } else {
        Offset current = Offset(points[i].dx - 1, points[i].dy - 1);
        Offset next = Offset(points[i + 1].dx - 1, points[i + 1].dy - 1);
        Offset controlPoint = Offset(
          current.dx + (next.dx - current.dx) * 0.3,
          current.dy + (next.dy - current.dy) * 0.3,
        );
        luxuryPath.quadraticBezierTo(controlPoint.dx, controlPoint.dy, current.dx, current.dy);
      }
    }

    canvas.drawPath(luxuryPath, luxuryHighlight);
  }

  List<BranchPoint> _getGoldBranchEndpoints(double centerX, double trunkTop) {
    List<BranchPoint> endpoints = [];

    // Ultimate luxury leaf positions
    List<Offset> leafPositions = [
      // Very early leaves (growth 1-8)
      Offset(centerX - 50, trunkTop - 15),
      Offset(centerX + 50, trunkTop - 15),
      Offset(centerX - 75, trunkTop - 30),
      Offset(centerX + 75, trunkTop - 30),
      Offset(centerX - 40, trunkTop - 55),
      Offset(centerX + 40, trunkTop - 55),
      Offset(centerX - 15, trunkTop - 70),
      Offset(centerX + 15, trunkTop - 70),

      // Early-mid leaves (growth 9-20)
      Offset(centerX - 100, trunkTop - 40),
      Offset(centerX + 100, trunkTop - 40),
      Offset(centerX - 115, trunkTop - 45),
      Offset(centerX + 115, trunkTop - 45),
      Offset(centerX - 140, trunkTop - 50),
      Offset(centerX + 140, trunkTop - 50),
      Offset(centerX - 60, trunkTop - 65),
      Offset(centerX + 60, trunkTop - 65),
      Offset(centerX - 75, trunkTop - 75),
      Offset(centerX + 75, trunkTop - 75),
      Offset(centerX - 30, trunkTop - 80),
      Offset(centerX + 30, trunkTop - 80),

      // Mid-late leaves (growth 21-35)
      Offset(centerX - 120, trunkTop - 35),
      Offset(centerX + 120, trunkTop - 35),
      Offset(centerX - 140, trunkTop - 30),
      Offset(centerX + 140, trunkTop - 30),
      Offset(centerX - 160, trunkTop - 22),
      Offset(centerX + 160, trunkTop - 22),
      Offset(centerX - 40, trunkTop - 90),
      Offset(centerX + 40, trunkTop - 90),
      Offset(centerX - 90, trunkTop - 85),
      Offset(centerX + 90, trunkTop - 85),
      Offset(centerX - 170, trunkTop - 58),
      Offset(centerX + 170, trunkTop - 58),
      Offset(centerX - 125, trunkTop - 50),
      Offset(centerX + 125, trunkTop - 50),

      // Late leaves (growth 36-49)
      Offset(centerX - 130, trunkTop - 55),
      Offset(centerX + 130, trunkTop - 55),
      Offset(centerX - 145, trunkTop - 55),
      Offset(centerX + 145, trunkTop - 55),
      Offset(centerX - 55, trunkTop - 100),
      Offset(centerX + 55, trunkTop - 100),
      Offset(centerX - 190, trunkTop - 62),
      Offset(centerX + 190, trunkTop - 62),
      Offset(centerX - 150, trunkTop - 25),
      Offset(centerX + 150, trunkTop - 25),
      Offset(centerX - 85, trunkTop - 80),
      Offset(centerX + 85, trunkTop - 80),
      Offset(centerX - 180, trunkTop - 60),
      Offset(centerX + 180, trunkTop - 60),
      Offset(centerX, trunkTop - 110),
    ];

    int numEndpoints = math.min(growthLevel, leafPositions.length);

    for (int i = 0; i < numEndpoints; i++) {
      Offset point = leafPositions[i];
      double angle = math.atan2(point.dy - trunkTop, point.dx - centerX);
      endpoints.add(BranchPoint(point.dx, point.dy, angle));
    }

    return endpoints;
  }

  void _drawGoldLeavesOnBranches(Canvas canvas, Size size, double centerX, double groundY) {
    if (growthLevel == 0) return;

    double maxTrunkHeight = size.height * 0.55;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 5) / 20.0);
    double trunkTop = groundY - currentTrunkHeight;

    List<BranchPoint> branchEndpoints = _getGoldBranchEndpoints(centerX, trunkTop);

    for (int i = 0; i < branchEndpoints.length; i++) {
      BranchPoint point = branchEndpoints[i];
      _drawGoldLeafAtPoint(canvas, point, i);
    }
  }

  void _drawGoldLeafAtPoint(Canvas canvas, BranchPoint point, int index) {
    canvas.save();
    canvas.translate(point.x, point.y);

    // Animate newest leaf
    double scale = leafScale;
    if (index == growthLevel - 1) {
      scale = leafScale * 0.8 + 0.2;
    }
    canvas.scale(scale);

    // Luxury gold-themed leaf colors
    Color leafColor = index % 8 == 0 ? Color(0xFFFFD700) :
    index % 8 == 1 ? Color(0xFFFFF8DC) :
    index % 8 == 2 ? Color(0xFFDAA520) :
    index % 8 == 3 ? Color(0xFF32CD32) :
    index % 8 == 4 ? Color(0xFF9ACD32) :
    index % 8 == 5 ? Color(0xFF98FB98) :
    index % 8 == 6 ? Color(0xFF90EE90) :
    Color(0xFFB8860B);

    Paint leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    double leafSize = 16 + (index % 5) * 2; // Largest leaves

    // Draw ultimate luxury leaf shape
    Path leafPath = Path();
    leafPath.moveTo(0, -leafSize);
    leafPath.quadraticBezierTo(leafSize * 1.1, -leafSize * 0.8, leafSize * 0.7, 0);
    leafPath.quadraticBezierTo(leafSize * 0.9, leafSize * 0.6, 0, leafSize * 0.7);
    leafPath.quadraticBezierTo(-leafSize * 0.9, leafSize * 0.6, -leafSize * 0.7, 0);
    leafPath.quadraticBezierTo(-leafSize * 1.1, -leafSize * 0.8, 0, -leafSize);

    canvas.drawPath(leafPath, leafPaint);

    // Add gold shimmer
    Paint goldShimmer = Paint()
      ..color = Color(0xFFFFD700).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    Path shimmerPath = Path();
    shimmerPath.moveTo(0, -leafSize * 0.9);
    shimmerPath.quadraticBezierTo(leafSize * 0.4, -leafSize * 0.5, leafSize * 0.3, -leafSize * 0.1);
    shimmerPath.quadraticBezierTo(leafSize * 0.2, leafSize * 0.2, 0, leafSize * 0.3);
    shimmerPath.quadraticBezierTo(-leafSize * 0.2, leafSize * 0.2, -leafSize * 0.3, -leafSize * 0.1);
    shimmerPath.quadraticBezierTo(-leafSize * 0.4, -leafSize * 0.5, 0, -leafSize * 0.9);

    canvas.drawPath(shimmerPath, goldShimmer);

    // Add luxury sparkle
    Paint luxurySparkle = Paint()
      ..color = Color(0xFFFFF8DC).withOpacity(0.4)
      ..style = PaintingStyle.fill;

    Path sparklePath = Path();
    sparklePath.moveTo(0, -leafSize * 0.7);
    sparklePath.quadraticBezierTo(leafSize * 0.2, -leafSize * 0.3, leafSize * 0.15, 0);
    sparklePath.quadraticBezierTo(leafSize * 0.1, leafSize * 0.1, 0, leafSize * 0.15);
    sparklePath.quadraticBezierTo(-leafSize * 0.1, leafSize * 0.1, -leafSize * 0.15, 0);
    sparklePath.quadraticBezierTo(-leafSize * 0.2, -leafSize * 0.3, 0, -leafSize * 0.7);

    canvas.drawPath(sparklePath, luxurySparkle);

    // Ultimate luxury veins
    Paint veinPaint = Paint()
      ..color = Color(0xFFB8860B)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(0, -leafSize * 1.05),
      Offset(0, leafSize * 0.6),
      veinPaint,
    );

    // Enhanced side veins
    for (int i = 0; i < 5; i++) {
      double veinY = -leafSize * 0.85 + (i * leafSize * 0.3);
      double veinLength = leafSize * 0.55 * (1 - i * 0.12);

      canvas.drawLine(
        Offset(0, veinY),
        Offset(-veinLength, veinY + veinLength * 0.5),
        veinPaint,
      );
      canvas.drawLine(
        Offset(0, veinY),
        Offset(veinLength, veinY + veinLength * 0.5),
        veinPaint,
      );
    }

    // Add golden vein highlights
    Paint goldVein = Paint()
      ..color = Color(0xFFFFD700)
      ..strokeWidth = 0.8;

    canvas.drawLine(
      Offset(1.5, -leafSize * 0.95),
      Offset(1.5, leafSize * 0.5),
      goldVein,
    );

    canvas.restore();
  }

  void _drawMultipleGoldFlowers(Canvas canvas, Size size, double centerX, double groundY) {
    double maxTrunkHeight = size.height * 0.55;
    double currentTrunkHeight = maxTrunkHeight * math.min(1.0, (growthLevel + 5) / 20.0);
    double trunkTop = groundY - currentTrunkHeight;

    // Get branch endpoints for flower positions
    List<BranchPoint> branchEndpoints = _getGoldBranchEndpoints(centerX, trunkTop);

    // Select 7 branch endpoints for flowers (increased from 5)
    List<int> flowerIndices = [
      branchEndpoints.length - 1,   // Top branch
      branchEndpoints.length - 3,   // Upper left
      branchEndpoints.length - 5,   // Upper right
      branchEndpoints.length - 7,   // Mid left
      branchEndpoints.length - 9,   // Mid right
      branchEndpoints.length - 11,  // Lower left
      branchEndpoints.length - 13,  // Lower right
    ];

    // Draw each flower at branch endpoints
    for (int i = 0; i < flowerIndices.length; i++) {
      if (flowerIndices[i] >= 0 && flowerIndices[i] < branchEndpoints.length) {
        BranchPoint branch = branchEndpoints[flowerIndices[i]];
        double individualRotation = flowerRotation + (i * 0.7);
        _drawGoldFlowerAtPosition(canvas, Offset(branch.x, branch.y), individualRotation, i);
      }
    }
  }

  void _drawGoldFlowerAtPosition(Canvas canvas, Offset position, double rotation, int flowerIndex) {
    double flowerCenterX = position.dx;
    double flowerCenterY = position.dy;

    // Luxury gold flower petals
    final Paint petalPaint = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk
      ..style = PaintingStyle.fill;

    final Paint petalOutlinePaint = Paint()
      ..color = Color(0xFFFFD700) // Gold outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Draw 12 luxury petals
    for (int i = 0; i < 12; i++) {
      double angle = (i * 2 * math.pi / 12) + rotation * 0.15;
      double petalLength = 24 * flowerBloom;
      double petalWidth = 16 * flowerBloom;

      canvas.save();
      canvas.translate(flowerCenterX, flowerCenterY);
      canvas.rotate(angle);

      final Path petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(petalWidth/2, -petalLength/3, petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(0, -petalLength * 0.9, -petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(-petalWidth/2, -petalLength/3, 0, 0);

      canvas.drawPath(petalPath, petalPaint);
      canvas.drawPath(petalPath, petalOutlinePaint);

      // Add gold highlight
      final Paint petalHighlight = Paint()
        ..color = Color(0xFFFFD700).withOpacity(0.6)
        ..style = PaintingStyle.fill;

      final Path highlightPath = Path();
      highlightPath.moveTo(0, 0);
      highlightPath.quadraticBezierTo(petalWidth/3, -petalLength/4, petalWidth/5, -petalLength/1.5);
      highlightPath.quadraticBezierTo(0, -petalLength * 0.7, -petalWidth/5, -petalLength/1.5);
      highlightPath.quadraticBezierTo(-petalWidth/3, -petalLength/4, 0, 0);

      canvas.drawPath(highlightPath, petalHighlight);

      // Add sparkles
      final Paint sparkleHighlight = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      final Path sparklePath = Path();
      sparklePath.moveTo(0, 0);
      sparklePath.quadraticBezierTo(petalWidth/6, -petalLength/6, petalWidth/8, -petalLength/3);
      sparklePath.quadraticBezierTo(0, -petalLength * 0.4, -petalWidth/8, -petalLength/3);
      sparklePath.quadraticBezierTo(-petalWidth/6, -petalLength/6, 0, 0);

      canvas.drawPath(sparklePath, sparkleHighlight);
      canvas.restore();
    }

    // Luxury gold flower center
    final Paint centerPaint = Paint()
      ..color = Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(flowerCenterX, flowerCenterY), 12 * flowerBloom, centerPaint);

    // Inner center
    canvas.drawCircle(
        Offset(flowerCenterX, flowerCenterY),
        9 * flowerBloom,
        Paint()
          ..color = Color(0xFFB8860B)
          ..style = PaintingStyle.fill
    );

    // Luxury center dots
    final Paint dotPaint = Paint()
      ..color = Color(0xFFFFF8DC)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      double dotAngle = i * 2 * math.pi / 8;
      double dotDistance = 5 * flowerBloom;
      canvas.drawCircle(
        Offset(
            flowerCenterX + dotDistance * math.cos(dotAngle),
            flowerCenterY + dotDistance * math.sin(dotAngle)
        ),
        2 * flowerBloom,
        dotPaint,
      );
    }

    // Add ultimate luxury sparkle effect
    if (flowerBloom > 0.8) {
      _drawGoldSparkles(canvas, flowerCenterX, flowerCenterY, rotation);
    }
  }

  void _drawGoldSparkles(Canvas canvas, double centerX, double centerY, double rotation) {
    final Paint sparklePaint = Paint()
      ..color = Color(0xFFFFD700)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final Paint luxurySparklePaint = Paint()
      ..color = Color(0xFFFFF8DC)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final Paint diamondSparklePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      double angle = i * math.pi / 6 + rotation;
      double distance = 45 + 8 * math.sin(rotation * 3);
      double x = centerX + distance * math.cos(angle);
      double y = centerY + distance * math.sin(angle);

      Paint currentPaint = i % 3 == 0 ? sparklePaint :
      i % 3 == 1 ? luxurySparklePaint :
      diamondSparklePaint;

      // Draw luxury sparkle stars
      canvas.drawLine(Offset(x - 7, y), Offset(x + 7, y), currentPaint);
      canvas.drawLine(Offset(x, y - 7), Offset(x, y + 7), currentPaint);
      canvas.drawLine(Offset(x - 5, y - 5), Offset(x + 5, y + 5), currentPaint);
      canvas.drawLine(Offset(x - 5, y + 5), Offset(x + 5, y - 5), currentPaint);

      // Add luxury cross sparkles
      if (i % 2 == 0) {
        canvas.drawLine(Offset(x - 3, y - 6), Offset(x + 3, y + 6), currentPaint);
        canvas.drawLine(Offset(x + 3, y - 6), Offset(x - 3, y + 6), currentPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is GoldTreePainter &&
        (oldDelegate.growthLevel != growthLevel ||
            oldDelegate.totalGrowth != totalGrowth ||
            oldDelegate.flowerBloom != flowerBloom ||
            oldDelegate.flowerRotation != flowerRotation ||
            oldDelegate.leafScale != leafScale ||
            oldDelegate.waterDropAnimation != waterDropAnimation);
  }
}