import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  Map<String, dynamic> _user = {};
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get userName => _user['name'] ?? 'User';
  String get userEmail => _user['email'] ?? '';

  // Fetch current user profile
  Future<void> fetchUserProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await ApiService.getCurrentUserProfile();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error fetching user profile: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  // Update user profile
  Future<void> updateUserProfile({String? name, String? email}) async {
    try {
      final updatedUser = await ApiService.updateUserProfile(name: name, email: email);
      _user = updatedUser;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error updating user profile: $e");
      notifyListeners();
      rethrow;
    }
  }
}
