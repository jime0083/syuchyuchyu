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
  
  // 集中レベル
  ConcentrationLevel _concentrationLevel = ConcentrationLevel.medium;

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
    super.didChangeAppLifecycleState(state);
    
    // 現在の時間を取得
    final now = DateTime.now();
    
    // アプリがバックグラウンドからフォアグラウンドに戻った場合
    if (_previousState == AppLifecycleState.paused && 
        state == AppLifecycleState.resumed) {
      _wasInBackground = true;
      
      // バックグラウンドにいた時間を計算（前回の状態変更時間がある場合）
      if (_lastStateChangeTime != null) {
        final backgroundDuration = now.difference(_lastStateChangeTime!);
        
        // バックグラウンドに5秒以上いた場合のみカウント
        if (backgroundDuration.inSeconds >= 5) {
          if (_isRunning) {
            // カウントダウンモードの場合、残り時間から引く
            if (_currentMode == TimerMode.countdown) {
              int secondsToSubtract = backgroundDuration.inSeconds;
              setState(() {
                _remainingSeconds = (_remainingSeconds - secondsToSubtract).clamp(0, _totalSeconds);
                
                // もし残り時間がなくなった場合、タイマーを停止
                if (_remainingSeconds <= 0) {
                  _pauseTimer();
                  _switchToStopwatchMode(); // 自動的にストップウォッチモードに切り替え
                }
              });
            } 
            // ストップウォッチモードの場合は経過時間に加える
            else if (_currentMode == TimerMode.stopwatch) {
              setState(() {
                _extraSeconds += backgroundDuration.inSeconds;
              });
            }
          }
        }
      }
    }
    
    // 状態変更時間を更新
    _lastStateChangeTime = now;
    _previousState = state;
  }

  void _startTimer() {
    if (!_isRunning) {
      setState(() {
        _isRunning = true;
        // 初回開始時のみセッション開始時間を記録
        if (_remainingSeconds == _totalSeconds && _extraSeconds == 0) {
          _startTime = DateTime.now();
        }
      });
      
      // タイマーを開始（1秒ごとに更新）
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          // カウントダウンモードの場合
          if (_currentMode == TimerMode.countdown) {
            if (_remainingSeconds > 0) {
              _remainingSeconds--;
            }
            
            // タイマーが0になったらストップウォッチモードに切り替え
            if (_remainingSeconds <= 0) {
              _switchToStopwatchMode();
            }
          } 
          // ストップウォッチモードの場合
          else if (_currentMode == TimerMode.stopwatch) {
            _extraSeconds++;
          }
        });
      });
    }
  }

  void _pauseTimer() {
    if (_isRunning) {
      // ストップウォッチ停止時のカウント除外フラグを一時的に立てる
      if (_currentMode == TimerMode.stopwatch) {
        _isStoppingStopwatch = true;
        // 0.5秒後にフラグを元に戻す（この間はタップカウントしない）
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _isStoppingStopwatch = false;
          });
        });
      }
      
      setState(() {
        _isRunning = false;
        _endTime = DateTime.now(); // セッション終了時間を記録
      });
      
      // タイマーを停止
      _timer?.cancel();
      _timer = null;
      
      // ストップウォッチモードでセッション終了時に達成アニメーションを表示
      if (_currentMode == TimerMode.stopwatch) {
        // タスク達成時にはセッションデータを保存
        _saveSessionData();
        
        // 祝福アニメーションを表示（数秒後）
        _showCelebrationAnimation();
      }
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
      _extraSeconds = 0;
      _currentMode = TimerMode.countdown;
      _phoneInteractionCount = 0;
      _showCelebration = false;
      _isSessionSaved = false; // セッション保存状態をリセット
    });
  }
  
  // セッションデータをFirestoreに保存
  void _saveSessionData() {
    // セッションがまだ保存されていない場合のみ実行
    if (!_isSessionSaved) {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      
      // セッション時間の計算
      final duration = _currentMode == TimerMode.countdown
          ? _totalSeconds - _remainingSeconds // カウントダウンモードでは設定時間からの減少分
          : _totalSeconds + _extraSeconds; // ストップウォッチモードでは設定時間＋追加時間
      
      // セッションデータ作成
      final sessionData = SessionModel(
        id: '', // IDはサービス側で生成
        taskId: widget.task.id,
        taskName: widget.task.name,
        scheduledTime: widget.task.scheduledTime,
        actualStartTime: _startTime,
        endTime: _endTime,
        plannedDuration: widget.task.duration,
        actualDuration: duration,
        touchCount: _phoneInteractionCount,
        onTimeStart: true, // この値は後でサービス側で計算される
        concentrationLevel: _concentrationLevel,
        memo: _memoController.text, // メモの内容を保存
        createdAt: DateTime.now()
      );
      
      // Firestoreに保存
      sessionService.saveSession(
        task: widget.task,
        startTime: _startTime,
        endTime: _endTime,
        concentrationLevel: _concentrationLevel,
        memo: _memoController.text,
      ).then((_) {
        print('セッションデータを保存しました');
        setState(() {
          _isSessionSaved = true;
        });
      }).catchError((error) {
        print('セッションデータの保存に失敗しました: $error');
      });
    }
  }
  
  // ストップウォッチモードに切り替え
  void _switchToStopwatchMode() {
    if (_currentMode == TimerMode.countdown) {
      setState(() {
        _currentMode = TimerMode.stopwatch;
        _extraSeconds = 0;
      });
      
      // タイマーが動いていない場合は開始
      if (!_isRunning) {
        _startTimer();
      }
    }
  }
  
  // 祝福アニメーションを表示
  void _showCelebrationAnimation() {
    // アニメーションがまだ表示されていない場合
    if (!_showCelebration) {
      // 少し遅らせてアニメーションを開始（UIが更新される時間を確保）
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          _showCelebration = true;
        });
        
        // 祝福アニメーションを開始
        _celebrationController.reset();
        _celebrationController.forward();
        
        // ラットアニメーションを開始（少し遅れて）
        Future.delayed(const Duration(milliseconds: 1000), () {
          _ratAnimationController.reset();
          _ratAnimationController.forward();
        });
      });
    }
  }
  
  // 時間のフォーマット（MM:SS形式）
  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  // ストップウォッチ時のフォーマット（設定時間に追加された時間を表示）
  String _formatStopwatchTime(int seconds) {
    if (seconds <= _totalSeconds) {
      // 設定時間以内の場合は通常のフォーマット
      return _formatTime(seconds);
    } else {
      // 設定時間を超えた場合は、超過分を「+MM:SS」形式で表示
      final extraTime = seconds - _totalSeconds;
      final baseTime = _formatTime(_totalSeconds); // 設定時間部分
      final extraTimeFormatted = _formatTime(extraTime); // 追加時間部分
      
      return '$baseTime (+$extraTimeFormatted)';
    }
  }
  
  // 経過時間のフォーマット（X分Y秒形式）
  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes}分${remainingSeconds}秒';
  }

  @override
  Widget build(BuildContext context) {
    // 背景色とテキスト色を設定（モードによって変更）
    final backgroundColor = _currentMode == TimerMode.countdown
        ? Colors.blueGrey[900]
        : TaskColors.getColor(widget.task.colorKey).withOpacity(0.9);
    
    final textColor = _currentMode == TimerMode.countdown
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
                  const SizedBox(height: 50),
                  
                  // タイマー表示
                  Text(
                    _currentMode == TimerMode.countdown
                        ? _formatTime(_remainingSeconds)
                        : _formatStopwatchTime(_totalSeconds + _extraSeconds),
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  
                  // ストップウォッチモードでの追加時間表示
                  if (_currentMode == TimerMode.stopwatch && _extraSeconds > 0)
                    Text(
                      additionalTimeText,
                      style: TextStyle(
                        fontSize: 24,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  
                  const SizedBox(height: 40),
                  
                  // カウントダウンの進捗バー
                  if (_currentMode == TimerMode.countdown)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: LinearProgressIndicator(
                        value: _remainingSeconds / _totalSeconds,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          TaskColors.getColor(widget.task.colorKey),
                        ),
                        minHeight: 10,
                      ),
                    ),
                  
                  const SizedBox(height: 50),
                  
                  // コントロールボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // リセットボタン
                      if (!_isRunning || _currentMode == TimerMode.stopwatch)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('リセット'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                          onPressed: _resetTimer,
                        ),
                      
                      const SizedBox(width: 20),
                      
                      // 開始/停止ボタン
                      ElevatedButton.icon(
                        icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                        label: Text(_isRunning ? '一時停止' : '開始'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: _isRunning ? _pauseTimer : _startTimer,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // スマホを触った回数表示（ストップウォッチモードのみ）
                  if (_currentMode == TimerMode.stopwatch)
                    Text(
                      'スマホを触った回数: $_phoneInteractionCount回',
                      style: TextStyle(
                        fontSize: 18,
                        color: textColor,
                      ),
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
                  child: Stack(
                    children: [
                      // 背景全体を覆う暗い色
                      Container(
                        color: Colors.black.withOpacity(0.7),
                      ),
                      // 赤っぽい背景色を使用
                      Positioned.fill(
                        child: Container(
                          color: Colors.red.shade900,
                        ),
                      ),
                      // ネズミのキャラクターを中央に配置
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ネズミのキャラクター
                            Image.asset(
                              'assets/images/rat2.png',
                              width: 150,
                              height: 150,
                            ),
                          ],
                        ),
                      ),
                      // 下部に表示する達成情報ウィジェット
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: SlideTransition(
                          position: _ratSlideAnimation,
                          child: Container(
                            width: 320,
                            margin: const EdgeInsets.symmetric(horizontal: 30),
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
                                  'assets/images/jerry.png', // ネズミのキャラクター画像
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
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
