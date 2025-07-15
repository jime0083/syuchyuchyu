import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:micro_habit_runner/models/task_model.dart';
import 'package:micro_habit_runner/models/user_model.dart';

class TaskService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<TaskModel> _tasks = [];
  List<TaskModel> get tasks => _tasks;
  
  TaskModel? _priorityTask;
  TaskModel? get priorityTask => _priorityTask;
  
  // ゲストユーザー用のタスク保存用
  List<TaskModel> _guestTasks = [];
  bool _hasGuestTask = false;
  bool get hasGuestTask => _hasGuestTask;
  
  // Get all tasks for current user
  Future<void> getTasks() async {
    try {
      if (_auth.currentUser == null) {
        // ゲストユーザーの場合はメモリ上のタスクを使用
        _tasks = _guestTasks;
        _priorityTask = _tasks.isNotEmpty
            ? _tasks.firstWhere((task) => task.isPriority, orElse: () => _tasks.first)
            : null;
        notifyListeners();
        return;
      }
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('tasks')
          .where('isActive', isEqualTo: true)
          .orderBy('scheduledTime')
          .get();
      
      _tasks = snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
      _priorityTask = _tasks.isNotEmpty
          ? _tasks.firstWhere((task) => task.isPriority, orElse: () => _tasks.first)
          : null;
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting tasks: $e');
      }
    }
  }
  
  // Add a new task
  Future<TaskModel?> addTask(String name, String scheduledTime, int duration, bool isPriority, UserModel? user, {String colorKey = 'orange', List<String> weekdays = const ['毎日']}) async {
    try {
      if (kDebugMode) {
        print('開始: タスク追加プロセス - タスク名: $name');
      }
      
      // ゲストユーザーの場合
      if (_auth.currentUser == null) {
        if (kDebugMode) {
          print('情報: ゲストユーザーとしてタスクを追加します');
        }
        
        // ゲストユーザーは1つのみタスクを登録可能
        if (_hasGuestTask) {
          if (kDebugMode) {
            print('エラー: ゲストユーザーは既にタスクを持っています');
          }
          throw Exception('ゲストユーザーは1つのみタスクを登録できます。\n追加のタスクを登録するにはログインしてください。');
        }
        
        // 新しいタスクを作成
        TaskModel newTask = TaskModel(
          id: 'guest-task-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          scheduledTime: scheduledTime,
          duration: duration,
          isPriority: true, // ゲストタスクは常に優先タスク
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          colorKey: colorKey,
          weekdays: weekdays,
        );
        
        // メモリに保存
        _guestTasks = [newTask];
        _hasGuestTask = true;
        
        if (kDebugMode) {
          print('成功: ゲストユーザーのタスクをメモリに保存しました');
        }
        
        // タスクリストを更新
        await getTasks();
        
        return newTask;
      }
      
      // ログインユーザーの場合
      if (kDebugMode) {
        print('情報: ログインユーザー(${_auth.currentUser!.uid})としてタスクを追加します');
      }
      
      // Check if user has reached free plan limit
      if (user != null && !user.isPremium && _tasks.length >= 2) {
        if (kDebugMode) {
          print('エラー: 無料プランの上限に達しています');
        }
        throw Exception('Free plan limit reached');
      }
      
      // If setting this task as priority, remove priority from other tasks
      if (isPriority) {
        if (kDebugMode) {
          print('処理: 他のタスクの優先フラグをリセットします');
        }
        await _resetPriorityTasks();
      }
      
      // Create new task
      TaskModel newTask = TaskModel(
        id: '',
        name: name,
        scheduledTime: scheduledTime,
        duration: duration,
        isPriority: isPriority,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        colorKey: colorKey,
        weekdays: weekdays,
      );
      
      if (kDebugMode) {
        print('処理: Firestoreにタスクを保存します - ユーザーID: ${_auth.currentUser!.uid}');
      }
      
      // Firestoreにユーザードキュメントが存在するか確認
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      if (!userDoc.exists) {
        if (kDebugMode) {
          print('警告: ユーザードキュメントが存在しません。認証サービスを使用して作成します。');
        }
        // ユーザードキュメントが存在しない場合は作成
        await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
          'email': _auth.currentUser!.email ?? '',
          'subscriptionStatus': 'free',
          'trialUsed': false,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'language': 'ja',
        });
        if (kDebugMode) {
          print('成功: ユーザードキュメントを作成しました');
        }
      }
      
      // Add to Firestore
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('tasks')
          .add(newTask.toMap());
      
      if (kDebugMode) {
        print('成功: Firestoreにタスクを保存しました - タスクID: ${docRef.id}');
      }
      
      // Create complete task with ID
      TaskModel completeTask = newTask.copyWith(id: docRef.id);
      
      // Refresh tasks
      await getTasks();
      
      return completeTask;
    } catch (e) {
      if (kDebugMode) {
        print('エラー: タスク追加中に例外が発生 - $e');
      }
      rethrow;
    }
  }
  
  // Update an existing task
  Future<void> updateTask(TaskModel task, {bool? isPriority}) async {
    try {
      if (_auth.currentUser == null) return;
      
      // If setting this task as priority, remove priority from other tasks
      if (isPriority != null && isPriority) {
        await _resetPriorityTasks();
      }
      
      // Update task
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('tasks')
          .doc(task.id)
          .update({
        'name': task.name,
        'scheduledTime': task.scheduledTime,
        'duration': task.duration,
        'isPriority': isPriority ?? task.isPriority,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Refresh tasks
      await getTasks();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating task: $e');
      }
      rethrow;
    }
  }
  
  // Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      if (_auth.currentUser == null) return;
      
      // Soft delete by setting isActive to false
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('tasks')
          .doc(taskId)
          .update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Refresh tasks
      await getTasks();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting task: $e');
      }
      rethrow;
    }
  }
  
  // Reset priority for all tasks
  Future<void> _resetPriorityTasks() async {
    try {
      if (_auth.currentUser == null) return;
      
      // Get all priority tasks
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('tasks')
          .where('isPriority', isEqualTo: true)
          .get();
      
      // Update each task to remove priority
      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'isPriority': false,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting priority tasks: $e');
      }
      rethrow;
    }
  }
  
  // Set a task as priority
  Future<void> setPriorityTask(String taskId) async {
    try {
      if (_auth.currentUser == null) return;
      
      // Reset all priority tasks
      await _resetPriorityTasks();
      
      // Set the new priority task
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('tasks')
          .doc(taskId)
          .update({
        'isPriority': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Refresh tasks
      await getTasks();
    } catch (e) {
      if (kDebugMode) {
        print('Error setting priority task: $e');
      }
      rethrow;
    }
  }
}
