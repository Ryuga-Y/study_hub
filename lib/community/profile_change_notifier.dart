import 'dart:async';
import 'package:flutter/foundation.dart';

class ProfileChangeNotifier extends ChangeNotifier {
  static final ProfileChangeNotifier _instance = ProfileChangeNotifier._internal();
  factory ProfileChangeNotifier() => _instance;
  ProfileChangeNotifier._internal();

  final StreamController<Map<String, dynamic>> _profileChangeController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get profileChangeStream => _profileChangeController.stream;

  void notifyProfileUpdate(Map<String, dynamic> updatedData) {
    _profileChangeController.add(updatedData);
    notifyListeners();
  }

  @override
  void dispose() {
    _profileChangeController.close();
    super.dispose();
  }
}