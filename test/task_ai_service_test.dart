import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/services/task_ai_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    await Hive.openBox<Task>('tasks');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('TaskAiSuggestion.fromJson', () {
    test('parses a valid estimate and breakdown', () {
      final suggestion = TaskAiSuggestion.fromJson('''
        {
          "estimateMinutes": 60,
          "minMinutes": 45,
          "maxMinutes": 90,
          "steps": ["Подготовить материалы", "Выполнить работу"],
          "assumptions": "Работа выполняется впервые"
        }
      ''');

      expect(suggestion.estimateMinutes, 60);
      expect(suggestion.minMinutes, 45);
      expect(suggestion.maxMinutes, 90);
      expect(suggestion.steps, ['Подготовить материалы', 'Выполнить работу']);
      expect(suggestion.assumptions, 'Работа выполняется впервые');
    });

    test('rejects an estimate outside its range', () {
      expect(
        () => TaskAiSuggestion.fromJson('''
          {
            "estimateMinutes": 100,
            "minMinutes": 30,
            "maxMinutes": 60,
            "steps": ["Подготовить материалы"],
            "assumptions": ""
          }
        '''),
        throwsFormatException,
      );
    });

    test('rejects invalid breakdown steps', () {
      expect(
        () => TaskAiSuggestion.fromJson('''
          {
            "estimateMinutes": 30,
            "minMinutes": 15,
            "maxMinutes": 45,
            "steps": ["Подготовить материалы", 42],
            "assumptions": ""
          }
        '''),
        throwsFormatException,
      );
    });
  });

  test('persists the AI estimate and breakdown with a task', () async {
    final task = Task(
      id: 'ai-task',
      title: 'Prepare presentation',
      estimatedDurationMinutes: 60,
      breakdownSteps: ['Outline slides', 'Prepare visuals'],
    );

    await Hive.box<Task>('tasks').put(task.id, task);

    final restored = Hive.box<Task>('tasks').get(task.id);
    expect(restored?.estimatedDurationMinutes, 60);
    expect(restored?.breakdownSteps, ['Outline slides', 'Prepare visuals']);
  });
}
