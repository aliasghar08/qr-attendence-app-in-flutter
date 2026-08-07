import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Login with email and password
  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email address.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'Please provide a valid email format.';
          break;
        case 'user-disabled':
          message = 'This account has been temporarily disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again in a few moments.';
          break;
        case 'network-request-failed':
          message = 'Network connection failed. Please check your internet.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password. Please check and try again.';
          break;
        default:
          message = e.message ?? 'Authentication failed. Please check credentials.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  /// Signup with email and password
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
          message = 'An account with this email already exists.';
          break;
        case 'invalid-email':
          message = 'Please provide a valid email format.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Use at least 8 characters with numbers & symbols.';
          break;
        case 'operation-not-allowed':
          message = 'Sign up is currently disabled.';
          break;
        default:
          message = e.message ?? 'Registration failed.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Signup error: $e');
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }
}