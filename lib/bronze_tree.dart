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

  BronzeTreePainter({
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

    // Draw the bronze tree trunk and branches
    _drawBronzeTree(canvas, size, centerX, groundY);

    // Draw leaves on branch endpoints
    _drawLeavesOnBranches(canvas, size, centerX, groundY);

    // Draw bronze flower if 100% complete
    if (totalGrowth >= 1.0) {
      _drawBronzeFlower(canvas, size, centerX, groundY);
    }
  }

  void _drawSoilAndGround(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw soil mound with bronze tint
    final Paint soilPaint = Paint()
      ..color = Color(0xFF8B4513) // Saddle brown with bronze hint
      ..style = PaintingStyle.fill;

    final Path soilPath = Path();
    double soilWidth = 140; // Bigger soil base
    double soilHeight = 30;

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
    soilPath.lineTo(centerX + soilWidth/2, groundY + 15);
    soilPath.lineTo(centerX - soilWidth/2, groundY + 15);
    soilPath.close();

    canvas.drawPath(soilPath, soilPaint);

    // Add bronze-tinted soil texture
    final Paint soilTexturePaint = Paint()
      ..color = Color(0xFF654321) // Dark bronze brown
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      double x = centerX - soilWidth/3 + (i * 12);
      double y = groundY - 8 + (i % 4) * 4;
      canvas.drawCircle(Offset(x, y), 2.5, soilTexturePaint);
    }

    // Draw ground line
    final Paint groundPaint = Paint()
      ..color = Color(0xFFA0522D) // Bronze-tinted brown
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      groundPaint,
    );
  }

  void _drawTreeRoots(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint rootPaint = Paint()
      ..color = Color(0xFF5D4037) // Dark bronze brown
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8; // Thicker roots

    // Main roots extending from trunk base
    List<Offset> rootDirections = [
      Offset(-1.2, 0.4),  // Left root
      Offset(1.2, 0.4),   // Right root
      Offset(-0.8, 0.6), // Left-center root
      Offset(0.8, 0.6),  // Right-center root
    ];

    for (int i = 0; i < rootDirections.length; i++) {
      Offset direction = rootDirections[i];
      _drawSingleRoot(canvas, centerX, groundY, direction, rootPaint);
    }

    // Smaller secondary roots
    rootPaint.strokeWidth = 4;
    List<Offset> smallRootDirections = [
      Offset(-1.5, 0.3),
      Offset(1.5, 0.3),
      Offset(-0.4, 0.8),
      Offset(0.4, 0.8),
    ];

    for (int i = 0; i < smallRootDirections.length; i++) {
      Offset direction = smallRootDirections[i];
      _drawSingleRoot(canvas, centerX, groundY, direction, rootPaint, isSmall: true);
    }
  }

  void _drawSingleRoot(Canvas canvas, double startX, double startY, Offset direction, Paint paint, {bool isSmall = false}) {
    double length = isSmall ? 40 : 60; // Longer roots

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
        ..strokeWidth = 3;

      // Small root branches
      for (int i = 0; i < 3; i++) {
        double branchAngle = (i - 1) * 0.5;
        double branchLength = 20;
        double branchStartX = endX - direction.dx * 15;
        double branchStartY = endY - direction.dy * 15;

        canvas.drawLine(
          Offset(branchStartX, branchStartY),
          Offset(
              branchStartX + branchLength * math.cos(branchAngle),
              branchStartY + branchLength * math.sin(branchAngle) + 8
          ),
          branchPaint,
        );
      }
    }
  }

  void _drawBronzeTree(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw bronze-style trunk
    _drawBronzeTrunk(canvas, size, centerX, groundY);

    // Draw bronze-style branches
    _drawBronzeBranches(canvas, size, centerX, groundY);
  }

  void _drawBronzeTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint trunkPaint = Paint()
      ..color = Color(0xFF8B4513) // Classic bronze brown
      ..style = PaintingStyle.fill;

    double trunkHeight = size.height * 0.5; // Taller trunk
    double trunkBase = groundY;
    double trunkTop = groundY - trunkHeight;

    // Create straight trunk shape with bronze coloring
    final Path trunkPath = Path();

    double baseWidth = 30; // Wider trunk
    double topWidth = 24;

    // Create trunk with bronze characteristics
    trunkPath.moveTo(centerX - baseWidth/2, trunkBase);
    trunkPath.lineTo(centerX - topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + topWidth/2, trunkTop);
    trunkPath.lineTo(centerX + baseWidth/2, trunkBase);
    trunkPath.close();

    canvas.drawPath(trunkPath, trunkPaint);

    // Add bronze bark texture
    _drawBronzeBarkTexture(canvas, centerX, groundY, trunkHeight, baseWidth, topWidth);
  }

  void _drawBronzeBarkTexture(Canvas canvas, double centerX, double groundY, double trunkHeight, double baseWidth, double topWidth) {
    // Bronze-style bark lines
    final Paint darkBarkPaint = Paint()
      ..color = Color(0xFF5D4037) // Dark bronze
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final Paint lightBarkPaint = Paint()
      ..color = Color(0xFFA0522D) // Light bronze
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Main vertical bark ridges with bronze characteristics
    for (int i = 0; i < 10; i++) {
      double x = centerX - 15 + (i * 3.5);
      double topY = groundY - trunkHeight + 20;
      double bottomY = groundY - 8;

      // Create organic bronze bark lines
      Path barkLine = Path();
      barkLine.moveTo(x, bottomY);

      int segments = 15;
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 2.5 * math.sin(j * 0.9 + i * 0.6) * (1 - j/segments);
        barkLine.lineTo(x + offset, segmentY);
      }

      canvas.drawPath(barkLine, darkBarkPaint);

      // Add lighter bronze lines
      Path lightLine = Path();
      lightLine.moveTo(x + 2, bottomY);
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 2 * math.sin(j * 0.7 + i * 0.4) * (1 - j/segments);
        lightLine.lineTo(x + 2 + offset, segmentY);
      }
      canvas.drawPath(lightLine, lightBarkPaint);
    }

    // Bronze bark texture rings
    final Paint ringPaint = Paint()
      ..color = Color(0xFF654321) // Bronze ring color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 12; i++) {
      double y = groundY - (trunkHeight * 0.08 * i) - 20;
      double width = baseWidth - (baseWidth - topWidth) * (i / 12.0);

      // Create bronze bark rings
      Path ringPath = Path();
      ringPath.moveTo(centerX - width/2 + 3, y);

      int ringSegments = 20;
      for (int j = 1; j <= ringSegments; j++) {
        double angle = (j / ringSegments) * math.pi;
        double radius = width/2 - 3;
        double x = centerX + radius * math.cos(angle - math.pi/2);
        double ringY = y + 3 * math.sin(j * 0.5);
        ringPath.lineTo(x, ringY);
      }

      canvas.drawPath(ringPath, ringPaint);
    }
  }

  void _drawBronzeBranches(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.5;
    double trunkTop = groundY - trunkHeight;

    final Paint mainBranchPaint = Paint()
      ..color = Color(0xFF8B4513) // Bronze brown
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw bronze branches based on growth level
    if (growthLevel >= 5) _drawBronzeMainBranches(canvas, centerX, trunkTop, mainBranchPaint);
    if (growthLevel >= 15) _drawBronzeSecondaryBranches(canvas, centerX, trunkTop, mainBranchPaint);
    if (growthLevel >= 25) _drawBronzeDetailBranches(canvas, centerX, trunkTop, mainBranchPaint);
    if (growthLevel >= 35) _drawBronzeFineBranches(canvas, centerX, trunkTop, mainBranchPaint);
  }

  void _drawBronzeMainBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 12; // Thicker main branches

    // Enhanced main bronze branches
    _drawBranchPath(canvas, paint, [
      Offset(centerX - 4, trunkTop + 30),
      Offset(centerX - 25, trunkTop + 8),
      Offset(centerX - 55, trunkTop - 18),
      Offset(centerX - 85, trunkTop - 40),
      Offset(centerX - 110, trunkTop - 50),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX + 4, trunkTop + 25),
      Offset(centerX + 30, trunkTop + 3),
      Offset(centerX + 60, trunkTop - 25),
      Offset(centerX + 90, trunkTop - 40),
      Offset(centerX + 120, trunkTop - 50),
    ]);

    // Upper main branches
    _drawBranchPath(canvas, paint, [
      Offset(centerX - 3, trunkTop + 15),
      Offset(centerX - 20, trunkTop - 18),
      Offset(centerX - 45, trunkTop - 45),
      Offset(centerX - 65, trunkTop - 75),
    ]);

    _drawBranchPath(canvas, paint, [
      Offset(centerX + 3, trunkTop + 8),
      Offset(centerX + 23, trunkTop - 12),
      Offset(centerX + 50, trunkTop - 40),
      Offset(centerX + 70, trunkTop - 70),
    ]);
  }

  void _drawBronzeSecondaryBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 8; // Medium bronze branches

    // Add more secondary branches for fuller look
    List<List<Offset>> secondaryBranches = [
      // Left side enhanced
      [Offset(centerX - 55, trunkTop - 18), Offset(centerX - 75, trunkTop - 28), Offset(centerX - 90, trunkTop - 22)],
      [Offset(centerX - 85, trunkTop - 40), Offset(centerX - 105, trunkTop - 28), Offset(centerX - 125, trunkTop - 35)],
      [Offset(centerX - 110, trunkTop - 50), Offset(centerX - 125, trunkTop - 40), Offset(centerX - 145, trunkTop - 45)],

      // Right side enhanced
      [Offset(centerX + 60, trunkTop - 25), Offset(centerX + 80, trunkTop - 35), Offset(centerX + 100, trunkTop - 28)],
      [Offset(centerX + 90, trunkTop - 40), Offset(centerX + 110, trunkTop - 28), Offset(centerX + 130, trunkTop - 35)],
      [Offset(centerX + 120, trunkTop - 50), Offset(centerX + 140, trunkTop - 40), Offset(centerX + 155, trunkTop - 45)],
    ];

    for (var branch in secondaryBranches) {
      _drawBranchPath(canvas, paint, branch);
    }
  }

  void _drawBronzeDetailBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 5; // Bronze detail branches

    // Enhanced detail branches for fuller appearance
    List<List<Offset>> detailBranches = [
      // Left side details
      [Offset(centerX - 75, trunkTop - 28), Offset(centerX - 85, trunkTop - 18), Offset(centerX - 95, trunkTop - 12)],
      [Offset(centerX - 90, trunkTop - 22), Offset(centerX - 100, trunkTop - 15), Offset(centerX - 110, trunkTop - 8)],
      [Offset(centerX - 105, trunkTop - 28), Offset(centerX - 115, trunkTop - 38), Offset(centerX - 120, trunkTop - 48)],

      // Right side details
      [Offset(centerX + 80, trunkTop - 35), Offset(centerX + 90, trunkTop - 25), Offset(centerX + 100, trunkTop - 18)],
      [Offset(centerX + 100, trunkTop - 28), Offset(centerX + 110, trunkTop - 18), Offset(centerX + 120, trunkTop - 12)],
      [Offset(centerX + 110, trunkTop - 28), Offset(centerX + 120, trunkTop - 38), Offset(centerX + 130, trunkTop - 48)],
    ];

    for (var branch in detailBranches) {
      _drawBranchPath(canvas, paint, branch);
    }
  }

  void _drawBronzeFineBranches(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 3; // Fine bronze branches

    // Generate fine branches based on growth level
    List<Offset> endpoints = [
      Offset(centerX - 95, trunkTop - 12), Offset(centerX - 110, trunkTop - 8), Offset(centerX - 120, trunkTop - 48),
      Offset(centerX - 145, trunkTop - 28), Offset(centerX - 135, trunkTop - 25), Offset(centerX + 100, trunkTop - 18),
      Offset(centerX + 120, trunkTop - 12), Offset(centerX + 130, trunkTop - 48), Offset(centerX + 155, trunkTop - 28),
    ];

    for (int i = 0; i < endpoints.length && i < (growthLevel - 30); i++) {
      if (i >= 0) {
        Offset endpoint = endpoints[i];

        // Draw 3-4 small twigs from each endpoint
        for (int j = 0; j < 4; j++) {
          double angle = (j - 1.5) * 0.5 + (i * 0.12);
          double length = 15 + j * 4;

          Offset twigEnd = Offset(
            endpoint.dx + length * math.cos(angle),
            endpoint.dy + length * math.sin(angle) - 10,
          );

          canvas.drawLine(endpoint, twigEnd, paint);
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

    List<Offset> allEndpoints = [
      // Left side branch endpoints
      Offset(centerX - 95, trunkTop - 12), Offset(centerX - 110, trunkTop - 8), Offset(centerX - 120, trunkTop - 48),
      Offset(centerX - 145, trunkTop - 28), Offset(centerX - 135, trunkTop - 25), Offset(centerX - 65, trunkTop - 75),

      // Right side branch endpoints
      Offset(centerX + 100, trunkTop - 18), Offset(centerX + 120, trunkTop - 12), Offset(centerX + 130, trunkTop - 48),
      Offset(centerX + 155, trunkTop - 28), Offset(centerX + 140, trunkTop - 40), Offset(centerX + 70, trunkTop - 70),
    ];

    for (int i = 0; i < allEndpoints.length && i < 25; i++) {
      Offset point = allEndpoints[i];
      double angle = math.atan2(point.dy - trunkTop, point.dx - centerX);
      endpoints.add(BranchPoint(point.dx, point.dy, angle));
    }

    return endpoints;
  }

  void _drawLeavesOnBranches(Canvas canvas, Size size, double centerX, double groundY) {
    if (growthLevel <= 10) return; // Start showing leaves after basic growth

    double trunkHeight = size.height * 0.5;
    double trunkTop = groundY - trunkHeight;

    List<BranchPoint> branchEndpoints = _getBranchEndpoints(centerX, trunkTop);

    // Draw bronze leaves based on growth level
    int leavesToShow = math.min(growthLevel - 10, branchEndpoints.length);
    for (int i = 0; i < leavesToShow; i++) {
      BranchPoint point = branchEndpoints[i];
      _drawBronzeLeafAtPoint(canvas, point, i);
    }
  }

  void _drawBronzeLeafAtPoint(Canvas canvas, BranchPoint point, int index) {
    canvas.save();
    canvas.translate(point.x, point.y);
    canvas.scale(leafScale);

    // Bronze-themed leaf colors
    Color leafColor = index % 6 == 0 ? Color(0xFF228B22) : // Forest green
    index % 6 == 1 ? Color(0xFF32CD32) : // Lime green
    index % 6 == 2 ? Color(0xFF90EE90) : // Light green
    index % 6 == 3 ? Color(0xFF006400) : // Dark green
    index % 6 == 4 ? Color(0xFF9ACD32) : // Yellow green
    Color(0xFF8FBC8F); // Dark sea green

    Paint leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    double leafSize = 11 + (index % 5) * 2; // Slightly bigger leaves

    // Draw bronze-style leaf shape
    Path leafPath = Path();
    leafPath.moveTo(0, -leafSize);
    leafPath.quadraticBezierTo(leafSize * 0.9, -leafSize * 0.6, leafSize * 0.5, 0);
    leafPath.quadraticBezierTo(leafSize * 0.7, leafSize * 0.4, 0, leafSize * 0.5);
    leafPath.quadraticBezierTo(-leafSize * 0.7, leafSize * 0.4, -leafSize * 0.5, 0);
    leafPath.quadraticBezierTo(-leafSize * 0.9, -leafSize * 0.6, 0, -leafSize);

    canvas.drawPath(leafPath, leafPaint);

    // Add bronze-style leaf veins
    Paint veinPaint = Paint()
      ..color = Color(0xFF004225) // Dark green veins
      ..strokeWidth = 1.4;

    // Main center vein
    canvas.drawLine(
      Offset(0, -leafSize * 0.95),
      Offset(0, leafSize * 0.4),
      veinPaint,
    );

    canvas.restore();
  }

  void _drawBronzeFlower(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.5;
    double trunkTop = groundY - trunkHeight;
    double flowerCenterX = centerX + 18;
    double flowerCenterY = trunkTop - 90;

    // Bronze flower center
    final Paint centerPaint = Paint()
      ..color = Color(0xFFCD7F32) // Bronze color
      ..style = PaintingStyle.fill;

    // Bronze flower petals
    final Paint petalPaint = Paint()
      ..color = Color(0xFFDAA520) // Golden rod (bronze-gold)
      ..style = PaintingStyle.fill;

    final Paint petalOutlinePaint = Paint()
      ..color = Color(0xFFB8860B) // Dark golden rod
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw bronze petals with blooming animation
    for (int i = 0; i < 8; i++) {
      double angle = (i * 2 * math.pi / 8) + flowerRotation * 0.1;
      double petalLength = 22 * flowerBloom;
      double petalWidth = 16 * flowerBloom;

      canvas.save();
      canvas.translate(flowerCenterX, flowerCenterY);
      canvas.rotate(angle);

      // Draw bronze petal shape
      final Path petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(petalWidth/2, -petalLength/3, petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(0, -petalLength * 0.8, -petalWidth/3, -petalLength);
      petalPath.quadraticBezierTo(-petalWidth/2, -petalLength/3, 0, 0);

      canvas.drawPath(petalPath, petalPaint);
      canvas.drawPath(petalPath, petalOutlinePaint);
      canvas.restore();
    }

    // Draw bronze flower center
    canvas.drawCircle(Offset(flowerCenterX, flowerCenterY), 12 * flowerBloom, centerPaint);

    // Inner bronze center detail
    canvas.drawCircle(
        Offset(flowerCenterX, flowerCenterY),
        8 * flowerBloom,
        Paint()
          ..color = Color(0xFFB8860B) // Dark golden rod
          ..style = PaintingStyle.fill
    );

    // Add bronze sparkle effect when fully bloomed
    if (flowerBloom > 0.8) {
      _drawBronzeSparkles(canvas, flowerCenterX, flowerCenterY);
    }
  }

  void _drawBronzeSparkles(Canvas canvas, double centerX, double centerY) {
    final Paint sparklePaint = Paint()
      ..color = Color(0xFFDAA520) // Golden rod sparkles
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      double angle = i * math.pi / 3 + flowerRotation;
      double distance = 35 + 6 * math.sin(flowerRotation * 2);
      double x = centerX + distance * math.cos(angle);
      double y = centerY + distance * math.sin(angle);

      // Draw bronze sparkle stars
      canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), sparklePaint);
      canvas.drawLine(Offset(x, y - 5), Offset(x, y + 5), sparklePaint);

      // Add diagonal lines for star effect
      canvas.drawLine(Offset(x - 4, y - 4), Offset(x + 4, y + 4), sparklePaint);
      canvas.drawLine(Offset(x - 4, y + 4), Offset(x + 4, y - 4), sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is BronzeTreePainter &&
        (oldDelegate.growthLevel != growthLevel ||
            oldDelegate.totalGrowth != totalGrowth ||
            oldDelegate.flowerBloom != flowerBloom ||
            oldDelegate.flowerRotation != flowerRotation ||
            oldDelegate.leafScale != leafScale);
  }
}