import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:micro_habit_runner/utils/task_colors.dart';

class TaskModel {
  final String id;
  final String name;
  final String scheduledTime; // Format: HH:mm
  final int duration; // in minutes
  final bool isPriority;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String colorKey; // 色を識別するキー
  final List<String> weekdays; // 曜日のリスト（複数選択可能）

  TaskModel({
    required this.id,
    required this.name,
    required this.scheduledTime,
    required this.duration,
    required this.isPriority,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.colorKey = TaskColors.defaultColorKey,
    this.weekdays = const ['毎日'],
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      name: data['name'] ?? '',
      scheduledTime: data['scheduledTime'] ?? '09:00',
      duration: data['duration'] ?? 25,
      isPriority: data['isPriority'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      colorKey: data['colorKey'] ?? TaskColors.defaultColorKey,
      weekdays: data['weekdays'] != null
          ? List<String>.from(data['weekdays'])
          : ['毎日'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'scheduledTime': scheduledTime,
      'duration': duration,
      'isPriority': isPriority,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'colorKey': colorKey,
      'weekdays': weekdays,
    };
  }

  TaskModel copyWith({
    String? id,
    String? name,
    String? scheduledTime,
    int? duration,
    bool? isPriority,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? colorKey,
    List<String>? weekdays,
  }) {
    return TaskModel(
      id: id ?? this.id,
      name: name ?? this.name,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      duration: duration ?? this.duration,
      isPriority: isPriority ?? this.isPriority,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorKey: colorKey ?? this.colorKey,
      weekdays: weekdays ?? this.weekdays,
    );
  }
}
