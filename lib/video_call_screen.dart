import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoCallScreen extends StatefulWidget {
  final String contactName;
  final String? contactAvatar;

  const VideoCallScreen({
    Key? key,
    required this.contactName,
    this.contactAvatar,
  }) : super(key: key);

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video placeholder
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: widget.contactAvatar != null
                      ? CachedNetworkImageProvider(widget.contactAvatar!)
                      : null,
                  child: widget.contactAvatar == null
                      ? Text(widget.contactName[0],
                      style: TextStyle(fontSize: 40))
                      : null,
                ),
                SizedBox(height: 20),
                Text(
                  widget.contactName,
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
                SizedBox(height: 10),
                Text(
                  'Calling...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),

          // Local video placeholder
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.person,
                  color: Colors.white54,
                  size: 40,
                ),
              ),
            ),
          ),

          // Call controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallControl(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  onPressed: () => setState(() => _isMuted = !_isMuted),
                  backgroundColor: _isMuted ? Colors.red : Colors.white24,
                ),
                _buildCallControl(
                  icon: Icons.call_end,
                  onPressed: () => Navigator.pop(context),
                  backgroundColor: Colors.red,
                ),
                _buildCallControl(
                  icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                  onPressed: () => setState(() => _isVideoOff = !_isVideoOff),
                  backgroundColor: _isVideoOff ? Colors.red : Colors.white24,
                ),
                _buildCallControl(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                  onPressed: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                  backgroundColor: Colors.white24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControl({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
      ),
    );
  }
}