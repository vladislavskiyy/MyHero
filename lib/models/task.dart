// lib/models/task.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'task.g.dart';

enum TaskRecurrenceType { none, daily, weekly, monthly }

enum TaskPriority { low, medium, high }

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
  // Planned day (or the first occurrence), independent of the deadline.
  DateTime? date;

  @HiveField(6)
  String? category;

  @HiveField(7)
  int? colorValue;

  @HiveField(8)
  String? listId;

  @HiveField(9, defaultValue: 0)
  int recurrenceTypeValue;

  @HiveField(10, defaultValue: 1)
  int priorityLevelValue;

  @HiveField(11)
  DateTime? deadline;

  @HiveField(12)
  int? estimatedDurationMinutes;

  @HiveField(13, defaultValue: <String>[])
  List<String> breakdownSteps;

  // Keep field 13 as text for compatibility. IDs travel with their steps when
  // editing, so renaming or moving a step never changes its action's identity.
  @HiveField(14)
  List<String> breakdownStepIds;

  @HiveField(15)
  String? parentTaskId;

  @HiveField(16)
  String? sourceStepId;

  // Null also means the completion date of a legacy done task is unknown.
  @HiveField(17)
  DateTime? completedAt;

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
    int? estimatedDurationMinutes,
    List<String>? breakdownSteps,
    List<String>? breakdownStepIds,
    this.parentTaskId,
    this.sourceStepId,
    this.completedAt,
  }) : recurrenceTypeValue = recurrenceType.index,
       priorityLevelValue = (taskPriority ?? TaskPriority.medium).index,
       estimatedDurationMinutes = estimatedDurationMinutes ?? durationMinutes,
       breakdownSteps = List.of(breakdownSteps ?? []),
       breakdownStepIds = _initialStepIds(id, breakdownSteps, breakdownStepIds);

  static final _stepRandom = Random.secure();

  static String newBreakdownStepId() => List.generate(
    16,
    (_) => _stepRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  static List<String> _initialStepIds(
    String taskId,
    List<String>? steps,
    List<String>? ids,
  ) {
    // Old records have no IDs. Deterministic legacy IDs survive reopening even
    // before the first edit; creating an action persists them with its parent.
    return List.generate(
      steps?.length ?? 0,
      (i) => ids != null && i < ids.length
          ? ids[i]
          : 'legacy-step:${Uri.encodeComponent(taskId)}:$i',
    );
  }

  Color? get color => colorValue != null ? Color(colorValue!) : null;
  set color(Color? c) => colorValue = c?.toARGB32();

  TaskRecurrenceType get recurrenceType =>
      TaskRecurrenceType.values[recurrenceTypeValue.clamp(
        0,
        TaskRecurrenceType.values.length - 1,
      )];
  set recurrenceType(TaskRecurrenceType value) =>
      recurrenceTypeValue = value.index;

  TaskPriority get taskPriority =>
      TaskPriority.values[priorityLevelValue.clamp(
        0,
        TaskPriority.values.length - 1,
      )];
  set taskPriority(TaskPriority value) => priorityLevelValue = value.index;

  int get effectiveDurationMinutes =>
      (durationMinutes ?? estimatedDurationMinutes ?? 30).clamp(1, 24 * 60);

  bool appearsOn(DateTime day) {
    final taskDate = date;
    if (taskDate == null) return false;
    final startDay = DateTime.utc(taskDate.year, taskDate.month, taskDate.day);
    final targetDay = DateTime.utc(day.year, day.month, day.day);

    switch (recurrenceType) {
      case TaskRecurrenceType.none:
        return DateUtils.isSameDay(taskDate, day);
      case TaskRecurrenceType.daily:
        return !targetDay.isBefore(startDay);
      case TaskRecurrenceType.weekly:
        if (targetDay.isBefore(startDay)) return false;
        final diff = targetDay.difference(startDay).inDays;
        return diff % 7 == 0;
      case TaskRecurrenceType.monthly:
        if (targetDay.isBefore(startDay)) return false;
        final diffMonths =
            (day.year - taskDate.year) * 12 + (day.month - taskDate.month);
        return diffMonths >= 0 && day.day == taskDate.day;
    }
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
      category: map['category'] as String?,
      color: map['color'] != null ? Color(map['color'] as int) : null,
      isDone: map['isDone'] as bool? ?? false,
      durationMinutes: map['durationMinutes'] as int?,
      priority: map['priority'] as int?,
      listId: map['listId'] as String?,
      recurrenceType:
          TaskRecurrenceType.values[(map['recurrenceType'] as int? ?? 0)],
      taskPriority: map['taskPriority'] != null
          ? TaskPriority.values[(map['taskPriority'] as int? ??
                TaskPriority.medium.index)]
          : (map['priorityLevelValue'] != null
                ? TaskPriority.values[(map['priorityLevelValue'] as int)]
                : TaskPriority.medium),
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'] as String)
          : null,
      estimatedDurationMinutes:
          map['estimatedDurationMinutes'] as int? ??
          map['durationMinutes'] as int?,
      breakdownSteps: (map['breakdownSteps'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      breakdownStepIds: (map['breakdownStepIds'] as List<dynamic>?)
          ?.cast<String>(),
      parentTaskId: map['parentTaskId'] as String?,
      sourceStepId: map['sourceStepId'] as String?,
      completedAt: map['completedAt'] == null
          ? null
          : DateTime.tryParse(map['completedAt'] as String),
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
      'breakdownSteps': breakdownSteps,
      'breakdownStepIds': breakdownStepIds,
      'parentTaskId': parentTaskId,
      'sourceStepId': sourceStepId,
      'completedAt': completedAt?.toUtc().toIso8601String(),
      'taskPriority': taskPriority.index,
    };
  }
}
