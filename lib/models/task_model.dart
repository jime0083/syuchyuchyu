import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String name;
  final String scheduledTime; // Format: HH:mm
  final int duration; // in minutes
  final bool isPriority;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.name,
    required this.scheduledTime,
    required this.duration,
    required this.isPriority,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
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
    );
  }
}
