import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/firebase_options.dart';
import 'package:micro_habit_runner/services/auth_service.dart';
import 'package:micro_habit_runner/services/task_service.dart';
import 'package:micro_habit_runner/services/session_service.dart';
import 'package:micro_habit_runner/services/subscription_service.dart';
import 'package:micro_habit_runner/utils/app_theme.dart';
import 'package:micro_habit_runner/utils/localization.dart';
import 'package:micro_habit_runner/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => TaskService()),
        ChangeNotifierProvider(create: (_) => SessionService()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
      ],
      child: const MicroHabitRunnerApp(),
    ),
  );
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
      home: const SplashScreen(),
    );
  }
}
