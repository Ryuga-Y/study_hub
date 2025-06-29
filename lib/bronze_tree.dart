import 'package:flutter/material.dart';
import 'dart:math' as math;

/*
 * USAGE: To add a leaf with animation when user presses water button:
 *
 * 1. Increment growthLevel by 1
 * 2. Set newestLeafIndex to (growthLevel - 1)
 * 3. Start animation with newLeafAnimationProgress from 0.0 to 1.0 over 3 seconds
 *
 * Example:
 * setState(() {
 *   growthLevel++; // Add one leaf
 *   newestLeafIndex = growthLevel - 1; // Track newest leaf
 *   newLeafAnimationProgress = 0.0; // Reset animation
 * });
 *
 * // Start 3-second animation timer
 * AnimationController controller = AnimationController(
 *   duration: Duration(seconds: 3),
 *   vsync: this,
 * );
 * controller.addListener(() {
 *   setState(() {
 *     newLeafAnimationProgress = controller.value;
 *   });
 * });
 * controller.forward();
 */

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
  final int? newestLeafIndex; // Track which leaf was just added
  final double newLeafAnimationProgress; // Animation progress for newest leaf (0.0 to 1.0)

  BronzeTreePainter({
    required this.growthLevel,
    required this.totalGrowth,
    required this.flowerBloom,
    required this.flowerRotation,
    required this.leafScale,
    this.newestLeafIndex,
    this.newLeafAnimationProgress = 0.0, // Default value to prevent errors
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double groundY = size.height * 0.85;

    // Draw soil and ground with bronze tint
    _drawBronzeSoilAndGround(canvas, size, centerX, groundY);

    // Draw tree roots with bronze colors
    _drawBronzeTreeRoots(canvas, size, centerX, groundY);

    // Draw the realistic tree trunk and branches with bronze colors
    _drawBronzeRealisticTree(canvas, size, centerX, groundY);

    // Draw leaves on branch endpoints
    _drawLeavesOnBranches(canvas, size, centerX, groundY);

    // Draw bronze flowers if 100% complete
    if (totalGrowth >= 1.0) {
      _drawMultipleBronzeFlowers(canvas, size, centerX, groundY);
    }
  }

  void _drawBronzeSoilAndGround(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw ground line with bronze tint first
    final Paint groundPaint = Paint()
      ..color = Color(0xFFA0522D) // Bronze-tinted brown
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      groundPaint,
    );

    // Add underbrush instead of grass
    _drawUnderbrush(canvas, size, groundY);

    // Draw soil mound BELOW the ground line
    final Paint soilPaint = Paint()
      ..color = Color(0xFF8B4513) // Bronze-tinted brown
      ..style = PaintingStyle.fill;

    final Path soilPath = Path();
    double soilWidth = 120;
    double soilHeight = 25;

    // Create a rounded soil mound below the ground line
    soilPath.moveTo(centerX - soilWidth/2, groundY);
    soilPath.quadraticBezierTo(
        centerX - soilWidth/3, groundY + soilHeight,
        centerX, groundY + soilHeight/2
    );
    soilPath.quadraticBezierTo(
        centerX + soilWidth/3, groundY + soilHeight,
        centerX + soilWidth/2, groundY
    );
    soilPath.lineTo(centerX + soilWidth/2, groundY + soilHeight + 10);
    soilPath.lineTo(centerX - soilWidth/2, groundY + soilHeight + 10);
    soilPath.close();

    canvas.drawPath(soilPath, soilPaint);

    // Add bronze-tinted soil texture below ground line
    final Paint soilTexturePaint = Paint()
      ..color = Color(0xFF654321) // Dark bronze
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      double x = centerX - soilWidth/3 + (i * 10);
      double y = groundY + 5 + (i % 3) * 3; // Below ground line
      canvas.drawCircle(Offset(x, y), 2, soilTexturePaint);
    }
  }

  void _drawUnderbrush(Canvas canvas, Size size, double groundY) {
    // Draw 2 underbrush at the most left and right
    _drawSingleUnderbrush(canvas, size.width * 0.1, groundY, true); // Left underbrush
    _drawSingleUnderbrush(canvas, size.width * 0.9, groundY, false); // Right underbrush
  }

  void _drawSingleUnderbrush(Canvas canvas, double centerX, double groundY, bool isLeft) {
    // Pixelated 8-bit style underbrush colors
    final List<Paint> pixelPaints = [
      Paint()..color = Color(0xFF1B5E20)..style = PaintingStyle.fill, // Very dark green
      Paint()..color = Color(0xFF2E7D32)..style = PaintingStyle.fill, // Dark green
      Paint()..color = Color(0xFF388E3C)..style = PaintingStyle.fill, // Medium dark green
      Paint()..color = Color(0xFF4CAF50)..style = PaintingStyle.fill, // Medium green
      Paint()..color = Color(0xFF66BB6A)..style = PaintingStyle.fill, // Light green
      Paint()..color = Color(0xFF81C784)..style = PaintingStyle.fill, // Lighter green
      Paint()..color = Color(0xFF8BC34A)..style = PaintingStyle.fill, // Yellow green
      Paint()..color = Color(0xFF9CCC65)..style = PaintingStyle.fill, // Light yellow green
    ];

    double pixelSize = 8.0; // Size of each pixel block
    double bushStartX = centerX - 60; // Start position for bush
    double bushStartY = groundY - 40; // Start height for bush

    // Define the pixelated bush pattern (similar to your image)
    List<List<int>> bushPattern = [
      // Bottom row (row 0)
      [0, 0, 1, 1, 2, 2, 3, 3, 4, 3, 2, 1, 0, 0, 0],
      // Row 1
      [0, 1, 1, 2, 3, 4, 5, 4, 5, 4, 3, 2, 1, 0, 0],
      // Row 2
      [1, 2, 3, 4, 5, 6, 5, 6, 5, 6, 4, 3, 2, 1, 0],
      // Row 3
      [0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1, 0],
      // Row 4 (top)
      [0, 0, 1, 2, 3, 4, 5, 4, 5, 4, 3, 2, 1, 0, 0],
    ];

    // Draw the pixelated bush
    for (int row = 0; row < bushPattern.length; row++) {
      for (int col = 0; col < bushPattern[row].length; col++) {
        int colorIndex = bushPattern[row][col];
        if (colorIndex >= 0 && colorIndex < pixelPaints.length) {
          double x = bushStartX + (col * pixelSize);
          double y = bushStartY + (row * pixelSize);

          // Draw the pixel block
          canvas.drawRect(
            Rect.fromLTWH(x, y, pixelSize, pixelSize),
            pixelPaints[colorIndex],
          );

          // Add subtle pixel borders for more authentic 8-bit look
          if (colorIndex < pixelPaints.length - 1) {
            Paint borderPaint = Paint()
              ..color = pixelPaints[colorIndex + 1].color.withOpacity(0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5;
            canvas.drawRect(
              Rect.fromLTWH(x, y, pixelSize, pixelSize),
              borderPaint,
            );
          }
        }
      }
    }

    // Add some random scattered pixels for variety
    final math.Random random = math.Random(isLeft ? 42 : 84); // Fixed seed for consistent pattern
    for (int i = 0; i < 12; i++) {
      double x = bushStartX - 20 + (random.nextDouble() * 140);
      double y = bushStartY + 5 + (random.nextDouble() * 15);
      int colorIndex = random.nextInt(4) + 2; // Use medium to light greens

      canvas.drawRect(
        Rect.fromLTWH(x, y, pixelSize * 0.7, pixelSize * 0.7),
        pixelPaints[colorIndex],
      );
    }
  }

  void _drawBronzeTreeRoots(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint rootPaint = Paint()
      ..color = Color(0xFF5D4037) // Dark bronze brown
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

  void _drawBronzeRealisticTree(Canvas canvas, Size size, double centerX, double groundY) {
    // Draw trunk with bronze colors using realistic design
    _drawBronzeImageStyleTrunk(canvas, size, centerX, groundY);

    // Draw branches with bronze colors using realistic design
    _drawBronzeImageStyleBranches(canvas, size, centerX, groundY);
  }

  void _drawBronzeImageStyleTrunk(Canvas canvas, Size size, double centerX, double groundY) {
    final Paint trunkPaint = Paint()
      ..color = Color(0xFF8B4513) // Bronze brown
      ..style = PaintingStyle.fill;

    double trunkHeight = size.height * 0.48;
    double trunkBase = groundY;
    double trunkTop = groundY - trunkHeight;

    // Create straight trunk shape - same as code 2 but bronze colors
    final Path trunkPath = Path();

    double baseWidth = 25;
    double topWidth = 20;

    // Create simple straight trunk
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
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint lightBarkPaint = Paint()
      ..color = Color(0xFFA0522D) // Light bronze
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Main vertical bark ridges with bronze characteristics
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

      // Add lighter bronze lines
      Path lightLine = Path();
      lightLine.moveTo(x + 1.5, bottomY);
      for (int j = 1; j <= segments; j++) {
        double segmentY = bottomY - (bottomY - topY) * (j / segments);
        double offset = 1.5 * math.sin(j * 0.6 + i * 0.3) * (1 - j/segments);
        lightLine.lineTo(x + 1.5 + offset, segmentY);
      }
      canvas.drawPath(lightLine, lightBarkPaint);
    }

    // Bronze bark texture rings
    final Paint ringPaint = Paint()
      ..color = Color(0xFF654321) // Bronze ring color
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

    // Add bronze bark texture patches
    final Paint patchPaint = Paint()
      ..color = Color(0xFF8B7355) // Light bronze
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

  void _drawBronzeImageStyleBranches(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.48;
    double trunkTop = groundY - trunkHeight;

    final Paint mainBranchPaint = Paint()
      ..color = Color(0xFF8B4513) // Bronze brown
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw branches in layers like code 2 but with bronze colors
    _drawMainBranchLayer(canvas, centerX, trunkTop, mainBranchPaint);
    _drawSecondaryBranchLayer(canvas, centerX, trunkTop, mainBranchPaint);
    _drawDetailBranchLayer(canvas, centerX, trunkTop, mainBranchPaint);
    _drawFineBranchLayer(canvas, centerX, trunkTop, mainBranchPaint);
  }

  void _drawMainBranchLayer(Canvas canvas, double centerX, double trunkTop, Paint paint) {
    paint.strokeWidth = 10; // Thick main branches

    // Main left branch system - same structure as code 2
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

    // Secondary branches from main left branch - same structure as code 2
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

    // Add many small branches throughout the tree - same structure as code 2
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

    // Generate many fine branches at the endpoints - same structure as code 2
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

    // Generate endpoints based on the realistic tree structure with spacing
    List<Offset> allEndpoints = [
      // Left side branch endpoints - spaced out more
      Offset(centerX - 80, trunkTop - 10),
      Offset(centerX - 95, trunkTop - 25), // Changed from -10 to avoid overlap
      Offset(centerX - 105, trunkTop - 45),
      Offset(centerX - 130, trunkTop - 35), // Changed from -25 to avoid overlap
      Offset(centerX - 120, trunkTop - 55), // Changed from -40 to avoid overlap
      Offset(centerX - 30, trunkTop - 75),
      Offset(centerX - 55, trunkTop - 90),
      Offset(centerX - 40, trunkTop - 105), // Changed from -30, -95 to avoid overlap
      Offset(centerX - 70, trunkTop - 105), // Changed from -90 to avoid overlap
      Offset(centerX - 100, trunkTop - 50), // Changed from -35 to avoid overlap
      Offset(centerX - 85, trunkTop - 30), // Changed from -15 to avoid overlap
      Offset(centerX - 25, trunkTop - 95), // Changed from -85 to avoid overlap

      // Right side branch endpoints - spaced out more
      Offset(centerX + 85, trunkTop - 15),
      Offset(centerX + 105, trunkTop - 30), // Changed from -10 to avoid overlap
      Offset(centerX + 115, trunkTop - 45),
      Offset(centerX + 135, trunkTop - 40), // Changed from -25 to avoid overlap
      Offset(centerX + 125, trunkTop - 60), // Changed from -20 to avoid overlap
      Offset(centerX + 35, trunkTop - 70),
      Offset(centerX + 60, trunkTop - 85),
      Offset(centerX + 43, trunkTop - 110), // Changed from 33, -100 to avoid overlap
      Offset(centerX + 75, trunkTop - 100), // Changed from -85 to avoid overlap
      Offset(centerX + 100, trunkTop - 55), // Changed from -35 to avoid overlap
      Offset(centerX + 90, trunkTop - 35), // Changed from -15 to avoid overlap
      Offset(centerX + 28, trunkTop - 105), // Changed from -90 to avoid overlap

      // Additional scattered endpoints for full coverage - well spaced
      Offset(centerX - 65, trunkTop - 65), // New position
      Offset(centerX + 65, trunkTop - 65), // New position
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
      bool isNewestLeaf = newestLeafIndex == i;
      _drawBronzeLeafAtPoint(canvas, point, i, isNewestLeaf);
    }
  }

  void _drawBronzeLeafAtPoint(Canvas canvas, BranchPoint point, int index, bool isNewestLeaf) {
    canvas.save();
    canvas.translate(point.x, point.y);
    canvas.scale(leafScale); // Apply leaf scale animation

    // Draw animation highlight for newest leaf
    if (isNewestLeaf && newLeafAnimationProgress > 0) {
      _drawNewLeafAnimation(canvas);
    }

    // Bronze-themed leaf colors - same variety as before
    Color leafColor = index % 5 == 0 ? Color(0xFF228B22) : // Forest green
    index % 5 == 1 ? Color(0xFF32CD32) : // Lime green
    index % 5 == 2 ? Color(0xFF90EE90) : // Light green
    index % 5 == 3 ? Color(0xFF006400) : // Dark green
    Color(0xFF9ACD32); // Yellow green

    Paint leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    // BIGGER leaf size - increased by 1.5x from 13 to 19.5
    double leafSize = 19.5; // Uniform bigger leaf size

    // Draw realistic leaf shape - same design as code 2
    Path leafPath = Path();
    leafPath.moveTo(0, -leafSize);
    leafPath.quadraticBezierTo(leafSize * 0.8, -leafSize * 0.5, leafSize * 0.4, 0);
    leafPath.quadraticBezierTo(leafSize * 0.6, leafSize * 0.3, 0, leafSize * 0.4);
    leafPath.quadraticBezierTo(-leafSize * 0.6, leafSize * 0.3, -leafSize * 0.4, 0);
    leafPath.quadraticBezierTo(-leafSize * 0.8, -leafSize * 0.5, 0, -leafSize);

    canvas.drawPath(leafPath, leafPaint);

    // Add realistic leaf veins - same design as code 2
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

  void _drawNewLeafAnimation(Canvas canvas) {
    // Animate for 3 seconds: 0.0 to 1.0 progress
    double animationRadius = 50 * (1.0 - newLeafAnimationProgress); // Larger radius for more visibility
    double opacity = newLeafAnimationProgress < 0.3 ?
    (1.0 - newLeafAnimationProgress * 3.33) :
    (newLeafAnimationProgress - 0.3) / 0.7; // More visible for longer

    // Pulsing circle animation - more prominent
    Paint animationPaint = Paint()
      ..color = Color(0xFFFFD700).withOpacity(opacity * 0.8) // More opaque golden color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6; // Thicker stroke

    canvas.drawCircle(Offset(0, 0), animationRadius, animationPaint);

    // Secondary smaller circle - more prominent
    Paint secondaryPaint = Paint()
      ..color = Color(0xFF32CD32).withOpacity(opacity * 0.6) // More opaque lime green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4; // Thicker stroke

    canvas.drawCircle(Offset(0, 0), animationRadius * 0.6, secondaryPaint);

    // Innermost circle for extra effect
    Paint innerPaint = Paint()
      ..color = Color(0xFFFFFFFF).withOpacity(opacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(0, 0), animationRadius * 0.3, innerPaint);

    // Enhanced sparkling effect
    if (newLeafAnimationProgress < 0.9) {
      Paint sparklePaint = Paint()
        ..color = Color(0xFFFFFFFF).withOpacity(opacity * 1.2)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < 6; i++) {
        double angle = i * math.pi / 3 + newLeafAnimationProgress * math.pi * 3; // Faster rotation
        double sparkleDistance = 35 + 15 * math.sin(newLeafAnimationProgress * math.pi * 6); // More dynamic movement
        double x = sparkleDistance * math.cos(angle);
        double y = sparkleDistance * math.sin(angle);

        // Draw enhanced sparkle star
        canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), sparklePaint);
        canvas.drawLine(Offset(x, y - 5), Offset(x, y + 5), sparklePaint);
        // Add diagonal lines for star effect
        canvas.drawLine(Offset(x - 4, y - 4), Offset(x + 4, y + 4), sparklePaint);
        canvas.drawLine(Offset(x - 4, y + 4), Offset(x + 4, y - 4), sparklePaint);
      }
    }

    // Add floating particles effect
    if (newLeafAnimationProgress < 0.7) {
      Paint particlePaint = Paint()
        ..color = Color(0xFFFFD700).withOpacity(opacity * 0.8)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 8; i++) {
        double angle = i * math.pi / 4 + newLeafAnimationProgress * math.pi * 2;
        double distance = 20 + 25 * newLeafAnimationProgress;
        double x = distance * math.cos(angle);
        double y = distance * math.sin(angle) - 10 * newLeafAnimationProgress; // Float upward

        canvas.drawCircle(Offset(x, y), 2 * (1 - newLeafAnimationProgress), particlePaint);
      }
    }
  }

  void _drawMultipleBronzeFlowers(Canvas canvas, Size size, double centerX, double groundY) {
    double trunkHeight = size.height * 0.48;
    double trunkTop = groundY - trunkHeight;

    // Multiple flower positions
    List<Offset> flowerPositions = [
      Offset(centerX + 15, trunkTop - 80),    // Main flower
      Offset(centerX - 25, trunkTop - 85),    // Left flower
      Offset(centerX + 45, trunkTop - 75),    // Right flower
      Offset(centerX - 5, trunkTop - 95),     // Top center flower
      Offset(centerX + 30, trunkTop - 105),   // Top right flower
    ];

    // Draw each flower with unique rotation
    for (int i = 0; i < flowerPositions.length; i++) {
      double individualRotation = flowerRotation + (i * 0.5); // Each flower rotates at different speed
      _drawBronzeFlowerAtPosition(canvas, flowerPositions[i], individualRotation, i);
    }
  }

  void _drawBronzeFlowerAtPosition(Canvas canvas, Offset position, double rotation, int flowerIndex) {
    double flowerCenterX = position.dx;
    double flowerCenterY = position.dy;

    // Bronze flower center
    final Paint centerPaint = Paint()
      ..color = Color(0xFFCD7F32) // Bronze color
      ..style = PaintingStyle.fill;

    // Bronze flower petals - vary colors slightly for each flower
    Color petalColor = flowerIndex % 3 == 0 ? Color(0xFFDAA520) : // Golden rod
    flowerIndex % 3 == 1 ? Color(0xFFFFD700) : // Gold
    Color(0xFFDEB887); // Burlywood

    final Paint petalPaint = Paint()
      ..color = petalColor
      ..style = PaintingStyle.fill;

    final Paint petalOutlinePaint = Paint()
      ..color = Color(0xFFB8860B) // Dark golden rod
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw bronze petals with blooming and rotation animation
    for (int i = 0; i < 8; i++) {
      double angle = (i * 2 * math.pi / 8) + rotation * 0.1;
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

    // Draw bronze flower center
    canvas.drawCircle(Offset(flowerCenterX, flowerCenterY), 10 * flowerBloom, centerPaint);

    // Inner bronze center detail
    canvas.drawCircle(
        Offset(flowerCenterX, flowerCenterY),
        6 * flowerBloom,
        Paint()
          ..color = Color(0xFFB8860B) // Dark golden rod
          ..style = PaintingStyle.fill
    );

    // Center dots for realism
    final Paint dotPaint = Paint()
      ..color = Color(0xFF5D4037) // Dark bronze
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

    // Add bronze sparkle effect when fully bloomed
    if (flowerBloom > 0.8) {
      _drawBronzeSparklesAtPosition(canvas, flowerCenterX, flowerCenterY, rotation);
    }
  }

  void _drawBronzeSparklesAtPosition(Canvas canvas, double centerX, double centerY, double rotation) {
    final Paint sparklePaint = Paint()
      ..color = Color(0xFFDAA520) // Golden rod sparkles
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      double angle = i * math.pi / 3 + rotation;
      double distance = 30 + 5 * math.sin(rotation * 2);
      double x = centerX + distance * math.cos(angle);
      double y = centerY + distance * math.sin(angle);

      // Draw bronze sparkle stars
      canvas.drawLine(Offset(x - 4, y), Offset(x + 4, y), sparklePaint);
      canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), sparklePaint);

      // Add diagonal lines for star effect
      canvas.drawLine(Offset(x - 3, y - 3), Offset(x + 3, y + 3), sparklePaint);
      canvas.drawLine(Offset(x - 3, y + 3), Offset(x + 3, y - 3), sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is BronzeTreePainter &&
        (oldDelegate.growthLevel != growthLevel ||
            oldDelegate.totalGrowth != totalGrowth ||
            oldDelegate.flowerBloom != flowerBloom ||
            oldDelegate.flowerRotation != flowerRotation ||
            oldDelegate.leafScale != leafScale ||
            oldDelegate.newestLeafIndex != newestLeafIndex ||
            oldDelegate.newLeafAnimationProgress != newLeafAnimationProgress);
  }
}
