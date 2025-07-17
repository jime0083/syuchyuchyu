import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:micro_habit_runner/models/session_model.dart';
import 'package:micro_habit_runner/services/session_service.dart';
import 'package:micro_habit_runner/utils/task_colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];
  Map<String, dynamic> _totalStats = {};
  int _streakDays = 0;
  
  // 直近30日の日付とセッションマッピング
  final Map<DateTime, List<SessionModel>> _dailySessions = {};
  
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
      
      // セッションデータを取得
      print('履歴ページ: セッションデータの取得を開始');
      await sessionService.getSessions();
      _sessions = sessionService.sessions;
      print('履歴ページ: セッションデータ取得完了 - ${_sessions.length}件のセッション');
      
      if (_sessions.isNotEmpty) {
        for (var i = 0; i < _sessions.length && i < 3; i++) {
          print('セッション$i: ${_sessions[i].taskName}, 日付: ${_sessions[i].actualStartTime}, ID: ${_sessions[i].id}');
        }
      } else {
        print('履歴ページ: セッションデータが0件です');
      }
      
      // 累計統計を取得
      _totalStats = await sessionService.getTotalStats();
      print('履歴ページ: 累計統計取得完了 - タスク数: ${_totalStats['totalTasks']}, 合計時間: ${_totalStats['totalMinutes']}分, 連続日数: ${_totalStats['streakDays'] ?? 0}日');
      
      // 直近30日のセッションマッピングを作成
      _createDailySessionMapping();
      print('履歴ページ: 日付マッピング作成完了');
      
      // 連続達成日数を計算
      _calculateStreakDays();
      print('履歴ページ: 連続達成日数: $_streakDays日');
      
    } catch (e) {
      print('履歴データの読み込みエラー: $e');
      // エラー表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('履歴データの読み込みに失敗しました')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 直近30日のセッションマッピングを作成
  void _createDailySessionMapping() {
    _dailySessions.clear();
    
    // 今日から30日前までの日付を生成
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateWithoutTime = DateTime(date.year, date.month, date.day);
      _dailySessions[dateWithoutTime] = [];
    }
    
    // セッションを日付ごとにグループ化
    for (var session in _sessions) {
      final sessionDate = DateTime(
        session.actualStartTime.year,
        session.actualStartTime.month,
        session.actualStartTime.day,
      );
      
      // 30日以内のセッションのみ処理
      if (now.difference(sessionDate).inDays < 30) {
        _dailySessions[sessionDate] ??= [];
        _dailySessions[sessionDate]!.add(session);
      }
    }
  }
  
  // 連続達成日数を計算
  void _calculateStreakDays() {
    _streakDays = 0;
    
    // 日付でソートされた日次セッションマップを作成
    final sortedDates = SplayTreeMap<DateTime, List<SessionModel>>.from(
      _dailySessions,
      (a, b) => b.compareTo(a), // 降順（最新日付が最初）
    );
    
    // 今日の日付
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    
    bool breakStreak = false;
    DateTime checkDate = today;
    
    // 連続日数をカウント
    for (int i = 0; i < 365; i++) { // 最大1年分チェック
      final sessionsOnDate = sortedDates[checkDate] ?? [];
      
      if (sessionsOnDate.isNotEmpty) {
        // タスクが完了している日
        _streakDays++;
      } else {
        // タスク完了がない日（今日を除く）
        if (i > 0 || checkDate.isBefore(today)) {
          breakStreak = true;
          break;
        }
      }
      
      // 前日に移動
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('履歴'),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccumulationSection(),
                    const SizedBox(height: 32),
                    _buildLast30DaysSection(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
    );
  }
  
  // これまでの積み上げセクション
  Widget _buildAccumulationSection() {
    final totalTasks = _totalStats['totalTasks'] ?? 0;
    final totalMinutes = _totalStats['totalMinutes'] ?? 0;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'これまでの積み上げ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // タスクカードの積み重ね表示
            _buildTaskCardStack(),
            const SizedBox(height: 24),
            // 統計情報
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  icon: Icons.check_circle,
                  value: totalTasks.toString(),
                  label: '達成タスク',
                ),
                _buildStatItem(
                  icon: Icons.access_time,
                  value: '${totalMinutes.toString()}分',
                  label: '総タスク時間',
                ),
                _buildStatItem(
                  icon: Icons.local_fire_department,
                  value: _streakDays.toString(),
                  label: '連続日数',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // タスクカードの積み重ね表示
  Widget _buildTaskCardStack() {
    // 最新の5つのセッションを抽出
    final recentSessions = _sessions.take(5).toList();
    
    if (recentSessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'まだタスクの記録がありません',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(recentSessions.length, (index) {
          // インデックスが小さいほど下に、大きいほど上に表示
          final reverseIndex = recentSessions.length - 1 - index;
          final session = recentSessions[reverseIndex];
          
          // タスクカードの色を取得
          final colorKey = TaskColors.colorMap.keys.contains(session.taskId.hashCode % TaskColors.colorMap.length)
            ? TaskColors.colorMap.keys.elementAt(session.taskId.hashCode % TaskColors.colorMap.length)
            : TaskColors.defaultColorKey;
          
          final cardColor = TaskColors.colorMap[colorKey]!;
          
          return Positioned(
            // 上に行くほど少しずつ上にオフセット
            top: index * 8.0,
            child: Transform.rotate(
              // わずかにランダムな角度を付ける
              angle: (index * 0.05) * (index % 2 == 0 ? 1 : -1),
              child: SizedBox(
                width: 240,
                height: 80,
                child: Card(
                  color: cardColor,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          session.taskName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('yyyy/MM/dd').format(session.actualStartTime),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
  
  // 統計情報アイテム
  Widget _buildStatItem({
    required IconData icon, 
    required String value, 
    required String label
  }) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
  
  // 直近30日の履歴セクション
  Widget _buildLast30DaysSection() {
    // 日付でソートされた日次セッションマップを作成 (新しい順)
    final sortedDates = SplayTreeMap<DateTime, List<SessionModel>>.from(
      _dailySessions,
      (a, b) => b.compareTo(a), // 降順
    );
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '直近30日の履歴',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // カレンダーグリッド
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: 30,
              itemBuilder: (context, index) {
                // sortedDatesのキーを取得（日付）
                final date = sortedDates.keys.elementAt(index);
                final sessions = sortedDates[date] ?? [];
                
                // 優先タスクの有無を確認
                final hasPriorityTask = sessions.any((session) {
                  // セッションの実際のタスクデータが必要。現在のモデルでは対応できない場合はUIだけ実装
                  // 実際のアプリではTaskServiceを使ってタスク情報を取得する実装が必要
                  return false; // 暫定的にfalse
                });
                
                return _buildDateBlock(date, sessions, hasPriorityTask);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // 日付ブロックウィジェット
  Widget _buildDateBlock(DateTime date, List<SessionModel> sessions, bool hasPriorityTask) {
    // セッションがあるかどうか
    final hasSession = sessions.isNotEmpty;
    
    // セッションがある場合はタスクの色を使用、ない場合は白
    Color blockColor = Colors.grey.shade100;
    
    if (hasSession && sessions.isNotEmpty) {
      // セッションからタスクIDを取得し、色に変換
      final taskId = sessions.first.taskId;
      String colorKey = 'orange'; // デフォルトの色
      
      // データベースから取得した色情報がない場合はハッシュコードを使用して割り当て
      final availableColorKeys = TaskColors.colorMap.keys.toList();
      if (availableColorKeys.isNotEmpty) {
        colorKey = availableColorKeys[taskId.hashCode % availableColorKeys.length];
      }
      
      blockColor = TaskColors.colorMap[colorKey] ?? Colors.orange;
    }
    
    // セッションから優先タスクかどうかを確認
    // 現在のセッションモデルには優先タスクの情報が含まれていないため、タスク名から推定
    bool isPriorityTask = false;
    if (sessions.isNotEmpty) {
      // 優先タスクを示すタスク名の特徴（例: 「重要」「優先」「★」などが含まれている場合）
      // ここでは簡単な例として、メモに「優先」が含まれている場合は優先タスクとして処理
      for (var session in sessions) {
        if (session.memo.contains('優先') || 
            session.taskName.contains('優先') || 
            session.taskName.contains('重要') || 
            session.taskName.contains('★')) {
          isPriorityTask = true;
          break;
        }
      }
    }
    
    return Container(
      decoration: BoxDecoration(
        color: hasSession ? blockColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: hasSession ? Colors.white : Colors.black,
              ),
            ),
          ),
          if (isPriorityTask)
            const Positioned(
              top: 2,
              right: 2,
              child: Icon(
                Icons.star,
                color: Colors.yellow,
                size: 14,
              ),
            ),
        ],
      ),
    );
  }
  
  // アクションボタン
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bar_chart),
            label: const Text('タスク別データ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              // TODO: タスク別データ画面に遷移
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('タスク別データは近日公開予定です')),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.psychology),
            label: const Text('集中の傾向'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              // TODO: 集中の傾向画面に遷移
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('集中の傾向は近日公開予定です')),
              );
            },
          ),
        ),
      ],
    );
  }
}
