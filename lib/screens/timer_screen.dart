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
  ConcentrationLevel? _concentrationLevel;
  
  // 集中レベル未選択エラーメッセージの表示フラグ
  bool _showConcentrationError = false;

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
    _ratAnimationController.dispose();
    _memoController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリがバックグラウンドになった場合
    if (state == AppLifecycleState.paused) {
      // タイマー実行中の場合は一時停止する
      if (_isRunning) {
        _pauseTimer();
      }
    }
  }
  
  void _startTimer() {
    setState(() {
      if (_remainingSeconds <= 0 && _currentMode == TimerMode.countdown) {
        // カウントダウンが終了している場合はリセット
        _resetTimer();
      }
      
      _isRunning = true;
      
      // 開始時間を記録（停止中に再開した場合は更新）
      if (_currentMode == TimerMode.stopwatch || _remainingSeconds == _totalSeconds) {
        _startTime = DateTime.now();
      }
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentMode == TimerMode.countdown) {
          // カウントダウンモード
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            _animationController.value = 1.0 - (_remainingSeconds / _totalSeconds);
          } else {
            _timer?.cancel();
            _isRunning = false;
            
            // 終了時間を記録
            _endTime = DateTime.now();
            
            // 達成お祝いアニメーションを表示
            _showCelebrationAnimation();
          }
        } else {
          // ストップウォッチモード
          _extraSeconds++;
        }
      });
    });
  }
  
  void _pauseTimer() {
    setState(() {
      _isRunning = false;
      _timer?.cancel();
      
      // ストップウォッチモードの場合、一時的にフラグをセット
      // （スマホを触った回数のカウントから除外するため）
      if (_currentMode == TimerMode.stopwatch) {
        _isStoppingStopwatch = true;
        
        // 少し遅延してフラグをリセット（ボタンタップのカウントを避けるため）
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _isStoppingStopwatch = false;
          });
        });
      }
      
      // タイマー停止時間を記録
      _endTime = DateTime.now();
    });
  }
  
  void _resetTimer() {
    setState(() {
      _isRunning = false;
      _timer?.cancel();
      _remainingSeconds = _totalSeconds;
      _extraSeconds = 0;
      _phoneInteractionCount = 0;
      _animationController.reset();
    });
  }
  
  void _saveSessionData() {
    // 既に保存済みの場合は処理しない
    if (_isSessionSaved) {
      return;
    }
    
    // 集中レベルが選択されていない場合は保存しない
    if (_concentrationLevel == null) {
      setState(() {
        _showConcentrationError = true;
      });
      return;
    }
    
    // セッションデータの保存
    final sessionService = Provider.of<SessionService>(context, listen: false);
    sessionService.saveSession(
      task: widget.task,
      startTime: _startTime,
      endTime: _endTime,
      concentrationLevel: _concentrationLevel!,
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
  
  void _switchToStopwatchMode() {
    if (_currentMode == TimerMode.countdown && !_isRunning) {
      setState(() {
        // ストップウォッチモードに変更
        _currentMode = TimerMode.stopwatch;
        
        // タイマーをリセット
        _timer?.cancel();
        _remainingSeconds = 0;
        _extraSeconds = 0;
        _phoneInteractionCount = 0;
        
        // アニメーションをリセット
        _animationController.reset();
      });
    }
  }
  
  void _showCelebrationAnimation() {
    setState(() {
      _showCelebration = true;
    });
    
    // ラットアニメーションを開始
    _ratAnimationController.forward();
  }
  
  String _formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  String _formatStopwatchTime(int seconds) {
    // 分:秒の表示形式
    if (seconds < 3600) {
      // 1時間未満の場合
      final int minutes = seconds ~/ 60;
      final int remainingSeconds = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      // 1時間以上の場合
      final int hours = seconds ~/ 3600;
      final int minutes = (seconds % 3600) ~/ 60;
      final int remainingSeconds = seconds % 60;
      return '${hours.toString()}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }
  
  String _formatDuration(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '$hours時間${minutes}分${remainingSeconds}秒';
    } else {
      return '$minutes分${remainingSeconds}秒';
    }
  }
  
  Widget _buildConcentrationOption(ConcentrationLevel level, String label) {
    final bool isSelected = _concentrationLevel == level;
    
    // 色を設定（選択状態によって変更）
    final Color backgroundColor = isSelected ? _getConcentrationColor(level) : Colors.grey.shade200;
    final Color textColor = isSelected ? Colors.white : Colors.black87;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _concentrationLevel = level;
          _showConcentrationError = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getConcentrationColor(ConcentrationLevel level) {
    switch (level) {
      case ConcentrationLevel.high:
        return Colors.green;
      case ConcentrationLevel.medium:
        return Colors.amber.shade700;
      case ConcentrationLevel.low:
        return Colors.red.shade400;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // 背景色とテキスト色を設定（モードによって変更）
    final backgroundColor = _currentMode == TimerMode.countdown
        ? Colors.blueGrey[900]
        : TaskColors.getColor(widget.task.colorKey).withOpacity(0.9);
    
    final textColor = _currentMode == TimerMode.countdown
        ? Colors.white
        : Colors.black;
    
    // 追加時間表示テキスト
    final String additionalTimeText = _currentMode == TimerMode.stopwatch
        ? '+${_formatTime(_extraSeconds)}'
        : '';
        
    return Scaffold(
      backgroundColor: backgroundColor,
      body: GestureDetector(
        // 画面タップ検知
        onTap: () {
          // ストップウォッチモード中かつ実行中の場合のみカウント
          if (_currentMode == TimerMode.stopwatch && _isRunning && !_isStoppingStopwatch) {
            setState(() {
              _phoneInteractionCount++;
              print('スマホタッチ: $_phoneInteractionCount回');
            });
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // タスク名表示
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.task.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // 時間表示
                  Expanded(
                    child: Center(
                      child: Text(
                        _currentMode == TimerMode.countdown
                            ? _formatTime(_remainingSeconds)
                            : _formatStopwatchTime(_totalSeconds + _extraSeconds),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  
                  // 追加時間表示
                  if (_currentMode == TimerMode.stopwatch && _extraSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        '追加時間: $additionalTimeText',
                        style: TextStyle(
                          fontSize: 18,
                          color: textColor,
                        ),
                      ),
                    ),
                  
                  // プログレスバー
                  if (_currentMode == TimerMode.countdown)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: LinearProgressIndicator(
                        value: _remainingSeconds / _totalSeconds,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          TaskColors.getColor(widget.task.colorKey),
                        ),
                        minHeight: 10,
                      ),
                    ),
                  
                  // 操作ボタン群
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // リセットボタン（停止時のみ表示）
                        if (!_isRunning || _currentMode == TimerMode.stopwatch)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('リセット'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: _resetTimer,
                          ),
                        
                        // 開始/一時停止ボタン
                        ElevatedButton.icon(
                          icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                          label: Text(_isRunning ? '一時停止' : '開始'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRunning ? Colors.orange : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                          onPressed: _isRunning ? _pauseTimer : _startTimer,
                        ),
                      ],
                    ),
                  ),
                  
                  // スマホタッチ回数表示
                  if (_currentMode == TimerMode.stopwatch)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'スマホを触った回数: $_phoneInteractionCount回',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                ],
              ),

              // 祝福アニメーションオーバーレイ
              if (_showCelebration)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Stack(
                      children: [
                        // 背景画像（kimi.gif）を全画面に確実に表示
                        Positioned.fill(
                          child: Stack(
                            children: [
                              // 背景画像（kimi.gif）を全画面覆うように表示
                              Positioned.fill(
                                child: Image(
                                  image: const AssetImage('assets/images/kimi.gif'),
                                  fit: BoxFit.cover, // coverで確実に全画面を覆う
                                ),
                              ),
                              // ラット画像を上部に配置（Alignment使用）
                              Align(
                                alignment: Alignment.topCenter, // 上部中央に配置
                                child: Padding(
                                  padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.05), // 上部から5%の位置（15%から5%に変更）
                                  child: SlideTransition(
                                    position: _ratSlideAnimation,
                                    child: Image.asset(
                                      'assets/images/junp-rat2.png',
                                      height: 400, // 200から400に変更（2倍）
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // ポップアップ本体を画面下部に配置
                        Positioned(
                          bottom: MediaQuery.of(context).size.height * 0.05,
                          left: MediaQuery.of(context).size.width * 0.075,
                          right: MediaQuery.of(context).size.width * 0.075,
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.52, // 0.4 * 1.3 = 0.52
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                // タスク達成バッジ（優先タスク用）
                                if (widget.task.isPriority)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('優先タスク達成!', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                const SizedBox(height: 8),
                                
                                // おめでとうメッセージ
                                Text(
                                  '${widget.task.name} 達成!!',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                
                                // タスク結果の詳細
                                Text(
                                  '続けた時間: ${_formatTime(widget.task.duration * 60 - _remainingSeconds)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 6),
                                
                                // スマホタッチ回数表示
                                Text(
                                  'スマホを触った回数: $_phoneInteractionCount回',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 6),
                                
                                // 集中度選択UI
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _showConcentrationError ? Colors.red : Colors.grey.shade300,
                                      width: _showConcentrationError ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '集中度を評価してください',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _showConcentrationError ? Colors.red : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildConcentrationOption(ConcentrationLevel.high, 'かなり集中できた'),
                                      _buildConcentrationOption(ConcentrationLevel.medium, '集中できた'),
                                      _buildConcentrationOption(ConcentrationLevel.low, '集中できなかった'),
                                      if (_showConcentrationError)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            'このタスクでの集中度を選択してください',
                                            style: TextStyle(color: Colors.red, fontSize: 14),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                
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
                                    maxLines: 2,
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                
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
                                    // 集中度が選択されていない場合はエラーメッセージを表示
                                    if (_concentrationLevel == null) {
                                      setState(() {
                                        _showConcentrationError = true;
                                      });
                                      return;
                                    }
                                    
                                    // セッションデータを保存
                                    _saveSessionData();
                                    
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
      ),
    );
  }
}
