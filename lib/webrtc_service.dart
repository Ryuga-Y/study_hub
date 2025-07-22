import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

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

  Future<void> initializeWebRTC() async {
    // Create peer connection
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    });

    // Setup event handlers
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _sendIceCandidate(candidate);
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      onRemoteStream?.call(stream);
    };
  }

  Future<void> getUserMedia() async {
    final constraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      }
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      onLocalStream?.call(_localStream!);

      if (_peerConnection != null) {
        _peerConnection!.addStream(_localStream!);
      }
    } catch (e) {
      print('Error getting user media: $e');
      throw e;
    }
  }

  Future<String> startCall(String targetUserId, String targetUserName) async {
    isInitiator = true;
    currentCallId = Uuid().v4();

    await initializeWebRTC();
    await getUserMedia();

    // Create call document in Firebase
    await _firestore.collection('videoCalls').doc(currentCallId).set({
      'callId': currentCallId,
      'callerId': _auth.currentUser!.uid,
      'targetId': targetUserId,
      'targetName': targetUserName,
      'status': 'calling',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Save offer to Firebase
    await _firestore.collection('videoCalls').doc(currentCallId).update({
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      }
    });

    // Listen for answer
    _listenForAnswer();

    return currentCallId!;
  }

  Future<void> answerCall(String callId) async {
    isInitiator = false;
    currentCallId = callId;

    await initializeWebRTC();
    await getUserMedia();

    // Get call data
    DocumentSnapshot callDoc = await _firestore.collection('videoCalls').doc(callId).get();
    Map<String, dynamic> callData = callDoc.data() as Map<String, dynamic>;

    // Set remote description (offer)
    await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(callData['offer']['sdp'], callData['offer']['type'])
    );

    // Create answer
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Update call with answer
    await _firestore.collection('videoCalls').doc(callId).update({
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      },
      'status': 'answered'
    });

    // Listen for ICE candidates
    _listenForIceCandidates();
  }

  void _listenForAnswer() {
    _firestore.collection('videoCalls').doc(currentCallId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

        if (data['answer'] != null && _peerConnection != null) {
          _peerConnection!.setRemoteDescription(
              RTCSessionDescription(data['answer']['sdp'], data['answer']['type'])
          );
          _listenForIceCandidates();
        }

        if (data['status'] == 'ended') {
          endCall();
        }
      }
    });
  }

  void _listenForIceCandidates() {
    _firestore.collection('videoCalls').doc(currentCallId)
        .collection('iceCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
          _peerConnection!.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });
  }

  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (currentCallId != null) {
      await _firestore.collection('videoCalls').doc(currentCallId)
          .collection('iceCandidates').add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> endCall() async {
    // Update call status
    if (currentCallId != null) {
      await _firestore.collection('videoCalls').doc(currentCallId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    }

    // Clean up
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();

    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    currentCallId = null;

    onCallEnd?.call();
  }

  void toggleMute() {
    if (_localStream != null) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    }
  }

  void toggleCamera() {
    if (_localStream != null) {
      bool enabled = _localStream!.getVideoTracks()[0].enabled;
      _localStream!.getVideoTracks()[0].enabled = !enabled;
    }
  }

  void switchCamera() {
    if (_localStream != null) {
      _localStream!.getVideoTracks()[0].switchCamera();
    }
  }
}