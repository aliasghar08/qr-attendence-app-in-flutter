import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Permanently delete current user account, credentials, and institutional records
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No active authenticated user session found.');
    }

    try {
      // 1. Re-authenticate user to satisfy Firebase security requirements
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;

      // 2. Delete user profile from Firestore
      await firestore.collection('users').doc(uid).delete();

      // 3. Purge student attendance records if any exist
      final attendanceSnapshots = await firestore
          .collection('attendance')
          .where('studentId', isEqualTo: uid)
          .get();

      if (attendanceSnapshots.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in attendanceSnapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // 4. Delete Firebase Auth user
      await user.delete();
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect password. Verification failed.';
          break;
        case 'requires-recent-login':
          message = 'Security timeout. Please sign out and sign back in to delete your account.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message = e.message ?? 'Account deletion failed.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
}