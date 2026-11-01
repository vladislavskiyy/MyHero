import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'task.dart';

part 'task_list.g.dart';

@HiveType(typeId: 2)
class TaskList extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  List<Task> tasks;

  TaskList({
    required this.id,
    required this.name,
    List<Task>? tasks,
    Color? color,
  })  : colorValue = color?.value ?? 0xFFFFFFFF, 
        tasks = tasks ?? [];

  Color get color => Color(colorValue);
  set color(Color c) => colorValue = c.value;

  factory TaskList.fromMap(Map<String, dynamic> map) {
    return TaskList(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] != null ? Color(map['color'] as int) : null,
      tasks: (map['tasks'] as List<dynamic>? ?? [])
          .map((e) => Task.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': colorValue,
      'tasks': tasks.map((t) => t.toMap()).toList(),
    };
  }
}
