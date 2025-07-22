import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/models/task_model.dart';
import 'package:micro_habit_runner/models/session_model.dart';
import 'package:micro_habit_runner/services/session_service.dart';
import 'package:micro_habit_runner/utils/task_colors.dart';

// タイマ�Eモード（タイマ�E/ストップウォチE���E�Eenum TimerMode { countdown, stopwatch }

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
  
  // セチE��ョンの開始�E終亁E��間を記録
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now();
  
  // 現在のタイマ�EモーチE  TimerMode _currentMode = TimerMode.countdown;
  
  // 画像�Eアニメーション用変数
  bool _showCelebration = false;
  
  // スマ�Eを触った回数をカウントする変数
  int _phoneInteractionCount = 0;
  
  // ストップウォチE��停止中フラグ�E�停止操作時のカウント除外用�E�E  bool _isStoppingStopwatch = false;
  
  // ラチE��画像�Eスライドインアニメーション用コントローラー
  late AnimationController _ratAnimationController;
  late Animation<Offset> _ratSlideAnimation;

  // メモ用チE��ストコントローラー
  final TextEditingController _memoController = TextEditingController();
  
  // セチE��ョンが保存済みかどぁE��のフラグ
  bool _isSessionSaved = false;
  
  // 雁E��レベル
  ConcentrationLevel? _concentrationLevel;
  
  // 雁E��レベル未選択エラーメチE��ージの表示フラグ
  bool _showConcentrationError = false;

  @override
  void initState() {
    super.initState();
    // AppLifecycleStateの監視を開姁E    WidgetsBinding.instance.addObserver(this);
    
    // 秒単位�E合計時間を計箁E    _totalSeconds = widget.task.duration * 60;
    _remainingSeconds = _totalSeconds;
    
    // アニメーションコントローラの設宁E    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );
    
    // 祝福アニメーション用のコントローラ設宁E    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _celebrationController.addListener(() {
      setState(() {}); // アニメーション値が変わるたびに画面を更新
    });
    
    // ラチE��画像�Eスライドアニメーション用コントローラーの設宁E    _ratAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // スライドインに1.5私E    );
    
    // 画面外から上にスライドインするアニメーション
    _ratSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5), // 画面下かめE      end: const Offset(0, 0), // 中央に
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
    // AppLifecycleStateの監視を終亁E    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _animationController.dispose();
    _celebrationController.dispose();
    _ratAnimationController.dispose(); // ラチE��アニメーションコントローラーも破棁E    _memoController.dispose(); // メモ用チE��ストコントローラーを破棁E    super.dispose();
  }
  
  // アプリがフォアグラウンチEバックグラウンドに刁E��替わる際�E処琁E  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 画面にタチE��したとみなす�Eはresumedの時�Eみ�E�アプリがフォアグラウンドに戻った時�E�E    if (state == AppLifecycleState.resumed) {
      if (_currentMode == TimerMode.stopwatch && _isRunning && !_isStoppingStopwatch) {
        setState(() {
          _phoneInteractionCount++;
          print('スマ�EタチE��: $_phoneInteractionCount囁E);
        });
      }
    }
  }
  
  // タイマ�E開姁E  void _startTimer() {
    if (_timer != null) {
      _timer!.cancel(); // 既存�Eタイマ�Eをキャンセル
    }
    
    setState(() {
      _isRunning = true;
      
      // 開始時間を記録�E��Eめて開始する場合�Eみ�E�E      if (_currentMode == TimerMode.countdown && _remainingSeconds == _totalSeconds ||
          _currentMode == TimerMode.stopwatch && _extraSeconds == 0) {
        _startTime = DateTime.now();
      }
    });
    
    _animationController.forward();
    
    // 1秒ごとにタイマ�Eを更新
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentMode == TimerMode.countdown) {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            _animationController.value = 1 - (_remainingSeconds / _totalSeconds);
          } else {
            // カウントダウン終亁E��
            _endTime = DateTime.now();
            _isRunning = false;
            _timer?.cancel();
            _showCelebrationAnimation();
          }
        } else {
          // ストップウォチE��モード�E場合�E時間を追加
          _extraSeconds++;
        }
      });
    });
  }
  
  // タイマ�E一時停止
  void _pauseTimer() {
    _timer?.cancel();
    _animationController.stop();
    
    setState(() {
      _isRunning = false;
      
      // ストップウォチE��を停止する場合�E、操作�EためのタチE��をカウントしなぁE��ぁE��ラグを立てめE      if (_currentMode == TimerMode.stopwatch) {
        _isStoppingStopwatch = true;
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _isStoppingStopwatch = false;
            });
          }
        });
      }
      
      // カウントダウンモードが終亁E��た場吁E      if (_currentMode == TimerMode.countdown && _remainingSeconds == 0) {
        // 終亁E��間を記録
        _endTime = DateTime.now();
        // 祝福アニメーションを表示
        _showCelebrationAnimation();
      }
    });
  }
  
  // タイマ�EリセチE��
  void _resetTimer() {
    _timer?.cancel();
    _animationController.reset();
    
    setState(() {
      _isRunning = false;
      if (_currentMode == TimerMode.countdown) {
        _remainingSeconds = _totalSeconds;
      } else {
        _extraSeconds = 0;
      }
    });
  }
  
  // セチE��ョンチE�EタをFirestoreに保孁E  void _saveSessionData() {
    // 雁E��レベルが選択されてぁE��ぁE��合�E保存しなぁE    if (_concentrationLevel == null) {
      setState(() {
        _showConcentrationError = true;
      });
      return;
    }
    
    // セチE��ョンがまだ保存されてぁE��ぁE��合�Eみ実衁E    if (!_isSessionSaved) {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      
      // セチE��ョン時間の計箁E      final duration = _currentMode == TimerMode.countdown
          ? _totalSeconds - _remainingSeconds // カウントダウンモードでは設定時間から�E減少�E
          : _totalSeconds + _extraSeconds; // ストップウォチE��モードでは設定時間＋追加時間
      
      // セチE��ョンチE�Eタ作�E
      final sessionData = SessionModel(
        id: '', // IDはサービス側で生�E
        taskId: widget.task.id,
        taskName: widget.task.name,
        scheduledTime: widget.task.scheduledTime,
        actualStartTime: _startTime,
        endTime: _endTime,
        plannedDuration: widget.task.duration,
        actualDuration: duration,
        touchCount: _phoneInteractionCount,
        onTimeStart: true, // こ�E値は後でサービス側で計算される
        concentrationLevel: _concentrationLevel!,
        memo: _memoController.text, // メモの冁E��を保孁E        createdAt: DateTime.now()
      );
      
      // Firestoreに保孁E      sessionService.saveSession(
        task: widget.task,
        startTime: _startTime,
        endTime: _endTime,
        concentrationLevel: _concentrationLevel!,
        memo: _memoController.text,
      ).then((_) {
        print('セチE��ョンチE�Eタを保存しました');
        setState(() {
          _isSessionSaved = true;
        });
      }).catchError((error) {
        print('セチE��ョンチE�Eタの保存に失敗しました: $error');
      });
    }
  }
  // ストップウォチE��モードに刁E��替ぁE  void _switchToStopwatchMode() {
    _timer?.cancel();
    
    setState(() {
      _currentMode = TimerMode.stopwatch;
      _isRunning = false;
      _extraSeconds = 0;
      
      // カウントダウン終亁E��にストップウォチE��開始�Eオプションを�Eす場合�E
      // 設定時間が経過したことを記録
      _remainingSeconds = 0;
      
      // アニメーションコントローラをリセチE��
      _animationController.reset();
    });
  }
  
  // 祝福アニメーションを表示
  void _showCelebrationAnimation() {
    setState(() {
      _showCelebration = true;
      
      // タスク完亁E��は時間を記録
      _endTime = DateTime.now();
    });
    
    // ラチE��がスライドインするアニメーション開姁E    _ratAnimationController.forward().then((_) {
      // 祝福アニメーションを開姁E      _celebrationController.repeat();
    });
  }
  
  // フォーマットされた時間を表示�E�E0:00形式！E  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  // フォーマットされた時間を表示�E�ストップウォチE��モード！E  String _formatStopwatchTime(int seconds) {
    // タイマ�Eモードと送E�E計算（開始時間から�E経過時間�E�E    int elapsedSeconds = _currentMode == TimerMode.stopwatch
        ? _extraSeconds // ストップウォチE��モード�E場合�E追加時間
        : _totalSeconds - _remainingSeconds; // カウントダウンモードでは残り時間を引く
        
    int hours = elapsedSeconds ~/ 3600;
    int minutes = (elapsedSeconds % 3600) ~/ 60;
    int secs = elapsedSeconds % 60;
    
    String hoursStr = hours > 0 ? '${hours.toString()}時間' : '';
    return '$hoursStr${minutes.toString().padLeft(2, '0')}刁E{secs.toString().padLeft(2, '0')}私E;
  }
  
  // 秒を日本語形式�E時間に変換�E�例！E5刁E 1時間30刁E��E  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '$hours時間$minutes刁E;
    } else {
      return '$minutes刁E;
    }
  }

  // 雁E��度選択オプションを構築するメソチE��
  Widget _buildConcentrationOption(ConcentrationLevel level, String label) {
    return InkWell(
      onTap: () {
        setState(() {
          _concentrationLevel = level;
          _showConcentrationError = false; // エラー表示をクリア
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Radio<ConcentrationLevel>(
              value: level,
              groupValue: _concentrationLevel,
              onChanged: (ConcentrationLevel? value) {
                setState(() {
                  _concentrationLevel = value;
                  _showConcentrationError = false; // エラー表示をクリア
                });
              },
              activeColor: _getConcentrationColor(level),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // 雁E��レベルに応じた色を返すヘルパ�EメソチE��
  Color _getConcentrationColor(ConcentrationLevel level) {
    switch (level) {
      case ConcentrationLevel.high:
        return Colors.green;
      case ConcentrationLevel.medium:
        return Colors.blue;
      case ConcentrationLevel.low:
        return Colors.red;
    }
  }
  @override
  Widget build(BuildContext context) {
    // 背景色とチE��スト色を設定（モードによって変更�E�E    final backgroundColor = _currentMode == TimerMode.countdown
        ? Colors.blueGrey[900]
        : TaskColors.getColor(widget.task.colorKey).withOpacity(0.9);
    
    final textColor = _currentMode == TimerMode.countdown
        ? Colors.white
        : Colors.black;
    
    // 追加時間表示チE��スチE    final String additionalTimeText = _currentMode == TimerMode.stopwatch
        ? '+${_formatTime(_extraSeconds)}'
        : '';
        
    return Scaffold(
      backgroundColor: backgroundColor,
      body: GestureDetector(
        // 画面タチE�E検知
        onTap: () {
          // ストップウォチE��モード中かつ実行中の場合�EみカウンチE          if (_currentMode == TimerMode.stopwatch && _isRunning && !_isStoppingStopwatch) {
            setState(() {
              _phoneInteractionCount++;
              print('スマ�EタチE��: $_phoneInteractionCount囁E);
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
                  
                  // プログレスバ�E
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
                  
                  // 操作�Eタン群
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // リセチE��ボタン�E�停止時�Eみ表示�E�E                        if (!_isRunning || _currentMode == TimerMode.stopwatch)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('リセチE��'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: _resetTimer,
                          ),
                        
                        // 開姁E一時停止ボタン
                        ElevatedButton.icon(
                          icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                          label: Text(_isRunning ? '一時停止' : '開姁E),
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
                  
                  // スマ�EタチE��回数表示
                  if (_currentMode == TimerMode.stopwatch)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'スマ�Eを触った回数: $_phoneInteractionCount囁E,
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                ],
              ),
              // 祝福アニメーションオーバ�Eレイ
              if (_showCelebration)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ラチE��のアニメーション
                              SlideTransition(
                                position: _ratSlideAnimation,
                                child: Image.asset(
                                  'assets/images/rat_celebration.png',
                                  height: 120,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // タスク達�Eバッジ�E�優先タスク用�E�E                              if (widget.task.isPriority)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('優先タスク達�E!', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              const SizedBox(height: 16),
                              
                              // おめでとぁE��チE��ージ
                              Text(
                                '${widget.task.name} 達�E!!',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              
                              // タスク結果の詳細
                              Text(
                                '続けた時閁E ${_formatTime(widget.task.duration * 60 - _remainingSeconds)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 15),
                              
                              // スマ�EタチE��回数表示
                              Text(
                                'スマ�Eを触った回数: $_phoneInteractionCount囁E,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 15),
                              // 雁E��度選択UI
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                      '雁E��度を評価してください',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _showConcentrationError ? Colors.red : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildConcentrationOption(ConcentrationLevel.high, 'かなり集中できた'),
                                    _buildConcentrationOption(ConcentrationLevel.medium, '雁E��できた'),
                                    _buildConcentrationOption(ConcentrationLevel.low, '雁E��できなかっぁE),
                                    if (_showConcentrationError)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          'こ�Eタスクでの雁E��度を選択してください',
                                          style: TextStyle(color: Colors.red, fontSize: 14),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              // メモ用チE��ストフィールドを追加
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  controller: _memoController,
                                  decoration: const InputDecoration(
                                    hintText: '感想めE��モを�E力してください',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  maxLines: 3,
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 閉じる�Eタン
                              ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('閉じめE),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: const TextStyle(fontSize: 18),
                                ),
                                onPressed: () {
                                  // 雁E��度が選択されてぁE��ぁE��合�EエラーメチE��ージを表示
                                  if (_concentrationLevel == null) {
                                    setState(() {
                                      _showConcentrationError = true;
                                    });
                                    return;
                                  }
                                  
                                  // セチE��ョンチE�Eタを保孁E                                  _saveSessionData();
                                  
                                  // ホ�Eム画面に戻る（�Eてのルートを削除してホ�Eムに移動！E                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/', // ホ�Eム画面のルーチE                                    (route) => false, // すべてのルートを削除
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
            ],
          ),
        ),
      ),
    );
  }
}
