import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/models/task_model.dart';
import 'package:micro_habit_runner/models/session_model.dart';
import 'package:micro_habit_runner/services/session_service.dart';
import 'package:micro_habit_runner/utils/task_colors.dart';

// 繧ｿ繧､繝槭・繝｢繝ｼ繝会ｼ医ち繧､繝槭・/繧ｹ繝医ャ繝励え繧ｩ繝・メ・・enum TimerMode { countdown, stopwatch }

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
  
  // 繧ｻ繝・す繝ｧ繝ｳ縺ｮ髢句ｧ九・邨ゆｺ・凾髢薙ｒ險倬鹸
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now();
  
  // 迴ｾ蝨ｨ縺ｮ繧ｿ繧､繝槭・繝｢繝ｼ繝・  TimerMode _currentMode = TimerMode.countdown;
  
  // 逕ｻ蜒上・繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ逕ｨ螟画焚
  bool _showCelebration = false;
  
  // 繧ｹ繝槭・繧定ｧｦ縺｣縺溷屓謨ｰ繧偵き繧ｦ繝ｳ繝医☆繧句､画焚
  int _phoneInteractionCount = 0;
  
  // 繧ｹ繝医ャ繝励え繧ｩ繝・メ蛛懈ｭ｢荳ｭ繝輔Λ繧ｰ・亥●豁｢謫堺ｽ懈凾縺ｮ繧ｫ繧ｦ繝ｳ繝磯勁螟也畑・・  bool _isStoppingStopwatch = false;
  
  // 繝ｩ繝・ヨ逕ｻ蜒上・繧ｹ繝ｩ繧､繝峨う繝ｳ繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ逕ｨ繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ繝ｼ
  late AnimationController _ratAnimationController;
  late Animation<Offset> _ratSlideAnimation;

  // 繝｡繝｢逕ｨ繝・く繧ｹ繝医さ繝ｳ繝医Ο繝ｼ繝ｩ繝ｼ
  final TextEditingController _memoController = TextEditingController();
  
  // 繧ｻ繝・す繝ｧ繝ｳ縺御ｿ晏ｭ俶ｸ医∩縺九←縺・°縺ｮ繝輔Λ繧ｰ
  bool _isSessionSaved = false;
  
  // 髮・ｸｭ繝ｬ繝吶Ν
  ConcentrationLevel? _concentrationLevel;
  
  // 髮・ｸｭ繝ｬ繝吶Ν譛ｪ驕ｸ謚槭お繝ｩ繝ｼ繝｡繝・そ繝ｼ繧ｸ縺ｮ陦ｨ遉ｺ繝輔Λ繧ｰ
  bool _showConcentrationError = false;

  @override
  void initState() {
    super.initState();
    // AppLifecycleState縺ｮ逶｣隕悶ｒ髢句ｧ・    WidgetsBinding.instance.addObserver(this);
    
    // 遘貞腰菴阪・蜷郁ｨ域凾髢薙ｒ險育ｮ・    _totalSeconds = widget.task.duration * 60;
    _remainingSeconds = _totalSeconds;
    
    // 繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ縺ｮ險ｭ螳・    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );
    
    // 逾晉ｦ上い繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ逕ｨ縺ｮ繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ險ｭ螳・    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _celebrationController.addListener(() {
      setState(() {}); // 繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ蛟､縺悟､峨ｏ繧九◆縺ｳ縺ｫ逕ｻ髱｢繧呈峩譁ｰ
    });
    
    // 繝ｩ繝・ヨ逕ｻ蜒上・繧ｹ繝ｩ繧､繝峨い繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ逕ｨ繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ繝ｼ縺ｮ險ｭ螳・    _ratAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // 繧ｹ繝ｩ繧､繝峨う繝ｳ縺ｫ1.5遘・    );
    
    // 逕ｻ髱｢螟悶°繧我ｸ翫↓繧ｹ繝ｩ繧､繝峨う繝ｳ縺吶ｋ繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ
    _ratSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5), // 逕ｻ髱｢荳九°繧・      end: const Offset(0, 0), // 荳ｭ螟ｮ縺ｫ
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
    // AppLifecycleState縺ｮ逶｣隕悶ｒ邨ゆｺ・    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _animationController.dispose();
    _celebrationController.dispose();
    _ratAnimationController.dispose(); // 繝ｩ繝・ヨ繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ繝ｼ繧らｴ譽・    _memoController.dispose(); // 繝｡繝｢逕ｨ繝・く繧ｹ繝医さ繝ｳ繝医Ο繝ｼ繝ｩ繝ｼ繧堤ｴ譽・    super.dispose();
  }
  
  // 繧｢繝励Μ縺後ヵ繧ｩ繧｢繧ｰ繝ｩ繧ｦ繝ｳ繝・繝舌ャ繧ｯ繧ｰ繝ｩ繧ｦ繝ｳ繝峨↓蛻・ｊ譖ｿ繧上ｋ髫帙・蜃ｦ逅・  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 逕ｻ髱｢縺ｫ繧ｿ繝・メ縺励◆縺ｨ縺ｿ縺ｪ縺吶・縺ｯresumed縺ｮ譎ゅ・縺ｿ・医い繝励Μ縺後ヵ繧ｩ繧｢繧ｰ繝ｩ繧ｦ繝ｳ繝峨↓謌ｻ縺｣縺滓凾・・    if (state == AppLifecycleState.resumed) {
      if (_currentMode == TimerMode.stopwatch && _isRunning && !_isStoppingStopwatch) {
        setState(() {
          _phoneInteractionCount++;
          print('繧ｹ繝槭・繧ｿ繝・メ: $_phoneInteractionCount蝗・);
        });
      }
    }
  }
  
  // 繧ｿ繧､繝槭・髢句ｧ・  void _startTimer() {
    if (_timer != null) {
      _timer!.cancel(); // 譌｢蟄倥・繧ｿ繧､繝槭・繧偵く繝｣繝ｳ繧ｻ繝ｫ
    }
    
    setState(() {
      _isRunning = true;
      
      // 髢句ｧ区凾髢薙ｒ險倬鹸・亥・繧√※髢句ｧ九☆繧句ｴ蜷医・縺ｿ・・      if (_currentMode == TimerMode.countdown && _remainingSeconds == _totalSeconds ||
          _currentMode == TimerMode.stopwatch && _extraSeconds == 0) {
        _startTime = DateTime.now();
      }
    });
    
    _animationController.forward();
    
    // 1遘偵＃縺ｨ縺ｫ繧ｿ繧､繝槭・繧呈峩譁ｰ
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentMode == TimerMode.countdown) {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            _animationController.value = 1 - (_remainingSeconds / _totalSeconds);
          } else {
            // 繧ｫ繧ｦ繝ｳ繝医ム繧ｦ繝ｳ邨ゆｺ・凾
            _endTime = DateTime.now();
            _isRunning = false;
            _timer?.cancel();
            _showCelebrationAnimation();
          }
        } else {
          // 繧ｹ繝医ャ繝励え繧ｩ繝・メ繝｢繝ｼ繝峨・蝣ｴ蜷医・譎る俣繧定ｿｽ蜉
          _extraSeconds++;
        }
      });
    });
  }
  
  // 繧ｿ繧､繝槭・荳譎ょ●豁｢
  void _pauseTimer() {
    _timer?.cancel();
    _animationController.stop();
    
    setState(() {
      _isRunning = false;
      
      // 繧ｹ繝医ャ繝励え繧ｩ繝・メ繧貞●豁｢縺吶ｋ蝣ｴ蜷医・縲∵桃菴懊・縺溘ａ縺ｮ繧ｿ繝・メ繧偵き繧ｦ繝ｳ繝医＠縺ｪ縺・ｈ縺・ヵ繝ｩ繧ｰ繧堤ｫ九※繧・      if (_currentMode == TimerMode.stopwatch) {
        _isStoppingStopwatch = true;
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _isStoppingStopwatch = false;
            });
          }
        });
      }
      
      // 繧ｫ繧ｦ繝ｳ繝医ム繧ｦ繝ｳ繝｢繝ｼ繝峨′邨ゆｺ・＠縺溷ｴ蜷・      if (_currentMode == TimerMode.countdown && _remainingSeconds == 0) {
        // 邨ゆｺ・凾髢薙ｒ險倬鹸
        _endTime = DateTime.now();
        // 逾晉ｦ上い繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ繧定｡ｨ遉ｺ
        _showCelebrationAnimation();
      }
    });
  }
  
  // 繧ｿ繧､繝槭・繝ｪ繧ｻ繝・ヨ
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
  
  // 繧ｻ繝・す繝ｧ繝ｳ繝・・繧ｿ繧巽irestore縺ｫ菫晏ｭ・  void _saveSessionData() {
    // 髮・ｸｭ繝ｬ繝吶Ν縺碁∈謚槭＆繧後※縺・↑縺・ｴ蜷医・菫晏ｭ倥＠縺ｪ縺・    if (_concentrationLevel == null) {
      setState(() {
        _showConcentrationError = true;
      });
      return;
    }
    
    // 繧ｻ繝・す繝ｧ繝ｳ縺後∪縺菫晏ｭ倥＆繧後※縺・↑縺・ｴ蜷医・縺ｿ螳溯｡・    if (!_isSessionSaved) {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      
      // 繧ｻ繝・す繝ｧ繝ｳ譎る俣縺ｮ險育ｮ・      final duration = _currentMode == TimerMode.countdown
          ? _totalSeconds - _remainingSeconds // 繧ｫ繧ｦ繝ｳ繝医ム繧ｦ繝ｳ繝｢繝ｼ繝峨〒縺ｯ險ｭ螳壽凾髢薙°繧峨・貂帛ｰ大・
          : _totalSeconds + _extraSeconds; // 繧ｹ繝医ャ繝励え繧ｩ繝・メ繝｢繝ｼ繝峨〒縺ｯ險ｭ螳壽凾髢難ｼ玖ｿｽ蜉譎る俣
      
      // 繧ｻ繝・す繝ｧ繝ｳ繝・・繧ｿ菴懈・
      final sessionData = SessionModel(
        id: '', // ID縺ｯ繧ｵ繝ｼ繝薙せ蛛ｴ縺ｧ逕滓・
        taskId: widget.task.id,
        taskName: widget.task.name,
        scheduledTime: widget.task.scheduledTime,
        actualStartTime: _startTime,
        endTime: _endTime,
        plannedDuration: widget.task.duration,
        actualDuration: duration,
        touchCount: _phoneInteractionCount,
        onTimeStart: true, // 縺薙・蛟､縺ｯ蠕後〒繧ｵ繝ｼ繝薙せ蛛ｴ縺ｧ險育ｮ励＆繧後ｋ
        concentrationLevel: _concentrationLevel!,
        memo: _memoController.text, // 繝｡繝｢縺ｮ蜀・ｮｹ繧剃ｿ晏ｭ・        createdAt: DateTime.now()
      );
      
      // Firestore縺ｫ菫晏ｭ・      sessionService.saveSession(
        task: widget.task,
        startTime: _startTime,
        endTime: _endTime,
        concentrationLevel: _concentrationLevel!,
        memo: _memoController.text,
      ).then((_) {
        print('繧ｻ繝・す繝ｧ繝ｳ繝・・繧ｿ繧剃ｿ晏ｭ倥＠縺ｾ縺励◆');
        setState(() {
          _isSessionSaved = true;
        });
      }).catchError((error) {
        print('繧ｻ繝・す繝ｧ繝ｳ繝・・繧ｿ縺ｮ菫晏ｭ倥↓螟ｱ謨励＠縺ｾ縺励◆: $error');
      });
    }
  }
  // 繧ｹ繝医ャ繝励え繧ｩ繝・メ繝｢繝ｼ繝峨↓蛻・ｊ譖ｿ縺・  void _switchToStopwatchMode() {
    _timer?.cancel();
    
    setState(() {
      _currentMode = TimerMode.stopwatch;
      _isRunning = false;
      _extraSeconds = 0;
      
      // 繧ｫ繧ｦ繝ｳ繝医ム繧ｦ繝ｳ邨ゆｺ・ｾ後↓繧ｹ繝医ャ繝励え繧ｩ繝・メ髢句ｧ九・繧ｪ繝励す繝ｧ繝ｳ繧貞・縺吝ｴ蜷医・
      // 險ｭ螳壽凾髢薙′邨碁℃縺励◆縺薙→繧定ｨ倬鹸
      _remainingSeconds = 0;
      
      // 繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ繧ｳ繝ｳ繝医Ο繝ｼ繝ｩ繧偵Μ繧ｻ繝・ヨ
      _animationController.reset();
    });
  }
  
  // 逾晉ｦ上い繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ繧定｡ｨ遉ｺ
  void _showCelebrationAnimation() {
    setState(() {
      _showCelebration = true;
      
      // 繧ｿ繧ｹ繧ｯ螳御ｺ・凾縺ｯ譎る俣繧定ｨ倬鹸
      _endTime = DateTime.now();
    });
    
    // 繝ｩ繝・ヨ縺後せ繝ｩ繧､繝峨う繝ｳ縺吶ｋ繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ髢句ｧ・    _ratAnimationController.forward().then((_) {
      // 逾晉ｦ上い繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ繧帝幕蟋・      _celebrationController.repeat();
    });
  }
  
  // 繝輔か繝ｼ繝槭ャ繝医＆繧後◆譎る俣繧定｡ｨ遉ｺ・・0:00蠖｢蠑擾ｼ・  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  // 繝輔か繝ｼ繝槭ャ繝医＆繧後◆譎る俣繧定｡ｨ遉ｺ・医せ繝医ャ繝励え繧ｩ繝・メ繝｢繝ｼ繝会ｼ・  String _formatStopwatchTime(int seconds) {
    // 繧ｿ繧､繝槭・繝｢繝ｼ繝峨→騾・・險育ｮ暦ｼ磯幕蟋区凾髢薙°繧峨・邨碁℃譎る俣・・    int elapsedSeconds = _currentMode == TimerMode.stopwatch
        ? _extraSeconds // 繧ｹ繝医ャ繝励え繧ｩ繝・メ繝｢繝ｼ繝峨・蝣ｴ蜷医・霑ｽ蜉譎る俣
        : _totalSeconds - _remainingSeconds; // 繧ｫ繧ｦ繝ｳ繝医ム繧ｦ繝ｳ繝｢繝ｼ繝峨〒縺ｯ谿九ｊ譎る俣繧貞ｼ輔￥
        
    int hours = elapsedSeconds ~/ 3600;
    int minutes = (elapsedSeconds % 3600) ~/ 60;
    int secs = elapsedSeconds % 60;
    
    String hoursStr = hours > 0 ? '${hours.toString()}譎る俣' : '';
    return '$hoursStr${minutes.toString().padLeft(2, '0')}蛻・{secs.toString().padLeft(2, '0')}遘・;
  }
  
  // 遘偵ｒ譌･譛ｬ隱槫ｽ｢蠑上・譎る俣縺ｫ螟画鋤・井ｾ具ｼ・5蛻・ 1譎る俣30蛻・ｼ・  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '$hours譎る俣$minutes蛻・;
    } else {
      return '$minutes蛻・;
    }
  }

  // 髮・ｸｭ蠎ｦ驕ｸ謚槭が繝励す繝ｧ繝ｳ繧呈ｧ狗ｯ峨☆繧九Γ繧ｽ繝・ラ
  Widget _buildConcentrationOption(ConcentrationLevel level, String label) {
    return InkWell(
      onTap: () {
        setState(() {
          _concentrationLevel = level;
          _showConcentrationError = false; // 繧ｨ繝ｩ繝ｼ陦ｨ遉ｺ繧偵け繝ｪ繧｢
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
                  _showConcentrationError = false; // 繧ｨ繝ｩ繝ｼ陦ｨ遉ｺ繧偵け繝ｪ繧｢
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

  // 髮・ｸｭ繝ｬ繝吶Ν縺ｫ蠢懊§縺溯牡繧定ｿ斐☆繝倥Ν繝代・繝｡繧ｽ繝・ラ
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
    // 閭梧勹濶ｲ縺ｨ繝・く繧ｹ繝郁牡繧定ｨｭ螳夲ｼ医Δ繝ｼ繝峨↓繧医▲縺ｦ螟画峩・・    final backgroundColor = _currentMode == TimerMode.countdown
        ? Colors.blueGrey[900]
        : TaskColors.getColor(widget.task.colorKey).withOpacity(0.9);
    
    final textColor = _currentMode == TimerMode.countdown
        ? Colors.white
        : Colors.black;
    
    // 霑ｽ蜉譎る俣陦ｨ遉ｺ繝・く繧ｹ繝・    final String additionalTimeText = _currentMode == TimerMode.stopwatch
        ? '+${_formatTime(_extraSeconds)}'
        : '';
        
    return Scaffold(
      backgroundColor: backgroundColor,
      body: GestureDetector(
        // 逕ｻ髱｢繧ｿ繝・・讀懃衍
        onTap: () {
          // 繧ｹ繝医ャ繝励え繧ｩ繝・メ繝｢繝ｼ繝我ｸｭ縺九▽螳溯｡御ｸｭ縺ｮ蝣ｴ蜷医・縺ｿ繧ｫ繧ｦ繝ｳ繝・          if (_currentMode == TimerMode.stopwatch && _isRunning && !_isStoppingStopwatch) {
            setState(() {
              _phoneInteractionCount++;
              print('繧ｹ繝槭・繧ｿ繝・メ: $_phoneInteractionCount蝗・);
            });
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 繧ｿ繧ｹ繧ｯ蜷崎｡ｨ遉ｺ
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
                  
                  // 譎る俣陦ｨ遉ｺ
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
                  
                  // 霑ｽ蜉譎る俣陦ｨ遉ｺ
                  if (_currentMode == TimerMode.stopwatch && _extraSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        '霑ｽ蜉譎る俣: $additionalTimeText',
                        style: TextStyle(
                          fontSize: 18,
                          color: textColor,
                        ),
                      ),
                    ),
                  
                  // 繝励Ο繧ｰ繝ｬ繧ｹ繝舌・
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
                  
                  // 謫堺ｽ懊・繧ｿ繝ｳ鄒､
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 繝ｪ繧ｻ繝・ヨ繝懊ち繝ｳ・亥●豁｢譎ゅ・縺ｿ陦ｨ遉ｺ・・                        if (!_isRunning || _currentMode == TimerMode.stopwatch)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('繝ｪ繧ｻ繝・ヨ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: _resetTimer,
                          ),
                        
                        // 髢句ｧ・荳譎ょ●豁｢繝懊ち繝ｳ
                        ElevatedButton.icon(
                          icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                          label: Text(_isRunning ? '荳譎ょ●豁｢' : '髢句ｧ・),
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
                  
                  // 繧ｹ繝槭・繧ｿ繝・メ蝗樊焚陦ｨ遉ｺ
                  if (_currentMode == TimerMode.stopwatch)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        '繧ｹ繝槭・繧定ｧｦ縺｣縺溷屓謨ｰ: $_phoneInteractionCount蝗・,
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                ],
              ),
              // 逾晉ｦ上い繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ繧ｪ繝ｼ繝舌・繝ｬ繧､
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
                              // 繝ｩ繝・ヨ縺ｮ繧｢繝九Γ繝ｼ繧ｷ繝ｧ繝ｳ
                              SlideTransition(
                                position: _ratSlideAnimation,
                                child: Image.asset(
                                  'assets/images/rat_celebration.png',
                                  height: 120,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 繧ｿ繧ｹ繧ｯ驕疲・繝舌ャ繧ｸ・亥━蜈医ち繧ｹ繧ｯ逕ｨ・・                              if (widget.task.isPriority)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('蜆ｪ蜈医ち繧ｹ繧ｯ驕疲・!', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              const SizedBox(height: 16),
                              
                              // 縺翫ａ縺ｧ縺ｨ縺・Γ繝・そ繝ｼ繧ｸ
                              Text(
                                '${widget.task.name} 驕疲・!!',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              
                              // 繧ｿ繧ｹ繧ｯ邨先棡縺ｮ隧ｳ邏ｰ
                              Text(
                                '邯壹￠縺滓凾髢・ ${_formatTime(widget.task.duration * 60 - _remainingSeconds)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 15),
                              
                              // 繧ｹ繝槭・繧ｿ繝・メ蝗樊焚陦ｨ遉ｺ
                              Text(
                                '繧ｹ繝槭・繧定ｧｦ縺｣縺溷屓謨ｰ: $_phoneInteractionCount蝗・,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 15),
                              // 髮・ｸｭ蠎ｦ驕ｸ謚朸I
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
                                      '髮・ｸｭ蠎ｦ繧定ｩ穂ｾ｡縺励※縺上□縺輔＞',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _showConcentrationError ? Colors.red : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildConcentrationOption(ConcentrationLevel.high, '縺九↑繧企寔荳ｭ縺ｧ縺阪◆'),
                                    _buildConcentrationOption(ConcentrationLevel.medium, '髮・ｸｭ縺ｧ縺阪◆'),
                                    _buildConcentrationOption(ConcentrationLevel.low, '髮・ｸｭ縺ｧ縺阪↑縺九▲縺・),
                                    if (_showConcentrationError)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          '縺薙・繧ｿ繧ｹ繧ｯ縺ｧ縺ｮ髮・ｸｭ蠎ｦ繧帝∈謚槭＠縺ｦ縺上□縺輔＞',
                                          style: TextStyle(color: Colors.red, fontSize: 14),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              // 繝｡繝｢逕ｨ繝・く繧ｹ繝医ヵ繧｣繝ｼ繝ｫ繝峨ｒ霑ｽ蜉
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  controller: _memoController,
                                  decoration: const InputDecoration(
                                    hintText: '諢滓Φ繧・Γ繝｢繧貞・蜉帙＠縺ｦ縺上□縺輔＞',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  maxLines: 3,
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // 髢峨§繧九・繧ｿ繝ｳ
                              ElevatedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('髢峨§繧・),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: const TextStyle(fontSize: 18),
                                ),
                                onPressed: () {
                                  // 髮・ｸｭ蠎ｦ縺碁∈謚槭＆繧後※縺・↑縺・ｴ蜷医・繧ｨ繝ｩ繝ｼ繝｡繝・そ繝ｼ繧ｸ繧定｡ｨ遉ｺ
                                  if (_concentrationLevel == null) {
                                    setState(() {
                                      _showConcentrationError = true;
                                    });
                                    return;
                                  }
                                  
                                  // 繧ｻ繝・す繝ｧ繝ｳ繝・・繧ｿ繧剃ｿ晏ｭ・                                  _saveSessionData();
                                  
                                  // 繝帙・繝逕ｻ髱｢縺ｫ謌ｻ繧具ｼ亥・縺ｦ縺ｮ繝ｫ繝ｼ繝医ｒ蜑企勁縺励※繝帙・繝縺ｫ遘ｻ蜍包ｼ・                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/', // 繝帙・繝逕ｻ髱｢縺ｮ繝ｫ繝ｼ繝・                                    (route) => false, // 縺吶∋縺ｦ縺ｮ繝ｫ繝ｼ繝医ｒ蜑企勁
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
