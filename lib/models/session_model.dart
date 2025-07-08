import 'package:cloud_firestore/cloud_firestore.dart';

enum ConcentrationLevel { low, medium, high }

class SessionModel {
  final String id;
  final String taskId;
  final String taskName;
  final String scheduledTime;
  final DateTime actualStartTime;
  final DateTime endTime;
  final int plannedDuration; // in minutes
  final int actualDuration; // in minutes
  final int touchCount;
  final bool onTimeStart;
  final ConcentrationLevel concentrationLevel;
  final String memo;
  final DateTime createdAt;

  SessionModel({
    required this.id,
    required this.taskId,
    required this.taskName,
    required this.scheduledTime,
    required this.actualStartTime,
    required this.endTime,
    required this.plannedDuration,
    required this.actualDuration,
    required this.touchCount,
    required this.onTimeStart,
    required this.concentrationLevel,
    required this.memo,
    required this.createdAt,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      taskName: data['taskName'] ?? '',
      scheduledTime: data['scheduledTime'] ?? '',
      actualStartTime: data['actualStartTime'] != null
          ? (data['actualStartTime'] as Timestamp).toDate()
          : DateTime.now(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : DateTime.now(),
      plannedDuration: data['plannedDuration'] ?? 0,
      actualDuration: data['actualDuration'] ?? 0,
      touchCount: data['touchCount'] ?? 0,
      onTimeStart: data['onTimeStart'] ?? false,
      concentrationLevel: _getConcentrationLevel(data['concentrationLevel']),
      memo: data['memo'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'taskName': taskName,
      'scheduledTime': scheduledTime,
      'actualStartTime': Timestamp.fromDate(actualStartTime),
      'endTime': Timestamp.fromDate(endTime),
      'plannedDuration': plannedDuration,
      'actualDuration': actualDuration,
      'touchCount': touchCount,
      'onTimeStart': onTimeStart,
      'concentrationLevel': _concentrationLevelToString(concentrationLevel),
      'memo': memo,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static ConcentrationLevel _getConcentrationLevel(String? level) {
    switch (level) {
      case 'high':
        return ConcentrationLevel.high;
      case 'medium':
        return ConcentrationLevel.medium;
      default:
        return ConcentrationLevel.low;
    }
  }

  static String _concentrationLevelToString(ConcentrationLevel level) {
    switch (level) {
      case ConcentrationLevel.high:
        return 'high';
      case ConcentrationLevel.medium:
        return 'medium';
      case ConcentrationLevel.low:
        return 'low';
    }
  }
}
