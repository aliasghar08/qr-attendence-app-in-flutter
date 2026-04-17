import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // LOGIN with error handling
  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      // Re-throw with user-friendly message
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email';
          break;
        case 'wrong-password':
          message = 'Wrong password provided';
          break;
        case 'invalid-email':
          message = 'Invalid email format';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Try again later';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your connection';
          break;
        default:
          message = e.message ?? 'Authentication failed';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // SIGN UP with error handling
  Future<User?> signup(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered';
          break;
        case 'invalid-email':
          message = 'Invalid email format';
          break;
        case 'weak-password':
          message = 'Password is too weak (minimum 6 characters)';
          break;
        case 'operation-not-allowed':
          message = 'Email/password signup is disabled';
          break;
        default:
          message = e.message ?? 'Signup failed';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Signup failed: ${e.toString()}');
    }
  }

  // LOGOUT with error handling
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: ${e.toString()}');
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;
  
  // Get user UID safely
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}