import 'dart:convert';
import 'dart:io';

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
  late Task action;
  final day = DateTime(2026, 11, 12);

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
    action = state.actionForStep(parent.id, 'materials')!;
  }

  Future<void> flushEvents() => Hive.box<Map>('analytics_events').flush();

  List<Map<String, dynamic>> eventsOf(String type) =>
      state.analyticsEvents.where((event) => event['type'] == type).toList();

  Map<String, dynamic> exportData() =>
      Map<String, dynamic>.from(jsonDecode(state.exportAnalyticsJson()) as Map);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myhero_pilot_tracking_');
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
      breakdownSteps: ['Собрать материалы'],
      breakdownStepIds: ['materials'],
    );
    await state.addTask(parent, listId: 'home');
    action = await state.createActionFromStep(
      parent,
      stepId: 'materials',
      estimatedDurationMinutes: 20,
    );
    action.deadline = day.add(const Duration(days: 1));
    await state.updateTask(action, title: action.title, date: day);
  });

  tearDown(() => state.dispose());

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'records actual completion once and persists its entity links',
    () async {
      final before = DateTime.now().toUtc();
      await Future.wait([
        state.toggleDone(action, true),
        state.toggleDone(action, true),
      ]);
      final after = DateTime.now().toUtc();
      final completedAt = action.completedAt!;
      expect(
        completedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(before.millisecondsSinceEpoch),
      );
      expect(
        completedAt.millisecondsSinceEpoch,
        lessThanOrEqualTo(after.millisecondsSinceEpoch),
      );
      final xp = state.xpEarned;
      await state.toggleDone(action, true);
      await flushEvents();
      expect(action.completedAt, completedAt);
      expect(state.xpEarned, xp);
      expect(parent.isDone, isFalse);
      final event = eventsOf('task_completed').single;
      expect(event['taskId'], action.id);
      expect(event['parentTaskId'], parent.id);
      expect(event['sourceStepId'], 'materials');
      expect(DateTime.parse(event['timestamp'] as String), completedAt);
      expect(DateTime.parse(event['completedAt'] as String), completedAt);

      await reopen();
      expect(action.isDone, isTrue);
      expect(action.completedAt, completedAt);
      expect(Task.fromMap(action.toMap()).completedAt, completedAt);
      expect(eventsOf('task_completed').single['id'], event['id']);
    },
  );

  test(
    'undo preserves the prior completion in an event and clears current completion',
    () async {
      await state.toggleDone(action, true);
      final completedAt = action.completedAt!;
      await state.toggleDone(action, false);
      await state.toggleDone(action, false);
      await flushEvents();
      expect(action.isDone, isFalse);
      expect(action.completedAt, isNull);
      final undo = eventsOf('task_completion_undone').single;
      expect(undo['taskId'], action.id);
      expect(undo['parentTaskId'], parent.id);
      expect(undo['sourceStepId'], 'materials');
      expect(
        DateTime.parse(undo['previousCompletedAt'] as String),
        completedAt,
      );
      expect(undo['completedAt'], isNull);

      await reopen();
      expect(action.isDone, isFalse);
      expect(action.completedAt, isNull);
      expect(eventsOf('task_completed').length, 1);
      expect(eventsOf('task_completion_undone').length, 1);
      await state.toggleDone(action, true);
      expect(action.completedAt!.isBefore(completedAt), isFalse);
      expect(eventsOf('task_completed').length, 2);
      final newestCompletionSequence = eventsOf('task_completed')
          .map((event) => event['sequence'] as num)
          .reduce((a, b) => a > b ? a : b);
      expect(newestCompletionSequence, greaterThan(undo['sequence'] as num));
    },
  );

  test(
    'legacy completed records retain unknown completion time until a new transition',
    () async {
      final old = Task(
        id: 'legacy-done',
        title: 'Выполнено раньше',
        isDone: true,
      );
      await state.addTaskToInbox(old);
      Hive.registerAdapter(_TaskBeforeCompletionAdapter(), override: true);
      final inbox = state.inboxList;
      await Hive.box<TaskList>('task_lists').put(inbox.id, inbox);
      await reopen();

      final restored = state.taskById(old.id)!;
      expect(restored.isDone, isTrue);
      expect(restored.completedAt, isNull);
      await state.toggleDone(restored, true);
      expect(restored.completedAt, isNull);
      expect(eventsOf('task_completed'), isEmpty);
      final exported = (exportData()['tasks'] as List).cast<Map>().singleWhere(
        (task) => task['id'] == old.id,
      );
      expect(exported['isDone'], isTrue);
      expect(exported['completedAt'], isNull);

      await state.toggleDone(restored, false);
      expect(
        eventsOf('task_completion_undone').single['previousCompletedAt'],
        isNull,
      );
      await state.toggleDone(restored, true);
      expect(restored.completedAt, isNotNull);
      expect(eventsOf('task_completed').single['taskId'], old.id);
    },
  );

  test(
    'only generation logs generation and plan edits include identifying snapshots',
    () async {
      await state.savePlanForDay(day, 60, plannedTasks: [action]);
      expect(eventsOf('plan_generated'), isEmpty);
      state.editAcceptedPlan(day);
      state.setPlanBudget(day, 90);
      state.setPlanBudget(day, 90);
      await state.acceptPlanDraft(day);
      await flushEvents();
      expect(eventsOf('plan_generated'), isEmpty);
      final changes = eventsOf('plan_changed');
      expect(changes, hasLength(1));
      expect(changes.single['planId'], isNotNull);
      expect(
        DateTime.tryParse(changes.single['timestamp'] as String),
        isNotNull,
      );

      state.generatePlanDraft(day, 60);
      await state.acceptPlanDraft(day);
      await flushEvents();
      final generated = eventsOf('plan_generated').single;
      expect(generated['planId'], isNotNull);
      expect(generated['selectedTaskIds'], contains(action.id));
      expect(DateTime.tryParse(generated['timestamp'] as String), isNotNull);
      final accepted = state.acceptedPlanForDay(day)!;
      final savedCount = eventsOf('plan_saved').length;
      await state.savePlan(accepted);
      await Future.wait([state.savePlan(accepted), state.savePlan(accepted)]);
      expect(eventsOf('plan_generated'), hasLength(1));
      expect(eventsOf('plan_saved'), hasLength(savedCount));
    },
  );

  test(
    'acceptance snapshots retain original composition and deadlines through later edits',
    () async {
      final firstDeadline = action.deadline!.toIso8601String();
      final firstTitle = action.title;
      await state.savePlanForDay(day, 60, plannedTasks: [action]);
      await flushEvents();
      final firstSnapshot =
          eventsOf('plan_saved').single['planSnapshot'] as Map;
      final firstAcceptance = firstSnapshot['acceptanceId'];
      expect(firstAcceptance, isNotNull);
      expect(firstSnapshot['selectedTaskIds'], [action.id]);
      expect(
        (firstSnapshot['taskSnapshots'] as Map)[action.id]['deadline'],
        firstDeadline,
      );

      (firstSnapshot['taskSnapshots'] as Map)[action.id]['title'] =
          'Изменение внешней копии';
      expect(
        ((eventsOf('plan_saved').single['planSnapshot'] as Map)['taskSnapshots']
            as Map)[action.id]['title'],
        firstTitle,
      );

      action.deadline = day.add(const Duration(days: 6));
      await state.updateTask(action, title: 'Новое название', date: day);
      state.editAcceptedPlan(day);
      state.addTaskToPlan(day, parent.id);
      state.setPlanBudget(day, 300);
      await state.acceptPlanDraft(day);
      await state.deleteTask(action);
      state.dispose();
      await Hive.close();
      await openBoxes();
      state = AppState();

      final data = exportData();
      final saved = (data['events'] as List)
          .cast<Map>()
          .where((event) => event['type'] == 'plan_saved')
          .toList();
      expect(saved, hasLength(2));
      final original = saved
          .map((event) => event['planSnapshot'] as Map)
          .singleWhere((plan) => plan['acceptanceId'] == firstAcceptance);
      expect(original['selectedTaskIds'], [action.id]);
      final originalTask = (original['taskSnapshots'] as Map)[action.id] as Map;
      expect(originalTask['title'], firstTitle);
      expect(originalTask['deadline'], firstDeadline);
      expect(originalTask['date'], day.toIso8601String());
      expect(
        (data['tasks'] as List).cast<Map>().any(
          (task) => task['id'] == action.id,
        ),
        isFalse,
      );
      expect((data['plans'] as List).cast<Map>().single['selectedTaskIds'], [
        action.id,
        parent.id,
      ]);
    },
  );

  test(
    'reaccepting a legacy plan preserves its known snapshot without inventing an acceptance time',
    () async {
      final legacyPlan = <String, dynamic>{
        'id': 'legacy-plan',
        'date': day.toIso8601String(),
        'status': 'saved',
        'availableMinutes': 60,
        'usedMinutes': 20,
        'generatedAt': '2026-11-10T09:00:00.000Z',
        'selectedTaskIds': [action.id],
        'selectedTitles': ['Первоначальный известный шаг'],
        'taskSnapshots': {
          action.id: {
            'title': 'Первоначальный известный шаг',
            'durationMinutes': 20,
            'date': day.toIso8601String(),
            'deadline': day.add(const Duration(days: 2)).toIso8601String(),
            'recurrenceType': TaskRecurrenceType.none.index,
            'priority': null,
          },
        },
      };
      await Hive.box<Map>('day_plans').put('legacy-plan', legacyPlan);
      action.deadline = day.add(const Duration(days: 7));
      await state.updateTask(action, title: 'Поздняя правка шага', date: day);
      state.editAcceptedPlan(day);
      await state.acceptPlanDraft(day);
      await flushEvents();
      await reopen();

      final exportedEvents = (exportData()['events'] as List).cast<Map>();
      final acceptance = exportedEvents.singleWhere(
        (event) => event['type'] == 'plan_saved',
      );
      final previous = acceptance['previousPlanSnapshot'] as Map;
      expect(previous, legacyPlan);
      expect(previous.containsKey('acceptanceId'), isFalse);
      expect(previous.containsKey('savedAt'), isFalse);
      expect(previous['generatedAt'], '2026-11-10T09:00:00.000Z');
      final knownTask = (previous['taskSnapshots'] as Map)[action.id] as Map;
      expect(knownTask['title'], 'Первоначальный известный шаг');
      expect(
        knownTask['deadline'],
        day.add(const Duration(days: 2)).toIso8601String(),
      );
      final current = acceptance['planSnapshot'] as Map;
      expect(current['acceptanceId'], isNotNull);
      expect(current['savedAt'], isNotNull);
      expect(
        (current['taskSnapshots'] as Map)[action.id]['title'],
        'Поздняя правка шага',
      );
    },
  );

  test(
    'export reconstructs accepted revisions and completion sequence after reopening',
    () async {
      final originalTitle = action.title;
      final originalDeadline = action.deadline!.toIso8601String();
      await state.savePlanForDay(day, 60, plannedTasks: [action]);
      await state.toggleDone(action, true);
      await state.toggleDone(action, false);
      await state.toggleDone(parent, true);
      await state.toggleDone(action, true);
      action.deadline = day.add(const Duration(days: 5));
      await state.updateTask(action, title: 'Изменённый шаг', date: day);
      state.editAcceptedPlan(day);
      state.setPlanBudget(day, 90);
      await state.acceptPlanDraft(day);
      await flushEvents();
      await reopen();

      final data = exportData();
      expect(data['schemaVersion'], 2);
      expect(DateTime.tryParse(data['exportedAt'] as String), isNotNull);
      expect(data['taskLists'], isA<List>());
      final tasks = (data['tasks'] as List).cast<Map>();
      final exportedAction = tasks.singleWhere(
        (task) => task['id'] == action.id,
      );
      expect(exportedAction['parentTaskId'], parent.id);
      expect(exportedAction['sourceStepId'], 'materials');
      expect(exportedAction['listId'], 'home');
      expect(
        exportedAction['completedAt'],
        action.completedAt!.toIso8601String(),
      );
      final exportedParent = tasks.singleWhere(
        (task) => task['id'] == parent.id,
      );
      expect(exportedParent['breakdownStepIds'], ['materials']);

      final events = (data['events'] as List).cast<Map>();
      expect(events.map((event) => event['id']).toSet().length, events.length);
      final acceptances =
          events.where((event) => event['type'] == 'plan_saved').toList()..sort(
            (a, b) => (a['sequence'] as num).compareTo(b['sequence'] as num),
          );
      expect(acceptances, hasLength(2));
      final originalPlan = acceptances.first['planSnapshot'] as Map;
      final latestPlan = acceptances.last['planSnapshot'] as Map;
      expect(originalPlan['selectedTaskIds'], [action.id]);
      expect(
        (originalPlan['taskSnapshots'] as Map)[action.id]['title'],
        originalTitle,
      );
      expect(
        (originalPlan['taskSnapshots'] as Map)[action.id]['deadline'],
        originalDeadline,
      );
      expect(latestPlan['acceptanceId'], isNot(originalPlan['acceptanceId']));
      final exportedPlan = (data['plans'] as List).cast<Map>().single;
      expect(exportedPlan['acceptanceId'], latestPlan['acceptanceId']);

      final transitions =
          events
              .where(
                (event) =>
                    event['type'] == 'task_completed' ||
                    event['type'] == 'task_completion_undone',
              )
              .toList()
            ..sort(
              (a, b) => (a['sequence'] as num).compareTo(b['sequence'] as num),
            );
      expect(transitions.map((event) => event['type']), [
        'task_completed',
        'task_completion_undone',
        'task_completed',
        'task_completed',
      ]);
      expect(transitions.map((event) => event['taskId']), [
        action.id,
        action.id,
        parent.id,
        action.id,
      ]);
      final reconstructedDone = <String, String?>{};
      for (final event in transitions) {
        final id = event['taskId'] as String;
        reconstructedDone[id] = event['type'] == 'task_completed'
            ? event['completedAt'] as String
            : null;
      }
      expect(reconstructedDone[action.id], exportedAction['completedAt']);
      expect(reconstructedDone[parent.id], exportedParent['completedAt']);
      expect(data.containsKey('planningDurationMinutes'), isFalse);
    },
  );
}

// The prior layout ends at field 16 and knows nothing about completedAt.
class _TaskBeforeCompletionAdapter extends TypeAdapter<Task> {
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
      obj.breakdownStepIds,
      obj.parentTaskId,
      obj.sourceStepId,
    ];
    writer.writeByte(fields.length);
    for (var i = 0; i < fields.length; i++) {
      writer
        ..writeByte(i)
        ..write(fields[i]);
    }
  }
}
