import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:micro_habit_runner/models/task_model.dart';
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
      
      // アプリがフォアグラウンドからバックグラウンドに移行
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _wasInBackground = true;
        _lastStateChangeTime = now;
        print('アプリがバックグラウンドに移行 -> カウントアップ');
        
        // 確実にカウントするために非同期処理でsetStateを実行
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _phoneInteractionCount++;
            });
            print('操作カウント更新: $_phoneInteractionCount');
          }
        });
      }
      
      // バックグラウンドからフォアグラウンドに戻ってきた場合
      else if (state == AppLifecycleState.resumed && _wasInBackground) {
        _wasInBackground = false;
        
        // 短時間の切り替えはカウントしないロジックを削除（常にカウントする）
        print('アプリがフォアグラウンドに戻ってきました');
      }
    }
    
    // 現在の状態を保存
    _previousState = state;
  }

  void _startTimer() {
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
    // ストップウォッチを止める操作の場合、カウント除外フラグを設定
    if (_currentMode == TimerMode.stopwatch && _isRunning) {
      _isStoppingStopwatch = true;
    }
    
    setState(() {
      _isRunning = false;
    });
    _timer?.cancel();
    if (_currentMode == TimerMode.countdown) {
      _animationController.stop();
    } else {
      // ストップウォッチモードで停止した場合は祝いアニメーションを表示
      print('Showing celebration animation on stopwatch pause');
      _showCelebrationAnimation();
    }
    
    // カウント除外フラグをリセット（次回の通常タッチでカウントされるように）
    Future.delayed(const Duration(milliseconds: 500), () {
      _isStoppingStopwatch = false;
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
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  String _formatStopwatchTime(int seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString()}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }


  // _formatDurationメソッドの追加
  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // タスクの色を取得
    final taskColor = TaskColors.getColor(widget.task.colorKey);
    
    // メインコンテンツ用のウィジェット
    final Widget mainContent = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 現在のモード表示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: taskColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentMode == TimerMode.countdown ? 'タイマーモード' : 'ストップウォッチモード',
              style: TextStyle(
                color: taskColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          // タイマー表示
          if (_currentMode == TimerMode.countdown) 
            Stack(
              alignment: Alignment.center,
              children: [
                // 進捗インジケーター
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: 1 - (_remainingSeconds / _totalSeconds),
                    strokeWidth: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(taskColor),
                  ),
                ),
                
                // 残り時間表示
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(_remainingSeconds),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '残り時間',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // ストップウォッチモードの表示
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: 1.0, // 常に完了状態
                    strokeWidth: 15,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                
                // 追加時間表示
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(_extraSeconds),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '追加時間',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          
          const SizedBox(height: 40),
          
          // コントロールボタン
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // リセットボタン
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _resetTimer,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('リセット'),
                  ],
                ),
              ),
              
              const SizedBox(width: 20),
              
              // スタート/一時停止ボタン
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    const SizedBox(width: 8),
                    Text(_isRunning ? '一時停止' : 'スタート'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    
    return Listener(
      onPointerDown: (_) {
        // ストップウォッチモードかつタイマー動作中かつ停止操作中でない場合のみカウント
        if (_currentMode == TimerMode.stopwatch && _isRunning && !_isStoppingStopwatch) {
          setState(() {
            _phoneInteractionCount++;
          });
          print('画面操作カウント: $_phoneInteractionCount');
        }
      },
      child: Scaffold(
        // AppBarの背景色をタスクの色に設定
        appBar: AppBar(
          backgroundColor: taskColor,
          foregroundColor: Colors.white,
          title: Text(widget.task.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
        body: Stack(
        children: [
          // メインコンテンツ
          mainContent,
          
          // 祈いアニメーションオーバーレイ
          if (_showCelebration)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 画像表示エリア
                            Container(
                              width: double.infinity,
                              height: 350,
                              margin: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // 背景に全画面表示kimi.gif
                                    Image.asset(
                                      'assets/images/kimi.gif',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        print('Error loading gif image: $error');
                                        return Container(
                                          color: Colors.amber.withOpacity(0.3),
                                          child: const Center(child: Text('おめでとう！', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),
                                        );
                                      },
                                    ),
                                    
                                    // 上に表示されるjunp-rat2.png - サイズを2倍にしてスライドインアニメーションを適用
                                    Center(
                                      child: SlideTransition(
                                        position: _ratSlideAnimation,
                                        child: Image.asset(
                                          'assets/images/junp-rat2.png',
                                          width: 400, // 幅を2倍に増やしました
                                          height: 400, // 高さを2倍に増やしました
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            print('Error loading rat image: $error');
                                            return const Icon(Icons.celebration, size: 300, color: Colors.amber); // エラー時のアイコンサイズも増やす
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // 達成メッセージ
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Column(
                                    children: [
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
