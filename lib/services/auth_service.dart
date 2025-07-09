import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:micro_habit_runner/models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // ログイン状態を確認するプロパティ
  bool get isLoggedIn => _auth.currentUser != null;
  
  UserModel? _userModel;
  UserModel? get userModel => _userModel;
  
  // Initialize user data
  Future<void> initUserData() async {
    if (currentUser != null) {
      await getUserData();
    }
  }
  
  // Get user data from Firestore
  Future<UserModel?> getUserData() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
        notifyListeners();
        return _userModel;
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user data: $e');
      }
      return null;
    }
  }
  
  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await getUserData();
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error signing in: $e');
      }
      rethrow;
    }
  }
  
  // Sign in with email (alias for signInWithEmailAndPassword)
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    return signInWithEmailAndPassword(email, password);
  }
  
  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google Sign In flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was canceled');
      }
      
      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in with credential
      UserCredential result = await _auth.signInWithCredential(credential);
      
      // Check if this is a new user
      if (result.additionalUserInfo?.isNewUser ?? false) {
        // Create user document in Firestore
        await _createUserDocument(result.user!.uid, result.user!.email ?? '');
      }
      
      await getUserData();
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error signing in with Google: $e');
      }
      rethrow;
    }
  }
  
  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      await _createUserDocument(result.user!.uid, email);
      
      await getUserData();
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error registering: $e');
      }
      rethrow;
    }
  }
  
  // Create user document in Firestore
  Future<void> _createUserDocument(String uid, String email) async {
    try {
      UserModel newUser = UserModel(
        id: uid,
        email: email,
        subscriptionStatus: SubscriptionStatus.free,
        trialUsed: false,
        createdAt: DateTime.now(),
        language: 'ja', // Default to Japanese
      );
      
      await _firestore.collection('users').doc(uid).set(newUser.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error creating user document: $e');
      }
      rethrow;
    }
  }
  
  // Start free trial
  Future<void> startFreeTrial() async {
    try {
      if (_userModel != null && !_userModel!.trialUsed) {
        await _firestore.collection('users').doc(_userModel!.id).update({
          'subscriptionStatus': 'trial',
          'trialStartDate': Timestamp.fromDate(DateTime.now()),
          'trialUsed': true,
        });
        await getUserData();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error starting free trial: $e');
      }
      rethrow;
    }
  }
  
  // Update user language preference
  Future<void> updateLanguage(String language) async {
    try {
      if (_userModel != null) {
        await _firestore.collection('users').doc(_userModel!.id).update({
          'language': language,
        });
        await getUserData();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating language: $e');
      }
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _userModel = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
      rethrow;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting password: $e');
      }
      rethrow;
    }
  }
}
