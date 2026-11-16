import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Fetch user profile from Firestore or create default if first time
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Real-time stream of current user's profile
  Stream<UserModel?> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, uid);
      }
      return null;
    });
  }

  /// Sign Up with Email and Password
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String targetExam,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user!;
      await user.updateDisplayName(displayName);

      final userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: 'student',
        targetExam: targetExam,
        preferredLanguage: 'en',
        streakCount: 1,
        totalPoints: 50, // Welcome points
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap(), SetOptions(merge: true));

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Login with Email and Password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user!;
      var profile = await getUserProfile(user.uid);
      if (profile == null) {
        // Fallback create profile if missing
        profile = UserModel(
          uid: user.uid,
          email: user.email ?? email,
          displayName: user.displayName ?? 'Student',
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(profile.toMap());
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Google Sign-In
  Future<UserModel> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Google sign-in was cancelled.';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      var profile = await getUserProfile(user.uid);
      if (profile == null) {
        profile = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'Student',
          role: 'student',
          targetExam: 'UPSC',
          preferredLanguage: 'en',
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(profile.toMap());
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Human-friendly Firebase Auth error messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or credentials. Please try again.';
      case 'email-already-in-use':
        return 'This email address is already registered. Try logging in.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many unsuccessful attempts. Please wait a few minutes before trying again.';
      default:
        return e.message ?? 'An unexpected authentication error occurred.';
    }
  }
}

