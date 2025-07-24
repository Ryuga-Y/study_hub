import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'webrtc_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class VideoCallScreen extends StatefulWidget {
  final String contactName;
  final String? contactAvatar;
  final String? callId;
  final bool isIncoming;
  final String? targetUserId;

  const VideoCallScreen({
    Key? key,
    required this.contactName,
    this.contactAvatar,
    this.callId,
    this.isIncoming = false,
    this.targetUserId,
  }) : super(key: key);

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webRTCService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  // ✅ ADD THIS LINE
  StreamSubscription? _callStatusMonitor;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isConnected = false;
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      // Request permissions first and check if granted
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        print('❌ Permissions not granted');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                'Camera and microphone permissions are required')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Initialize renderers
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      _webRTCService.onLocalStream = (stream) {
        if (mounted && stream != null) {
          setState(() {
            _localRenderer.srcObject = stream;
          });
          print('✅ Local video stream connected in UI');
        }
      };

      _webRTCService.onRemoteStream = (stream) {
        if (mounted) {
          setState(() {
            _remoteRenderer.srcObject = stream;
            _isConnected = true;
            _isConnecting = false;
          });
          print('✅ Remote video stream connected in UI');
        }
      };

      _webRTCService.onCallEnd = () {
        Navigator.pop(context);
      };

      // ADD THIS: Monitor call status in Firebase
      if (widget.callId != null) {
        _monitorCallStatus();
      }

      // Start or answer call
      if (widget.isIncoming && widget.callId != null) {
        await _webRTCService.answerCall(widget.callId!);
      } else if (widget.targetUserId != null) {
        await _webRTCService.startCall(
            widget.targetUserId!, widget.contactName);
      }

      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      print('❌ Error initializing call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize call: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _monitorCallStatus() {
    _callStatusMonitor?.cancel(); // Cancel any existing subscription

    _callStatusMonitor = FirebaseFirestore.instance
        .collection('videoCalls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'calling';

        print('📞 Video call status: $status');

        if (status == 'ended' || status == 'declined') {
          if (mounted) {
            Navigator.pop(context);
          }
        } else if (status == 'answered') {
          if (mounted) {
            setState(() {
              _isConnecting = false;
            });
          }
        }
      }
    });
  }

    Future<bool> _requestPermissions() async {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
        // Open app settings if permanently denied
        openAppSettings();
        return false;
      }

      return cameraStatus.isGranted && micStatus.isGranted;
    }

    @override
    void dispose() {
      // Cancel monitoring first
      _callStatusMonitor?.cancel();

      // Dispose service before renderers
      _webRTCService.dispose();

      // Dispose renderers synchronously
      try {
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
        _localRenderer.dispose();
        _remoteRenderer.dispose();
      } catch (e) {
        print('Error disposing renderers: $e');
      }

      super.dispose();
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          _isConnected
              ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              : _buildWaitingScreen(),

          // Local video (small overlay)
          if (_isConnected)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),
            ),

          // Call controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildCallControls(),
          ),

          // Top info bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: widget.contactAvatar != null
                ? CachedNetworkImageProvider(widget.contactAvatar!)
                : null,
            child: widget.contactAvatar == null
                ? Text(widget.contactName[0], style: TextStyle(fontSize: 40))
                : null,
          ),
          SizedBox(height: 20),
          Text(
            widget.contactName,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            _isConnecting ? 'Connecting...' : (widget.isIncoming ? 'Incoming call' : 'Ringing...'),
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (!widget.isIncoming && !_isConnected) ...[
            SizedBox(height: 20),
            Text(
              'Calling ${widget.contactName}...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
          if (_isConnecting) ...[
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.videocam, color: Colors.white),
            SizedBox(width: 8),
            Text(
              widget.contactName,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _isConnected ? 'Connected' : 'Connecting',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCallControl(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            onPressed: () {
              setState(() => _isMuted = !_isMuted);
              _webRTCService.toggleMute();
            },
            backgroundColor: _isMuted ? Colors.red : Colors.white24,
          ),
          _buildCallControl(
            icon: Icons.call_end,
            onPressed: () async {
              print('📞 User pressed end call button');
              await _webRTCService.endCall();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            backgroundColor: Colors.red,
          ),
          _buildCallControl(
            icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
            onPressed: () {
              setState(() => _isVideoOff = !_isVideoOff);
              _webRTCService.toggleCamera();
            },
            backgroundColor: _isVideoOff ? Colors.red : Colors.white24,
          ),
          _buildCallControl(
            icon: Icons.flip_camera_ios,
            onPressed: () => _webRTCService.switchCamera(),
            backgroundColor: Colors.white24,
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