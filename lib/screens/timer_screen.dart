import 'dart:async';
import 'package:flutter/material.dart';
import 'package:micro_habit_runner/models/task_model.dart';
import 'package:micro_habit_runner/utils/task_colors.dart';

class TimerScreen extends StatefulWidget {
  final TaskModel task;
  
  const TimerScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with TickerProviderStateMixin {
  late int _totalSeconds;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // タスクの持続時間を秒に変換
    _totalSeconds = widget.task.duration * 60;
    _remainingSeconds = _totalSeconds;
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );
    
    _animationController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    
    _animationController.reverse(
      from: _remainingSeconds / _totalSeconds,
    );
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isRunning = false;
          _timer?.cancel();
          _showCompletionDialog();
        }
      });
    });
  }

  void _pauseTimer() {
    setState(() {
      _isRunning = false;
    });
    _timer?.cancel();
    _animationController.stop();
  }

  void _resetTimer() {
    setState(() {
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
    });
    _timer?.cancel();
    _animationController.reset();
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('おめでとうございます！'),
        content: const Text('タイマーが完了しました。集中時間の記録を保存しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              // ここでタスク完了の記録を保存する処理を追加
              Navigator.pop(context);
              Navigator.pop(context); // タイマー画面を閉じる
            },
            child: const Text('保存する'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // タスクの色を取得
    final taskColor = TaskColors.getColor(widget.task.colorKey);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // タイマー表示
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
                // 時間表示
                Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w300,
                    color: taskColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            
            // コントロールボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_remainingSeconds < _totalSeconds && !_isRunning)
                  FloatingActionButton(
                    onPressed: _resetTimer,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.refresh, color: Colors.black54),
                  ),
                const SizedBox(width: 30),
                FloatingActionButton(
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  backgroundColor: taskColor,
                  child: Icon(
                    _isRunning ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                  elevation: 5,
                ),
              ],
            ),
            
            const SizedBox(height: 50),
            
            // 今日の日付表示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Today', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: taskColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: taskColor),
                      const SizedBox(width: 2),
                      Text(
                        '${DateTime.now().day}/${DateTime.now().month}',
                        style: TextStyle(
                          color: taskColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
