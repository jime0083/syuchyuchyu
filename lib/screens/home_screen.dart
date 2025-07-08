import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:micro_habit_runner/models/user_model.dart';
import 'package:micro_habit_runner/services/auth_service.dart';
import 'package:micro_habit_runner/services/task_service.dart';
import 'package:micro_habit_runner/utils/app_theme.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイクロハビットランナー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: userModel == null
          ? const Center(child: CircularProgressIndicator())
          : _buildHomeContent(context, userModel, taskService),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (userModel != null) {
            _showAddTaskDialog(context, userModel);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, UserModel user, TaskService taskService) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'こんにちは、${user.email}さん',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '今日のタスク',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: taskService.tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.task_alt, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'タスクがありません',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '新しいタスクを追加しましょう',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: taskService.tasks.length,
                    itemBuilder: (context, index) {
                      final task = taskService.tasks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: task.isPriority
                              ? const Icon(Icons.star, color: AppTheme.primaryOrange)
                              : const Icon(Icons.circle_outlined),
                          title: Text(task.name),
                          subtitle: Text('予定時間: ${task.scheduledTime} (${task.duration}分)'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                          onTap: () {
                            if (!task.isPriority) {
                              _showPriorityConfirmation(context, task.id);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, UserModel user) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    final nameController = TextEditingController();
    final timeController = TextEditingController();
    final durationController = TextEditingController();
    bool isPriority = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新しいタスク'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'タスク名',
                    hintText: '例: 朝のストレッチ',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: '予定時間',
                    hintText: '例: 7:00',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: '所要時間（分）',
                    hintText: '例: 10',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isPriority,
                      onChanged: (value) {
                        setState(() {
                          isPriority = value ?? false;
                        });
                      },
                    ),
                    const Text('優先タスクにする'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    timeController.text.isEmpty ||
                    durationController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('すべての項目を入力してください')),
                  );
                  return;
                }

                try {
                  await taskService.addTask(
                    nameController.text,
                    timeController.text,
                    int.parse(durationController.text),
                    isPriority,
                    user,
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: ${e.toString()}')),
                  );
                }
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, task) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    final nameController = TextEditingController(text: task.name);
    final timeController = TextEditingController(text: task.scheduledTime);
    final durationController = TextEditingController(text: task.duration.toString());
    bool isPriority = task.isPriority;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('タスクを編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'タスク名',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: '予定時間',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: '所要時間（分）',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isPriority,
                      onChanged: (value) {
                        setState(() {
                          isPriority = value ?? false;
                        });
                      },
                    ),
                    const Text('優先タスクにする'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    timeController.text.isEmpty ||
                    durationController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('すべての項目を入力してください')),
                  );
                  return;
                }

                try {
                  final updatedTask = task.copyWith(
                    name: nameController.text,
                    scheduledTime: timeController.text,
                    duration: int.parse(durationController.text),
                  );
                  await taskService.updateTask(updatedTask, isPriority: isPriority);
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: ${e.toString()}')),
                  );
                }
              },
              child: const Text('更新'),
            ),
          ],
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
            onPressed: () async {
              await taskService.deleteTask(taskId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
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
}
