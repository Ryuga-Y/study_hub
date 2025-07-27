import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'incoming_call_screen.dart';
import 'video_call_screen.dart';

// Global navigator key - ADD THIS AT THE TOP
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CallListenerService {
  static final CallListenerService _instance = CallListenerService._internal();
  factory CallListenerService() => _instance;
  CallListenerService._internal();

  StreamSubscription? _callSubscription;

  void initialize() {
    _startListening();
  }

  void _startListening() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    _callSubscription?.cancel();

    _callSubscription = FirebaseFirestore.instance
        .collection('videoCalls')
        .where('targetId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final callData = change.doc.data() as Map<String, dynamic>;
          _showIncomingCall(
            callData['callId'],
            callData['callerId'],
            callData['callerName'] ?? 'Unknown',
          );
        }
      }
    });
  }

  void _showIncomingCall(String callId, String callerId, String callerName) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          onAccept: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => VideoCallScreen(
                  contactName: callerName,
                  callId: callId,
                  isIncoming: true,
                ),
              ),
            );
          },
          onDecline: () {
            FirebaseFirestore.instance.collection('videoCalls').doc(callId).update({
              'status': 'declined',
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void dispose() {
    // Only dispose if explicitly called, not automatically
    print('⚠️ CallListenerService dispose called - this should rarely happen');
    _callSubscription?.cancel();
  }

// Add method to ensure service is always listening
  void ensureListening() {
    if (_callSubscription == null || _callSubscription!.isPaused) {
      print('🔄 Restarting call listener service');
      _startListening();
    }
  }
}