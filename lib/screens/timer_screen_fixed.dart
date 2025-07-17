import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/models/task_model.dart';
import 'package:micro_habit_runner/models/session_model.dart';
import 'package:micro_habit_runner/services/session_service.dart';
import 'package:micro_habit_runner/utils/task_colors.dart';

// タイマーモード（タイマー/ストップウォッチ）
enum TimerMode { countdown, stopwatch }

class TimerScreen extends StatefulWidget {
  final TaskModel task;
  
  const TimerScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late int _totalSeconds;
  int _remainingSeconds = 0;
  int _extraSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  late AnimationController _animationController;
  late AnimationController _celebrationController;
  
  // セッションの開始・終了時間を記録
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now();
  
  // 現在のタイマーモード
  TimerMode _currentMode = TimerMode.countdown;
  
  // 画像のアニメーション用変数
  bool _showCelebration = false;
  
  // スマホを触った回数をカウントする変数
  int _phoneInteractionCount = 0;
  
  // ストップウォッチ停止中フラグ（停止操作時のカウント除外用）
  bool _isStoppingStopwatch = false;
  
  // ラット画像のスライドインアニメーション用コントローラー
  late AnimationController _ratAnimationController;
  late Animation<Offset> _ratSlideAnimation;

  // メモ用テキストコントローラー
  final TextEditingController _memoController = TextEditingController();
  
  // セッションが保存済みかどうかのフラグ
  bool _isSessionSaved = false;

  @override
  void initState() {
    super.initState();
    // AppLifecycleStateの監視を開始
    WidgetsBinding.instance.addObserver(this);
    
    // 秒単位の合計時間を計算
    _totalSeconds = widget.task.duration * 60;
    _remainingSeconds = _totalSeconds;
    
    // アニメーションコントローラの設定
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );
    
    // 祝福アニメーション用のコントローラ設定
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _celebrationController.addListener(() {
      setState(() {}); // アニメーション値が変わるたびに画面を更新
    });
    
    // ラット画像のスライドアニメーション用コントローラーの設定
    _ratAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // スライドインに1.5秒
    );
    
    // 画面外から上にスライドインするアニメーション
    _ratSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5), // 画面下から
      end: const Offset(0, 0), // 中央に
    ).animate(CurvedAnimation(
      parent: _ratAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // AppLifecycleStateの監視を終了
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _animationController.dispose();
    _celebrationController.dispose();
    _ratAnimationController.dispose(); // ラットアニメーションコントローラーも破棄
    _memoController.dispose(); // メモ用テキストコントローラーを破棄
    super.dispose();
  }
  
  // 前回のアプリの状態を保存する変数
  AppLifecycleState _previousState = AppLifecycleState.resumed;
  bool _wasInBackground = false;
  DateTime? _lastStateChangeTime;
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('アプリの状態変化: $_previousState -> $state');
    
    // ストップウォッチモードで動作中かつ停止ボタン操作でない場合のみ
    if (_currentMode == TimerMode.stopwatch && _isRunning && !_isStoppingStopwatch) {
      final now = DateTime.now();
      
      // バックグラウンドに移行した場合
      if (_previousState == AppLifecycleState.resumed && 
          (state == AppLifecycleState.inactive || 
           state == AppLifecycleState.paused)) {
        
        // ストップウォッチの場合はバックグラウンドに移行したことを記録
        _wasInBackground = true;
        _lastStateChangeTime = now;
        
        // バックグラウンド移行時にスマホ操作としてカウント
        setState(() {
          _phoneInteractionCount++;
          print('バックグラウンドに移行: スマホ操作カウント $_phoneInteractionCount');
        });
      }
      
      // アプリに戻ってきた場合
      else if ((_previousState == AppLifecycleState.inactive || 
                _previousState == AppLifecycleState.paused) && 
               state == AppLifecycleState.resumed && 
               _wasInBackground) {
        
        // バックグラウンド状態をリセット
        _wasInBackground = false;
        
        if (_lastStateChangeTime != null) {
          // バックグラウンドにいた時間を計算（実時間を反映）
          final secondsInBackground = now.difference(_lastStateChangeTime!).inSeconds;
          print('バックグラウンドにいた時間: $secondsInBackground 秒');
          
          // ストップウォッチの場合、バックグラウンドにいた時間を加算
          if (_isRunning && _currentMode == TimerMode.stopwatch) {
            setState(() {
              _extraSeconds += secondsInBackground;
            });
          }
        }
      }
    }
    
    _previousState = state;
  }

  void _startTimer() {
    // タイマー開始時の時間を記録
    if (!_isRunning) {
      _startTime = DateTime.now();
      print('タイマー開始: ${_startTime.toString()}');
    }
  
    setState(() {
      _isRunning = true;
    });
    
    if (_currentMode == TimerMode.countdown) {
      _animationController.reverse(
        from: _remainingSeconds / _totalSeconds,
      );
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            // タイマー完了時は祈いアニメーションを表示せずにストップウォッチへ移行
            _switchToStopwatchMode();
          }
        });
      });
    } else {
      // ストップウォッチモード
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _extraSeconds++;
        });
      });
    }
  }

  void _pauseTimer() {
    setState(() {
      _isRunning = false;
      _isStoppingStopwatch = true;
      _endTime = DateTime.now(); // タスク終了時間を記録
    });
    
    _timer?.cancel();
    _animationController.stop();
    
    // ストップウォッチ停止時に祝福アニメーションを表示
    if (_currentMode == TimerMode.stopwatch) {
      // セッションデータを保存してから祝福アニメーションを表示
      _saveSessionData().then((_) {
        _showCelebrationAnimation();
      });
    }
    
    // ストップウォッチ停止操作のフラグをリセット
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isStoppingStopwatch = false;
        });
      }
    });
  }

  void _resetTimer() {
    setState(() {
      if (_currentMode == TimerMode.countdown) {
        _remainingSeconds = _totalSeconds;
      } else {
        _extraSeconds = 0;
      }
      _isRunning = false;
    });
    
    _timer?.cancel();
    _animationController.reset();
  }

  // セッションデータをFirestoreに保存するメソッド
  Future<void> _saveSessionData() async {
    // すでに保存済みの場合は処理しない
    if (_isSessionSaved) {
      print('セッションはすでに保存済みです');
      return;
    }
    
    try {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      
      // 集中度レベルを決定（シンプルな実装として、タッチ回数で判定）
      ConcentrationLevel concentrationLevel;
      if (_phoneInteractionCount == 0) {
        concentrationLevel = ConcentrationLevel.high;
      } else if (_phoneInteractionCount <= 3) {
        concentrationLevel = ConcentrationLevel.medium;
      } else {
        concentrationLevel = ConcentrationLevel.low;
      }
      
      // セッション保存
      final SessionModel? savedSession = await sessionService.saveSession(
        task: widget.task,
        startTime: _startTime,
        endTime: _endTime,
        concentrationLevel: concentrationLevel,
        memo: _memoController.text,
      );
      
      if (savedSession != null) {
        print('セッションが正常に保存されました: ${savedSession.id}');
        _isSessionSaved = true;
        
        // セッションリストを再読み込み
        await sessionService.getSessions();
      } else {
        print('セッション保存に失敗しました');
      }
    } catch (e) {
      print('セッション保存中にエラーが発生しました: $e');
    }
  }

  void _switchToStopwatchMode() {
    _timer?.cancel();
    setState(() {
      _currentMode = TimerMode.stopwatch;
      _extraSeconds = 0;
      _isRunning = true; // 自動的にストップウォッチを開始
    });
    // ストップウォッチモードを自動的に開始
    _startTimer();
  }

  void _showCelebrationAnimation() {
    // アニメーション実行前にリセット
    _celebrationController.reset();
    _ratAnimationController.reset();
    
    setState(() {
      _showCelebration = true;
    });
    
    print('Starting celebration animation');
    
    // ラット画像のスライドインアニメーションを開始
    Future.delayed(const Duration(milliseconds: 300), () {
      _ratAnimationController.forward();
    });
    
    // アニメーションを確実に開始
    _celebrationController.forward().then((_) {
      print('Animation completed');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          // 自動的に閉じる場合もホーム画面に移動
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/', // ホーム画面のルート
            (route) => false, // すべてのルートを削除
          );
          _celebrationController.reset();
          print('Navigation to home after animation completion');
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  String _formatStopwatchTime(int seconds) {
    if (seconds < 3600) {
      // 1時間未満: MM:SS形式
      final int minutes = seconds ~/ 60;
      final int remainingSeconds = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      // 1時間以上: H:MM:SS形式
      final int hours = seconds ~/ 3600;
      final int remainingMinutes = (seconds % 3600) ~/ 60;
      final int remainingSeconds = seconds % 60;
      return '$hours:${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }
  
  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    return '$minutes分';
  }
  
  @override
  Widget build(BuildContext context) {
    // 現在のモードに応じた表示テキスト
    final String timeText = _currentMode == TimerMode.countdown
        ? _formatTime(_remainingSeconds)
        : _formatStopwatchTime(_extraSeconds);
    
    // プログレスバーの値（0.0〜1.0）
    double progress = _currentMode == TimerMode.countdown
        ? _remainingSeconds / _totalSeconds
        : 1.0; // ストップウォッチモードでは常に100%
    
    // 背景色は、カウントダウンモードではタスクに関連する色、ストップウォッチモードでは緑系
    Color backgroundColor = _currentMode == TimerMode.countdown
        ? TaskColors.getColorByKey(widget.task.colorKey)
        : Colors.green.shade50;
    
    // テキスト色もモードに応じて変更
    Color textColor = _currentMode == TimerMode.countdown
        ? Colors.white
        : Colors.black87;
    
    // セッション画面（ストップウォッチモード）での追加時間表示
    final String additionalTimeText = _currentMode == TimerMode.stopwatch
        ? '+${_formatTime(_extraSeconds)}'
        : '';
    
    return Scaffold(
      body: GestureDetector(
        // スマホを触った回数をカウントするためのGestureDetector
        onTap: () {
          // ストップウォッチモードで実行中、かつ停止操作中でない場合のみカウント
          if (_currentMode == TimerMode.stopwatch && _isRunning && !_isStoppingStopwatch) {
            setState(() {
              _phoneInteractionCount++;
              print('スマホタッチ: $_phoneInteractionCount回');
            });
          }
        },
        child: Stack(
          children: [
            // 背景
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              color: backgroundColor,
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // タスク情報表示
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      widget.task.name,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.task.scheduledTime,
                    style: TextStyle(
                      fontSize: 24,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  // 大きなタイマー表示
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w200,
                      color: textColor,
                    ),
                  ),
                  
                  // ストップウォッチモードのみ表示する追加情報
                  if (_currentMode == TimerMode.stopwatch) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // もともとの予定時間
                        Text(
                          '${_formatDuration(widget.task.duration * 60)}予定 ',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        // スマホを触った回数
                        Text(
                          'タッチ: $_phoneInteractionCount回',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 50),
                  
                  // プログレスサークル
                  _currentMode == TimerMode.countdown
                      ? SizedBox(
                          width: 200,
                          height: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 15,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isRunning ? Colors.white : Colors.grey,
                                ),
                              ),
                              // プログレスの数値表示（パーセント）
                              Text(
                                '${(progress * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(height: 200),
                  
                  const SizedBox(height: 50),
                  
                  // コントロールボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // リセットボタン
                      if (!_showCelebration) // 祝いアニメーション表示中は非表示
                        IconButton(
                          onPressed: _resetTimer,
                          icon: Icon(
                            Icons.restore,
                            size: 40,
                            color: textColor,
                          ),
                        ),
                      const SizedBox(width: 40),
                      
                      // 再生/一時停止ボタン
                      if (!_showCelebration) // 祝いアニメーション表示中は非表示
                        IconButton(
                          onPressed: _isRunning ? _pauseTimer : _startTimer,
                          icon: Icon(
                            _isRunning ? Icons.pause : Icons.play_arrow,
                            size: 64,
                            color: textColor,
                          ),
                        ),
                      const SizedBox(width: 40),
                      
                      // 戻るボタン
                      if (!_showCelebration) // 祝いアニメーション表示中は非表示
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: Icon(
                            Icons.close,
                            size: 40,
                            color: textColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 祝福アニメーション
            if (_showCelebration)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    // タップしても何もしない（下のレイヤーへの伝播を防ぐ）
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: SlideTransition(
                        position: _ratSlideAnimation,
                        child: Container(
                          width: 320,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 画像とテキスト
                              Image.asset(
                                'assets/images/niku2.png',
                                width: 120,
                                height: 120,
                              ),
                              const SizedBox(height: 10),
                              Column(
                                children: [
                                  // 優先タスクの場合は特別なテキストを表示
                                  if (widget.task.isPriority)
                                    const Text(
                                      '優先タスク達成!!',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  Text(
                                    '${widget.task.name} 達成!!',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '続けた時間: ${_formatTime(widget.task.duration * 60 - _remainingSeconds)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'スマホを触った回数: $_phoneInteractionCount回',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 15),
                              // メモ用テキストフィールドを追加
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  controller: _memoController,
                                  decoration: const InputDecoration(
                                    hintText: '感想やメモを入力してください',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  maxLines: 3,
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // 閉じるボタン
                              ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('閉じる'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: const TextStyle(fontSize: 18),
                                ),
                                onPressed: () {
                                  // ホーム画面に戻る（全てのルートを削除してホームに移動）
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/', // ホーム画面のルート
                                    (route) => false, // すべてのルートを削除
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
