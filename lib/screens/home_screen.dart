import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/models/user_model.dart';
import 'package:micro_habit_runner/services/auth_service.dart';
import 'package:micro_habit_runner/services/task_service.dart';
import 'package:micro_habit_runner/services/ad_service.dart';
import 'package:micro_habit_runner/utils/app_theme.dart';
import 'package:micro_habit_runner/utils/task_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // タスクを取得
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TaskService>(context, listen: false).getTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final taskService = Provider.of<TaskService>(context);
    final userModel = authService.userModel;
    final isLoggedIn = authService.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        // タイトルを削除
        // 右上に3つのアイコンボタンを追加
        actions: [
          // 履歴ページのノートアイコン
          IconButton(
            icon: const Icon(Icons.note_alt_outlined),
            onPressed: () {
              _showHistoryPopup(context);
            },
            tooltip: '履歴',
          ),
          // 使い方のコツの角帽アイコン
          IconButton(
            icon: const Icon(Icons.school_outlined),
            onPressed: () {
              _showTipsPopup(context);
            },
            tooltip: '使い方のコツ',
          ),
          // 設定の歯車アイコン
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              _showSettingsPopup(context);
            },
            tooltip: '設定',
          ),
        ],
      ),
      body: Column(
        children: [
          // メインコンテンツ
          Expanded(
            child: _buildHomeContent(context, userModel, taskService),
          ),
          // 広告バナー - 必要に応じて表示
          Consumer<AdService>(
            builder: (context, adService, child) {
              return adService.getBannerWidget();
            },
          ),
        ],
      ),
      // FloatingActionButton
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton(
          onPressed: () {
            _showAddTaskDialog(context, userModel);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, UserModel? user, TaskService taskService) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isLoggedIn = authService.isLoggedIn;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: taskService.tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'タスクがありません',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('右下の+ボタンからタスクを追加しましょう'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: taskService.tasks.length,
                    itemBuilder: (context, index) {
                      final task = taskService.tasks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Checkbox(
                            value: !task.isActive,
                            onChanged: (value) async {
                              // タスクの有効/無効を切り替える
                              final updatedTask = task.copyWith(isActive: !(task.isActive));
                              await taskService.updateTask(updatedTask);
                            },
                          ),
                          title: Text(
                            task.name,
                            style: TextStyle(
                              decoration: !task.isActive
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text('${task.scheduledTime} (${task.duration}分)'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (task.isPriority)
                                const Icon(Icons.star, color: Colors.amber),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  _showEditTaskDialog(context, task);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  _showDeleteConfirmation(context, task.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 設定状態を管理する変数
  bool _notificationsEnabled = false;
  bool _darkModeEnabled = false;
  
  void _showAddTaskDialog(BuildContext context, UserModel? user) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final taskService = Provider.of<TaskService>(context, listen: false);
    final isLoggedIn = authService.isLoggedIn;
    
    // ゲストユーザーで既にタスクがある場合はログインを促す
    if (!isLoggedIn && taskService.hasGuestTask) {
      final emailController = TextEditingController();
      final passwordController = TextEditingController();
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('ログインが必要です'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('追加のタスクを登録するにはログインが必要です。'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'メールアドレス',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      try {
                        await authService.signInWithEmail(
                          emailController.text.trim(), 
                          passwordController.text
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          // ログイン成功後、タスク追加ダイアログを再表示
                          _showAddTaskDialog(context, authService.userModel);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ログインエラー: ${e.toString()}')),
                        );
                      }
                    },
                    child: const Text('ログイン', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.login),
                    label: const Text('Googleアカウントでログイン'),
                    onPressed: () async {
                      try {
                        await authService.signInWithGoogle();
                        if (context.mounted) {
                          Navigator.pop(context);
                          // ログイン成功後、タスク追加ダイアログを再表示
                          _showAddTaskDialog(context, authService.userModel);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Googleログインエラー: ${e.toString()}')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
                child: const Text('キャンセル'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    
    // ログインしていてもユーザーデータがない場合
    if (isLoggedIn && user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報を読み込み中です。後ほどお試しください')),
      );
      return;
    }
    
    final nameController = TextEditingController();
    String selectedTime = '09:00';
    int selectedDuration = 30;
    bool isPriority = false;
    String selectedColorKey = TaskColors.defaultColorKey;
    List<String> selectedWeekdays = ['毎日'];

    // 所要時間の選択肢
    final List<int> durationOptions = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '新しいタスクを追加',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                // タスク名と色選択
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'タスク名',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: TaskColors.getColor(selectedColorKey)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () {
                          _showColorPickerDialog(context, selectedColorKey, (colorKey) {
                            setState(() {
                              selectedColorKey = colorKey;
                            });
                          });
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: TaskColors.getColor(selectedColorKey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.color_lens, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // いつやる？（曜日選択）
                const Text('いつやる？', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  childAspectRatio: 2.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: TaskColors.weekdays.map((weekday) {
                    final isSelected = selectedWeekdays.contains(weekday);
                    
                    return SizedBox(
                      height: 32, // 固定の高さを設定
                      child: FilterChip(
                        label: Text(weekday),
                        selected: isSelected,
                        selectedColor: TaskColors.getColor(selectedColorKey).withOpacity(0.7),
                        onSelected: (selected) {
                          setState(() {
                            if (weekday == '毎日') {
                              // 「毎日」が選択された場合は他の曜日をクリア
                              if (selected) {
                                selectedWeekdays = ['毎日'];
                              } else {
                                selectedWeekdays.remove('毎日');
                              }
                            } else {
                              // 他の曜日が選択された場合は「毎日」を自動的に除外
                              if (selected) {
                                // 「毎日」が選択されていたら自動的に外す
                                if (selectedWeekdays.contains('毎日')) {
                                  selectedWeekdays.remove('毎日');
                                }
                                selectedWeekdays.add(weekday);
                              } else {
                                selectedWeekdays.remove(weekday);
                              }
                              
                              // 何も選択されていない場合は「毎日」を選択
                              if (selectedWeekdays.isEmpty) {
                                selectedWeekdays.add('毎日');
                              }
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                
                // 何時からやる？
                const Text('何時からやる？', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: TaskColors.getColor(selectedColorKey)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // 時間選択
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 40,
                          selectionOverlay: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: TaskColors.getColor(selectedColorKey).withOpacity(0.2),
                              border: Border.symmetric(
                                horizontal: BorderSide(color: TaskColors.getColor(selectedColorKey), width: 1.5),
                              ),
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                          onSelectedItemChanged: (index) {
                            final hour = index + 0;
                            final hourStr = hour.toString().padLeft(2, '0');
                            final minute = selectedTime.split(':')[1];
                            setState(() {
                              selectedTime = '$hourStr:$minute';
                            });
                          },
                          children: List.generate(24, (index) {
                            return Center(
                              child: Text(
                                '${index.toString().padLeft(2, '0')}時',
                                style: const TextStyle(fontSize: 20),
                              ),
                            );
                          }),
                          scrollController: FixedExtentScrollController(
                            initialItem: int.parse(selectedTime.split(':')[0]),
                          ),
                        ),
                      ),
                      // 分選択
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 40,
                          selectionOverlay: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: TaskColors.getColor(selectedColorKey).withOpacity(0.2),
                              border: Border.symmetric(
                                horizontal: BorderSide(color: TaskColors.getColor(selectedColorKey), width: 1.5),
                              ),
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                          onSelectedItemChanged: (index) {
                            final minute = index * 5;
                            final minuteStr = minute.toString().padLeft(2, '0');
                            final hour = selectedTime.split(':')[0];
                            setState(() {
                              selectedTime = '$hour:$minuteStr';
                            });
                          },
                          children: List.generate(12, (index) {
                            final minute = index * 5;
                            return Center(
                              child: Text(
                                '${minute.toString().padLeft(2, '0')}分',
                                style: const TextStyle(fontSize: 20),
                              ),
                            );
                          }),
                          scrollController: FixedExtentScrollController(
                            initialItem: int.parse(selectedTime.split(':')[1]) ~/ 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 何分やる？
                const Text('何分やる？', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: TaskColors.getColor(selectedColorKey)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoPicker(
                    itemExtent: 40,
                    selectionOverlay: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: TaskColors.getColor(selectedColorKey).withOpacity(0.2),
                        border: Border.symmetric(
                          horizontal: BorderSide(color: TaskColors.getColor(selectedColorKey), width: 1.5),
                        ),
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        selectedDuration = durationOptions[index];
                      });
                    },
                    children: durationOptions.map((duration) {
                      return Center(
                        child: Text(
                          '$duration分',
                          style: const TextStyle(fontSize: 20),
                        ),
                      );
                    }).toList(),
                    scrollController: FixedExtentScrollController(
                      initialItem: durationOptions.indexOf(selectedDuration),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 優先タスク
                Row(
                  children: [
                    Checkbox(
                      value: isPriority,
                      activeColor: TaskColors.getColor(selectedColorKey),
                      onChanged: (value) {
                        setState(() {
                          isPriority = value ?? false;
                        });
                      },
                    ),
                    const Text('優先タスクにする'),
                  ],
                ),
                const SizedBox(height: 24),
                
                // ボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TaskColors.getColor(selectedColorKey),
                      ),
                      onPressed: () async {
                        if (nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('タスク名を入力してください')),
                          );
                          return;
                        }

                        try {
                          await taskService.addTask(
                            nameController.text,
                            selectedTime,
                            selectedDuration,
                            isPriority,
                            user,
                            colorKey: selectedColorKey,
                            weekdays: selectedWeekdays,
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラー: ${e.toString()}')),
                          );
                        }
                      },
                      child: const Text('追加', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _showEditTaskDialog(BuildContext context, task) {
  final taskService = Provider.of<TaskService>(context, listen: false);
  final nameController = TextEditingController(text: task.name);
  String selectedTime = task.scheduledTime.split(':')[0] + ':' + task.scheduledTime.split(':')[1];
  int selectedDuration = task.duration;
  bool isPriority = task.isPriority;
  String selectedColorKey = task.colorKey ?? TaskColors.defaultColorKey;
  List<String> selectedWeekdays = task.weekdays ?? ['毎日'];

  // 所要時間の選択肢
  final List<int> durationOptions = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120];

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'タスクを編集',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                // タスク名と色選択
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'タスク名',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: TaskColors.getColor(selectedColorKey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('色', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 色選択
                const Text('色を選ぶ', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: TaskColors.colorKeys.map((colorKey) {
                      final isSelected = selectedColorKey == colorKey;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedColorKey = colorKey;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: TaskColors.getColor(colorKey),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                
                // いつやる？
                const Text('いつやる？', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: TaskColors.weekdays.map((weekday) {
                      final isSelected = selectedWeekdays.contains(weekday);
                      return SizedBox(
                        height: 32,
                        child: FilterChip(
                          label: Text(weekday),
                          selected: isSelected,
                          selectedColor: TaskColors.getColor(selectedColorKey).withOpacity(0.7),
                          onSelected: (selected) {
                            setState(() {
                              if (weekday == '毎日') {
                                if (selected) {
                                  selectedWeekdays = ['毎日'];
                                } else {
                                  selectedWeekdays.remove('毎日');
                                }
                              } else {
                                if (selected) {
                                  if (selectedWeekdays.contains('毎日')) {
                                    selectedWeekdays.remove('毎日');
                                  }
                                  selectedWeekdays.add(weekday);
                                } else {
                                  selectedWeekdays.remove(weekday);
                                }
                                if (selectedWeekdays.isEmpty) {
                                  selectedWeekdays.add('毎日');
                                }
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 何時からやる？
                const Text('何時からやる？', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: TaskColors.getColor(selectedColorKey)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // 時間選択
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 40,
                          selectionOverlay: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: TaskColors.getColor(selectedColorKey).withOpacity(0.2),
                              border: Border.symmetric(
                                horizontal: BorderSide(color: TaskColors.getColor(selectedColorKey), width: 1.5),
                              ),
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                          onSelectedItemChanged: (index) {
                            final hour = (index + 5).toString().padLeft(2, '0');
                            final minute = selectedTime.split(':')[1];
                            setState(() {
                              selectedTime = '$hour:$minute';
                            });
                          },
                          children: List.generate(20, (index) {
                            final hour = index + 5;
                            return Center(
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}時',
                                style: const TextStyle(fontSize: 20),
                              ),
                            );
                          }),
                          scrollController: FixedExtentScrollController(
                            initialItem: int.parse(selectedTime.split(':')[0]) - 5,
                          ),
                        ),
                      ),
                      // 分選択
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 40,
                          selectionOverlay: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: TaskColors.getColor(selectedColorKey).withOpacity(0.2),
                              border: Border.symmetric(
                                horizontal: BorderSide(color: TaskColors.getColor(selectedColorKey), width: 1.5),
                              ),
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                          onSelectedItemChanged: (index) {
                            final minute = index * 5;
                            final minuteStr = minute.toString().padLeft(2, '0');
                            final hour = selectedTime.split(':')[0];
                            setState(() {
                              selectedTime = '$hour:$minuteStr';
                            });
                          },
                          children: List.generate(12, (index) {
                            final minute = index * 5;
                            return Center(
                              child: Text(
                                '${minute.toString().padLeft(2, '0')}分',
                                style: const TextStyle(fontSize: 20),
                              ),
                            );
                          }),
                          scrollController: FixedExtentScrollController(
                            initialItem: int.parse(selectedTime.split(':')[1]) ~/ 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 何分やる？
                const Text('何分やる？', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: TaskColors.getColor(selectedColorKey)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoPicker(
                    itemExtent: 40,
                    selectionOverlay: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: TaskColors.getColor(selectedColorKey).withOpacity(0.2),
                        border: Border.symmetric(
                          horizontal: BorderSide(color: TaskColors.getColor(selectedColorKey), width: 1.5),
                        ),
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        selectedDuration = durationOptions[index];
                      });
                    },
                    children: durationOptions.map((duration) {
                      return Center(
                        child: Text(
                          '$duration分',
                          style: const TextStyle(fontSize: 20),
                        ),
                      );
                    }).toList(),
                    scrollController: FixedExtentScrollController(
                      initialItem: durationOptions.indexOf(selectedDuration),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 優先タスク
                Row(
                  children: [
                    Checkbox(
                      value: isPriority,
                      activeColor: TaskColors.getColor(selectedColorKey),
                      onChanged: (value) {
                        setState(() {
                          isPriority = value ?? false;
                        });
                      },
                    ),
                    const Text('優先タスクにする'),
                  ],
                ),
                const SizedBox(height: 24),
                
                // ボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TaskColors.getColor(selectedColorKey),
                      ),
                      onPressed: () async {
                        if (nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('タスク名を入力してください')),
                          );
                          return;
                        }

                        try {
                          final updatedTask = task.copyWith(
                            name: nameController.text,
                            scheduledTime: selectedTime,
                            duration: selectedDuration,
                            colorKey: selectedColorKey,
                            weekdays: selectedWeekdays,
                          );
                          await taskService.updateTask(updatedTask, isPriority: isPriority);
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラー: ${e.toString()}')),
                          );
                        }
                      },
                      child: const Text('更新', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _showDeleteConfirmation(BuildContext context, String taskId) {
  final taskService = Provider.of<TaskService>(context, listen: false);
  
  showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タスクを削除'),
        content: const Text('このタスクを削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await taskService.deleteTask(taskId);
              Navigator.pop(context);
            },
            child: const Text('削除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPriorityConfirmation(BuildContext context, String taskId) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('優先タスクに設定'),
        content: const Text('このタスクを優先タスクに設定しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              await taskService.setPriorityTask(taskId);
              Navigator.pop(context);
            },
            child: const Text('設定'),
          ),
        ],
      ),
    );
  }

  void _showHistoryPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('履歴'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('2023/4/1'),
                subtitle: const Text('タスク完了: 3件'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // 詳細画面へ遷移
                  Navigator.pop(context);
                  // 履歴詳細画面へ遷移する処理をここに追加
                },
              ),
              ListTile(
                title: const Text('2023/3/31'),
                subtitle: const Text('タスク完了: 5件'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // 詳細画面へ遷移
                  Navigator.pop(context);
                  // 履歴詳細画面へ遷移する処理をここに追加
                },
              ),
              // 他の履歴項目...
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showTipsPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使い方のコツ'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('1. タスクは右下の+ボタンから追加できます。'),
              SizedBox(height: 8),
              Text('2. 優先タスクは上部に表示されます。'),
              SizedBox(height: 8),
              Text('3. タスクを完了したらチェックボックスをタップしましょう。'),
              SizedBox(height: 8),
              Text('4. 履歴からこれまでの活動を振り返ることができます。'),
              SizedBox(height: 8),
              Text('5. 継続は力なり！毎日少しずつ進めましょう。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showSettingsPopup(BuildContext context) {
    // 設定の状態を管理する変数
    bool notificationsEnabled = _notificationsEnabled;
    bool darkModeEnabled = _darkModeEnabled;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('設定'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('通知'),
                    subtitle: const Text('タスクの通知を受け取る'),
                    value: notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        notificationsEnabled = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('ダークモード'),
                    subtitle: const Text('ダークテーマを使用する'),
                    value: darkModeEnabled,
                    onChanged: (value) {
                      setState(() {
                        darkModeEnabled = value;
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('アカウント設定'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      // アカウント設定画面へ遷移する処理をここに追加
                    },
                  ),
                  ListTile(
                    title: const Text('アプリについて'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      // アプリ情報画面へ遷移する処理をここに追加
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // 色選択ダイアログを表示する
  void _showColorPickerDialog(BuildContext context, String currentColorKey, Function(String) onColorSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('色を選択'),
        content: Container(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: TaskColors.colorMap.length,
            itemBuilder: (context, index) {
              final colorKey = TaskColors.colorMap.keys.elementAt(index);
              final color = TaskColors.colorMap[colorKey]!;
              final isSelected = colorKey == currentColorKey;
              
              return GestureDetector(
                onTap: () {
                  onColorSelected(colorKey);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected 
                        ? Border.all(color: Colors.white, width: 3) 
                        : null,
                    boxShadow: isSelected 
                        ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5)]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }
}
