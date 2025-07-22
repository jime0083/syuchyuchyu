import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/models/session_model.dart';
import 'package:micro_habit_runner/models/task_model.dart';
import 'package:micro_habit_runner/services/session_service.dart';
import 'package:micro_habit_runner/services/task_service.dart';
import 'package:micro_habit_runner/utils/task_colors.dart';

class TaskStatsScreen extends StatefulWidget {
  final String taskId;

  const TaskStatsScreen({Key? key, required this.taskId}) : super(key: key);

  @override
  State<TaskStatsScreen> createState() => _TaskStatsScreenState();
}

class _TaskStatsScreenState extends State<TaskStatsScreen> {
  bool _isLoading = true;
  List<SessionModel> _taskSessions = [];
  TaskModel? _task;
  
  // 統計データ
  int _totalSessions = 0;
  int _onTimePercentage = 0;
  double _averageTouchCount = 0;
  Map<String, int> _concentrationBreakdown = {
    'high': 0,  // とても集中できた
    'medium': 0, // 集中できた
    'low': 0,    // 集中できなかった
  };
  
  // 直近30日のセッションマッピング
  final Map<DateTime, bool> _last30DaysSessions = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      // 初期値を設定しておく（データがないケースに備えて）
      _totalSessions = 0;
      _onTimePercentage = 0;
      _averageTouchCount = 0;
      _concentrationBreakdown = {'high': 0, 'medium': 0, 'low': 0};
      _last30DaysSessions.clear();
    });

    try {
      // Firebaseの初期化状態を確認
      print('Firebaseの初期化状態確認...');
      
      // セッションサービスとタスクサービスを取得
      final sessionService = Provider.of<SessionService>(context, listen: false);
      final taskService = Provider.of<TaskService>(context, listen: false);
      
      // タスク情報を取得
      print('タスク情報の取得を開始します - ID: ${widget.taskId}');
      await taskService.getTasks();
      
      try {
        _task = taskService.tasks.firstWhere(
          (task) => task.id == widget.taskId,
          orElse: () => throw Exception('Task not found'),
        );
        print('タスク取得成功: ${_task!.name}, カラー: ${_task!.colorKey}');
      } catch (e) {
        print('タスク取得エラー: $e');
        // エラー時の対応（UIに影響しないよう最低限のデータは設定）
        _task = TaskModel(
          id: widget.taskId,
          name: 'Unknown Task',
          scheduledTime: '00:00',
          duration: 0,
          isPriority: false,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          colorKey: 'blue',
          weekdays: ['毎日'],
        );
      }
      
      // 複数の方法でセッションデータ取得を試みる
      print('セッションデータの取得を開始 - 方法1: getSessionsByTask');
      _taskSessions = await sessionService.getSessionsByTask(widget.taskId);
      
      if (_taskSessions.isEmpty) {
        print('方法1でセッション取得できず、方法2: refreshAndGetSessionsByTask を試行');
        _taskSessions = await sessionService.refreshAndGetSessionsByTask(widget.taskId);
        
        // それでもデータが取得できない場合の確認
        if (_taskSessions.isEmpty) {
          print('方法2でもセッション取得できず。バックアップ方法を試行: 全セッション取得後フィルタリング');
          // 全セッションを取得してメモリ上でフィルタリング
          List<SessionModel> allSessions = await sessionService.getAllSessions();
          _taskSessions = allSessions.where((s) => s.taskId == widget.taskId).toList();
          print('バックアップ方法でのセッション取得結果: ${_taskSessions.length}件');
        }
      }
      
      // 検出されたセッション数をUIに反映
      _totalSessions = _taskSessions.length;
      print('タスク統計: セッション取得完了 - ${_taskSessions.length}件');
      
      // セッションの詳細をデバッグ出力
      if (_taskSessions.isNotEmpty) {
        print('タスク統計: 最初のセッション - ${_taskSessions.first.id}');
        print('  開始時間: ${_taskSessions.first.actualStartTime}');
        print('  タスクID: ${_taskSessions.first.taskId}');
        
        print('全セッションデータ:');
        for (int i = 0; i < _taskSessions.length; i++) {
          var session = _taskSessions[i];
          print('  [$i] ID: ${session.id}, タスクID: ${session.taskId}, 時間: ${session.actualStartTime}, タッチ: ${session.touchCount}, 集中度: ${session.concentrationLevel}');
        }
      } else {
        print('タスク統計: セッションデータがありません - このタスクは一度も完了していない可能性があります');
      }
      
      // 各種統計を計算
      print('統計情報の計算を開始');
      _calculateStatistics();
      
      // 直近30日のセッション情報を作成
      print('直近30日マッピングの作成を開始');
      _createLast30DaysMapping();
      
      // 最終的な統計情報をログ出力
      print('タスク統計 (最終結果) - 累計: $_totalSessions, 時間通り率: $_onTimePercentage%, タッチ回数: $_averageTouchCount');
      print('タスク統計 (最終結果) - 集中度 - 高: ${_concentrationBreakdown["high"]}, 中: ${_concentrationBreakdown["medium"]}, 低: ${_concentrationBreakdown["low"]}');
    } catch (e) {
      print('タスク統計の読み込み中にエラー発生: $e');
      print('スタックトレース: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込み中にエラーが発生しました: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 統計データを計算
  void _calculateStatistics() {
    // セッションがない場合は0にしておく
    if (_taskSessions.isEmpty) {
      print('タスク統計: セッションデータがないため統計は0になります');
      _onTimePercentage = 0;
      _averageTouchCount = 0;
      _concentrationBreakdown = {'high': 0, 'medium': 0, 'low': 0};
      return;
    }
    
    print('タスク統計: 統計計算開始 - ${_taskSessions.length}件のセッションデータを処理します');
    
    // 時間通りに開始したセッションの割合を計算（計画時間の前後5分以内）
    int onTimeCount = 0;
    
    // 平均タップ回数
    int totalTouchCount = 0;
    
    // 集中度の内訳
    int highConcentration = 0;
    int mediumConcentration = 0;
    int lowConcentration = 0;
    
    for (var session in _taskSessions) {
      // 時間通りかどうかをチェック（計画時間の前後5分以内）
      if (session.scheduledTime != null && session.scheduledTime.isNotEmpty) {
        final scheduledTimeParts = session.scheduledTime.split(':');
        if (scheduledTimeParts.length == 2) {
          final scheduledHour = int.parse(scheduledTimeParts[0]);
          final scheduledMinute = int.parse(scheduledTimeParts[1]);
          
          final scheduledDateTime = DateTime(
            session.actualStartTime.year,
            session.actualStartTime.month,
            session.actualStartTime.day,
            scheduledHour,
            scheduledMinute,
          );
          
          final difference = session.actualStartTime.difference(scheduledDateTime).inMinutes.abs();
          if (difference <= 5) {
            onTimeCount++;
          }
        }
      }
      
      // タップ回数を累積
      totalTouchCount += session.touchCount;
      
      // 集中度をカウント
      if (session.concentrationLevel != null) {
        switch (session.concentrationLevel) {
          case ConcentrationLevel.high:
            highConcentration++;
            break;
          case ConcentrationLevel.medium:
            mediumConcentration++;
            break;
          case ConcentrationLevel.low:
            lowConcentration++;
            break;
          default:
            // null値や想定外の値の場合は何もしない
            break;
        }
      }
    }
    
    // 統計データを設定
    _onTimePercentage = (_taskSessions.isEmpty) 
        ? 0 
        : ((onTimeCount / _taskSessions.length) * 100).round();
    
    _averageTouchCount = (_taskSessions.isEmpty) 
        ? 0 
        : totalTouchCount / _taskSessions.length;
    
    // 集中度の割合
    _concentrationBreakdown = {
      'high': highConcentration,
      'medium': mediumConcentration,
      'low': lowConcentration,
    };
    
    print('タスク統計: 計算結果 - 時間通り率: $_onTimePercentage%, 平均タッチ: $_averageTouchCount');
    print('タスク統計: 集中度内訳 - 高: $highConcentration, 中: $mediumConcentration, 低: $lowConcentration');
  }

  // 直近30日のセッションマッピングを作成
  void _createLast30DaysMapping() {
    final now = DateTime.now();
    _last30DaysSessions.clear();
    
    // 過去30日分の日付を生成
    for (int i = 29; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      _last30DaysSessions[date] = false;
    }
    
    // セッションがある日付にフラグを立てる
    for (var session in _taskSessions) {
      final sessionDate = DateTime(
        session.actualStartTime.year, 
        session.actualStartTime.month, 
        session.actualStartTime.day
      );
      
      // 過去30日以内のセッションかチェック
      final difference = now.difference(sessionDate).inDays;
      if (difference <= 29) {
        _last30DaysSessions[sessionDate] = true;
        print('タスク統計: セッション検出 ${sessionDate.toString().split(' ')[0]}');
      }
    }
    
    print('タスク統計: 直近30日のマッピング作成完了 - ${_last30DaysSessions.values.where((v) => v).length}日にタスク達成あり');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_task?.name ?? 'タスク詳細'),
        backgroundColor: _task != null 
            ? TaskColors.getColor(_task!.colorKey)
            : Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTaskHeader(),
                  const SizedBox(height: 24),
                  _buildTotalAchievements(),
                  const SizedBox(height: 24),
                  _buildStatistics(),
                  const SizedBox(height: 24),
                  _buildLast30DaysCalendar(),
                  const SizedBox(height: 24),
                  _buildConcentrationChart(),
                ],
              ),
            ),
    );
  }

  // タスクヘッダー情報
  Widget _buildTaskHeader() {
    if (_task == null) return const SizedBox();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  color: TaskColors.getColor(_task!.colorKey),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _task!.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_task!.isPriority)
                  const Icon(Icons.star, color: Colors.amber, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_task!.scheduledTime} (${_task!.duration}分)',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(
                  _task!.weekdays.join(', '),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 累計達成セクションの構築
  Widget _buildTotalAchievements() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '累計達成',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  // 発生したエラーがあれば記録しておく
                  Builder(builder: (context) {
                    print('累計達成表示時のデータ: $_totalSessions');
                    return Text(
                      _totalSessions.toString(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Text(
                    '回達成',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 統計情報の構築
  Widget _buildStatistics() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '統計情報',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Builder(builder: (context) {
                    print('統計情報表示時の時間通り率データ: $_onTimePercentage%');
                    return _buildStatItem(
                      icon: Icons.schedule,
                      label: '時間通り率',
                      value: '$_onTimePercentage%',
                    );
                  }),
                ),
                Expanded(
                  child: Builder(builder: (context) {
                    print('統計情報表示時の平均タッチ回数データ: ${_averageTouchCount.toStringAsFixed(1)}');
                    return _buildStatItem(
                      icon: Icons.touch_app,
                      label: '平均タッチ回数',
                      value: _averageTouchCount.toStringAsFixed(1),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 統計アイテム
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _task != null 
                  ? TaskColors.getColor(_task!.colorKey)
                  : Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // 直近30日のカレンダー
  Widget _buildLast30DaysCalendar() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '直近30日の達成状況',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 3行×10列のグリッドに変更
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10, // 横10個
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: 30,
              itemBuilder: (context, index) {
                // 日付の順番を調整（古い日付が上、新しい日付が下になるように）
                // 0-9: 最初の行（20日前～29日前）
                // 10-19: 中間の行（10日前～19日前）
                // 20-29: 最新の行（0日前～9日前）
                final int row = index ~/ 10; // 行番号（0, 1, 2）
                final int col = index % 10;  // 列番号（0-9）
                
                // 日数計算（29-0日前に対応）
                final daysAgo = 29 - (row * 10 + col);
                final date = DateTime.now().subtract(Duration(days: daysAgo));
                final dateKey = DateTime(date.year, date.month, date.day);
                final hasSession = _last30DaysSessions[dateKey] ?? false;
                
                return Container(
                  decoration: BoxDecoration(
                    color: hasSession 
                        ? (_task != null ? TaskColors.getColor(_task!.colorKey) : Theme.of(context).primaryColor)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: hasSession ? Colors.white : Colors.grey[600],
                          ),
                        ),
                        // 各行の最初の要素（0, 10, 20）に月表示を追加
                        if (col == 0) 
                          Text(
                            '${date.month}月',
                            style: TextStyle(
                              fontSize: 10,
                              color: hasSession ? Colors.white.withOpacity(0.8) : Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _task != null 
                        ? TaskColors.getColor(_task!.colorKey)
                        : Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('タスク達成日'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 集中度グラフ
  Widget _buildConcentrationChart() {
    // 総数を計算
    final total = _concentrationBreakdown['high']! + 
                  _concentrationBreakdown['medium']! + 
                  _concentrationBreakdown['low']!;
    
    print('集中度評価表示時のデータ - 高: ${_concentrationBreakdown['high']}, 中: ${_concentrationBreakdown['medium']}, 低: ${_concentrationBreakdown['low']}, 合計: $total');
    
    // パーセンテージを計算（小数点以下も保持してより正確に）
    final highPercent = total > 0 ? (_concentrationBreakdown['high']! / total * 100).round() : 0;
    final mediumPercent = total > 0 ? (_concentrationBreakdown['medium']! / total * 100).round() : 0;
    final lowPercent = total > 0 ? (_concentrationBreakdown['low']! / total * 100).round() : 0;

    print('集中度パーセンテージ - 高: $highPercent%, 中: $mediumPercent%, 低: $lowPercent%');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '集中度評価',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('データがありません'),
                ),
              )
            else
              Column(
                children: [
                  _buildConcentrationBar(
                    label: 'とても集中できた',
                    percent: highPercent,
                    color: Colors.green,
                    count: _concentrationBreakdown['high']!,
                  ),
                  const SizedBox(height: 12),
                  _buildConcentrationBar(
                    label: '集中できた',
                    percent: mediumPercent,
                    color: Colors.blue,
                    count: _concentrationBreakdown['medium']!,
                  ),
                  const SizedBox(height: 12),
                  _buildConcentrationBar(
                    label: '集中できなかった',
                    percent: lowPercent,
                    color: Colors.red,
                    count: _concentrationBreakdown['low']!,
                  ),
                  const SizedBox(height: 16),
                  // 集中度の説明を追加
                  Text(
                    '集中できた・とても集中できた: ${highPercent + mediumPercent}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // 集中度バー
  Widget _buildConcentrationBar({
    required String label,
    required int percent,
    required Color color,
    required int count,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '($count回)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 12,
          ),
        ),
      ],
    );
  }
}
