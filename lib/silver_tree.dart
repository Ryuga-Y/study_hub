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

  SilverTreePainter({
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

    // Draw enhanced soil and ground
    _drawSilverSoilAndGround(canvas, size, centerX, groundY);

    // Draw enhanced tree roots
    _drawSilverTreeRoots(canvas, size, centerX, groundY);

    // Draw the premium silver tree
    _drawSilverTree(canvas, size, centerX, groundY);

    // Draw silver leaves on branch endpoints
    _drawSilverLeavesOnBranches(canvas, size, centerX, groundY);

    // Draw silver flower if 100% complete
    if (totalGrowth >= 1.0) {
      _drawSilverFlower(canvas, size, centerX, groundY);
    }
  }

  void _drawSilverSoilAndGround(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw premium soil mound with silver tint
    final Paint soilPaint = Paint()
      ..color = Color(0xFF696969) // Dim gray with silver hint
      ..style = PaintingStyle.fill;

    final Path soilPath = Path();
    double soilWidth = 160; // Even bigger soil base
    double soilHeight = 35;

    // Create enhanced soil mound
    soilPath.moveTo(centerX - soilWidth/2, groundY);
    soilPath.quadraticBezierTo(
        centerX - soilWidth/3, groundY - soilHeight,
        centerX, groundY - soilHeight/2
    );
    soilPath.quadraticBezierTo(
        centerX + soilWidth/3, groundY - soilHeight,
        centerX + soilWidth/2, groundY
    );
    soilPath.lineTo(centerX + soilWidth/2, groundY + 18);
    soilPath.lineTo(centerX - soilWidth/2, groundY + 18);
    soilPath.close();

    canvas.drawPath(soilPath, soilPaint);

    // Add silver-tinted soil texture with sparkles
    final Paint soilTexturePaint = Paint()
      ..color = Color(0xFF2F4F4F) // Dark slate gray
      ..style = PaintingStyle.fill;

    final Paint silverSparkle = Paint()
      ..color = Color(0xFFC0C0C0) // Silver
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 15; i++) {
      double x = centerX - soilWidth/3 + (i * 12);
      double y = groundY - 10 + (i % 5) * 4;
      canvas.drawCircle(Offset(x, y), 3, soilTexturePaint);

      // Add silver sparkles in soil
      if (i % 3 == 0) {
        canvas.drawCircle(Offset(x + 2, y - 1), 1.5, silverSparkle);
      }
    }

    // Draw premium ground line with silver accent
    final Paint groundPaint = Paint()
      ..color = Color(0xFF708090) // Slate gray
      ..strokeWidth = 5;
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      groundPaint,
    );

    // Add silver ground accent line
    final Paint silverAccent = Paint()
      ..color = Color(0xFFC0C0C0) // Silver
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, groundY - 2),
      Offset(size.width, groundY - 2),
      silverAccent,
    );
  }

  void _drawSilverTreeRoots(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint rootPaint = Paint()
      ..color = Color(0xFF2F4F4F) // Dark slate gray
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10; // Even thicker roots

    // Enhanced main roots
    List<Offset> rootDirections = [
      Offset(-1.4, 0.5),  // Left root
      Offset(1.4, 0.5),   // Right root
      Offset(-1.0, 0.7),  // Left-center root
      Offset(1.0, 0.7),   // Right-center root
      Offset(-0.6, 0.9),  // Additional roots
      Offset(0.6, 0.9),
    ];

    for (int i = 0; i < rootDirections.length; i++) {
      Offset direction = rootDirections[i];
      _drawSilverSingleRoot(canvas, centerX, groundY, direction, rootPaint);
    }

    // Enhanced secondary roots
    rootPaint.strokeWidth = 5;
    List<Offset> smallRootDirections = [
      Offset(-1.8, 0.4),
      Offset(1.8, 0.4),
      Offset(-0.5, 1.0),
      Offset(0.5, 1.0),
      Offset(-1.2, 0.8),
      Offset(1.2, 0.8),
    ];

    for (int i = 0; i < smallRootDirections.length; i++) {
      Offset direction = smallRootDirections[i];
      _drawSilverSingleRoot(canvas, centerX, groundY, direction, rootPaint, isSmall: true);
    }
  }

  void _drawSilverSingleRoot(Canvas canvas, double startX, double startY, Offset direction, Paint paint, {bool isSmall = false}) {
    double length = isSmall ? 50 : 80; // Even longer roots

    Path rootPath = Path();
    rootPath.moveTo(startX, startY);

    // Create curved root
    double midX = startX + direction.dx * length * 0.5;
    double midY = startY + direction.dy * length * 0.5;
    double endX = startX + direction.dx * length;
    double endY = startY + direction.dy * length;

    rootPath.quadraticBezierTo(midX, midY, endX, endY);
    canvas.drawPath(rootPath, paint);

    // Add silver root accents
    Paint silverAccent = Paint()
      ..color = Color(0xFF778899) // Light slate gray
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = isSmall ? 2 : 3;

    Path accentPath = Path();
    accentPath.moveTo(startX, startY);
    accentPath.quadraticBezierTo(midX - 1, midY - 1, endX - 2, endY - 2);
    canvas.drawPath(accentPath, silverAccent);

    // Add enhanced root branches
    if (!isSmall) {
      Paint branchPaint = Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4;

      // Enhanced root branches
      for (int i = 0; i < 4; i++) {
        double branchAngle = (i - 1.5) * 0.4;
        double branchLength = 25;
        double branchStartX = endX - direction.dx * 20;
        double branchStartY = endY - direction.dy * 20;

        canvas.drawLine(
          Offset(branchStartX, branchStartY),
          Offset(
              branchStartX + branchLength * math.cos(branchAngle),
              branchStartY + branchLength * math.sin(branchAngle) + 10
          ),
          branchPaint,
        );
      }
    }
  }

  void _drawSilverTree(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw premium silver trunk
    _drawSilverTrunk(canvas, size, centerX, groundY);

    // Draw premium silver branches
    _drawSilverBranches(canvas, size, centerX, groundY);
  }

  void _drawSilverTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint trunkPaint = Paint()
      ..color = Color(0xFF708090) // Slate gray (silver tone)
      ..style = PaintingStyle.fill;

    double trunkHeight = size.height * 0.52; // Even taller trunk
    double trunkBase = groundY;
    double trunkTop = groundY - trunkHeight;

    // Create premium silver trunk
    final Path trunkPath = Path();

    double baseWidth = 35; // Even wider trunk
    double topWidth = 28;

    // Create trunk with silver characteristics
    trunkPath.moveTo(centerX - baseWidth/2, trunkBase);
    trunkPath.lineTo(centerX - topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + baseWidth/2, trunkBase);
    trunkPath.close();

    canvas.drawPath(trunkPath, trunkPaint);

    // Add silver highlights
    final Paint silverHighlight = Paint()
      ..color = Color(0xFFC0C0C0) // Silver
      ..style = PaintingStyle.fill;

    final Path highlightPath = Path();
    highlightPath.moveTo(centerX - baseWidth/2 + 3, trunkBase);
    highlightPath.lineTo(centerX - topWidth/2 + 2, trunkTop);
    highlightPath.lineTo(centerX - topWidth/2 + 8, trunkTop);
    highlightPath.lineTo(centerX - baseWidth/2 + 9, trunkBase);
    highlightPath.close();

    canvas.drawPath(highlightPath, silverHighlight);

    // Add premium silver bark texture
    _drawSilverBarkTexture(canvas, centerX, groundY, trunkHeight, baseWidth, topWidth);
  }

  void _drawSilverBarkTexture(Canvas canvas, double centerX, double groundY, double trunkHeight, double baseWidth, double topWidth) {
    // Premium silver bark lines
    final Paint darkBarkPaint = Paint()
      ..color = Color(0xFF2F4F4F) // Dark slate gray
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final Paint lightBarkPaint = Paint()
      ..color = Color(0xFFC0C0C0) // Silver
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Enhanced vertical bark ridges
    for (int i = 0; i < 12; i++) {
      double x = centerX - 18 + (i * 3.5);
      double topY = groundY - trunkHeight + 25;
      double bottomY = groundY - 10;

      // Create premium bark lines
      Path barkLine = Path();
      barkLine.moveTo(x, bottomY);

      int segments = 18;
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 3 * math.sin(j * 1.0 + i * 0.7) * (1 - j/segments);
        barkLine.lineTo(x + offset, segmentY);
      }

      canvas.drawPath(barkLine, darkBarkPaint);

      // Add silver highlights
      Path lightLine = Path();
      lightLine.moveTo(x + 2.5, bottomY);
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 2.5 * math.sin(j * 0.8 + i * 0.5) * (1 - j/segments);
        lightLine.lineTo(x + 2.5 + offset, segmentY);
      }
      canvas.drawPath(lightLine, lightBarkPaint);
    }

    // Premium silver bark rings
    final Paint ringPaint = Paint()
      ..color = Color(0xFF696969) // Dim gray
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final Paint silverRingPaint = Paint()
      ..color = Color(0xFFB0C4DE) // Light steel blue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 15; i++) {
      double y = groundY - (trunkHeight * 0.07 * i) - 25;
      double width = baseWidth - (baseWidth - topWidth) * (i / 15.0);

      // Create silver bark rings
      Path ringPath = Path();
      ringPath.moveTo(centerX - width/2 + 4, y);

      int ringSegments = 24;
      for (int j = 1; j <= ringSegments; j++) {
        double angle = (j / ringSegments) * math.pi;
        double radius = width/2 - 4;
        double x = centerX + radius * math.cos(angle - math.pi/2);
        double ringY = y + 4 * math.sin(j * 0.6);
        ringPath.lineTo(x, ringY);
      }

      canvas.drawPath(ringPath, ringPaint);

      // Add silver accent rings
      if (i % 2 == 0) {
        Path silverRing = Path();
        silverRing.moveTo(centerX - width/2 + 6, y + 1);
        for (int j = 1; j <= ringSegments; j++) {
          double angle = (j / ringSegments) * math.pi;
          double radius = width/2 - 6;
          double x = centerX + radius * math.cos(angle - math.pi/2);
          double ringY = y + 1 + 2 * math.sin(j * 0.4);
          silverRing.lineTo(x, ringY);
        }
        canvas.drawPath(silverRing, silverRingPaint);
      }
    }
  }

  void _drawSilverBranches(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.52;
    double trunkTop = groundY - trunkHeight;

    final Paint mainBranchPaint = Paint()
      ..color = Color(0xFF708090) // Slate gray
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw premium silver branches based on growth level
    if (growthLevel >= 5) _drawSilverMainBranches(canvas, centerX, trunkTop, mainBranchPaint);
    if (growthLevel >= 15) _drawSilverSecondaryBranches(canvas, centerX, trunkTop, mainBranchPaint);
    if (growthLevel >= 25) _drawSilverDetailBranches(canvas, centerX, trunkTop, mainBranchPaint);
    if (growthLevel >= 35) _drawSilverFineBranches(canvas, centerX, trunkTop, mainBranchPaint);
  }

  void _drawSilverMainBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 14; // Even thicker main branches

    // Premium main silver branches
    _drawSilverBranchPath(canvas, paint, [
      Offset(centerX - 5, trunkTop + 35),
      Offset(centerX - 30, trunkTop + 10),
      Offset(centerX - 65, trunkTop - 20),
      Offset(centerX - 100, trunkTop - 45),
      Offset(centerX - 130, trunkTop - 55),
    ]);

    _drawSilverBranchPath(canvas, paint, [
      Offset(centerX + 5, trunkTop + 30),
      Offset(centerX + 35, trunkTop + 5),
      Offset(centerX + 70, trunkTop - 28),
      Offset(centerX + 105, trunkTop - 45),
      Offset(centerX + 140, trunkTop - 55),
    ]);

    // Enhanced upper main branches
    _drawSilverBranchPath(canvas, paint, [
      Offset(centerX - 4, trunkTop + 18),
      Offset(centerX - 25, trunkTop - 20),
      Offset(centerX - 55, trunkTop - 50),
      Offset(centerX - 80, trunkTop - 85),
    ]);

    _drawSilverBranchPath(canvas, paint, [
      Offset(centerX + 4, trunkTop + 10),
      Offset(centerX + 28, trunkTop - 15),
      Offset(centerX + 60, trunkTop - 45),
      Offset(centerX + 85, trunkTop - 80),
    ]);

    // Premium central branches
    _drawSilverBranchPath(canvas, paint, [
      Offset(centerX - 3, trunkTop + 5),
      Offset(centerX - 15, trunkTop - 35),
      Offset(centerX - 25, trunkTop - 70),
      Offset(centerX - 30, trunkTop - 100),
    ]);

    _drawSilverBranchPath(canvas, paint, [
      Offset(centerX + 3, trunkTop - 5),
      Offset(centerX + 18, trunkTop - 40),
      Offset(centerX + 28, trunkTop - 75),
      Offset(centerX + 35, trunkTop - 105),
    ]);
  }

  void _drawSilverSecondaryBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 10; // Enhanced secondary branches

    // Premium secondary branches with more detail
    List<List<Offset>> secondaryBranches = [
      // Left side enhanced
      [Offset(centerX - 65, trunkTop - 20), Offset(centerX - 85, trunkTop - 32), Offset(centerX - 105, trunkTop - 25)],
      [Offset(centerX - 100, trunkTop - 45), Offset(centerX - 125, trunkTop - 32), Offset(centerX - 150, trunkTop - 40)],
      [Offset(centerX - 130, trunkTop - 55), Offset(centerX - 150, trunkTop - 45), Offset(centerX - 175, trunkTop - 50)],

      // Right side enhanced
      [Offset(centerX + 70, trunkTop - 28), Offset(centerX + 90, trunkTop - 40), Offset(centerX + 115, trunkTop - 32)],
      [Offset(centerX + 105, trunkTop - 45), Offset(centerX + 130, trunkTop - 32), Offset(centerX + 155, trunkTop - 40)],
      [Offset(centerX + 140, trunkTop - 55), Offset(centerX + 165, trunkTop - 45), Offset(centerX + 185, trunkTop - 50)],

      // Premium upper branches
      [Offset(centerX - 55, trunkTop - 50), Offset(centerX - 70, trunkTop - 68), Offset(centerX - 60, trunkTop - 90)],
      [Offset(centerX - 80, trunkTop - 85), Offset(centerX - 100, trunkTop - 98), Offset(centerX - 105, trunkTop - 120)],
      [Offset(centerX + 60, trunkTop - 45), Offset(centerX + 75, trunkTop - 63), Offset(centerX + 65, trunkTop - 85)],
      [Offset(centerX + 85, trunkTop - 80), Offset(centerX + 105, trunkTop - 93), Offset(centerX + 110, trunkTop - 115)],
    ];

    for (var branch in secondaryBranches) {
      _drawSilverBranchPath(canvas, paint, branch);
    }
  }

  void _drawSilverDetailBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 6; // Premium detail branches

    // Enhanced detail branches for luxury appearance
    List<List<Offset>> detailBranches = [
      // Left side premium details
      [Offset(centerX - 85, trunkTop - 32), Offset(centerX - 95, trunkTop - 22), Offset(centerX - 110, trunkTop - 15)],
      [Offset(centerX - 105, trunkTop - 25), Offset(centerX - 120, trunkTop - 18), Offset(centerX - 135, trunkTop - 10)],
      [Offset(centerX - 125, trunkTop - 32), Offset(centerX - 140, trunkTop - 42), Offset(centerX - 150, trunkTop - 55)],
      [Offset(centerX - 150, trunkTop - 40), Offset(centerX - 165, trunkTop - 30), Offset(centerX - 180, trunkTop - 35)],

      // Right side premium details
      [Offset(centerX + 90, trunkTop - 40), Offset(centerX + 105, trunkTop - 30), Offset(centerX + 120, trunkTop - 22)],
      [Offset(centerX + 115, trunkTop - 32), Offset(centerX + 130, trunkTop - 22), Offset(centerX + 145, trunkTop - 15)],
      [Offset(centerX + 130, trunkTop - 32), Offset(centerX + 145, trunkTop - 42), Offset(centerX + 160, trunkTop - 55)],
      [Offset(centerX + 155, trunkTop - 40), Offset(centerX + 170, trunkTop - 30), Offset(centerX + 185, trunkTop - 35)],

      // Premium upper details
      [Offset(centerX - 70, trunkTop - 68), Offset(centerX - 55, trunkTop - 80), Offset(centerX - 45, trunkTop - 95)],
      [Offset(centerX - 60, trunkTop - 90), Offset(centerX - 75, trunkTop - 105), Offset(centerX - 80, trunkTop - 125)],
      [Offset(centerX - 30, trunkTop - 100), Offset(centerX - 45, trunkTop - 115), Offset(centerX - 50, trunkTop - 135)],
      [Offset(centerX + 75, trunkTop - 63), Offset(centerX + 60, trunkTop - 75), Offset(centerX + 50, trunkTop - 90)],
      [Offset(centerX + 65, trunkTop - 85), Offset(centerX + 80, trunkTop - 100), Offset(centerX + 85, trunkTop - 120)],
      [Offset(centerX + 35, trunkTop - 105), Offset(centerX + 50, trunkTop - 120), Offset(centerX + 55, trunkTop - 140)],
    ];

    for (var branch in detailBranches) {
      _drawSilverBranchPath(canvas, paint, branch);
    }
  }

  void _drawSilverFineBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 4; // Premium fine branches

    // Generate premium fine branches based on growth level
    List<Offset> endpoints = [
      // Left side premium endpoints
      Offset(centerX - 110, trunkTop - 15), Offset(centerX - 135, trunkTop - 10), Offset(centerX - 150, trunkTop - 55),
      Offset(centerX - 180, trunkTop - 35), Offset(centerX - 165, trunkTop - 30), Offset(centerX - 45, trunkTop - 95),
      Offset(centerX - 80, trunkTop - 125), Offset(centerX - 50, trunkTop - 135), Offset(centerX - 105, trunkTop - 120),

      // Right side premium endpoints
      Offset(centerX + 120, trunkTop - 22), Offset(centerX + 145, trunkTop - 15), Offset(centerX + 160, trunkTop - 55),
      Offset(centerX + 185, trunkTop - 35), Offset(centerX + 170, trunkTop - 30), Offset(centerX + 50, trunkTop - 90),
      Offset(centerX + 85, trunkTop - 120), Offset(centerX + 55, trunkTop - 140), Offset(centerX + 110, trunkTop - 115),

      // Additional premium endpoints for fuller coverage
      Offset(centerX - 140, trunkTop - 42), Offset(centerX - 120, trunkTop - 18), Offset(centerX + 145, trunkTop - 42),
      Offset(centerX + 125, trunkTop - 22), Offset(centerX - 45, trunkTop - 115), Offset(centerX + 50, trunkTop - 120),
    ];

    for (int i = 0; i < endpoints.length && i < (growthLevel - 30); i++) {
      if (i >= 0) {
        Offset endpoint = endpoints[i];

        // Draw 4-5 premium twigs from each endpoint
        for (int j = 0; j < 5; j++) {
          double angle = (j - 2) * 0.4 + (i * 0.15);
          double length = 18 + j * 5;

          Offset twigEnd = Offset(
            endpoint.dx + length * math.cos(angle),
            endpoint.dy + length * math.sin(angle) - 12,
          );

          canvas.drawLine(endpoint, twigEnd, paint);

          // Add premium sub-twigs with silver accents
          if (j == 1 || j == 2 || j == 3) {
            for (int k = 0; k < 3; k++) {
              double subAngle = angle + (k - 1) * 0.3;
              double subLength = 10;
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
      ..color = Color(0xFFB0C4DE) // Light steel blue
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

    List<Offset> allEndpoints = [
      // Premium left side branch endpoints
      Offset(centerX - 110, trunkTop - 15), Offset(centerX - 135, trunkTop - 10), Offset(centerX - 150, trunkTop - 55),
      Offset(centerX - 180, trunkTop - 35), Offset(centerX - 165, trunkTop - 30), Offset(centerX - 45, trunkTop - 95),
      Offset(centerX - 80, trunkTop - 125), Offset(centerX - 50, trunkTop - 135), Offset(centerX - 105, trunkTop - 120),
      Offset(centerX - 140, trunkTop - 42), Offset(centerX - 120, trunkTop - 18), Offset(centerX - 45, trunkTop - 115),

      // Premium right side branch endpoints
      Offset(centerX + 120, trunkTop - 22), Offset(centerX + 145, trunkTop - 15), Offset(centerX + 160, trunkTop - 55),
      Offset(centerX + 185, trunkTop - 35), Offset(centerX + 170, trunkTop - 30), Offset(centerX + 50, trunkTop - 90),
      Offset(centerX + 85, trunkTop - 120), Offset(centerX + 55, trunkTop - 140), Offset(centerX + 110, trunkTop - 115),
      Offset(centerX + 145, trunkTop - 42), Offset(centerX + 125, trunkTop - 22), Offset(centerX + 50, trunkTop - 120),

      // Additional premium endpoints
      Offset(centerX - 105, trunkTop - 25), Offset(centerX + 115, trunkTop - 32),
    ];

    for (int i = 0; i < allEndpoints.length && i < 35; i++) {
      Offset point = allEndpoints[i];
      double angle = math.atan2(point.dy - trunkTop, point.dx - centerX);
      endpoints.add(BranchPoint(point.dx, point.dy, angle));
    }

    return endpoints;
  }

  void _drawSilverLeavesOnBranches(Canvas canvas, Size size, double centerX, double groundY) {
    if (growthLevel <= 10) return; // Start showing leaves after basic growth

    double trunkHeight = size.height * 0.52;
    double trunkTop = groundY - trunkHeight;

    List<BranchPoint> branchEndpoints = _getSilverBranchEndpoints(centerX, trunkTop);

    // Draw premium silver leaves based on growth level
    int leavesToShow = math.min(growthLevel - 10, branchEndpoints.length);
    for (int i = 0; i < leavesToShow; i++) {
      BranchPoint point = branchEndpoints[i];
      _drawSilverLeafAtPoint(canvas, point, i);
    }
  }

  void _drawSilverLeafAtPoint(Canvas canvas, BranchPoint point, int index) {
    canvas.save();
    canvas.translate(point.x, point.y);
    canvas.scale(leafScale);

    // Premium silver-themed leaf colors
    Color leafColor = index % 7 == 0 ? Color(0xFF228B22) : // Forest green
    index % 7 == 1 ? Color(0xFF32CD32) : // Lime green
    index % 7 == 2 ? Color(0xFF90EE90) : // Light green
    index % 7 == 3 ? Color(0xFF006400) : // Dark green
    index % 7 == 4 ? Color(0xFF9ACD32) : // Yellow green
    index % 7 == 5 ? Color(0xFF8FBC8F) : // Dark sea green
    Color(0xFF98FB98); // Pale green

    Paint leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    double leafSize = 13 + (index % 6) * 2; // Bigger premium leaves

    // Draw premium silver-style leaf shape
    Path leafPath = Path();
    leafPath.moveTo(0, -leafSize);
    leafPath.quadraticBezierTo(leafSize * 1.0, -leafSize * 0.7, leafSize * 0.6, 0);
    leafPath.quadraticBezierTo(leafSize * 0.8, leafSize * 0.5, 0, leafSize * 0.6);
    leafPath.quadraticBezierTo(-leafSize * 0.8, leafSize * 0.5, -leafSize * 0.6, 0);
    leafPath.quadraticBezierTo(-leafSize * 1.0, -leafSize * 0.7, 0, -leafSize);

    canvas.drawPath(leafPath, leafPaint);

    // Add silver shimmer effect
    Paint shimmerPaint = Paint()
      ..color = Color(0xFFE6E6FA).withOpacity(0.4) // Lavender shimmer
      ..style = PaintingStyle.fill;

    Path shimmerPath = Path();
    shimmerPath.moveTo(0, -leafSize * 0.8);
    shimmerPath.quadraticBezierTo(leafSize * 0.3, -leafSize * 0.4, leafSize * 0.2, -leafSize * 0.1);
    shimmerPath.quadraticBezierTo(leafSize * 0.1, leafSize * 0.1, 0, leafSize * 0.2);
    shimmerPath.quadraticBezierTo(-leafSize * 0.1, leafSize * 0.1, -leafSize * 0.2, -leafSize * 0.1);
    shimmerPath.quadraticBezierTo(-leafSize * 0.3, -leafSize * 0.4, 0, -leafSize * 0.8);

    canvas.drawPath(shimmerPath, shimmerPaint);

    // Add premium silver-style leaf veins
    Paint veinPaint = Paint()
      ..color = Color(0xFF2F4F4F) // Dark slate gray veins
      ..strokeWidth = 1.6;

    // Main center vein
    canvas.drawLine(
      Offset(0, -leafSize * 1.0),
      Offset(0, leafSize * 0.5),
      veinPaint,
    );

    // Enhanced side veins
    veinPaint.strokeWidth = 1.2;
    for (int i = 0; i < 5; i++) {
      double veinY = -leafSize * 0.8 + (i * leafSize * 0.3);
      double veinLength = leafSize * 0.5 * (1 - i * 0.12);

      // Left side vein
      canvas.drawLine(
        Offset(0, veinY),
        Offset(-veinLength, veinY + veinLength * 0.5),
        veinPaint,
      );

      // Right side vein
      canvas.drawLine(
        Offset(0, veinY),
        Offset(veinLength, veinY + veinLength * 0.5),
        veinPaint,
      );
    }

    // Add silver vein highlights
    Paint silverVein = Paint()
      ..color = Color(0xFFC0C0C0) // Silver
      ..strokeWidth = 0.8;

    canvas.drawLine(
      Offset(1, -leafSize * 0.9),
      Offset(1, leafSize * 0.4),
      silverVein,
    );

    canvas.restore();
  }

  void _drawSilverFlower(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.52;
    double trunkTop = groundY - trunkHeight;
    double flowerCenterX = centerX + 20;
    double flowerCenterY = trunkTop - 100;

    // Premium silver flower center
    final Paint centerPaint = Paint()
      ..color = Color(0xFFC0C0C0) // Silver
      ..style = PaintingStyle.fill;

    // Premium silver flower petals
    final Paint petalPaint = Paint()
      ..color = Color(0xFFE6E6FA) // Lavender
      ..style = PaintingStyle.fill;

    final Paint petalOutlinePaint = Paint()
      ..color = Color(0xFF9370DB) // Medium purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Draw premium silver petals
    for (int i = 0; i < 10; i++) {
      double angle = (i * 2 * math.pi / 10) + flowerRotation * 0.12;
      double petalLength = 26 * flowerBloom;
      double petalWidth = 18 * flowerBloom;

      canvas.save();
      canvas.translate(flowerCenterX, flowerCenterY);
      canvas.rotate(angle);

      // Draw premium petal shape
      final Path petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(petalWidth/2, -petalLength/3, petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(0, -petalLength * 0.85, -petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(-petalWidth/2, -petalLength/3, 0, 0);

      canvas.drawPath(petalPath, petalPaint);
      canvas.drawPath(petalPath, petalOutlinePaint);

      // Add silver petal highlights
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

    // Draw premium silver flower center
    canvas.drawCircle(Offset(flowerCenterX, flowerCenterY), 14 * flowerBloom, centerPaint);

    // Inner premium center detail
    canvas.drawCircle(
        Offset(flowerCenterX, flowerCenterY),
        10 * flowerBloom,
        Paint()
          ..color = Color(0xFF9370DB) // Medium purple
          ..style = PaintingStyle.fill
    );

    // Premium silver center dots
    final Paint dotPaint = Paint()
      ..color = Color(0xFF2F4F4F) // Dark slate gray
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

    // Add premium silver sparkle effect
    if (flowerBloom > 0.8) {
      _drawSilverSparkles(canvas, flowerCenterX, flowerCenterY);
    }
  }

  void _drawSilverSparkles(Canvas canvas, double centerX, double centerY) {
    final Paint sparklePaint = Paint()
      ..color = Color(0xFFE6E6FA) // Lavender sparkles
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final Paint silverSparklePaint = Paint()
      ..color = Color(0xFFC0C0C0) // Silver sparkles
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      double angle = i * math.pi / 4 + flowerRotation;
      double distance = 40 + 8 * math.sin(flowerRotation * 2.5);
      double x = centerX + distance * math.cos(angle);
      double y = centerY + distance * math.sin(angle);

      // Draw premium sparkle stars
      Paint currentPaint = i % 2 == 0 ? sparklePaint : silverSparklePaint;

      canvas.drawLine(Offset(x - 6, y), Offset(x + 6, y), currentPaint);
      canvas.drawLine(Offset(x, y - 6), Offset(x, y + 6), currentPaint);

      // Add diagonal lines for premium star effect
      canvas.drawLine(Offset(x - 5, y - 5), Offset(x + 5, y + 5), currentPaint);
      canvas.drawLine(Offset(x - 5, y + 5), Offset(x + 5, y - 5), currentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is SilverTreePainter &&
        (oldDelegate.growthLevel != growthLevel ||
            oldDelegate.totalGrowth != totalGrowth ||
            oldDelegate.flowerBloom != flowerBloom ||
            oldDelegate.flowerRotation != flowerRotation ||
            oldDelegate.leafScale != leafScale);
  }
}