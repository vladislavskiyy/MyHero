// lib/models/task.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:math' as math;

part 'task.g.dart';

enum TaskRecurrenceType {
  none,
  daily,
  weekly,
  monthly,
}

enum TaskPriority {
  low,
  medium,
  high,
}

@HiveType(typeId: 1)
class Task extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isDone;

  @HiveField(3)
  int? durationMinutes;

  @HiveField(4)
  int? priority;

  @HiveField(5)
  DateTime? date;

  @HiveField(6)
  String? category;

  @HiveField(7)
  int? colorValue;

  @HiveField(8)
  String? listId;

  @HiveField(9)
  int recurrenceTypeValue;

  @HiveField(10)
  int priorityLevelValue;

  @HiveField(11)
  DateTime? deadline;

  @HiveField(12)
  int? estimatedDurationMinutes;

  Task({
    required this.id,
    required this.title,
    this.date,
    this.category,
    Color? color,
    this.isDone = false,
    this.durationMinutes,
    this.priority,
    this.listId,
    TaskRecurrenceType recurrenceType = TaskRecurrenceType.none,
    TaskPriority? taskPriority,
    this.deadline,
    this.estimatedDurationMinutes,
  }) : recurrenceTypeValue = recurrenceType.index,
        priorityLevelValue = (taskPriority ?? TaskPriority.medium).index;

  Color? get color => colorValue != null ? Color(colorValue!) : null;
  set color(Color? c) => colorValue = c?.value;

  TaskRecurrenceType get recurrenceType => TaskRecurrenceType.values[recurrenceTypeValue.clamp(0, TaskRecurrenceType.values.length - 1)];
  set recurrenceType(TaskRecurrenceType value) => recurrenceTypeValue = value.index;

  TaskPriority get taskPriority => TaskPriority.values[priorityLevelValue.clamp(0, TaskPriority.values.length - 1)];
  set taskPriority(TaskPriority value) => priorityLevelValue = value.index;

  int get effectiveDurationMinutes => (durationMinutes ?? estimatedDurationMinutes ?? 30).clamp(1, 24 * 60);

  bool appearsOn(DateTime day) {
    final taskDate = date;
    if (taskDate == null) return false;

    switch (recurrenceType) {
      case TaskRecurrenceType.none:
        return DateUtils.isSameDay(taskDate, day);
      case TaskRecurrenceType.daily:
        return !day.isBefore(taskDate) && day.difference(taskDate).inDays >= 0;
      case TaskRecurrenceType.weekly:
        if (day.isBefore(taskDate)) return false;
        final diff = day.difference(taskDate).inDays;
        return diff % 7 == 0;
      case TaskRecurrenceType.monthly:
        if (day.isBefore(taskDate)) return false;
        final diffMonths = (day.year - taskDate.year) * 12 + (day.month - taskDate.month);
        return diffMonths >= 0 && day.day == taskDate.day;
    }
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      date: map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : null,
      category: map['category'] as String?,
      color: map['color'] != null
          ? Color(map['color'] as int)
          : null,
      isDone: map['isDone'] as bool? ?? false,
      durationMinutes: map['durationMinutes'] as int?,
      priority: map['priority'] as int?,
      listId: map['listId'] as String?,
      recurrenceType: TaskRecurrenceType.values[(map['recurrenceType'] as int? ?? 0)],
      taskPriority: map['taskPriority'] != null
          ? TaskPriority.values[(map['taskPriority'] as int? ?? TaskPriority.medium.index)]
          : (map['priorityLevelValue'] != null
              ? TaskPriority.values[(map['priorityLevelValue'] as int)]
              : TaskPriority.medium),
      deadline: map['deadline'] != null ? DateTime.tryParse(map['deadline'] as String) : null,
      estimatedDurationMinutes: map['estimatedDurationMinutes'] as int? ?? map['durationMinutes'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date?.toIso8601String(),
      'category': category,
      'color': colorValue,
      'isDone': isDone,
      'durationMinutes': durationMinutes,
      'priority': priority,
      'listId': listId,
      'recurrenceType': recurrenceType.index,
      'priorityLevelValue': priorityLevelValue,
      'deadline': deadline?.toIso8601String(),
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'taskPriority': taskPriority.index,
    };
  }
}
