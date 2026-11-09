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
  final day = DateTime(2026, 11, 10);
  late Task a;
  late Task b;
  late Task c;

  Future<void> openBoxes() async {
    await Hive.openBox('settings');
    await Hive.openBox<Map>('day_plans');
    await Hive.openBox<Map>('analytics_events');
    await Hive.openBox<TaskList>('task_lists');
    await Hive.openBox<Habit>('habits');
    await Hive.openBox<JournalEntry>('journal_entries');
    await Hive.openBox<Achievement>('achievements');
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myhero_day_plan_');
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
    a = Task(id: 'a', title: 'Task A', durationMinutes: 30, priority: 5);
    b = Task(id: 'b', title: 'Task B', durationMinutes: 30, priority: 4);
    c = Task(id: 'c', title: 'Task C', durationMinutes: 30, priority: 3);
    await state.addTaskToInbox(a);
    await state.addTaskToInbox(b);
    await state.addTask(c, listId: 'home');
  });

  tearDown(() => state.dispose());

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> saveTasks(List<Task> tasks, {int budget = 60, DateTime? date}) =>
      state.savePlanForDay(date ?? day, budget, plannedTasks: tasks);

  test(
    'generate, remove, add, reorder, accept and reopen Hive preserves the working list',
    () async {
      state.generatePlanDraft(day, 60);
      expect(state.planDraftForDay(day)!['selectedTaskIds'], ['a', 'b']);
      expect(state.acceptedPlanForDay(day), isNull);

      state.removeTaskFromPlan(day, 'a');
      expect(
        state.reviewPlan(state.planDraftForDay(day)!).remainingMinutes,
        30,
      );
      state.addTaskToPlan(day, 'c');
      state.movePlanTask(day, 1, 0);
      final draft = state.planDraftForDay(day)!;
      expect(draft['selectedTaskIds'], ['c', 'b']);
      expect(draft['usedMinutes'], 60);
      expect(state.acceptedPlanForDay(day), isNull);

      await state.acceptPlanDraft(day);
      expect(state.planDraftForDay(day), isNull);
      expect(
        state
            .tasksForPlan(state.acceptedPlanForDay(day)!)
            .map((task) => task.id),
        ['c', 'b'],
      );
      expect(a.date, isNull);

      state.dispose();
      await Hive.close();
      await openBoxes();
      state = AppState();
      final accepted = state.acceptedPlanForDay(day)!;
      expect(accepted['selectedTaskIds'], ['c', 'b']);
      expect(state.tasksForPlan(accepted).map((task) => task.id), ['c', 'b']);
      expect(state.reviewPlan(accepted).usedMinutes, 60);
      expect(state.reviewPlan(accepted).hasChanges, isFalse);
      expect(state.planDraftForDay(day), isNull);
      expect(state.acceptedPlanForDay(DateTime(2026, 11, 11)), isNull);
      expect(
        state.remainingTasksForPlan(accepted).map((task) => task.id),
        contains('a'),
      );
    },
  );

  test(
    'draft edits and regeneration never replace the accepted plan without acceptance',
    () async {
      await saveTasks([a]);
      state.generatePlanDraft(day, 60);
      state.removeTaskFromPlan(day, 'a');
      state.addTaskToPlan(day, 'c');
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['a']);
      expect(state.planDraftForDay(day)!['selectedTaskIds'], ['b', 'c']);

      state.discardPlanDraft(day);
      expect(state.planDraftForDay(day), isNull);
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['a']);
      state.editAcceptedPlan(day);
      state.setPlanBudget(day, 90);
      expect(state.acceptedPlanForDay(day)!['availableMinutes'], 60);
      expect(state.planDraftForDay(day)!['availableMinutes'], 90);
    },
  );

  test(
    'deduplicates tasks and blocks an over-budget draft before persistence',
    () async {
      await saveTasks([a]);
      state.generatePlanDraft(day, 60);
      state.addTaskToPlan(day, 'b');
      state.addTaskToPlan(day, 'c');
      final draft = state.planDraftForDay(day)!;
      expect(draft['selectedTaskIds'], ['a', 'b', 'c']);
      final review = state.reviewPlan(draft);
      expect(review.usedMinutes, 90);
      expect(review.remainingMinutes, -30);
      expect(review.canAccept, isFalse);
      await expectLater(state.acceptPlanDraft(day), throwsStateError);
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['a']);
      expect(Hive.box<Map>('day_plans').length, 1);

      state.removeTaskFromPlan(day, 'a');
      await state.acceptPlanDraft(day);
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['b', 'c']);
      expect(state.acceptedPlanForDay(day)!['usedMinutes'], 60);
    },
  );

  test(
    'validates live durations in every save API instead of trusting stored totals',
    () async {
      await expectLater(
        state.savePlan({
          'date': day.toIso8601String(),
          'availableMinutes': 30,
          'usedMinutes': 0,
          'selectedTaskIds': ['a', 'b'],
        }),
        throwsStateError,
      );
      await expectLater(saveTasks([a, b], budget: 30), throwsStateError);
      expect(state.savedPlans, isEmpty);

      await state.savePlan({
        'date': day.toIso8601String(),
        'availableMinutes': 30,
        'usedMinutes': 999,
        'selectedTaskIds': ['a', 'a'],
      });
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['a']);
      expect(state.acceptedPlanForDay(day)!['usedMinutes'], 30);
    },
  );

  test(
    'repeated and concurrent saves do not create duplicate plans or analytics',
    () async {
      await saveTasks([b, a]);
      final accepted = state.acceptedPlanForDay(day)!;
      await state.savePlan(accepted);
      await Future.wait([state.savePlan(accepted), state.savePlan(accepted)]);
      state.editAcceptedPlan(day);
      await state.acceptPlanDraft(day);

      expect(Hive.box<Map>('day_plans').length, 1);
      expect(state.savedPlans.length, 1);
      expect(state.acceptedPlanForDay(day)!['savedAt'], accepted['savedAt']);
      expect(
        state.analyticsEvents
            .where((event) => event['type'] == 'plan_saved')
            .length,
        1,
      );
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['b', 'a']);
    },
  );

  test('accepted plans and drafts belong to their calendar day', () async {
    final tomorrow = DateTime(2026, 11, 11);
    await saveTasks([a]);
    await saveTasks([c], date: tomorrow, budget: 90);
    state.editAcceptedPlan(day);
    state.removeTaskFromPlan(day, 'a');

    expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['a']);
    expect(state.planDraftForDay(day)!['selectedTaskIds'], isEmpty);
    expect(state.planDraftForDay(tomorrow), isNull);
    expect(state.acceptedPlanForDay(tomorrow)!['selectedTaskIds'], ['c']);
    expect(
      state.acceptedPlanForDay(DateTime(2026, 11, 10, 23))!['selectedTaskIds'],
      ['a'],
    );
    expect(state.acceptedPlanForDay(DateTime(2026, 11, 12)), isNull);
    expect(state.savedPlans.length, 2);
  });

  test(
    'restores the latest legacy accepted plan by save time, not insertion order',
    () async {
      final box = Hive.box<Map>('day_plans');
      await box.put('newer', {
        'date': day.toIso8601String(),
        'status': 'saved',
        'availableMinutes': 60,
        'selectedTaskIds': ['c', 'a'],
        'savedAt': '2026-11-10T12:00:00.000',
      });
      await box.put('older', {
        'date': day.toIso8601String(),
        'status': 'saved',
        'availableMinutes': 60,
        'selectedTaskIds': ['b'],
        'savedAt': '2026-11-10T09:00:00.000',
      });
      await box.put('unaccepted', {
        'date': day.toIso8601String(),
        'status': 'proposed',
        'availableMinutes': 60,
        'selectedTaskIds': ['a'],
        'savedAt': '2026-11-10T15:00:00.000',
      });
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['c', 'a']);
      expect(state.savedPlans.length, 1);
    },
  );

  test(
    'a source duration change is visible and must fit before accepting again',
    () async {
      await saveTasks([a, b]);
      a.durationMinutes = 60;
      await state.updateTask(a, title: a.title, date: a.date);
      var review = state.reviewPlan(state.acceptedPlanForDay(day)!);
      expect(review.usedMinutes, 90);
      expect(review.hasChanges, isTrue);
      expect(review.isOverBudget, isTrue);
      expect(state.acceptedPlanForDay(day)!['usedMinutes'], 60);

      state.editAcceptedPlan(day);
      await expectLater(state.acceptPlanDraft(day), throwsStateError);
      state.setPlanBudget(day, 90);
      await state.acceptPlanDraft(day);
      review = state.reviewPlan(state.acceptedPlanForDay(day)!);
      expect(review.usedMinutes, 90);
      expect(review.hasChanges, isFalse);
      expect(review.canAccept, isTrue);
    },
  );

  test(
    'deleted and rescheduled source tasks remain visible as invalid plan entries',
    () async {
      await saveTasks([a, b]);
      await state.deleteTask(a);
      await state.updateTask(
        b,
        title: 'Renamed B',
        date: DateTime(2026, 11, 11),
      );
      final accepted = state.acceptedPlanForDay(day)!;
      final review = state.reviewPlan(accepted);
      expect(review.entries.map((entry) => entry.id), ['a', 'b']);
      expect(review.entries.first.title, 'Task A');
      expect(review.entries.first.task, isNull);
      expect(review.entries.last.title, 'Renamed B');
      expect(review.entries.last.isAvailable, isFalse);
      expect(review.blockingMessages.length, 2);
      expect(state.tasksForPlan(accepted).map((task) => task.id), ['b']);

      state.editAcceptedPlan(day);
      await expectLater(state.acceptPlanDraft(day), throwsStateError);
      state.removeTaskFromPlan(day, 'a');
      state.removeTaskFromPlan(day, 'b');
      state.addTaskToPlan(day, 'c');
      await state.acceptPlanDraft(day);
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], ['c']);
    },
  );

  test(
    'completing a task preserves membership, order and snapshot validity',
    () async {
      await saveTasks([b, a]);
      await state.toggleDone(b, true);
      final accepted = state.acceptedPlanForDay(day)!;
      expect(state.tasksForPlan(accepted).map((task) => task.id), ['b', 'a']);
      expect(state.reviewPlan(accepted).hasChanges, isFalse);
      expect(state.reviewPlan(accepted).canAccept, isTrue);
    },
  );

  test(
    'empty plans remain accepted and returned maps cannot mutate state',
    () async {
      await saveTasks([]);
      final accepted = state.acceptedPlanForDay(day)!;
      expect(accepted['selectedTaskIds'], isEmpty);
      (accepted['selectedTaskIds'] as List).add('a');
      expect(state.acceptedPlanForDay(day)!['selectedTaskIds'], isEmpty);
      state.editAcceptedPlan(day);
      final draft = state.planDraftForDay(day)!;
      (draft['selectedTaskIds'] as List).add('b');
      expect(state.planDraftForDay(day)!['selectedTaskIds'], isEmpty);
    },
  );
}
