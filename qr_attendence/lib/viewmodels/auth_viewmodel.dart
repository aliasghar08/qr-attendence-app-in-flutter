import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService? _authService;
  final FirebaseFirestore? _firestore;

  AuthViewModel({
    AuthService? authService,
    FirebaseFirestore? firestore,
  })  : _authService = authService,
        _firestore = firestore;

  AuthService get authService => _authService ?? AuthService();
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPasswordVisible = false;
  bool get isPasswordVisible => _isPasswordVisible;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _selectedRole = 'student'; // 'student' or 'teacher'
  String get selectedRole => _selectedRole;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  void setSelectedRole(String role) {
    if (_selectedRole != role) {
      _selectedRole = role;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await authService.login(email.trim(), password.trim());
      if (user == null) {
        throw Exception('Login failed. Please verify your credentials.');
      }

      final doc = await firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) {
        throw Exception('User profile record not found in system.');
      }

      return {
        'uid': user.uid,
        'user': user,
        'data': data,
        'role': (data['role'] as String?)?.toLowerCase() ?? 'student',
        'name': data['name'] ?? 'User',
        'email': data['email'] ?? user.email ?? '',
      };
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseAuthError(e);
      return null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> extraData,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await authService.signup(email.trim(), password.trim());
      if (user != null) {
        final userData = {
          'name': name.trim(),
          'email': email.trim(),
          'role': role.toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
          ...extraData,
        };
        await firestore.collection('users').doc(user.uid).set(userData);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseAuthError(e);
      return null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signOut() async {
    try {
      await authService.logout();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to sign out: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount({required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await authService.deleteAccount(password.trim());
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'The password is too weak. Must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact administration.';
      case 'network-request-failed':
        return 'Network connection error. Check your internet connectivity.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
