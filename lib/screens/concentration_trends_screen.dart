import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/models/session_model.dart';
import 'package:micro_habit_runner/services/session_service.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class ConcentrationTrendsScreen extends StatefulWidget {
  const ConcentrationTrendsScreen({Key? key}) : super(key: key);

  @override
  State<ConcentrationTrendsScreen> createState() => _ConcentrationTrendsScreenState();
}

class _ConcentrationTrendsScreenState extends State<ConcentrationTrendsScreen> {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];
  
  // 分析結果
  Map<int, double> _touchesPerHour = {};  // 時間帯ごとの平均タッチ回数
  Map<int, double> _focusRatePerHour = {}; // 時間帯ごとの集中度高/中の割合
  Map<int, double> _focusRateByDuration = {}; // タスク時間別の集中度高/中の割合
  String? _difficultWeekday; // 集中しにくい曜日
  int? _difficultHour; // 集中しにくい時間

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      
      // すべてのセッションデータを取得
      await sessionService.getSessions();
      _sessions = sessionService.sessions;
      
      if (_sessions.isNotEmpty) {
        _analyzeData();
      }
    } catch (e) {
      print('集中傾向分析エラー: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _analyzeData() {
    if (_sessions.isEmpty) return;

    // 時間帯ごとのセッション分類（0-23時）
    Map<int, List<SessionModel>> sessionsByHour = {};
    for (int i = 0; i < 24; i++) {
      sessionsByHour[i] = [];
    }
    
    // タスク時間（分）ごとのセッション分類
    Map<int, List<SessionModel>> sessionsByDuration = {};
    Set<int> durations = _sessions.map((s) => s.plannedDuration).toSet();
    for (int duration in durations) {
      sessionsByDuration[duration] = [];
    }

    // 曜日・時間ごとのセッション分類
    Map<int, Map<int, List<SessionModel>>> sessionsByWeekdayAndHour = {};
    for (int weekday = 1; weekday <= 7; weekday++) {
      sessionsByWeekdayAndHour[weekday] = {};
      for (int hour = 0; hour < 24; hour++) {
        sessionsByWeekdayAndHour[weekday]![hour] = [];
      }
    }

    // セッションを分類
    for (var session in _sessions) {
      // 開始時間の時間帯を取得
      int hour = session.actualStartTime.hour;
      sessionsByHour[hour]!.add(session);
      
      // タスク時間で分類
      sessionsByDuration[session.plannedDuration]!.add(session);
      
      // 曜日と時間で分類
      int weekday = session.actualStartTime.weekday;
      sessionsByWeekdayAndHour[weekday]![hour]!.add(session);
    }

    // 1. 時間帯ごとのスマホを触った回数の平均を計算
    _touchesPerHour = {};
    sessionsByHour.forEach((hour, hourSessions) {
      if (hourSessions.isNotEmpty) {
        double avgTouches = hourSessions.map((s) => s.touchCount).reduce((a, b) => a + b) / hourSessions.length;
        _touchesPerHour[hour] = avgTouches;
      }
    });

    // スマホを触った回数が最も少ない時間帯を特定
    int? bestHourByTouches;
    double? lowestTouches;
    _touchesPerHour.forEach((hour, avgTouches) {
      if (lowestTouches == null || avgTouches < lowestTouches!) {
        lowestTouches = avgTouches;
        bestHourByTouches = hour;
      }
    });

    // 2. 時間帯ごとの「集中できた/非常に集中できた」の割合を計算
    _focusRatePerHour = {};
    sessionsByHour.forEach((hour, hourSessions) {
      if (hourSessions.isNotEmpty) {
        int focusedCount = hourSessions.where((s) => 
            s.concentrationLevel == ConcentrationLevel.medium || 
            s.concentrationLevel == ConcentrationLevel.high).length;
        _focusRatePerHour[hour] = focusedCount / hourSessions.length;
      }
    });

    // 集中度が最も高い時間帯を特定
    int? bestHourByFocus;
    double? highestFocusRate;
    _focusRatePerHour.forEach((hour, focusRate) {
      if (highestFocusRate == null || focusRate > highestFocusRate!) {
        highestFocusRate = focusRate;
        bestHourByFocus = hour;
      }
    });

    // 3. タスク時間ごとの「集中できた/非常に集中できた」の割合を計算
    _focusRateByDuration = {};
    sessionsByDuration.forEach((duration, durationSessions) {
      if (durationSessions.isNotEmpty) {
        int focusedCount = durationSessions.where((s) => 
            s.concentrationLevel == ConcentrationLevel.medium || 
            s.concentrationLevel == ConcentrationLevel.high).length;
        _focusRateByDuration[duration] = focusedCount / durationSessions.length;
      }
    });

    // 集中度が最も高いタスク時間を特定
    int? bestDuration;
    double? highestDurationFocusRate;
    _focusRateByDuration.forEach((duration, focusRate) {
      if (highestDurationFocusRate == null || focusRate > highestDurationFocusRate!) {
        highestDurationFocusRate = focusRate;
        bestDuration = duration;
      }
    });

    // 4. 集中しにくい曜日と時間帯の分析（タスク数が300以上の場合のみ）
    if (_sessions.length >= 300) {
      Map<int, Map<int, double>> touchRateByWeekdayAndHour = {};
      Map<int, Map<int, double>> lowFocusRateByWeekdayAndHour = {};
      
      sessionsByWeekdayAndHour.forEach((weekday, hourData) {
        touchRateByWeekdayAndHour[weekday] = {};
        lowFocusRateByWeekdayAndHour[weekday] = {};
        
        hourData.forEach((hour, sessions) {
          if (sessions.isNotEmpty) {
            // スマホを触った回数の平均
            double avgTouches = sessions.map((s) => s.touchCount).reduce((a, b) => a + b) / sessions.length;
            touchRateByWeekdayAndHour[weekday]![hour] = avgTouches;
            
            // 「集中できなかった」の割合
            int lowFocusCount = sessions.where((s) => s.concentrationLevel == ConcentrationLevel.low).length;
            lowFocusRateByWeekdayAndHour[weekday]![hour] = lowFocusCount / sessions.length;
          }
        });
      });
      
      // 両方のスコアを合計して最も高い（=集中しにくい）曜日と時間を特定
      double highestCombinedScore = -1;
      
      touchRateByWeekdayAndHour.forEach((weekday, hourData) {
        hourData.forEach((hour, touchRate) {
          double? lowFocusRate = lowFocusRateByWeekdayAndHour[weekday]?[hour];
          if (lowFocusRate != null) {
            // スコアは「スマホのタッチ回数」+「集中できなかった率」で評価
            double combinedScore = touchRate + lowFocusRate * 100; // 重み付け
            
            if (combinedScore > highestCombinedScore) {
              highestCombinedScore = combinedScore;
              _difficultWeekday = _getWeekdayName(weekday);
              _difficultHour = hour;
            }
          }
        });
      });
    }
  }
  
  String _getWeekdayName(int weekday) {
    const Map<int, String> weekdayNames = {
      1: '月曜日',
      2: '火曜日',
      3: '水曜日',
      4: '木曜日',
      5: '金曜日',
      6: '土曜日',
      7: '日曜日',
    };
    return weekdayNames[weekday] ?? '不明';
  }

  String _formatHour(int hour) {
    return '$hour:00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('集中力の傾向'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _sessions.isEmpty
          ? const Center(child: Text('タスクデータがありません'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    title: 'スマホ操作が少ない時間帯',
                    icon: Icons.smartphone_outlined,
                    content: _touchesPerHour.isNotEmpty 
                      ? _formatHour(_getBestHourByLowestTouches())
                      : 'データ不足',
                    description: 'この時間帯のタスクでは、スマホを触る回数が最も少ない傾向があります。',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildInfoCard(
                    title: '集中しやすい時間帯',
                    icon: Icons.psychology,
                    content: _focusRatePerHour.isNotEmpty
                      ? _formatHour(_getBestHourByHighestFocusRate())
                      : 'データ不足',
                    description: 'この時間帯のタスクで「集中できた」または「非常に集中できた」と評価する割合が高い傾向があります。',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildInfoCard(
                    title: '集中しやすいタスク時間',
                    icon: Icons.timer,
                    content: _focusRateByDuration.isNotEmpty
                      ? '${_getBestDurationByFocusRate()}分'
                      : 'データ不足',
                    description: 'この長さのタスクで「集中できた」または「非常に集中できた」と評価する割合が高い傾向があります。',
                  ),
                  
                  if (_sessions.length >= 300 && _difficultWeekday != null && _difficultHour != null) ...[
                    const SizedBox(height: 16),
                    
                    _buildInfoCard(
                      title: '集中しにくい傾向',
                      icon: Icons.warning_amber_rounded,
                      content: '$_difficultWeekday $_difficultHour:00',
                      description: 'この時間帯はスマホを触る回数が多く、「集中できなかった」と評価する割合も高い傾向があります。',
                      isNegative: true,
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  _buildDataSummary(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String content,
    required String description,
    bool isNegative = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isNegative ? Colors.orange : Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isNegative ? Colors.orange : Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDataSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分析情報',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '分析したタスク: ${_sessions.length}件',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '分析期間: ${DateFormat('yyyy/MM/dd').format(_sessions.last.actualStartTime)} - ${DateFormat('yyyy/MM/dd').format(_sessions.first.actualStartTime)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            if (_sessions.length < 300) ...[
              const SizedBox(height: 12),
              Text(
                'より詳細な分析には300件以上のタスクデータが必要です (現在: ${_sessions.length}件)',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  int _getBestHourByLowestTouches() {
    int bestHour = 0;
    double lowestTouches = double.infinity;
    
    _touchesPerHour.forEach((hour, avgTouches) {
      if (avgTouches < lowestTouches) {
        lowestTouches = avgTouches;
        bestHour = hour;
      }
    });
    
    return bestHour;
  }
  
  int _getBestHourByHighestFocusRate() {
    int bestHour = 0;
    double highestFocusRate = -1;
    
    _focusRatePerHour.forEach((hour, focusRate) {
      if (focusRate > highestFocusRate) {
        highestFocusRate = focusRate;
        bestHour = hour;
      }
    });
    
    return bestHour;
  }
  
  int _getBestDurationByFocusRate() {
    int bestDuration = 0;
    double highestFocusRate = -1;
    
    _focusRateByDuration.forEach((duration, focusRate) {
      if (focusRate > highestFocusRate) {
        highestFocusRate = focusRate;
        bestDuration = duration;
      }
    });
    
    return bestDuration;
  }
}
