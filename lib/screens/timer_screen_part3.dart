  // ストップウォッチモードに切り替え
  void _switchToStopwatchMode() {
    _timer?.cancel();
    
    setState(() {
      _currentMode = TimerMode.stopwatch;
      _isRunning = false;
      _extraSeconds = 0;
      
      // カウントダウン終了後にストップウォッチ開始のオプションを出す場合は
      // 設定時間が経過したことを記録
      _remainingSeconds = 0;
      
      // アニメーションコントローラをリセット
      _animationController.reset();
    });
  }
  
  // 祝福アニメーションを表示
  void _showCelebrationAnimation() {
    setState(() {
      _showCelebration = true;
      
      // タスク完了時は時間を記録
      _endTime = DateTime.now();
    });
    
    // ラットがスライドインするアニメーション開始
    _ratAnimationController.forward().then((_) {
      // 祝福アニメーションを開始
      _celebrationController.repeat();
    });
  }
  
  // フォーマットされた時間を表示（00:00形式）
  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  // フォーマットされた時間を表示（ストップウォッチモード）
  String _formatStopwatchTime(int seconds) {
    // タイマーモードと逆の計算（開始時間からの経過時間）
    int elapsedSeconds = _currentMode == TimerMode.stopwatch
        ? _extraSeconds // ストップウォッチモードの場合は追加時間
        : _totalSeconds - _remainingSeconds; // カウントダウンモードでは残り時間を引く
        
    int hours = elapsedSeconds ~/ 3600;
    int minutes = (elapsedSeconds % 3600) ~/ 60;
    int secs = elapsedSeconds % 60;
    
    String hoursStr = hours > 0 ? '${hours.toString()}時間' : '';
    return '$hoursStr${minutes.toString().padLeft(2, '0')}分${secs.toString().padLeft(2, '0')}秒';
  }
  
  // 秒を日本語形式の時間に変換（例：25分, 1時間30分）
  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '$hours時間$minutes分';
    } else {
      return '$minutes分';
    }
  }

  // 集中度選択オプションを構築するメソッド
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

  // 集中レベルに応じた色を返すヘルパーメソッド
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
