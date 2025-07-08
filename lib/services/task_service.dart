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
  Future<TaskModel?> addTask(String name, String scheduledTime, int duration, bool isPriority, UserModel? user) async {
    try {
      // ゲストユーザーの場合
      if (_auth.currentUser == null) {
        // ゲストユーザーは1つのみタスクを登録可能
        if (_hasGuestTask) {
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
        );
        
        // メモリに保存
        _guestTasks = [newTask];
        _hasGuestTask = true;
        
        // タスクリストを更新
        await getTasks();
        
        return newTask;
      }
      
      // ログインユーザーの場合
      // Check if user has reached free plan limit
      if (user != null && !user.isPremium && _tasks.length >= 2) {
        throw Exception('Free plan limit reached');
      }
      
      // If setting this task as priority, remove priority from other tasks
      if (isPriority) {
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
      );
      
      // Add to Firestore
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('tasks')
          .add(newTask.toMap());
      
      // Create complete task with ID
      TaskModel completeTask = newTask.copyWith(id: docRef.id);
      
      // Refresh tasks
      await getTasks();
      
      return completeTask;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding task: $e');
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
