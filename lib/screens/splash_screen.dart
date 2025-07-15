import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/services/auth_service.dart';
import 'package:micro_habit_runner/screens/onboarding_screen.dart';
import 'package:micro_habit_runner/screens/home_screen.dart';
import 'package:micro_habit_runner/screens/auth/login_screen.dart';
import 'package:micro_habit_runner/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
    
    // 初期化と画面遷移を順番に実行
    _initializeAndNavigate();
  }
  
  // 初期化と画面遷移を順番に実行する関数
  Future<void> _initializeAndNavigate() async {
    try {
      debugPrint('アプリの初期化を開始します');
      
      // 最初の起動かどうかを確認
      await _checkFirstLaunch();
      
      // Firebaseが初期化されているか確認
      debugPrint('Firebaseの初期化状態を確認します');
      try {
        if (Firebase.apps.isEmpty) {
          debugPrint('Firebaseが初期化されていません。main.dartで初期化されているはずです');
        } else {
          debugPrint('Firebaseは既に初期化されています');
        }
      } catch (e) {
        debugPrint('Firebase初期化状態確認エラー: $e');
      }
      
      // Firebase認証の状態を確認
      User? currentUser;
      try {
        currentUser = FirebaseAuth.instance.currentUser;
        debugPrint('現在のユーザー状態: ${currentUser != null ? "ログイン済み (${currentUser.email})" : "未ログイン"}');
      } catch (e) {
        debugPrint('FirebaseAuth状態確認エラー: $e');
      }
      
      // アニメーションのために少し待機
      await Future.delayed(const Duration(seconds: 2));
      
      // 次の画面に遷移
      if (mounted) {
        await _navigateToNextScreen();
      }
    } catch (e) {
      // エラーをログに出力
      debugPrint('スプラッシュスクリーンでエラーが発生しました: $e');
      
      // エラーが発生した場合はログイン画面に遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _checkFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isFirstLaunch = prefs.getBool('first_launch') ?? true;
      debugPrint('初回起動チェック: $_isFirstLaunch');
    } catch (e) {
      debugPrint('初回起動チェックでエラー: $e');
      _isFirstLaunch = true; // エラーの場合はデフォルト値を使用
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;
    
    try {
      debugPrint('画面遷移を開始します');
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // 初回起動フラグを更新
      if (_isFirstLaunch) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('first_launch', false);
      }
      
      // ユーザーが既にログインしているか確認
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('画面遷移時のユーザー状態: ${currentUser?.email ?? 'ゲストユーザー'}');
      
      // ログイン済みの場合はユーザーデータを初期化
      if (currentUser != null) {
        try {
          debugPrint('ユーザーデータを初期化します');
          await authService.initUserData();
          debugPrint('ユーザーデータの初期化が完了しました');
        } catch (e) {
          debugPrint('ユーザーデータの初期化中にエラーが発生しました: $e');
        }
      } else {
        debugPrint('ゲストユーザーとして続行します');
      }
      
      // オンボーディングとログイン画面をスキップして直接ホーム画面に遷移
      debugPrint('直接ホーム画面に遷移します');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      debugPrint('画面遷移中にエラーが発生しました: $e');
      // エラーが発生した場合もホーム画面に遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryOrange,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo (placeholder)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  Icons.timer,
                  size: 80,
                  color: AppTheme.primaryOrange,
                ),
              ),
              const SizedBox(height: 24),
              // App name
              const Text(
                '集中チュー',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'NotoSansJP',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Micro Habit Runner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
