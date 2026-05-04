import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  AuthService() {
    // Listen to auth state changes and notify listeners
    _auth.authStateChanges().listen((user) {
      notifyListeners();
    });
  }

  /// Register with email and password, create Firestore profile doc
  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await cred.user!.updateDisplayName(displayName);

      // Create user profile document in Firestore
      await _db.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'displayName': displayName,
        'email': email,
        'avatarUrl': '',
        'stats': {
          'totalWorkouts': 0,
          'currentStreak': 0,
          'totalVolume': 0,
        },
        'weeklyGoal': {
          'strengthDays': 3,
          'cardioDays': 2,
        },
        'notificationPreferences': {
          'challengeAlerts': true,
          'milestoneAlerts': true,
          'reminderAlerts': false,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save FCM token after registration
      await _saveFCMToken(cred.user!.uid);

      return cred;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Refresh FCM token on login
      await _saveFCMToken(cred.user!.uid);

      return cred;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// Sign out and clear session
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Save or refresh FCM token in Firestore under /users/{uid}/fcmToken
  Future<void> _saveFCMToken(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS requires this)
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        await _db.collection('users').doc(uid).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('FCM token save failed: $e');
    }
  }

  /// Map Firebase error codes to readable messages
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
