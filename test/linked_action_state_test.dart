import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_application_1/models/achievement.dart';
import 'package:flutter_application_1/models/habit.dart';
import 'package:flutter_application_1/models/journal_entry.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/models/task_list.dart';
import 'package:flutter_application_1/state/app_state.dart';

void main() {
  late Directory tempDir;
  late AppState state;
  late Task parent;
  final day = DateTime(2026, 11, 11);

  Future<void> openBoxes() async {
    await Hive.openBox('settings');
    await Hive.openBox<Map>('day_plans');
    await Hive.openBox<Map>('analytics_events');
    await Hive.openBox<TaskList>('task_lists');
    await Hive.openBox<Habit>('habits');
    await Hive.openBox<JournalEntry>('journal_entries');
    await Hive.openBox<Achievement>('achievements');
  }

  Future<void> reopen() async {
    state.dispose();
    await Hive.close();
    Hive.registerAdapter(TaskAdapter(), override: true);
    await openBoxes();
    state = AppState();
    parent = state.taskById('project')!;
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myhero_linked_actions_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(TaskListAdapter());
    Hive.registerAdapter(HabitAdapter());
    Hive.registerAdapter(JournalEntryAdapter());
    Hive.registerAdapter(AchievementAdapter());
    Hive.registerAdapter(AchievementTypeAdapter());
    await openBoxes();
  });

  setUp(() async {
    await Hive.box<TaskList>('task_lists').clear();
    await Hive.box<Map>('day_plans').clear();
    await Hive.box<Map>('analytics_events').clear();
    state = AppState();
    parent = Task(
      id: 'project',
      title: 'Подготовить презентацию',
      durationMinutes: 240,
      estimatedDurationMinutes: 300,
      date: day.add(const Duration(days: 5)),
      deadline: day.add(const Duration(days: 7)),
      recurrenceType: TaskRecurrenceType.weekly,
      taskPriority: TaskPriority.high,
      breakdownSteps: ['Собрать материалы', 'Подготовить слайды'],
      breakdownStepIds: ['materials', 'slides'],
    )..color = Colors.green;
    await state.addTask(parent, listId: 'home');
  });

  tearDown(() => state.dispose());

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<Task> create({String stepId = 'materials', int minutes = 20}) =>
      state.createActionFromStep(
        parent,
        stepId: stepId,
        estimatedDurationMinutes: minutes,
      );

  test(
    'creates a linked, independently estimated and plannable action',
    () async {
      final action = await create();
      expect(action.title, 'Собрать материалы');
      expect(action.parentTaskId, parent.id);
      expect(action.sourceStepId, 'materials');
      expect(action.estimatedDurationMinutes, 20);
      expect(action.effectiveDurationMinutes, 20);
      expect(action.durationMinutes, isNull);
      expect(action.date, isNull);
      expect(action.recurrenceType, TaskRecurrenceType.none);
      expect(action.isDone, isFalse);
      expect(parent.isDone, isFalse);
      expect(parent.effectiveDurationMinutes, 240);
      expect(
        state.lists.singleWhere((l) => l.id == 'home').tasks,
        contains(action),
      );
      expect(state.candidatesForPlan(day), contains(action));
      expect(state.acceptedPlanForDay(day), isNull);
    },
  );

  test(
    'repeated and simultaneous creation reuses the action after edits',
    () async {
      final actions = await Future.wait([create(), create()]);
      expect(actions[0], same(actions[1]));
      final action = actions.first;
      parent
        ..breakdownSteps = ['Подготовить слайды', 'Уточнённый сбор материалов']
        ..breakdownStepIds = ['slides', 'materials'];
      await state.updateTask(parent, title: parent.title, date: parent.date);
      await state.updateTask(action, title: 'Моё название действия');
      await state.toggleDone(action, true);

      final repeated = await create(minutes: 90);
      expect(repeated.id, action.id);
      expect(repeated.title, 'Моё название действия');
      expect(repeated.estimatedDurationMinutes, 20);
      expect(repeated.isDone, isTrue);
      expect(state.lists.expand((l) => l.tasks).length, 2);
      expect(parent.isDone, isFalse);
    },
  );

  test(
    'identical step text with distinct IDs creates distinct actions',
    () async {
      parent.breakdownSteps[1] = parent.breakdownSteps[0];
      final first = await create();
      final second = await create(stepId: 'slides', minutes: 15);
      expect(first.title, second.title);
      expect(first.id, isNot(second.id));
      expect(first.sourceStepId, isNot(second.sourceStepId));
      expect(second.effectiveDurationMinutes, 15);
    },
  );

  test(
    'action uses plan correction, budget checks and independent completion',
    () async {
      final other = Task(
        id: 'other',
        title: 'Другая задача',
        durationMinutes: 30,
      );
      await state.addTaskToInbox(other);
      await state.savePlanForDay(day, 30, plannedTasks: [other]);
      final action = await create();

      state.editAcceptedPlan(day);
      state.addTaskToPlan(day, action.id);
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['other']);
      expect(state.reviewPlan(state.planDraftForDay(day)!).usedMinutes, 50);
      await expectLater(state.acceptPlanDraft(day), throwsStateError);
      state.removeTaskFromPlan(day, other.id);
      await state.acceptPlanDraft(day);
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], [action.id]);
      expect(state.reviewPlan(state.acceptedPlanForDay(day)!).usedMinutes, 20);

      await state.toggleDone(action, true);
      expect(action.isDone, isTrue);
      expect(parent.isDone, isFalse);
      expect(state.tasksForPlan(state.acceptedPlanForDay(day)!), [action]);
      expect(
        state.reviewPlan(state.acceptedPlanForDay(day)!).hasChanges,
        isFalse,
      );
    },
  );

  test(
    'reopening Hive retains edited steps, links, plan and completion',
    () async {
      final action = await create();
      parent.breakdownSteps[0] = 'Собрать и проверить материалы';
      await state.updateTask(parent, title: parent.title, date: parent.date);
      await state.savePlanForDay(day, 30, plannedTasks: [action]);
      await state.toggleDone(action, true);
      final actionId = action.id;

      await reopen();
      expect(parent.breakdownSteps, [
        'Собрать и проверить материалы',
        'Подготовить слайды',
      ]);
      expect(parent.breakdownStepIds, ['materials', 'slides']);
      final restored = state.actionForStep(parent.id, 'materials')!;
      expect(restored.id, actionId);
      expect(restored.parentTaskId, parent.id);
      expect(restored.sourceStepId, 'materials');
      expect(restored.effectiveDurationMinutes, 20);
      expect(restored.isDone, isTrue);
      expect(parent.isDone, isFalse);
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], [actionId]);
      expect((await create()).id, actionId);
      expect(state.lists.expand((l) => l.tasks).length, 2);
    },
  );

  test(
    'legacy Hive records gain stable step IDs without losing old fields',
    () async {
      // Write actual old binary layouts, then reopen them with the new adapter.
      Hive.registerAdapter(_LegacyTaskAdapter(), override: true);
      final old = Task(
        id: 'very-old',
        title: 'Старая задача',
        durationMinutes: 45,
      );
      final list = state.lists.singleWhere((l) => l.id == 'home');
      list.tasks.add(old);
      await Hive.box<TaskList>('task_lists').put(list.id, list);
      await reopen();

      expect(parent.breakdownSteps, [
        'Собрать материалы',
        'Подготовить слайды',
      ]);
      expect(parent.date, day.add(const Duration(days: 5)));
      expect(parent.deadline, day.add(const Duration(days: 7)));
      expect(parent.durationMinutes, 240);
      expect(parent.estimatedDurationMinutes, 300);
      expect(parent.recurrenceType, TaskRecurrenceType.weekly);
      expect(parent.taskPriority, TaskPriority.high);
      expect(parent.colorValue, Colors.green.toARGB32());
      expect(parent.parentTaskId, isNull);
      expect(parent.sourceStepId, isNull);
      final stepIds = List.of(parent.breakdownStepIds);
      expect(stepIds.toSet().length, 2);
      final veryOld = state.taskById('very-old')!;
      expect(veryOld.breakdownSteps, isEmpty);
      expect(veryOld.breakdownStepIds, isEmpty);
      expect(veryOld.recurrenceType, TaskRecurrenceType.none);
      expect(veryOld.taskPriority, TaskPriority.medium);
      expect(veryOld.estimatedDurationMinutes, 45);

      await reopen();
      expect(parent.breakdownStepIds, stepIds);
      final action = await create(stepId: stepIds.first);
      await reopen();
      expect(parent.breakdownStepIds, stepIds);
      expect((await create(stepId: stepIds.first)).id, action.id);
      expect(state.taskById('very-old')!.title, 'Старая задача');
    },
  );

  test(
    'map export and import preserve step identities and action links',
    () async {
      final action = await create();
      final restoredParent = Task.fromMap(parent.toMap());
      final restoredAction = Task.fromMap(action.toMap());
      expect(restoredParent.breakdownStepIds, parent.breakdownStepIds);
      expect(restoredParent.breakdownSteps, parent.breakdownSteps);
      expect(restoredAction.parentTaskId, parent.id);
      expect(restoredAction.sourceStepId, parent.breakdownStepIds.first);
      expect(restoredAction.effectiveDurationMinutes, 20);
    },
  );

  test(
    'rejects invalid durations and stale step or parent identifiers',
    () async {
      for (final minutes in [0, -1, 1441]) {
        await expectLater(create(minutes: minutes), throwsArgumentError);
      }
      await expectLater(create(stepId: 'missing'), throwsStateError);
      parent.breakdownSteps[0] = ' ';
      await expectLater(create(), throwsStateError);
      await state.deleteTask(parent);
      await expectLater(create(), throwsStateError);
      expect(state.lists.expand((l) => l.tasks), isEmpty);
    },
  );
}

// This fixture deliberately implements the layouts used before linked actions.
class _LegacyTaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 1;

  @override
  Task read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, Task obj) {
    final fields = [
      obj.id,
      obj.title,
      obj.isDone,
      obj.durationMinutes,
      obj.priority,
      obj.date,
      obj.category,
      obj.colorValue,
      obj.listId,
      obj.recurrenceType.index,
      obj.taskPriority.index,
      obj.deadline,
      obj.estimatedDurationMinutes,
      obj.breakdownSteps,
    ];
    final count = obj.id == 'very-old' ? 9 : 14;
    writer.writeByte(count);
    for (var i = 0; i < count; i++) {
      writer
        ..writeByte(i)
        ..write(fields[i]);
    }
  }
}
