import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'webrtc_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

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
  // ADD THESE LINES AFTER OTHER VARIABLES
  DateTime? _callStartTime;
  Duration _callDuration = Duration.zero;
  final WebRTCService _webRTCService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  // ✅ ADD THIS LINE
  StreamSubscription? _callStatusMonitor;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isConnected = false;
  bool _isConnecting = true;
  Timer? _callTimer;

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

      // Initialize renderers with error handling
      try {
        // Initialize with explicit configuration to avoid graphics buffer issues
        await _localRenderer.initialize();
        await _remoteRenderer.initialize();
      } catch (e) {
        print('❌ Video renderer initialization failed: $e');
        // Try with software rendering fallback
        await Future.delayed(Duration(milliseconds: 500));
        try {
          // Force software rendering to avoid hardware buffer allocation issues
          await _localRenderer.initialize();
          await _remoteRenderer.initialize();
        } catch (e2) {
          print('❌ Video renderer retry failed: $e2');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Video rendering not supported on this device')),
            );
          }
        }
      }

      _webRTCService.onLocalStream = (stream) {
        if (mounted && stream != null) {
          // Use post-frame callback to avoid frame timing issues
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _localRenderer.srcObject = stream;
              });
              print('✅ Local video stream connected in UI');
            }
          });
        }
      };

      _webRTCService.onRemoteStream = (stream) {
        if (mounted) {
          // Use post-frame callback to avoid frame timing issues
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _remoteRenderer.srcObject = stream;
                _isConnected = true;
                _isConnecting = false;
                _callStartTime = DateTime.now(); // Start timing when actually connected
              });
              print('✅ Remote video stream connected in UI');
              _startCallTimer();
            }
          });
        }
      };
      _webRTCService.onCallEnd = () async {
        // Send call record if call was connected
        if (_isConnected && _callStartTime != null) {
          _callDuration = DateTime.now().difference(_callStartTime!);
          await _sendCallRecord();
        }
        if (mounted) {
          Navigator.pop(context);
        }
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

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && _isConnected && _callStartTime != null) {
        setState(() {
          _callDuration = DateTime.now().difference(_callStartTime!);
        });
      } else if (!_isConnected) {
        // Stop timer if connection lost
        timer.cancel();
      }
    });
  }

  void _monitorCallStatus() {
    _callStatusMonitor?.cancel();

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
          _callStatusMonitor?.cancel();
          _callStatusMonitor = null;

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
      } else {
        // Document deleted - call ended
        _callStatusMonitor?.cancel();
        _callStatusMonitor = null;

        if (mounted) {
          Navigator.pop(context);
        }
      }
    }, onError: (error) {
      print('Error monitoring call status: $error');
      if (mounted) {
        _callStatusMonitor?.cancel();
        Navigator.pop(context);
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
    _callTimer?.cancel();

    // Ensure call is marked as ended in Firebase
    if (widget.callId != null) {
      FirebaseFirestore.instance.collection('videoCalls').doc(widget.callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      }).catchError((e) => print('Error updating call status on dispose: $e'));
    }

    // Clear callbacks to prevent accessing disposed context
    _webRTCService.onCallEnd = null;
    _webRTCService.onLocalStream = null;
    _webRTCService.onRemoteStream = null;

    Future.delayed(Duration(milliseconds: 100), () {
      _webRTCService.cleanup(); // Use cleanup instead of dispose
    });

    // Dispose service before renderers
    _webRTCService.dispose();

    // Dispose renderers with proper cleanup
    try {
      // Clear video sources first
      if (_localRenderer.srcObject != null) {
        _localRenderer.srcObject = null;
      }
      if (_remoteRenderer.srcObject != null) {
        _remoteRenderer.srcObject = null;
      }

      // Add delay to ensure resources are released
      Future.delayed(Duration(milliseconds: 100), () async {
        try {
          await _localRenderer.dispose();
          await _remoteRenderer.dispose();
        } catch (e) {
          print('Error disposing renderers: $e');
        }
      });
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
          // Remote video (full screen)
          // Remote video (full screen)
          _isConnected
              ? Container(
            child: RepaintBoundary(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: false,
                filterQuality: FilterQuality.low,
              ),
            ),
          )
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
                  child: RepaintBoundary(
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
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
        child: Column(
          children: [
            Row(
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
            if (_isConnected && _callStartTime != null) ...[
              SizedBox(height: 8),
              Text(
                _formatCallDuration(_callDuration),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCallDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "$hours:$minutes:$seconds";
    } else {
      return "$minutes:$seconds";
    }
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

              // Calculate call duration
              if (_callStartTime != null) {
                _callDuration = DateTime.now().difference(_callStartTime!);
              }

              // Cancel monitoring first to prevent race conditions
              _callStatusMonitor?.cancel();

              // Set callback to null to prevent double navigation
              _webRTCService.onCallEnd = null;

              // Send call record to chat BEFORE ending call
              await _sendCallRecord();

              // End the call
              await _webRTCService.endCall();

              // Force close the screen
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

  Future<void> _sendCallRecord() async {
    // Only send call record if we have target user and call was connected
    if (widget.targetUserId == null || !_isConnected) return;

    // Ensure minimum duration of 1 second for display
    if (_callDuration.inSeconds < 1) {
      _callDuration = Duration(seconds: 1);
    }

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Generate chat ID
      final chatId = _generateChatId(currentUserId, widget.targetUserId!);

      // Format duration - make it more user-friendly
      String durationText;
      if (_callDuration.inHours > 0) {
        durationText = '${_callDuration.inHours}h ${_callDuration.inMinutes.remainder(60)}m';
      } else if (_callDuration.inMinutes > 0) {
        durationText = '${_callDuration.inMinutes} mins';
      } else {
        durationText = '${_callDuration.inSeconds}s';
      }

      // Create call record message
      // Create call record message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': 'Video call\n$durationText',
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'call_record',
        'callDuration': _callDuration.inSeconds,
      });

// Update chat last message
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'lastMessage': 'Video call ($durationText)',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.${widget.targetUserId}': FieldValue.increment(1),
      });

      print('✅ Call record sent: $durationText');

    } catch (e) {
      print('Error sending call record: $e');
    }
  }

  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }
}