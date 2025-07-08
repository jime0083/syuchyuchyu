import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:micro_habit_runner/models/session_model.dart';
import 'package:micro_habit_runner/models/task_model.dart';

class SessionService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<SessionModel> _sessions = [];
  List<SessionModel> get sessions => _sessions;
  
  int _touchCount = 0;
  int get touchCount => _touchCount;
  
  // Get all sessions for current user
  Future<void> getSessions() async {
    try {
      if (_auth.currentUser == null) return;
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('sessions')
          .orderBy('createdAt', descending: true)
          .get();
      
      _sessions = snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting sessions: $e');
      }
    }
  }
  
  // Get sessions for a specific date
  Future<List<SessionModel>> getSessionsByDate(DateTime date) async {
    try {
      if (_auth.currentUser == null) return [];
      
      // Create date range for the given day
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('sessions')
          .where('actualStartTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('actualStartTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      return snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting sessions by date: $e');
      }
      return [];
    }
  }
  
  // Get sessions for a specific task
  Future<List<SessionModel>> getSessionsByTask(String taskId) async {
    try {
      if (_auth.currentUser == null) return [];
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('sessions')
          .where('taskId', isEqualTo: taskId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting sessions by task: $e');
      }
      return [];
    }
  }
  
  // Start a new session
  void startSession() {
    _touchCount = 0;
    notifyListeners();
  }
  
  // Record a touch event
  void recordTouch() {
    _touchCount++;
    notifyListeners();
  }
  
  // Save completed session
  Future<SessionModel?> saveSession({
    required TaskModel task,
    required DateTime startTime,
    required DateTime endTime,
    required ConcentrationLevel concentrationLevel,
    required String memo,
  }) async {
    try {
      if (_auth.currentUser == null) return null;
      
      // Calculate if the task was started on time (within 5 minutes of scheduled time)
      bool onTimeStart = _isOnTime(task.scheduledTime, startTime);
      
      // Calculate actual duration in minutes
      int actualDuration = endTime.difference(startTime).inMinutes;
      
      // Create session model
      SessionModel session = SessionModel(
        id: '',
        taskId: task.id,
        taskName: task.name,
        scheduledTime: task.scheduledTime,
        actualStartTime: startTime,
        endTime: endTime,
        plannedDuration: task.duration,
        actualDuration: actualDuration,
        touchCount: _touchCount,
        onTimeStart: onTimeStart,
        concentrationLevel: concentrationLevel,
        memo: memo,
        createdAt: DateTime.now(),
      );
      
      // Save to Firestore
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('sessions')
          .add(session.toMap());
      
      // Create complete session with ID
      SessionModel completeSession = SessionModel(
        id: docRef.id,
        taskId: session.taskId,
        taskName: session.taskName,
        scheduledTime: session.scheduledTime,
        actualStartTime: session.actualStartTime,
        endTime: session.endTime,
        plannedDuration: session.plannedDuration,
        actualDuration: session.actualDuration,
        touchCount: session.touchCount,
        onTimeStart: session.onTimeStart,
        concentrationLevel: session.concentrationLevel,
        memo: session.memo,
        createdAt: session.createdAt,
      );
      
      // Reset touch count
      _touchCount = 0;
      
      // Refresh sessions
      await getSessions();
      
      return completeSession;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving session: $e');
      }
      return null;
    }
  }
  
  // Check if the task was started on time (within 5 minutes of scheduled time)
  bool _isOnTime(String scheduledTime, DateTime actualStartTime) {
    try {
      // Parse scheduled time
      List<String> timeParts = scheduledTime.split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      
      // Create scheduled DateTime
      DateTime scheduledDateTime = DateTime(
        actualStartTime.year,
        actualStartTime.month,
        actualStartTime.day,
        hour,
        minute,
      );
      
      // Calculate difference in minutes
      int diffMinutes = actualStartTime.difference(scheduledDateTime).inMinutes;
      
      // Return true if started within 5 minutes of scheduled time
      return diffMinutes >= 0 && diffMinutes <= 5;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking if on time: $e');
      }
      return false;
    }
  }
  
  // Get statistics for the current week
  Future<Map<String, dynamic>> getWeeklyStats() async {
    try {
      if (_auth.currentUser == null) return {};
      
      // Get start and end of current week (Monday to Sunday)
      DateTime now = DateTime.now();
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      
      // Query sessions for current week
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('sessions')
          .where('actualStartTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('actualStartTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
          .get();
      
      List<SessionModel> weeklySessions = snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
      
      // Calculate statistics
      int totalTasks = weeklySessions.length;
      int totalMinutes = weeklySessions.fold(0, (sum, session) => sum + session.actualDuration);
      int onTimeTasks = weeklySessions.where((session) => session.onTimeStart).length;
      int noTouchTasks = weeklySessions.where((session) => session.touchCount == 0).length;
      int focusedTasks = weeklySessions.where((session) => 
          session.concentrationLevel == ConcentrationLevel.medium || 
          session.concentrationLevel == ConcentrationLevel.high).length;
      int deepFocusTasks = weeklySessions.where((session) => 
          session.concentrationLevel == ConcentrationLevel.high).length;
      
      return {
        'totalTasks': totalTasks,
        'totalMinutes': totalMinutes,
        'onTimeTasks': onTimeTasks,
        'noTouchTasks': noTouchTasks,
        'focusedTasks': focusedTasks,
        'deepFocusTasks': deepFocusTasks,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting weekly stats: $e');
      }
      return {};
    }
  }
  
  // Get total stats for all time
  Future<Map<String, dynamic>> getTotalStats() async {
    try {
      if (_auth.currentUser == null) return {};
      
      // Query all sessions
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('sessions')
          .get();
      
      List<SessionModel> allSessions = snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
      
      // Calculate statistics
      int totalTasks = allSessions.length;
      int totalMinutes = allSessions.fold(0, (sum, session) => sum + session.actualDuration);
      
      return {
        'totalTasks': totalTasks,
        'totalMinutes': totalMinutes,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting total stats: $e');
      }
      return {};
    }
  }
}
