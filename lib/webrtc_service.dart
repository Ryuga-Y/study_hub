import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function()? onCallEnd;

  // Call state
  String? currentCallId;
  bool isInitiator = false;
  bool _isDisposed = false;

  // ✅ ADD THESE LINES
  StreamSubscription? _callStatusSubscription;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _iceCandidatesSubscription;

  Future<void> initializeWebRTC() async {
    try {
      print('🔧 Initializing WebRTC...');

      // Ensure previous connection is closed
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

      // Create peer connection with STUN and TURN servers
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          // Multiple TURN servers for better mobile connectivity
          {
            'urls': 'turn:numb.viagenie.ca',
            'username': 'webrtc@live.com',
            'credential': 'muazkh'
          },
          {
            'urls': 'turn:turn.bistri.com:80',
            'username': 'homeo',
            'credential': 'homeo'
          }
        ],
        'sdpSemantics': 'unified-plan',  // Better for mobile
        'iceCandidatePoolSize': 10,
      });

      // Setup event handlers
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('🧊 New ICE candidate: ${candidate.candidate}');
        _sendIceCandidate(candidate);
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('📺 Remote track received');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams.first;
          onRemoteStream?.call(_remoteStream!);
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('🔗 ICE Connection State: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          print('✅ WebRTC connection established');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          print('❌ WebRTC connection failed');
          // Add delay before ending call to allow reconnection attempts
          Future.delayed(Duration(seconds: 3), () {
            if (!_isDisposed) {
              endCall();
            }
          });
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          print('⚠️ WebRTC connection disconnected - will wait for reconnection');
          // Don't end call immediately - wait for potential reconnection
        }
      };

      // ✅ ADD THIS NEW CALLBACK
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('🔗 Peer Connection State: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          print('✅ Peer connection established successfully');
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          print('❌ Peer connection failed');
          endCall();
        }
      };

      print('✅ WebRTC initialized successfully');

// Configure video rendering to avoid graphics buffer issues
      _configureVideoRendering();
    } catch (e) {
      print('❌ Error initializing WebRTC: $e');
      throw e;
    }
  }

  void _configureVideoRendering() {
    // Configure peer connection for better compatibility
    if (_peerConnection != null) {
      try {
        // Log successful peer connection creation
        print('📹 Video rendering configured for peer connection');
        print('📹 Peer connection state: ${_peerConnection!.connectionState}');
      } catch (error) {
        print('⚠️ Could not configure video rendering: $error');
      }
    }
  }

  Future<void> getUserMedia() async {
    try {
      print('🎥 Getting user media...');

      // Check if already have stream
      if (_localStream != null) {
        print('✅ Already have local stream');
        return;
      }

      final constraints = {
        'audio': {
          'echoCancellation': false,  // Use software-based instead of hardware
          'noiseSuppression': false,  // Use software-based instead of hardware
          'autoGainControl': true,
          'googEchoCancellation': true,     // Google's software implementation
          'googNoiseSuppression': true,     // Google's software implementation
          'googAutoGainControl': true,
          'googHighpassFilter': true,
          'googTypingNoiseDetection': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640, 'max': 1280},
          'height': {'ideal': 480, 'max': 720},
          'frameRate': {'ideal': 24, 'max': 30},
          'aspectRatio': {'ideal': 1.33333},
        }
      };
      try {
        _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      } catch (e) {
        print('⚠️ Failed to get media with full constraints, trying fallback: $e');

        // Try with basic audio constraints
        try {
          final basicConstraints = {
            'audio': true,
            'video': {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          };
          _localStream = await navigator.mediaDevices.getUserMedia(basicConstraints);
        } catch (e2) {
          print('⚠️ Failed to get video, trying audio only: $e2');
          // Fallback to audio only if video fails
          _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
        }
      }
      print('✅ Local stream obtained');

      onLocalStream?.call(_localStream!);

      if (_peerConnection != null && _localStream != null) {
        // Use addTrack for unified-plan
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
        print('✅ Local tracks added to peer connection');
      }
    } catch (e) {
      print('❌ Error getting user media: $e');
      throw e;
    }
  }

  Future<String> startCall(String targetUserId, String targetUserName) async {
    try {
      print('📞 Starting call to $targetUserName ($targetUserId)');

      isInitiator = true;
      currentCallId = Uuid().v4();

      await initializeWebRTC();
      await getUserMedia();

      // Create call document in Firebase
      try {
        await _firestore.collection('videoCalls').doc(currentCallId).set({
          'callId': currentCallId,
          'callerId': _auth.currentUser!.uid,
          'callerName': _auth.currentUser!.displayName ?? 'Unknown',
          'targetId': targetUserId,
          'targetName': targetUserName,
          'status': 'calling',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': DateTime.now().add(Duration(seconds: 60)),
        });
      } catch (e) {
        print('❌ Permission error creating call: $e');
        if (e.toString().contains('permission-denied')) {
          throw Exception('Unable to create call - check Firestore permissions');
        }
        throw e;
      }

      print('✅ Call document created: $currentCallId');

      // Listen for call status changes
      _listenForCallStatus();

      // Listen for answer BEFORE creating offer
      _listenForAnswer();

      // Create offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      print('📤 Created and set local offer');

      // Save offer to Firebase
      await _firestore.collection('videoCalls').doc(currentCallId).update({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        }
      });

      print('✅ Offer saved to Firebase');
      return currentCallId!;
    } catch (e) {
      print('❌ Error starting call: $e');
      throw e;
    }
  }


  Future<void> answerCall(String callId) async {
    try {
      print('📞 Answering call: $callId');

      isInitiator = false;
      currentCallId = callId;

      // Get call data first to check if call is still valid
      DocumentSnapshot callDoc = await _firestore.collection('videoCalls').doc(callId).get();

      if (!callDoc.exists) {
        print('❌ Call document does not exist');
        throw Exception('Call no longer exists');
      }

      Map<String, dynamic> callData = callDoc.data() as Map<String, dynamic>;

      if (callData['status'] != 'calling') {
        print('❌ Call is not in calling state: ${callData['status']}');
        throw Exception('Call is not available');
      }

      // Initialize WebRTC and get media
      await initializeWebRTC();
      await getUserMedia();

      // Start listening for everything BEFORE updating status
      _listenForCallStatus();
      _listenForIceCandidates();

      // Update call status to answered
      await _firestore.collection('videoCalls').doc(callId).update({
        'status': 'answered',
        'answeredAt': FieldValue.serverTimestamp(),
      });

      print('✅ Call status updated to answered');

      // Now set the remote description with the offer
      if (callData['offer'] != null) {
        // Set remote description (offer)
        await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(callData['offer']['sdp'], callData['offer']['type'])
        );

        print('✅ Remote offer set');

        // Create answer
        RTCSessionDescription answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        print('📤 Created and set local answer');

        // Update call with answer
        await _firestore.collection('videoCalls').doc(callId).update({
          'answer': {
            'type': answer.type,
            'sdp': answer.sdp,
          },
          'status': 'connected'
        });

        print('✅ Answer saved to Firebase');
      }

    } catch (e) {
      print('❌ Error answering call: $e');
      throw e;
    }
  }

  void _listenForCallStatus() {
    if (currentCallId == null || _isDisposed) return;

    print('👂 Listening for call status changes: $currentCallId');

    _callStatusSubscription?.cancel(); // Cancel any existing subscription

    _callStatusSubscription = _firestore.collection('videoCalls').doc(currentCallId).snapshots().listen((snapshot) {
      if (_isDisposed || !snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      String status = data['status'] ?? 'calling';

      print('📞 Call status changed to: $status');

      if (status == 'ended' || status == 'declined') {
        print('📞 Call ended remotely, cleaning up...');
        endCall(); // Use endCall instead of direct _cleanup
      }
    });
  }

  void _listenForAnswer() {
    if (currentCallId == null || _isDisposed) return;

    print('👂 Listening for answer: $currentCallId');

    _answerSubscription?.cancel(); // Cancel any existing subscription

    _answerSubscription = _firestore.collection('videoCalls').doc(currentCallId).snapshots().listen((snapshot) async {
      if (_isDisposed || !snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      if (data['answer'] != null && _peerConnection != null && !_isDisposed) {
        print('📥 Answer received, setting remote description');

        try {
          await _peerConnection!.setRemoteDescription(
              RTCSessionDescription(data['answer']['sdp'], data['answer']['type'])
          );

          print('✅ Remote answer set');

          if (!_isDisposed) {
            await _firestore.collection('videoCalls').doc(currentCallId).update({
              'status': 'connected'
            });
            // Start listening for ICE candidates after answer is set
            _listenForIceCandidates();
          }
        } catch (e) {
          print('❌ Error setting remote description: $e');
        }
      }

      if (data['status'] == 'ended' || data['status'] == 'declined') {
        endCall();
      }
    });
  }

  void _listenForIceCandidates() {
    if (currentCallId == null || _isDisposed) return;

    print('👂 Listening for ICE candidates: $currentCallId');

    _iceCandidatesSubscription?.cancel(); // Cancel any existing subscription

    _iceCandidatesSubscription = _firestore.collection('videoCalls').doc(currentCallId)
        .collection('iceCandidates').snapshots().listen((snapshot) {
      if (_isDisposed) return;

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;

          if (_peerConnection != null && data['candidate'] != null) {
            try {
              _peerConnection!.addCandidate(RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              ));

              print('🧊 ICE candidate added: ${data['candidate']}');
            } catch (e) {
              print('❌ Error adding ICE candidate: $e');
            }
          }
        }
      }
    });
  }

  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (currentCallId != null && !_isDisposed && candidate.candidate != null) {
      try {
        await _firestore.collection('videoCalls').doc(currentCallId)
            .collection('iceCandidates').add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'timestamp': FieldValue.serverTimestamp(),
        });

        print('🧊 ICE candidate sent to Firebase');
      } catch (e) {
        print('❌ Error sending ICE candidate: $e');
      }
    }
  }

  Future<void> endCall() async {
    print('📞 Ending call: $currentCallId');

    if (_isDisposed) return;
    _isDisposed = true;

    // Store callId before clearing
    final callIdToEnd = currentCallId;

    // Cancel all subscriptions FIRST
    _callStatusSubscription?.cancel();
    _answerSubscription?.cancel();
    _iceCandidatesSubscription?.cancel();

    _callStatusSubscription = null;
    _answerSubscription = null;
    _iceCandidatesSubscription = null;

    // Update status to ended IMMEDIATELY with retry logic
    if (callIdToEnd != null) {
      try {
        await _firestore.collection('videoCalls').doc(callIdToEnd).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        }).timeout(Duration(seconds: 5), onTimeout: () {
          print('⚠️ Update timeout, attempting delete');
          return _firestore.collection('videoCalls').doc(callIdToEnd).delete();
        });

        // Delete after a short delay to allow other clients to see the status
        Future.delayed(Duration(seconds: 2), () async {
          try {
            await _firestore.collection('videoCalls').doc(currentCallId).delete();
            print('🗑️ Call document deleted');
          } catch (e) {
            print('Error deleting call document: $e');
          }
        });

        // Also delete ICE candidates collection
        final iceCandidatesRef = _firestore.collection('videoCalls')
            .doc(currentCallId)
            .collection('iceCandidates');

        final iceDocs = await iceCandidatesRef.get();
        final batch = _firestore.batch();

        for (final doc in iceDocs.docs) {
          batch.delete(doc.reference);
        }

        if (iceDocs.docs.isNotEmpty) {
          await batch.commit();
          print('🗑️ ICE candidates deleted');
        }
      } catch (e) {
        print('❌ Error updating call status: $e');
        // If update fails, try to delete immediately
        try {
          await _firestore.collection('videoCalls').doc(currentCallId).delete();
          print('🗑️ Call document force deleted after update failure');
        } catch (deleteError) {
          print('❌ Error force deleting call document: $deleteError');
        }
      }
    }

    _cleanup();

    // Call onCallEnd only if it's not null and widget is still mounted
    if (onCallEnd != null) {
      onCallEnd?.call();
    }
  }

  void _cleanup() {
    print('🧹 Cleaning up WebRTC resources...');

    try {
      // Close peer connection first to stop all tracks
      if (_peerConnection != null) {
        try {
          _peerConnection!.close();
        } catch (e) {
          print('Error closing peer connection: $e');
        }
        _peerConnection = null;
      }

      // Stop and dispose local stream tracks with delay
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          try {
            track.stop();
          } catch (e) {
            print('Error stopping track: $e');
          }
        });

        // Dispose after tracks are stopped
        Future.delayed(Duration(milliseconds: 100), () {
          try {
            _localStream?.dispose();
          } catch (e) {
            print('Error disposing local stream: $e');
          }
        });
        _localStream = null;
      }

      // Stop and dispose remote stream tracks with delay
      if (_remoteStream != null) {
        _remoteStream!.getTracks().forEach((track) {
          try {
            track.stop();
          } catch (e) {
            print('Error stopping remote track: $e');
          }
        });

        // Dispose after tracks are stopped
        Future.delayed(Duration(milliseconds: 100), () {
          try {
            _remoteStream?.dispose();
          } catch (e) {
            print('Error disposing remote stream: $e');
          }
        });
        _remoteStream = null;
      }

      print('✅ WebRTC cleanup completed');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }

    currentCallId = null;
  }

  void toggleMute() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
      print('🎤 Microphone ${!enabled ? 'unmuted' : 'muted'}');
    }
  }

  void toggleCamera() {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      bool enabled = _localStream!.getVideoTracks()[0].enabled;
      _localStream!.getVideoTracks()[0].enabled = !enabled;
      print('📷 Camera ${!enabled ? 'enabled' : 'disabled'}');
    }
  }

  void switchCamera() {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      _localStream!.getVideoTracks()[0].switchCamera();
      print('🔄 Camera switched');
    }
  }

  // Add connection recovery mechanism
  void _handleConnectionRecovery() {
    if (_peerConnection != null && !_isDisposed) {
      // Restart ICE if connection fails
      _peerConnection!.restartIce();
      print('🔄 Attempting ICE restart for connection recovery');
    }
  }

  // Add a new cleanup method that doesn't set _isDisposed
  void cleanup() {
    print('🧹 Cleaning up WebRTC resources without disposing service...');
    _cleanup();
    // Don't set _isDisposed = true here
  }

  void dispose() {
    print('🗑️ Disposing WebRTC service');
    _isDisposed = true;
    _cleanup();
  }
}