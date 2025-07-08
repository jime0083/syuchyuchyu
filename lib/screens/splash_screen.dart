import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // 最初の起動かどうかを確認
      await _checkFirstLaunch();
      
      // 少し待機してからナビゲーション
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
      
      // Check if user is already logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('現在のユーザー: ${currentUser?.email ?? 'なし'}');
      
      if (currentUser != null) {
        // Initialize user data
        debugPrint('ユーザーデータを初期化します');
        await authService.initUserData();
        
        // Navigate to home screen
        debugPrint('ホーム画面に遷移します');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // Check if this is the first launch
        if (_isFirstLaunch) {
          // Mark as not first launch
          debugPrint('初回起動のため、フラグを更新します');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('first_launch', false);
          
          // Navigate to onboarding
          debugPrint('オンボーディング画面に遷移します');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        } else {
          // Navigate to login
          debugPrint('ログイン画面に遷移します');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('画面遷移中にエラーが発生しました: $e');
      // エラーが発生した場合はログイン画面に遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
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
