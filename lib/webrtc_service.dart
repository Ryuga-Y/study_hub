import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

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

      // Create peer connection with STUN servers
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          {'urls': 'stun:stun3.l.google.com:19302'},
        ]
      });

      // Setup event handlers
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('🧊 New ICE candidate: ${candidate.candidate}');
        _sendIceCandidate(candidate);
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        print('📺 Remote stream received');
        _remoteStream = stream;
        onRemoteStream?.call(stream);
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('🔗 ICE Connection State: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          print('✅ WebRTC connection established');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          print('❌ WebRTC connection failed or disconnected');
          endCall();
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
    } catch (e) {
      print('❌ Error initializing WebRTC: $e');
      throw e;
    }
  }

  Future<void> getUserMedia() async {
    try {
      print('🎥 Getting user media...');

      final constraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 30},
        }
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      print('✅ Local stream obtained');

      onLocalStream?.call(_localStream!);

      if (_peerConnection != null) {
        _peerConnection!.addStream(_localStream!);
        print('✅ Local stream added to peer connection');
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
      await _firestore.collection('videoCalls').doc(currentCallId).set({
        'callId': currentCallId,
        'callerId': _auth.currentUser!.uid,
        'callerName': _auth.currentUser!.displayName ?? 'Unknown',
        'targetId': targetUserId,
        'targetName': targetUserName,
        'status': 'calling',
        'createdAt': FieldValue.serverTimestamp(),
      });

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

      await initializeWebRTC();
      await getUserMedia();

      // Update call status to answered
      await _firestore.collection('videoCalls').doc(callId).update({
        'status': 'answered',
        'answeredAt': FieldValue.serverTimestamp(),
      });

      print('✅ Call status updated to answered');

      // Listen for call status changes
      _listenForCallStatus();

      // Listen for ICE candidates FIRST to catch early candidates
      _listenForIceCandidates();

      // Get call data
      DocumentSnapshot callDoc = await _firestore.collection('videoCalls').doc(callId).get();
      Map<String, dynamic> callData = callDoc.data() as Map<String, dynamic>;

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

    // Cancel all subscriptions first
    await _callStatusSubscription?.cancel();
    await _answerSubscription?.cancel();
    await _iceCandidatesSubscription?.cancel();

    // Update call status in Firebase
    if (currentCallId != null) {
      try {
        await _firestore.collection('videoCalls').doc(currentCallId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'endedBy': _auth.currentUser?.uid ?? 'unknown',
        });

        print('✅ Call status updated to ended');
      } catch (e) {
        print('❌ Error updating call status: $e');
      }
    }

    _cleanup();
    onCallEnd?.call();
  }

  void _cleanup() {
    print('🧹 Cleaning up WebRTC resources...');

    try {
      // Dispose streams
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream?.dispose();

      _remoteStream?.getTracks().forEach((track) {
        track.stop();
      });
      _remoteStream?.dispose();

      // Close peer connection
      _peerConnection?.close();

      print('✅ WebRTC cleanup completed');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }

    // Reset state
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    currentCallId = null;
    // ✅ Don't reset _isDisposed flag
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

  // Dispose method for proper cleanup
  void dispose() {
    print('🗑️ Disposing WebRTC service');
    _isDisposed = true;
    _cleanup();
  }
}