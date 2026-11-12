import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/models/achievement.dart';
import 'package:flutter_application_1/models/habit.dart';
import 'package:flutter_application_1/models/journal_entry.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/models/task_list.dart';
import 'package:flutter_application_1/pages/scheduler_page.dart';
import 'package:flutter_application_1/state/app_state.dart';

void main() {
  late Directory tempDir;
  late AppState state;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myhero_pilot_export_ui_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(TaskListAdapter());
    Hive.registerAdapter(HabitAdapter());
    Hive.registerAdapter(JournalEntryAdapter());
    Hive.registerAdapter(AchievementAdapter());
    Hive.registerAdapter(AchievementTypeAdapter());
    await Hive.openBox('settings');
    await Hive.openBox<Map>('day_plans');
    await Hive.openBox<Map>('analytics_events');
    await Hive.openBox<TaskList>('task_lists');
    await Hive.openBox<Habit>('habits');
    await Hive.openBox<JournalEntry>('journal_entries');
    await Hive.openBox<Achievement>('achievements');
  });

  setUp(() {
    state = AppState();
    state.notificationsEnabled = false;
  });

  tearDown(() => state.dispose());

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets(
    'Scheduler copies tasks, linked actions, accepted plan and events as JSON',
    (tester) async {
      final day = DateTime(2026, 11, 12);
      final deadline = day.add(const Duration(days: 1));
      final project = Task(
        id: 'project',
        title: 'Подготовить доклад',
        estimatedDurationMinutes: 180,
        breakdownSteps: ['Проверить источники'],
        breakdownStepIds: ['sources'],
      );
      late Task action;
      await tester.runAsync(() async {
        await state.addTask(project, listId: 'home');
        action = await state.createActionFromStep(
          project,
          stepId: 'sources',
          estimatedDurationMinutes: 20,
        );
        action.deadline = deadline;
        await state.savePlanForDay(day, 30, plannedTasks: [action]);
        await state.toggleDone(action, true);
      });

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(home: SchedulerPage(initialDay: day)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Экспорт JSON'));
      await tester.tap(find.text('Экспорт JSON'));
      await tester.pumpAndSettle();

      expect(find.text('JSON скопирован в буфер обмена'), findsOneWidget);
      expect(copied, isNotNull);
      final export = jsonDecode(copied!) as Map<String, dynamic>;
      expect(export['schemaVersion'], 2);
      expect(DateTime.parse(export['exportedAt'] as String).isUtc, isTrue);
      final tasks = (export['tasks'] as List).cast<Map>();
      final exportedAction = tasks.singleWhere(
        (task) => task['id'] == action.id,
      );
      expect(
        tasks.map((task) => task['id']),
        containsAll([project.id, action.id]),
      );
      expect(exportedAction['listId'], 'home');
      expect(exportedAction['parentTaskId'], project.id);
      expect(exportedAction['sourceStepId'], 'sources');
      expect(exportedAction['isDone'], isTrue);
      expect(
        exportedAction['completedAt'],
        action.completedAt!.toIso8601String(),
      );
      final plans = (export['plans'] as List).cast<Map>();
      expect(plans.single['selectedTaskIds'], [action.id]);
      expect(
        (plans.single['taskSnapshots'] as Map)[action.id]['deadline'],
        deadline.toIso8601String(),
      );
      final events = (export['events'] as List).cast<Map>();
      final accepted = events.singleWhere(
        (event) => event['type'] == 'plan_saved',
      );
      expect((accepted['planSnapshot'] as Map)['selectedTaskIds'], [action.id]);
      final completed = events.singleWhere(
        (event) => event['type'] == 'task_completed',
      );
      expect(completed['taskId'], action.id);
      expect(completed['parentTaskId'], project.id);
      expect(completed['sourceStepId'], 'sources');
      expect(tester.takeException(), isNull);
    },
  );
}
