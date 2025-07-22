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
  
  // アプリがフォアグラウンド/バックグラウンドに切り替わる際の処理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 画面にタッチしたとみなすのはresumedの時のみ（アプリがフォアグラウンドに戻った時）
    if (state == AppLifecycleState.resumed) {
      if (_currentMode == TimerMode.stopwatch && _isRunning && !_isStoppingStopwatch) {
        setState(() {
          _phoneInteractionCount++;
          print('スマホタッチ: $_phoneInteractionCount回');
        });
      }
    }
  }
  
  // タイマー開始
  void _startTimer() {
    if (_timer != null) {
      _timer!.cancel(); // 既存のタイマーをキャンセル
    }
    
    setState(() {
      _isRunning = true;
      
      // 開始時間を記録（初めて開始する場合のみ）
      if (_currentMode == TimerMode.countdown && _remainingSeconds == _totalSeconds ||
          _currentMode == TimerMode.stopwatch && _extraSeconds == 0) {
        _startTime = DateTime.now();
      }
    });
    
    _animationController.forward();
    
    // 1秒ごとにタイマーを更新
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentMode == TimerMode.countdown) {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            _animationController.value = 1 - (_remainingSeconds / _totalSeconds);
          } else {
            // カウントダウン終了時
            _endTime = DateTime.now();
            _isRunning = false;
            _timer?.cancel();
            _showCelebrationAnimation();
          }
        } else {
          // ストップウォッチモードの場合は時間を追加
          _extraSeconds++;
        }
      });
    });
  }
  
  // タイマー一時停止
  void _pauseTimer() {
    _timer?.cancel();
    _animationController.stop();
    
    setState(() {
      _isRunning = false;
      
      // ストップウォッチを停止する場合は、操作のためのタッチをカウントしないようフラグを立てる
      if (_currentMode == TimerMode.stopwatch) {
        _isStoppingStopwatch = true;
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _isStoppingStopwatch = false;
            });
          }
        });
      }
      
      // カウントダウンモードが終了した場合
      if (_currentMode == TimerMode.countdown && _remainingSeconds == 0) {
        // 終了時間を記録
        _endTime = DateTime.now();
        // 祝福アニメーションを表示
        _showCelebrationAnimation();
      }
    });
  }
  
  // タイマーリセット
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
  
  // セッションデータをFirestoreに保存
  void _saveSessionData() {
    // 集中レベルが選択されていない場合は保存しない
    if (_concentrationLevel == null) {
      setState(() {
        _showConcentrationError = true;
      });
      return;
    }
    
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
        concentrationLevel: _concentrationLevel!,
        memo: _memoController.text, // メモの内容を保存
        createdAt: DateTime.now()
      );
      
      // Firestoreに保存
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
  }
