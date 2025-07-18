import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/models/task_model.dart';
import 'package:micro_habit_runner/models/session_model.dart' show ConcentrationLevel, SessionModel;
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
  
  // タスク達成時のアニメーションコントローラ
  late AnimationController _completionAnimationController;
  late Animation<double> _slideAnimation;

  // メモ用テキストコントローラー
  final TextEditingController _memoController = TextEditingController();
  
  // 集中度評価
  ConcentrationLevel _concentrationLevel = ConcentrationLevel.medium;
  
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
    
    // タスク達成時のアニメーション
    _completionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _slideAnimation = Tween<double>(
      begin: 1.5,  // 画面外から
      end: 0.0,    // 目標位置まで
    ).animate(CurvedAnimation(
      parent: _completionAnimationController,
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
    _completionAnimationController.dispose();
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
  Future<void> _saveSessionData() async {
    if (_isSessionSaved) {
      print('セッションはすでに保存されています');
      return;
    }
    
    try {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      
      // Firestoreに保存（正しいメソッドを使用）
      final result = await sessionService.saveSession(
        task: widget.task,
        startTime: _startTime,
        endTime: _endTime,
        concentrationLevel: _concentrationLevel, // ユーザーが選択した集中度
        memo: _memoController.text,
      );
      
      if (result != null) {
        _isSessionSaved = true;
        print('セッションデータを保存しました');
      } else {
        print('セッションデータの保存に失敗しました');
      }
      
    } catch (e) {
      print('セッションデータの保存に失敗: $e');
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
        
      });
    });
  }
}

// ...

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
          // 紙吹雪のあるお祝い背景
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  image: AssetImage('assets/images/kimi.gif'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // 下からスライドインするネズミのキャラクター（アニメーション表示）
          AnimatedBuilder(
            animation: _completionAnimationController,
            builder: (context, child) {
              return Positioned(
                bottom: MediaQuery.of(context).size.height * _slideAnimation.value,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    'assets/images/junp-rat2.png',
                    width: 300, // 画像サイズを2倍に
                    height: 300,
                  ),
                ),
              );
            },
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
                    // 画像はすでに上部に表示されているため、テキストのみを表示
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
                    // 集中度評価
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '集中度の自己評価',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.9,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _concentrationLevel = ConcentrationLevel.high;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _concentrationLevel == ConcentrationLevel.high 
                                      ? Colors.green 
                                      : Colors.grey[300],
                                  foregroundColor: _concentrationLevel == ConcentrationLevel.high 
                                      ? Colors.white 
                                      : Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                child: const Text('とても集中できた'),
                              ),
                              const SizedBox(width: 8),
                              
                              // 集中できた
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _concentrationLevel = ConcentrationLevel.medium;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _concentrationLevel == ConcentrationLevel.medium 
                                      ? Colors.blue 
                                      : Colors.grey[300],
                                  foregroundColor: _concentrationLevel == ConcentrationLevel.medium 
                                      ? Colors.white 
                                      : Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                // 集中度評価
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        '集中度の自己評価',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.9,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        children: [
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _concentrationLevel = ConcentrationLevel.high;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _concentrationLevel == ConcentrationLevel.high 
                                                ? Colors.green 
                                                : Colors.grey[300],
                                            foregroundColor: _concentrationLevel == ConcentrationLevel.high 
                                                ? Colors.white 
                                                : Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          child: const Text('とても集中できた'),
                                        ),
                                        const SizedBox(width: 8),
                                        
                                        // 集中できた
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _concentrationLevel = ConcentrationLevel.medium;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _concentrationLevel == ConcentrationLevel.medium 
                                                ? Colors.blue 
                                                : Colors.grey[300],
                                            foregroundColor: _concentrationLevel == ConcentrationLevel.medium 
                                                ? Colors.white 
                                                : Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          child: const Text('集中できた'),
                                        ),
                                        const SizedBox(width: 8),
                                        
                                        // 集中できなかった
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _concentrationLevel = ConcentrationLevel.low;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _concentrationLevel == ConcentrationLevel.low 
                                                ? Colors.red 
                                                : Colors.grey[300],
                                            foregroundColor: _concentrationLevel == ConcentrationLevel.low 
                                                ? Colors.white 
                                                : Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          child: const Text('集中できなかった'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ],
                                ),
                                const SizedBox(height: 20),
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
