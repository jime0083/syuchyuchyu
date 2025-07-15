import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // PlatformExceptionのために追加
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      if (currentUser == null) {
        if (kDebugMode) {
          print('getUserData: currentUser が null のためユーザーデータを取得できません');
        }
        return null;
      }
      
      if (kDebugMode) {
        print('getUserData: ユーザードキュメントを取得します - UID: ${currentUser!.uid}');
      }
      
      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      
      if (doc.exists) {
        if (kDebugMode) {
          print('getUserData: ドキュメントが存在します - データ: ${doc.data()}');
        }
        
        _userModel = UserModel.fromFirestore(doc);
        notifyListeners();
        
        if (kDebugMode) {
          print('getUserData: ユーザーモデルを作成しました - ID: ${_userModel?.id}, Email: ${_userModel?.email}');
        }
        
        return _userModel;
      } else {
        if (kDebugMode) {
          print('getUserData: ドキュメントが存在しません - UID: ${currentUser!.uid}、新規作成します');
        }
        
        // ユーザードキュメントが存在しない場合は作成
        await _createUserDocument(currentUser!.uid, currentUser!.email ?? 'unknown@email.com');
        
        // 作成後に再度取得
        doc = await _firestore.collection('users').doc(currentUser!.uid).get();
        
        if (doc.exists) {
          _userModel = UserModel.fromFirestore(doc);
          notifyListeners();
          
          if (kDebugMode) {
            print('getUserData: 新規ユーザーモデルを作成しました - ID: ${_userModel?.id}, Email: ${_userModel?.email}');
          }
          
          return _userModel;
        } else {
          if (kDebugMode) {
            print('getUserData: ドキュメントの作成に失敗しました');
          }
          return null;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('getUserData エラー: $e');
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
    if (kDebugMode) {
      print('⚡️ Googleサインイン開始');
    }

    try {
      // 1. エミュレータか実機かを判定して最適な設定を選択
      final bool isEmulator = !kIsWeb && Platform.isAndroid && (kDebugMode);
      if (kDebugMode) {
        print('🐛 デバイス環境: エミュレータ = $isEmulator');
      }
      
      // エミュレータと実機で異なる設定を使い分け
      final GoogleSignIn googleSignIn;
      
      if (isEmulator) {
        // エミュレータ用の最小設定
        googleSignIn = GoogleSignIn(scopes: ['email']);
        if (kDebugMode) {
          print('🔧 エミュレータ用GoogleSignIn設定を使用');
        }
      } else {
        // 実機用の設定
        googleSignIn = GoogleSignIn(
          scopes: ['email'],
          // android/app/build.gradle.ktsのapplicationIdと一致する必要がある
          clientId: Platform.isAndroid ? 'micro_habit.runner' : null,
        );
        if (kDebugMode) {
          print('🔧 実機用GoogleSignIn設定を使用');
        }
      }
      
      // 2. 既存のセッションをクリア
      try {
        final isSignedIn = await googleSignIn.isSignedIn();
        if (isSignedIn) {
          if (kDebugMode) {
            print('❗ 既存セッションをクリア中...');
          }
          
          // disconnectで接続を完全に切断
          await googleSignIn.disconnect().catchError((e) {
            if (kDebugMode) {
              print('⚠️ disconnectエラー (無視): $e');
            }
          });
          
          // 次にsignOutでログアウト
          await googleSignIn.signOut().catchError((e) {
            if (kDebugMode) {
              print('⚠️ signOutエラー (無視): $e');
            }
          });
        }
      } catch (e) {
        // セッションクリアのエラーは無視して続行
        if (kDebugMode) {
          print('⚠️ セッションクリアエラー (無視): $e');
        }
      }
      
      // 3. Googleサインイン実行
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      // キャンセルまたはエラーの場合
      if (googleUser == null) {
        if (kDebugMode) {
          print('❌ サインインがキャンセルまたは失敗');
        }
        return null;
      }
      
      // 4. サインイン成功 - 詳細ログ
      if (kDebugMode) {
        print('✅ サインイン成功: ${googleUser.email}');
        print('✅ ユーザー情報: ID=${googleUser.id}, 名前=${googleUser.displayName}');
      }
      
      // 5. 認証情報を取得
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (kDebugMode) {
        final bool hasAccessToken = googleAuth.accessToken != null;
        final bool hasIdToken = googleAuth.idToken != null;
        print('✅ トークン: accessToken=${hasAccessToken ? "成功" : "失敗"}, idToken=${hasIdToken ? "成功" : "失敗"}');
      }
      
      // 6. Firebase認証情報を作成
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // 7. Firebaseに認証
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (kDebugMode) {
        print('✅ Firebase認証成功: ${userCredential.user?.uid}');
      }
      
      // 8. ユーザードキュメント確認・作成
      try {
        final String uid = userCredential.user!.uid;
        final DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
        
        if (!userDoc.exists) {
          if (kDebugMode) {
            print('➕ 新規ユーザードキュメント作成: $uid');
          }
          // Firestoreにユーザー情報保存
          await _createUserDocument(uid, userCredential.user!.email ?? 'unknown@email.com');
        } else {
          if (kDebugMode) {
            print('✅ 既存ユーザードキュメント確認: $uid');
          }
        }
        
        // 9. ユーザーデータ取得
        await getUserData();
        
        return userCredential;
      } catch (firestoreError) {
        // Firestore操作エラーは記録するが認証自体は成功として返す
        if (kDebugMode) {
          print('⚠️ Firestore操作エラー: $firestoreError');
        }
        return userCredential;
      }
    } catch (e) {
      // Google認証プロセス全体のエラー処理
      if (kDebugMode) {
        print('❌ Google認証エラー:');
        print('タイプ: ${e.runtimeType}');
        print('メッセージ: $e');
        
        if (e is PlatformException) {
          print('❌ PlatformException詳細:');
          print('  コード: ${e.code}');
          print('  メッセージ: ${e.message}');
          print('  詳細: ${e.details}');
          
          if (e.code == 'sign_in_failed' || e.code == '10') {
            print('❌ 考えられる原因:');
            print('1. FirebaseのSHA-1フィンガープリントが不正確');
            print('2. google-services.jsonが最新版でない');
            print('3. パッケージ名(micro_habit.runner)が不一致');
          }
        }
      }
      return null;
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
  
  // Update user profile information
  Future<void> updateUserProfile({String? username, String? profileImageUrl}) async {
    try {
      if (_userModel != null && (username != null || profileImageUrl != null)) {
        final Map<String, dynamic> updateData = {};
        
        if (username != null && username.trim().isNotEmpty) {
          updateData['username'] = username.trim();
        }
        
        if (profileImageUrl != null) {
          updateData['profileImageUrl'] = profileImageUrl;
        }
        
        if (updateData.isNotEmpty) {
          if (kDebugMode) {
            print('プロフィール情報を更新します: $updateData');
          }
          
          await _firestore.collection('users').doc(_userModel!.id).update(updateData);
          await getUserData();
          
          if (kDebugMode) {
            print('プロフィール情報の更新が完了しました');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user profile: $e');
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