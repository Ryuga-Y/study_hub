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

  GoldTreePainter({
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

    // Draw luxury soil and ground
    _drawGoldSoilAndGround(canvas, size, centerX, groundY);

    // Draw luxury tree roots
    _drawGoldTreeRoots(canvas, size, centerX, groundY);

    // Draw the ultimate luxury gold tree
    _drawGoldTree(canvas, size, centerX, groundY);

    // Draw golden leaves on branch endpoints
    _drawGoldLeavesOnBranches(canvas, size, centerX, groundY);

    // Draw luxury gold flower if 100% complete
    if (totalGrowth >= 1.0) {
      _drawGoldFlower(canvas, size, centerX, groundY);
    }
  }

  void _drawGoldSoilAndGround(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw luxury soil mound with golden tint
    final Paint soilPaint = Paint()
      ..color = Color(0xFFB8860B) // Dark golden rod
      ..style = PaintingStyle.fill;

    final Path soilPath = Path();
    double soilWidth = 180; // Largest soil base
    double soilHeight = 40;

    // Create luxury soil mound
    soilPath.moveTo(centerX - soilWidth/2, groundY);
    soilPath.quadraticBezierTo(
        centerX - soilWidth/3, groundY - soilHeight,
        centerX, groundY - soilHeight/2
    );
    soilPath.quadraticBezierTo(
        centerX + soilWidth/3, groundY - soilHeight,
        centerX + soilWidth/2, groundY
    );
    soilPath.lineTo(centerX + soilWidth/2, groundY + 20);
    soilPath.lineTo(centerX - soilWidth/2, groundY + 20);
    soilPath.close();

    canvas.drawPath(soilPath, soilPaint);

    // Add luxury gold-tinted soil texture with gems
    final Paint soilTexturePaint = Paint()
      ..color = Color(0xFF8B7355) // Dark khaki
      ..style = PaintingStyle.fill;

    final Paint goldSparkle = Paint()
      ..color = Color(0xFFFFD700) // Gold
      ..style = PaintingStyle.fill;

    final Paint gemPaint = Paint()
      ..color = Color(0xFF9ACD32) // Yellow green (emerald)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 18; i++) {
      double x = centerX - soilWidth/3 + (i * 14);
      double y = groundY - 12 + (i % 6) * 5;
      canvas.drawCircle(Offset(x, y), 3.5, soilTexturePaint);

      // Add gold sparkles in soil
      if (i % 2 == 0) {
        canvas.drawCircle(Offset(x + 3, y - 2), 2, goldSparkle);
      }

      // Add gems in soil
      if (i % 4 == 0) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x - 2, y + 1), width: 3, height: 2),
          gemPaint,
        );
      }
    }

    // Draw luxury ground line with gold accent
    final Paint groundPaint = Paint()
      ..color = Color(0xFFDAA520) // Golden rod
      ..strokeWidth = 6;
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      groundPaint,
    );

    // Add multiple gold ground accent lines
    final Paint goldAccent1 = Paint()
      ..color = Color(0xFFFFD700) // Gold
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, groundY - 3),
      Offset(size.width, groundY - 3),
      goldAccent1,
    );

    final Paint goldAccent2 = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, groundY - 6),
      Offset(size.width, groundY - 6),
      goldAccent2,
    );
  }

  void _drawGoldTreeRoots(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint rootPaint = Paint()
      ..color = Color(0xFFB8860B) // Dark golden rod
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12; // Thickest roots

    // Luxury enhanced main roots
    List<Offset> rootDirections = [
      Offset(-1.6, 0.6),  // Left root
      Offset(1.6, 0.6),   // Right root
      Offset(-1.2, 0.8),  // Left-center root
      Offset(1.2, 0.8),   // Right-center root
      Offset(-0.8, 1.0),  // Additional roots
      Offset(0.8, 1.0),
      Offset(-2.0, 0.4),  // Extended roots
      Offset(2.0, 0.4),
    ];

    for (int i = 0; i < rootDirections.length; i++) {
      Offset direction = rootDirections[i];
      _drawGoldSingleRoot(canvas, centerX, groundY, direction, rootPaint);
    }

    // Luxury secondary roots
    rootPaint.strokeWidth = 6;
    List<Offset> smallRootDirections = [
      Offset(-2.2, 0.5),
      Offset(2.2, 0.5),
      Offset(-0.6, 1.2),
      Offset(0.6, 1.2),
      Offset(-1.5, 1.0),
      Offset(1.5, 1.0),
      Offset(-1.8, 0.7),
      Offset(1.8, 0.7),
    ];

    for (int i = 0; i < smallRootDirections.length; i++) {
      Offset direction = smallRootDirections[i];
      _drawGoldSingleRoot(canvas, centerX, groundY, direction, rootPaint, isSmall: true);
    }
  }

  void _drawGoldSingleRoot(Canvas canvas, double startX, double startY, Offset direction, Paint paint, {bool isSmall = false}) {
    double length = isSmall ? 60 : 100; // Longest roots

    Path rootPath = Path();
    rootPath.moveTo(startX, startY);

    // Create curved root
    double midX = startX + direction.dx * length * 0.5;
    double midY = startY + direction.dy * length * 0.5;
    double endX = startX + direction.dx * length;
    double endY = startY + direction.dy * length;

    rootPath.quadraticBezierTo(midX, midY, endX, endY);
    canvas.drawPath(rootPath, paint);

    // Add golden root accents
    Paint goldAccent = Paint()
      ..color = Color(0xFFFFD700) // Gold
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = isSmall ? 2.5 : 4;

    Path accentPath = Path();
    accentPath.moveTo(startX, startY);
    accentPath.quadraticBezierTo(midX - 2, midY - 2, endX - 3, endY - 3);
    canvas.drawPath(accentPath, goldAccent);

    // Add golden highlights
    Paint goldHighlight = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = isSmall ? 1 : 2;

    Path highlightPath = Path();
    highlightPath.moveTo(startX + 1, startY + 1);
    highlightPath.quadraticBezierTo(midX - 1, midY - 1, endX - 1, endY - 1);
    canvas.drawPath(highlightPath, goldHighlight);

    // Add luxury root branches
    if (!isSmall) {
      Paint branchPaint = Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5;

      // Luxury root branches
      for (int i = 0; i < 5; i++) {
        double branchAngle = (i - 2) * 0.3;
        double branchLength = 30;
        double branchStartX = endX - direction.dx * 25;
        double branchStartY = endY - direction.dy * 25;

        canvas.drawLine(
          Offset(branchStartX, branchStartY),
          Offset(
              branchStartX + branchLength * math.cos(branchAngle),
              branchStartY + branchLength * math.sin(branchAngle) + 12
          ),
          branchPaint,
        );
      }
    }
  }

  void _drawGoldTree(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw ultimate luxury gold trunk
    _drawGoldTrunk(canvas, size, centerX, groundY);

    // Draw ultimate luxury gold branches
    _drawGoldBranches(canvas, size, centerX, groundY);
  }

  void _drawGoldTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint trunkPaint = Paint()
      ..color = Color(0xFFDAA520) // Golden rod
      ..style = PaintingStyle.fill;

    double trunkHeight = size.height * 0.55; // Tallest trunk
    double trunkBase = groundY;
    double trunkTop = groundY - trunkHeight;

    // Create ultimate luxury gold trunk
    final Path trunkPath = Path();

    double baseWidth = 40; // Widest trunk
    double topWidth = 32;

    // Create trunk with golden characteristics
    trunkPath.moveTo(centerX - baseWidth/2, trunkBase);
    trunkPath.lineTo(centerX - topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + baseWidth/2, trunkBase);
    trunkPath.close();

    canvas.drawPath(trunkPath, trunkPaint);

    // Add multiple golden highlights
    final Paint goldHighlight1 = Paint()
      ..color = Color(0xFFFFD700) // Gold
      ..style = PaintingStyle.fill;

    final Path highlight1Path = Path();
    highlight1Path.moveTo(centerX - baseWidth/2 + 4, trunkBase);
    highlight1Path.lineTo(centerX - topWidth/2 + 3, trunkTop);
    highlight1Path.lineTo(centerX - topWidth/2 + 12, trunkTop);
    highlight1Path.lineTo(centerX - baseWidth/2 + 13, trunkBase);
    highlight1Path.close();

    canvas.drawPath(highlight1Path, goldHighlight1);

    final Paint goldHighlight2 = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk
      ..style = PaintingStyle.fill;

    final Path highlight2Path = Path();
    highlight2Path.moveTo(centerX + baseWidth/2 - 4, trunkBase);
    highlight2Path.lineTo(centerX + topWidth/2 - 3, trunkTop);
    highlight2Path.lineTo(centerX + topWidth/2 - 12, trunkTop);
    highlight2Path.lineTo(centerX + baseWidth/2 - 13, trunkBase);
    highlight2Path.close();

    canvas.drawPath(highlight2Path, goldHighlight2);

    // Add ultimate luxury gold bark texture
    _drawGoldBarkTexture(canvas, centerX, groundY, trunkHeight, baseWidth, topWidth);
  }

  void _drawGoldBarkTexture(Canvas canvas, double centerX, double groundY, double trunkHeight, double baseWidth, double topWidth) {
    // Ultimate luxury gold bark lines
    final Paint darkBarkPaint = Paint()
      ..color = Color(0xFFB8860B) // Dark golden rod
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final Paint lightBarkPaint = Paint()
      ..color = Color(0xFFFFD700) // Gold
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final Paint luxuryBarkPaint = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Ultimate vertical bark ridges
    for (int i = 0; i < 15; i++) {
      double x = centerX - 20 + (i * 3.2);
      double topY = groundY - trunkHeight + 30;
      double bottomY = groundY - 12;

      // Create luxury bark lines
      Path barkLine = Path();
      barkLine.moveTo(x, bottomY);

      int segments = 20;
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 3.5 * math.sin(j * 1.1 + i * 0.8) * (1 - j/segments);
        barkLine.lineTo(x + offset, segmentY);
      }

      canvas.drawPath(barkLine, darkBarkPaint);

      // Add gold highlights
      Path lightLine = Path();
      lightLine.moveTo(x + 3, bottomY);
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 3 * math.sin(j * 0.9 + i * 0.6) * (1 - j/segments);
        lightLine.lineTo(x + 3 + offset, segmentY);
      }
      canvas.drawPath(lightLine, lightBarkPaint);

      // Add luxury highlights
      if (i % 2 == 0) {
        Path luxuryLine = Path();
        luxuryLine.moveTo(x + 1.5, bottomY);
        for (int j = 1; j <= segments; j++) {
          double segmentY = bottomY - (bottomY - topY) * (j / segments);
          double offset = 2 * math.sin(j * 0.7 + i * 0.4) * (1 - j/segments);
          luxuryLine.lineTo(x + 1.5 + offset, segmentY);
        }
        canvas.drawPath(luxuryLine, luxuryBarkPaint);
      }
    }

    // Ultimate luxury gold bark rings
    final Paint ringPaint = Paint()
      ..color = Color(0xFFB8860B) // Dark golden rod
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final Paint goldRingPaint = Paint()
      ..color = Color(0xFFFFD700) // Gold
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint luxuryRingPaint = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 18; i++) {
      double y = groundY - (trunkHeight * 0.06 * i) - 30;
      double width = baseWidth - (baseWidth - topWidth) * (i / 18.0);

      // Create luxury bark rings
      Path ringPath = Path();
      ringPath.moveTo(centerX - width/2 + 5, y);

      int ringSegments = 28;
      for (int j = 1; j <= ringSegments; j++) {
        double angle = (j / ringSegments) * math.pi;
        double radius = width/2 - 5;
        double x = centerX + radius * math.cos(angle - math.pi/2);
        double ringY = y + 5 * math.sin(j * 0.7);
        ringPath.lineTo(x, ringY);
      }

      canvas.drawPath(ringPath, ringPaint);

      // Add gold accent rings
      if (i % 2 == 0) {
        Path goldRing = Path();
        goldRing.moveTo(centerX - width/2 + 7, y + 1);
        for (int j = 1; j <= ringSegments; j++) {
          double angle = (j / ringSegments) * math.pi;
          double radius = width/2 - 7;
          double x = centerX + radius * math.cos(angle - math.pi/2);
          double ringY = y + 1 + 3 * math.sin(j * 0.5);
          goldRing.lineTo(x, ringY);
        }
        canvas.drawPath(goldRing, goldRingPaint);
      }

      // Add luxury accent rings
      if (i % 3 == 0) {
        Path luxuryRing = Path();
        luxuryRing.moveTo(centerX - width/2 + 9, y + 2);
        for (int j = 1; j <= ringSegments; j++) {
          double angle = (j / ringSegments) * math.pi;
          double radius = width/2 - 9;
          double x = centerX + radius * math.cos(angle - math.pi/2);
          double ringY = y + 2 + 2 * math.sin(j * 0.3);
          luxuryRing.lineTo(x, ringY);
        }
        canvas.drawPath(luxuryRing, luxuryRingPaint);
      }
    }
  }

  void _drawGoldBranches(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.55;
    double trunkTop = groundY - trunkHeight;

    final Paint mainBranchPaint = Paint()
      ..color = Color(0xFFDAA520) // Golden rod
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw ultimate luxury gold branches based on growth level
    if (growthLevel >= 5) _drawGoldMainBranches(canvas, centerX, trunkTop, mainBranchPaint);
    if (growthLevel >= 15) _drawGoldSecondaryBranches(canvas, centerX, trunkTop, mainBranchPaint);
    if (growthLevel >= 25) _drawGoldDetailBranches(canvas, centerX, trunkTop, mainBranchPaint);
    if (growthLevel >= 35) _drawGoldFineBranches(canvas, centerX, trunkTop, mainBranchPaint);
  }

  void _drawGoldMainBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 16; // Thickest main branches

    // Ultimate main gold branches
    _drawGoldBranchPath(canvas, paint, [
      Offset(centerX - 6, trunkTop + 40),
      Offset(centerX - 35, trunkTop + 12),
      Offset(centerX - 75, trunkTop - 22),
      Offset(centerX - 115, trunkTop - 50),
      Offset(centerX - 150, trunkTop - 65),
    ]);

    _drawGoldBranchPath(canvas, paint, [
      Offset(centerX + 6, trunkTop + 35),
      Offset(centerX + 40, trunkTop + 8),
      Offset(centerX + 80, trunkTop - 30),
      Offset(centerX + 120, trunkTop - 50),
      Offset(centerX + 160, trunkTop - 65),
    ]);

    // Ultimate upper main branches
    _drawGoldBranchPath(canvas, paint, [
      Offset(centerX - 5, trunkTop + 20),
      Offset(centerX - 30, trunkTop - 22),
      Offset(centerX - 65, trunkTop - 55),
      Offset(centerX - 95, trunkTop - 95),
    ]);

    _drawGoldBranchPath(canvas, paint, [
      Offset(centerX + 5, trunkTop + 12),
      Offset(centerX + 33, trunkTop - 18),
      Offset(centerX + 70, trunkTop - 50),
      Offset(centerX + 100, trunkTop - 90),
    ]);

    // Premium central branches
    _drawGoldBranchPath(canvas, paint, [
      Offset(centerX - 4, trunkTop + 8),
      Offset(centerX - 18, trunkTop - 40),
      Offset(centerX - 30, trunkTop - 80),
      Offset(centerX - 40, trunkTop - 115),
    ]);

    _drawGoldBranchPath(canvas, paint, [
      Offset(centerX + 4, trunkTop - 8),
      Offset(centerX + 22, trunkTop - 45),
      Offset(centerX + 35, trunkTop - 85),
      Offset(centerX + 45, trunkTop - 120),
    ]);
  }

  void _drawGoldSecondaryBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 12; // Ultimate secondary branches

    // Ultimate secondary branches with maximum detail
    List<List<Offset>> secondaryBranches = [
      // Left side ultimate
      [Offset(centerX - 75, trunkTop - 22), Offset(centerX - 100, trunkTop - 35), Offset(centerX - 125, trunkTop - 28)],
      [Offset(centerX - 115, trunkTop - 50), Offset(centerX - 145, trunkTop - 35), Offset(centerX - 175, trunkTop - 45)],
      [Offset(centerX - 150, trunkTop - 65), Offset(centerX - 175, trunkTop - 52), Offset(centerX - 205, trunkTop - 60)],

      // Right side ultimate
      [Offset(centerX + 80, trunkTop - 30), Offset(centerX + 105, trunkTop - 43), Offset(centerX + 135, trunkTop - 35)],
      [Offset(centerX + 120, trunkTop - 50), Offset(centerX + 150, trunkTop - 35), Offset(centerX + 180, trunkTop - 45)],
      [Offset(centerX + 160, trunkTop - 65), Offset(centerX + 190, trunkTop - 52), Offset(centerX + 215, trunkTop - 60)],

      // Ultimate upper branches
      [Offset(centerX - 65, trunkTop - 55), Offset(centerX - 85, trunkTop - 75), Offset(centerX - 75, trunkTop - 100)],
      [Offset(centerX - 95, trunkTop - 95), Offset(centerX - 120, trunkTop - 110), Offset(centerX - 125, trunkTop - 135)],
      [Offset(centerX + 70, trunkTop - 50), Offset(centerX + 90, trunkTop - 70), Offset(centerX + 80, trunkTop - 95)],
      [Offset(centerX + 100, trunkTop - 90), Offset(centerX + 125, trunkTop - 105), Offset(centerX + 130, trunkTop - 130)],
    ];

    for (var branch in secondaryBranches) {
      _drawGoldBranchPath(canvas, paint, branch);
    }
  }

  void _drawGoldDetailBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 8; // Ultimate detail branches

    // Ultimate detail branches for maximum luxury
    List<List<Offset>> detailBranches = [
      // Left side ultimate details
      [Offset(centerX - 100, trunkTop - 35), Offset(centerX - 115, trunkTop - 25), Offset(centerX - 130, trunkTop - 18)],
      [Offset(centerX - 125, trunkTop - 28), Offset(centerX - 140, trunkTop - 20), Offset(centerX - 155, trunkTop - 12)],
      [Offset(centerX - 145, trunkTop - 35), Offset(centerX - 165, trunkTop - 45), Offset(centerX - 180, trunkTop - 58)],
      [Offset(centerX - 175, trunkTop - 45), Offset(centerX - 195, trunkTop - 35), Offset(centerX - 215, trunkTop - 40)],

      // Right side ultimate details
      [Offset(centerX + 105, trunkTop - 43), Offset(centerX + 120, trunkTop - 33), Offset(centerX + 140, trunkTop - 25)],
      [Offset(centerX + 135, trunkTop - 35), Offset(centerX + 150, trunkTop - 25), Offset(centerX + 165, trunkTop - 18)],
      [Offset(centerX + 150, trunkTop - 35), Offset(centerX + 170, trunkTop - 45), Offset(centerX + 190, trunkTop - 58)],
      [Offset(centerX + 180, trunkTop - 45), Offset(centerX + 200, trunkTop - 35), Offset(centerX + 220, trunkTop - 40)],

      // Ultimate upper details
      [Offset(centerX - 85, trunkTop - 75), Offset(centerX - 70, trunkTop - 88), Offset(centerX - 58, trunkTop - 105)],
      [Offset(centerX - 75, trunkTop - 100), Offset(centerX - 90, trunkTop - 115), Offset(centerX - 95, trunkTop - 135)],
      [Offset(centerX - 40, trunkTop - 115), Offset(centerX - 55, trunkTop - 130), Offset(centerX - 60, trunkTop - 150)],
      [Offset(centerX + 90, trunkTop - 70), Offset(centerX + 75, trunkTop - 83), Offset(centerX + 63, trunkTop - 100)],
      [Offset(centerX + 80, trunkTop - 95), Offset(centerX + 95, trunkTop - 110), Offset(centerX + 100, trunkTop - 130)],
      [Offset(centerX + 45, trunkTop - 120), Offset(centerX + 60, trunkTop - 135), Offset(centerX + 65, trunkTop - 155)],
    ];

    for (var branch in detailBranches) {
      _drawGoldBranchPath(canvas, paint, branch);
    }
  }

  void _drawGoldFineBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 5; // Ultimate fine branches

    // Generate ultimate fine branches based on growth level
    List<Offset> endpoints = [
      // Left side ultimate endpoints
      Offset(centerX - 130, trunkTop - 18), Offset(centerX - 155, trunkTop - 12), Offset(centerX - 180, trunkTop - 58),
      Offset(centerX - 215, trunkTop - 40), Offset(centerX - 195, trunkTop - 35), Offset(centerX - 58, trunkTop - 105),
      Offset(centerX - 95, trunkTop - 135), Offset(centerX - 60, trunkTop - 150), Offset(centerX - 125, trunkTop - 135),

      // Right side ultimate endpoints
      Offset(centerX + 140, trunkTop - 25), Offset(centerX + 165, trunkTop - 18), Offset(centerX + 190, trunkTop - 58),
      Offset(centerX + 220, trunkTop - 40), Offset(centerX + 200, trunkTop - 35), Offset(centerX + 63, trunkTop - 100),
      Offset(centerX + 100, trunkTop - 130), Offset(centerX + 65, trunkTop - 155), Offset(centerX + 130, trunkTop - 130),

      // Additional ultimate endpoints for maximum coverage
      Offset(centerX - 165, trunkTop - 45), Offset(centerX - 140, trunkTop - 20), Offset(centerX + 170, trunkTop - 45),
      Offset(centerX + 145, trunkTop - 25), Offset(centerX - 55, trunkTop - 130), Offset(centerX + 60, trunkTop - 135),
    ];

    for (int i = 0; i < endpoints.length && i < (growthLevel - 30); i++) {
      if (i >= 0) {
        Offset endpoint = endpoints[i];

        // Draw 5-6 ultimate twigs from each endpoint
        for (int j = 0; j < 6; j++) {
          double angle = (j - 2.5) * 0.35 + (i * 0.18);
          double length = 22 + j * 6;

          Offset twigEnd = Offset(
            endpoint.dx + length * math.cos(angle),
            endpoint.dy + length * math.sin(angle) - 15,
          );

          canvas.drawLine(endpoint, twigEnd, paint);

          // Add ultimate sub-twigs with golden accents
          if (j >= 1 && j <= 4) {
            for (int k = 0; k < 4; k++) {
              double subAngle = angle + (k - 1.5) * 0.25;
              double subLength = 12;
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
      ..color = Color(0xFFFFD700) // Gold
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
      ..color = Color(0xFFFFF8DC) // Cornsilk
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

    List<Offset> allEndpoints = [
      // Ultimate left side branch endpoints
      Offset(centerX - 130, trunkTop - 18), Offset(centerX - 155, trunkTop - 12), Offset(centerX - 180, trunkTop - 58),
      Offset(centerX - 215, trunkTop - 40), Offset(centerX - 195, trunkTop - 35), Offset(centerX - 58, trunkTop - 105),
      Offset(centerX - 95, trunkTop - 135), Offset(centerX - 60, trunkTop - 150), Offset(centerX - 125, trunkTop - 135),
      Offset(centerX - 165, trunkTop - 45), Offset(centerX - 140, trunkTop - 20), Offset(centerX - 55, trunkTop - 130),

      // Ultimate right side branch endpoints
      Offset(centerX + 140, trunkTop - 25), Offset(centerX + 165, trunkTop - 18), Offset(centerX + 190, trunkTop - 58),
      Offset(centerX + 220, trunkTop - 40), Offset(centerX + 200, trunkTop - 35), Offset(centerX + 63, trunkTop - 100),
      Offset(centerX + 100, trunkTop - 130), Offset(centerX + 65, trunkTop - 155), Offset(centerX + 130, trunkTop - 130),
      Offset(centerX + 170, trunkTop - 45), Offset(centerX + 145, trunkTop - 25), Offset(centerX + 60, trunkTop - 135),

      // Additional ultimate endpoints
      Offset(centerX - 125, trunkTop - 28), Offset(centerX + 135, trunkTop - 35),
    ];

    for (int i = 0; i < allEndpoints.length && i < 40; i++) {
      Offset point = allEndpoints[i];
      double angle = math.atan2(point.dy - trunkTop, point.dx - centerX);
      endpoints.add(BranchPoint(point.dx, point.dy, angle));
    }

    return endpoints;
  }

  void _drawGoldLeavesOnBranches(Canvas canvas, Size size, double centerX, double groundY) {
    if (growthLevel <= 10) return; // Start showing leaves after basic growth

    double trunkHeight = size.height * 0.55;
    double trunkTop = groundY - trunkHeight;

    List<BranchPoint> branchEndpoints = _getGoldBranchEndpoints(centerX, trunkTop);

    // Draw ultimate luxury gold leaves
    int leavesToShow = math.min(growthLevel - 10, branchEndpoints.length);
    for (int i = 0; i < leavesToShow; i++) {
      BranchPoint point = branchEndpoints[i];
      _drawGoldLeafAtPoint(canvas, point, i);
    }
  }

  void _drawGoldLeafAtPoint(Canvas canvas, BranchPoint point, int index) {
    canvas.save();
    canvas.translate(point.x, point.y);
    canvas.scale(leafScale);

    // Ultimate luxury gold-themed leaf colors
    Color leafColor = index % 8 == 0 ? Color(0xFFFFD700) : // Gold
    index % 8 == 1 ? Color(0xFFFFF8DC) : // Cornsilk
    index % 8 == 2 ? Color(0xFFDAA520) : // Golden rod
    index % 8 == 3 ? Color(0xFF32CD32) : // Lime green
    index % 8 == 4 ? Color(0xFF9ACD32) : // Yellow green
    index % 8 == 5 ? Color(0xFF98FB98) : // Pale green
    index % 8 == 6 ? Color(0xFF90EE90) : // Light green
    Color(0xFFB8860B); // Dark golden rod

    Paint leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    double leafSize = 15 + (index % 7) * 2; // Largest premium leaves

    // Draw ultimate luxury gold-style leaf shape
    Path leafPath = Path();
    leafPath.moveTo(0, -leafSize);
    leafPath.quadraticBezierTo(leafSize * 1.1, -leafSize * 0.8, leafSize * 0.7, 0);
    leafPath.quadraticBezierTo(leafSize * 0.9, leafSize * 0.6, 0, leafSize * 0.7);
    leafPath.quadraticBezierTo(-leafSize * 0.9, leafSize * 0.6, -leafSize * 0.7, 0);
    leafPath.quadraticBezierTo(-leafSize * 1.1, -leafSize * 0.8, 0, -leafSize);

    canvas.drawPath(leafPath, leafPaint);

    // Add ultimate gold shimmer effect
    Paint goldShimmer = Paint()
      ..color = Color(0xFFFFD700).withOpacity(0.6) // Gold shimmer
      ..style = PaintingStyle.fill;

    Path shimmerPath = Path();
    shimmerPath.moveTo(0, -leafSize * 0.9);
    shimmerPath.quadraticBezierTo(leafSize * 0.4, -leafSize * 0.5, leafSize * 0.3, -leafSize * 0.1);
    shimmerPath.quadraticBezierTo(leafSize * 0.2, leafSize * 0.2, 0, leafSize * 0.3);
    shimmerPath.quadraticBezierTo(-leafSize * 0.2, leafSize * 0.2, -leafSize * 0.3, -leafSize * 0.1);
    shimmerPath.quadraticBezierTo(-leafSize * 0.4, -leafSize * 0.5, 0, -leafSize * 0.9);

    canvas.drawPath(shimmerPath, goldShimmer);

    // Add luxury sparkle effect
    Paint luxurySparkle = Paint()
      ..color = Color(0xFFFFF8DC).withOpacity(0.4) // Cornsilk sparkle
      ..style = PaintingStyle.fill;

    Path sparklePath = Path();
    sparklePath.moveTo(0, -leafSize * 0.7);
    sparklePath.quadraticBezierTo(leafSize * 0.2, -leafSize * 0.3, leafSize * 0.15, 0);
    sparklePath.quadraticBezierTo(leafSize * 0.1, leafSize * 0.1, 0, leafSize * 0.15);
    sparklePath.quadraticBezierTo(-leafSize * 0.1, leafSize * 0.1, -leafSize * 0.15, 0);
    sparklePath.quadraticBezierTo(-leafSize * 0.2, -leafSize * 0.3, 0, -leafSize * 0.7);

    canvas.drawPath(sparklePath, luxurySparkle);

    // Add ultimate luxury gold-style leaf veins
    Paint veinPaint = Paint()
      ..color = Color(0xFFB8860B) // Dark golden rod veins
      ..strokeWidth = 1.8;

    // Main center vein
    canvas.drawLine(
      Offset(0, -leafSize * 1.05),
      Offset(0, leafSize * 0.6),
      veinPaint,
    );

    // Ultimate enhanced side veins
    veinPaint.strokeWidth = 1.4;
    for (int i = 0; i < 6; i++) {
      double veinY = -leafSize * 0.85 + (i * leafSize * 0.25);
      double veinLength = leafSize * 0.55 * (1 - i * 0.1);

      // Left side vein
      canvas.drawLine(
        Offset(0, veinY),
        Offset(-veinLength, veinY + veinLength * 0.6),
        veinPaint,
      );

      // Right side vein
      canvas.drawLine(
        Offset(0, veinY),
        Offset(veinLength, veinY + veinLength * 0.6),
        veinPaint,
      );
    }

    // Add ultimate gold vein highlights
    Paint goldVein = Paint()
      ..color = Color(0xFFFFD700) // Gold
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(1.5, -leafSize * 0.95),
      Offset(1.5, leafSize * 0.5),
      goldVein,
    );

    // Add luxury vein accents
    Paint luxuryVein = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk
      ..strokeWidth = 0.6;

    canvas.drawLine(
      Offset(0.8, -leafSize * 0.85),
      Offset(0.8, leafSize * 0.4),
      luxuryVein,
    );

    canvas.restore();
  }

  void _drawGoldFlower(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.55;
    double trunkTop = groundY - trunkHeight;
    double flowerCenterX = centerX + 25;
    double flowerCenterY = trunkTop - 115;

    // Ultimate luxury gold flower center
    final Paint centerPaint = Paint()
      ..color = Color(0xFFFFD700) // Gold
      ..style = PaintingStyle.fill;

    // Ultimate luxury gold flower petals
    final Paint petalPaint = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk
      ..style = PaintingStyle.fill;

    final Paint petalOutlinePaint = Paint()
      ..color = Color(0xFFFFD700) // Gold outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw ultimate luxury gold petals
    for (int i = 0; i < 12; i++) {
      double angle = (i * 2 * math.pi / 12) + flowerRotation * 0.15;
      double petalLength = 30 * flowerBloom;
      double petalWidth = 20 * flowerBloom;

      canvas.save();
      canvas.translate(flowerCenterX, flowerCenterY);
      canvas.rotate(angle);

      // Draw ultimate luxury petal shape
      final Path petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(petalWidth/2, -petalLength/3, petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(0, -petalLength * 0.9, -petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(-petalWidth/2, -petalLength/3, 0, 0);

      canvas.drawPath(petalPath, petalPaint);
      canvas.drawPath(petalPath, petalOutlinePaint);

      // Add ultimate gold petal highlights
      final Paint petalHighlight = Paint()
        ..color = Color(0xFFFFD700).withOpacity(0.6)
        ..style = PaintingStyle.fill;

      final Path highlightPath = Path();
      highlightPath.moveTo(0, 0);
      highlightPath.quadraticBezierTo(petalWidth/3, -petalLength/4, petalWidth/5, -petalLength/1.5);
      highlightPath.quadraticBezierTo(0, -petalLength * 0.7, -petalWidth/5, -petalLength/1.5);
      highlightPath.quadraticBezierTo(-petalWidth/3, -petalLength/4, 0, 0);

      canvas.drawPath(highlightPath, petalHighlight);

      // Add luxury sparkles on petals
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

    // Draw ultimate luxury gold flower center
    canvas.drawCircle(Offset(flowerCenterX, flowerCenterY), 16 * flowerBloom, centerPaint);

    // Inner ultimate center detail
    canvas.drawCircle(
        Offset(flowerCenterX, flowerCenterY),
        12 * flowerBloom,
        Paint()
          ..color = Color(0xFFB8860B) // Dark golden rod
          ..style = PaintingStyle.fill
    );

    // Ultimate luxury gold center dots
    final Paint dotPaint = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      double dotAngle = i * 2 * math.pi / 10;
      double dotDistance = 6 * flowerBloom;
      canvas.drawCircle(
        Offset(
            flowerCenterX + dotDistance * math.cos(dotAngle),
            flowerCenterY + dotDistance * math.sin(dotAngle)
        ),
        2.5 * flowerBloom,
        dotPaint,
      );
    }

    // Add ultimate luxury gold sparkle effect
    if (flowerBloom > 0.8) {
      _drawGoldSparkles(canvas, flowerCenterX, flowerCenterY);
    }
  }

  void _drawGoldSparkles(Canvas canvas, double centerX, double centerY) {
    final Paint sparklePaint = Paint()
      ..color = Color(0xFFFFD700) // Gold sparkles
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final Paint luxurySparklePaint = Paint()
      ..color = Color(0xFFFFF8DC) // Cornsilk sparkles
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final Paint diamondSparklePaint = Paint()
      ..color = Colors.white // Diamond sparkles
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      double angle = i * math.pi / 6 + flowerRotation;
      double distance = 50 + 10 * math.sin(flowerRotation * 3);
      double x = centerX + distance * math.cos(angle);
      double y = centerY + distance * math.sin(angle);

      // Draw ultimate luxury sparkle stars
      Paint currentPaint = i % 3 == 0 ? sparklePaint :
      i % 3 == 1 ? luxurySparklePaint :
      diamondSparklePaint;

      canvas.drawLine(Offset(x - 8, y), Offset(x + 8, y), currentPaint);
      canvas.drawLine(Offset(x, y - 8), Offset(x, y + 8), currentPaint);

      // Add diagonal lines for ultimate star effect
      canvas.drawLine(Offset(x - 6, y - 6), Offset(x + 6, y + 6), currentPaint);
      canvas.drawLine(Offset(x - 6, y + 6), Offset(x + 6, y - 6), currentPaint);

      // Add ultimate luxury cross sparkles
      if (i % 2 == 0) {
        canvas.drawLine(Offset(x - 4, y - 8), Offset(x + 4, y + 8), currentPaint);
        canvas.drawLine(Offset(x + 4, y - 8), Offset(x - 4, y + 8), currentPaint);
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
            oldDelegate.leafScale != leafScale);
  }
}