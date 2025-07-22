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
