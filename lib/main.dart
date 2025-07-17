import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/firebase_options.dart';
import 'package:micro_habit_runner/services/auth_service.dart';
import 'package:micro_habit_runner/services/task_service.dart';
import 'package:micro_habit_runner/services/session_service.dart';
import 'package:micro_habit_runner/services/subscription_service.dart';
import 'package:micro_habit_runner/services/ad_service.dart';
import 'package:micro_habit_runner/utils/app_theme.dart';
import 'package:micro_habit_runner/utils/localization.dart';
import 'package:micro_habit_runner/screens/home_screen.dart';
import 'package:micro_habit_runner/screens/main_screen.dart';
import 'package:micro_habit_runner/screens/timer_screen.dart';
import 'package:micro_habit_runner/models/task_model.dart';

Future<void> main() async {
  // エラーハンドリングを追加
  await runZonedGuarded<Future<void>>(() async {
    // 1. ウィジェットバインディングの初期化
    WidgetsFlutterBinding.ensureInitialized();
    
    // 2. Firebase初期化 - 最もシンプルな方法にリファクタリング
    try {
      // 全ての判定を除去し、単純にFirebaseを初期化
      final FirebaseApp app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      if (kDebugMode) {
        print('✅ Firebase初期化成功: ${app.name}');
      }
    } catch (e) {
      // Firebase初期化に失敗した場合は、初期化済みのアプリを使用
      if (kDebugMode) {
        print('❗ Firebase初期化エラー: $e');
        print('✅ 別の方法で初期化を試みます...');
      }
      
      try {
        // 初期化済みのアプリを使用
        final FirebaseApp app = Firebase.app();
        if (kDebugMode) {
          print('✅ 既存のFirebaseアプリを使用: ${app.name}');
        }
      } catch (e2) {
        if (kDebugMode) {
          print('🔴 Firebase初期化が完全に失敗しました: $e2');
        }
      }
    }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => TaskService()),
        ChangeNotifierProvider(create: (_) => SessionService()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
        ChangeNotifierProvider(create: (_) => AdService()..initialize()),
      ],
      child: const MicroHabitRunnerApp(),
    ),
  );
}, (error, stack) {
  // アプリケーションレベルのエラーハンドリング
  if (kDebugMode) {
    print('🔴 アプリケーションエラー: $error');
    print('🔴 スタックトレース: $stack');
  }
});
}

class MicroHabitRunnerApp extends StatelessWidget {
  const MicroHabitRunnerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Micro Habit Runner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ja', ''), // Japanese
      ],
      // ホーム画面の設定
      home: const MainScreen(),
      // ルート設定
      routes: {
        '/timer': (context) {
          // TaskModelを引数として受け取る
          final task = ModalRoute.of(context)!.settings.arguments as TaskModel;
          return TimerScreen(task: task);
        },
      },
    );
  }
}
