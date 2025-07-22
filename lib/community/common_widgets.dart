import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'safeNetworkImage.dart';

// Avatar widgets with online indicator
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final bool isOnline;
  final VoidCallback? onTap;

  const UserAvatar({
    Key? key,
    this.imageUrl,
    this.radius = 20,
    this.isOnline = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[300],
            child: imageUrl != null
                ? ClipOval(
              child: SafeNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                placeholder: Icon(
                  Icons.person,
                  size: radius,
                  color: Colors.grey[600],
                ),
                errorWidget: Icon(
                  Icons.person,
                  size: radius,
                  color: Colors.grey[600],
                ),
              ),
            )
                : Icon(
              Icons.person,
              size: radius,
              color: Colors.grey[600],
            ),
          ),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: radius * 0.35,
                height: radius * 0.35,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Loading indicator
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    required this.child,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    if (message != null) ...[
                      SizedBox(height: 16),
                      Text(
                        message!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Empty state widgets
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.buttonText,
    this.onButtonPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: 12),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (buttonText != null && onButtonPressed != null) ...[
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Custom badge widgets
class CustomBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final EdgeInsets padding;

  const CustomBadge({
    Key? key,
    required this.text,
    this.backgroundColor = Colors.red,
    this.textColor = Colors.white,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Shimmer loading effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    Key? key,
    required this.child,
    required this.isLoading,
  }) : super(key: key);

  @override
  _ShimmerLoadingState createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
              stops: [
                _animation.value - 1,
                _animation.value,
                _animation.value + 1,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// Custom snackbar
class CustomSnackbar {
  static void show({
    required BuildContext context,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final color = _getColorForType(type);
    final icon = _getIconForType(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  static Color _getColorForType(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return Colors.green;
      case SnackbarType.error:
        return Colors.red;
      case SnackbarType.warning:
        return Colors.orange;
      case SnackbarType.info:
      default:
        return Colors.blue;
    }
  }

  static IconData _getIconForType(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return Icons.check_circle;
      case SnackbarType.error:
        return Icons.error;
      case SnackbarType.warning:
        return Icons.warning;
      case SnackbarType.info:
      default:
        return Icons.info;
    }
  }
}

enum SnackbarType { success, error, warning, info }

// Custom dialog
class CustomDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget content;
  final List<Widget>? actions;

  const CustomDialog({
    Key? key,
    required this.title,
    this.subtitle,
    required this.content,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.purple[600],
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(24),
            child: content,
          ),

          // Actions
          if (actions != null && actions!.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24).copyWith(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ),
        ],
      ),
    );
  }
}

// Animated like button
class AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final double size;

  const AnimatedLikeButton({
    Key? key,
    required this.isLiked,
    required this.onTap,
    this.size = 24,
  }) : super(key: key);

  @override
  _AnimatedLikeButtonState createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
    if (widget.isLiked) {
      _controller.forward().then((_) {
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_outline,
              color: widget.isLiked ? Colors.red : Colors.grey[700],
              size: widget.size,
            ),
          );
        },
      ),
    );
  }
}

// Media carousel indicator
class CarouselIndicator extends StatelessWidget {
  final int itemCount;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;

  const CarouselIndicator({
    Key? key,
    required this.itemCount,
    required this.currentIndex,
    this.activeColor = Colors.purple,
    this.inactiveColor = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
            (index) => Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == currentIndex ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }
}

// Privacy selector widgets
class PrivacySelector extends StatelessWidget {
  final String currentPrivacy;
  final Function(String) onChanged;

  const PrivacySelector({
    Key? key,
    required this.currentPrivacy,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButton<String>(
        value: currentPrivacy,
        isDense: true,
        underline: SizedBox(),
        icon: Icon(Icons.arrow_drop_down, size: 20),
        style: TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
        items: [
          DropdownMenuItem(
            value: 'public',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.public, size: 16),
                SizedBox(width: 4),
                Text('Public'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'friends',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 16),
                SizedBox(width: 4),
                Text('Friends'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'private',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 16),
                SizedBox(width: 4),
                Text('Private'),
              ],
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}