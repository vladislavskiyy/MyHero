import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/dialogs/task_dialog.dart';
import 'package:flutter_application_1/models/achievement.dart';
import 'package:flutter_application_1/models/habit.dart';
import 'package:flutter_application_1/models/journal_entry.dart';
import 'package:flutter_application_1/models/task.dart';
import 'package:flutter_application_1/models/task_list.dart';
import 'package:flutter_application_1/pages/scheduler_page.dart';
import 'package:flutter_application_1/pages/today_page.dart';
import 'package:flutter_application_1/state/app_state.dart';

void main() {
  late Directory tempDir;
  late AppState appState;

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
    tempDir = await Directory.systemTemp.createTemp('myhero_planning_ui_');
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
    appState = AppState();
    appState.notificationsEnabled = false;
  });

  tearDown(() => appState.dispose());

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> showPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final page in [
    (
      name: 'Today',
      widget: const TodayPage(),
      generateLabel: 'Сгенерировать план',
    ),
    (
      name: 'Scheduler',
      widget: const SchedulerPage(),
      generateLabel: 'Сгенерировать план',
    ),
  ]) {
    testWidgets(
      '${page.name} generates the real plan and rejects invalid time',
      (tester) async {
        appState.inboxList.tasks.addAll([
          Task(
            id: 'important',
            title: 'Important task',
            durationMinutes: 90,
            priority: 5,
          ),
          Task(
            id: 'short',
            title: 'Short task',
            durationMinutes: 30,
            priority: 4,
          ),
        ]);
        await showPage(tester, page.widget);
        final minutesField = find.byType(TextField);
        final generate = find.widgetWithText(
          ElevatedButton,
          page.generateLabel,
        );

        await tester.enterText(minutesField, '90');
        await tester.runAsync(() async {
          await tester.tap(generate);
          await Hive.box<Map>('analytics_events').flush();
        });
        await tester.pumpAndSettle();

        expect(find.text('Important task'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('plan-totals'))).data,
          contains('90 мин'),
        );
        expect(
          appState.analyticsEvents
              .where((event) => event['type'] == 'plan_generated')
              .length,
          1,
        );

        for (final invalid in ['', 'abc', '0', '-1', '1.5', '1441']) {
          await tester.enterText(minutesField, invalid);
          await tester.tap(generate);
          await tester.pumpAndSettle();

          expect(
            find.text('Введите целое число минут от 1 до 1440.'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Сохранить'),
                )
                .onPressed,
            isNull,
          );
          expect(appState.acceptedPlanForDay(DateTime.now()), isNull);
          expect(
            appState.analyticsEvents
                .where((event) => event['type'] == 'plan_generated')
                .length,
            1,
          );
        }

        await tester.enterText(minutesField, ' 90 ');
        await tester.runAsync(() async {
          await tester.tap(generate);
          await Hive.box<Map>('analytics_events').flush();
        });
        await tester.pumpAndSettle();
        expect(
          find.text('Введите целое число минут от 1 до 1440.'),
          findsNothing,
        );
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('plan-totals'))).data,
          contains('90 мин'),
        );
        expect(
          appState.analyticsEvents
              .where((event) => event['type'] == 'plan_generated')
              .length,
          2,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<List<Task>> seedDayTasks(WidgetTester tester) async {
    final tasks = [
      Task(id: 'a', title: 'Task A', durationMinutes: 30, priority: 5),
      Task(id: 'b', title: 'Task B', durationMinutes: 30, priority: 4),
      Task(id: 'c', title: 'Task C', durationMinutes: 30, priority: 3),
      Task(
        id: 'future',
        title: 'Future task',
        date: DateTime.now().add(const Duration(days: 2)),
      ),
    ];
    await tester.runAsync(() async {
      for (final task in tasks) {
        await appState.addTaskToInbox(task);
      }
    });
    return tasks;
  }

  Future<void> tapWithStorage(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.runAsync(() async {
      await tester.tap(target);
      await Hive.box<Map>('day_plans').flush();
      await Hive.box<Map>('analytics_events').flush();
    });
    await tester.pumpAndSettle();
  }

  Future<void> enterTextWithStorage(
    WidgetTester tester,
    Finder target,
    String text,
  ) async {
    await tester.ensureVisible(target);
    await tester.runAsync(() async {
      await tester.enterText(target, text);
      await Hive.box<Map>('analytics_events').flush();
    });
    await tester.pumpAndSettle();
  }

  Future<void> confirmPlan(WidgetTester tester) async {
    final save = find.widgetWithText(ElevatedButton, 'Сохранить');
    await tester.ensureVisible(save);
    await tester.runAsync(() => tester.tap(save));
    await tester.pumpAndSettle();
    expect(find.text('Принять план?'), findsOneWidget);
    await tapWithStorage(
      tester,
      find.widgetWithText(FilledButton, 'Принять план'),
    );
  }

  for (final page in [
    (name: 'Today', widget: const TodayPage()),
    (name: 'Scheduler', widget: const SchedulerPage()),
  ]) {
    testWidgets(
      '${page.name}: edit, confirm, close and reopen restores the accepted working list',
      (tester) async {
        await seedDayTasks(tester);
        final today = DateUtils.dateOnly(DateTime.now());
        await showPage(tester, page.widget);
        await tester.enterText(
          find.byKey(const ValueKey('plan-minutes')),
          '60',
        );
        await tapWithStorage(
          tester,
          find.widgetWithText(ElevatedButton, 'Сгенерировать план'),
        );

        await tapWithStorage(tester, find.byTooltip('Убрать из плана: Task A'));
        expect(find.text('Осталось: 30 мин'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Добавить задачу'),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('plan-add-b')), findsNothing);
        expect(find.byKey(const ValueKey('plan-add-future')), findsNothing);
        await tapWithStorage(tester, find.byKey(const ValueKey('plan-add-c')));
        await tapWithStorage(tester, find.byTooltip('Поднять: Task C'));
        expect(appState.planDraftForDay(today)!['selectedTaskIds'], ['c', 'b']);
        expect(find.text('Осталось: 0 мин'), findsOneWidget);
        expect(appState.acceptedPlanForDay(today), isNull);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
        await tester.pumpAndSettle();
        expect(Hive.box<Map>('day_plans').length, 0);
        await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
        await tester.pumpAndSettle();
        expect(appState.acceptedPlanForDay(today), isNull);
        await confirmPlan(tester);
        expect(appState.acceptedPlanForDay(today)!['selectedTaskIds'], [
          'c',
          'b',
        ]);

        await tester.pumpWidget(const SizedBox.shrink());
        appState.dispose();
        await tester.runAsync(() async {
          await Hive.close();
          await openBoxes();
          appState = AppState();
          appState.notificationsEnabled = false;
        });
        await showPage(tester, const TodayPage());

        expect(find.text('Принятый план'), findsOneWidget);
        final first = find.byKey(const ValueKey('working-task-c'));
        final second = find.byKey(const ValueKey('working-task-b'));
        expect(first, findsOneWidget);
        expect(second, findsOneWidget);
        expect(
          tester.getTopLeft(first).dy,
          lessThan(tester.getTopLeft(second).dy),
        );
        expect(find.byKey(const ValueKey('working-task-a')), findsNothing);
        expect(appState.planDraftForDay(today), isNull);
        expect(Hive.box<Map>('day_plans').length, 1);

        await tester.ensureVisible(find.byKey(const ValueKey('other-tasks')));
        await tester.tap(find.text('Остальные задачи (2)'));
        await tester.pumpAndSettle();
        expect(find.text('Task A'), findsOneWidget);
        expect(find.text('Future task'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'day selection switches plans and drafts without showing another day on Today',
    (tester) async {
      final tasks = await seedDayTasks(tester);
      final today = DateUtils.dateOnly(DateTime.now());
      final otherDay = DateTime(
        today.year,
        today.month,
        today.day == 15 ? 16 : 15,
      );
      await tester.runAsync(() async {
        await appState.savePlanForDay(today, 60, plannedTasks: [tasks[0]]);
        await appState.savePlanForDay(otherDay, 90, plannedTasks: [tasks[2]]);
        await Hive.box<Map>('analytics_events').flush();
      });
      await showPage(tester, const SchedulerPage());
      await tester.tap(find.widgetWithText(OutlinedButton, 'Изменить план'));
      await tester.pumpAndSettle();
      await tapWithStorage(tester, find.byTooltip('Убрать из плана: Task A'));
      await tester.tap(find.byKey(const ValueKey('plan-day-picker')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('${otherDay.day}'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-entry-c')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-entry-a')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('plan-minutes')))
            .controller!
            .text,
        '90',
      );
      expect(appState.planDraftForDay(today)!['selectedTaskIds'], isEmpty);
      expect(appState.planDraftForDay(otherDay), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      appState.discardPlanDraft(today);
      await showPage(tester, const TodayPage());
      expect(find.byKey(const ValueKey('working-task-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('working-task-c')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source duration and deletion show warnings and prevent invalid acceptance',
    (tester) async {
      final tasks = await seedDayTasks(tester);
      final today = DateUtils.dateOnly(DateTime.now());
      await tester.runAsync(() async {
        await appState.savePlanForDay(
          today,
          60,
          plannedTasks: [tasks[0], tasks[1]],
        );
        await Hive.box<Map>('analytics_events').flush();
      });
      await showPage(tester, const TodayPage());
      tasks[0].durationMinutes = 90;
      await tester.runAsync(
        () => appState.updateTask(tasks[0], title: tasks[0].title),
      );
      await tester.pumpAndSettle();
      expect(find.text('Превышение: 60 мин'), findsOneWidget);
      expect(
        find.textContaining('Исходные задачи изменились.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Изменить план'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      await tapWithStorage(tester, find.byTooltip('Убрать из плана: Task B'));
      await enterTextWithStorage(
        tester,
        find.byKey(const ValueKey('plan-minutes')),
        '90',
      );
      expect(appState.acceptedPlanForDay(today)!['availableMinutes'], 60);
      await confirmPlan(tester);
      expect(appState.acceptedPlanForDay(today)!['availableMinutes'], 90);

      await tester.runAsync(() => appState.deleteTask(tasks[0]));
      await tester.pumpAndSettle();
      expect(
        find.text('Задача «Task A» удалена. Уберите её из плана.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('working-task-a')), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Изменить план'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      await tapWithStorage(tester, find.byTooltip('Убрать из плана: Task A'));
      await confirmPlan(tester);
      expect(appState.acceptedPlanForDay(today)!['selectedTaskIds'], isEmpty);
      expect(find.byKey(const ValueKey('working-task-b')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Today ignores another day plan and shares its draft with Scheduler',
    (tester) async {
      final tasks = await seedDayTasks(tester);
      final today = DateUtils.dateOnly(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));
      await tester.runAsync(() async {
        await appState.savePlanForDay(tomorrow, 60, plannedTasks: [tasks[2]]);
        await Hive.box<Map>('analytics_events').flush();
      });
      await showPage(tester, const TodayPage());
      expect(find.text('Принятый план'), findsNothing);
      expect(find.byKey(const ValueKey('working-task-c')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('plan-minutes')), '60');
      await tapWithStorage(
        tester,
        find.widgetWithText(ElevatedButton, 'Сгенерировать план'),
      );
      await tapWithStorage(tester, find.byTooltip('Поднять: Task B'));
      expect(appState.planDraftForDay(today)!['selectedTaskIds'], ['b', 'a']);

      await tester.pumpWidget(const SizedBox.shrink());
      await showPage(tester, const SchedulerPage());
      expect(appState.planDraftForDay(today)!['selectedTaskIds'], ['b', 'a']);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('plan-entry-b'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('plan-entry-a'))).dy,
        ),
      );
      await confirmPlan(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await showPage(tester, const TodayPage());
      expect(find.byKey(const ValueKey('working-task-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('working-task-a')), findsOneWidget);
      expect(appState.acceptedPlanForDay(tomorrow)!['selectedTaskIds'], ['c']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow screen shows over-budget edits and keeps acceptance disabled until corrected',
    (tester) async {
      await seedDayTasks(tester);
      await showPage(tester, const SchedulerPage());
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('plan-minutes')), '90');
      await tapWithStorage(
        tester,
        find.widgetWithText(ElevatedButton, 'Сгенерировать план'),
      );
      await enterTextWithStorage(
        tester,
        find.byKey(const ValueKey('plan-minutes')),
        '60',
      );
      expect(find.text('Превышение: 30 мин'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      await tapWithStorage(tester, find.byTooltip('Убрать из плана: Task A'));
      expect(find.text('Осталось: 0 мин'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Сохранить'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editable steps create one action that can be added through plan correction and completed',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final parent = Task(
        id: 'project',
        title: 'Большое дело',
        estimatedDurationMinutes: 240,
        breakdownSteps: ['Собрать материалы', 'Сделать слайды'],
        breakdownStepIds: ['materials', 'slides'],
      );
      await tester.runAsync(() async {
        await appState.addTaskToInbox(parent);
        await appState.savePlanForDay(today, 60, plannedTasks: []);
      });
      await showPage(tester, const TodayPage());
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('other-tasks')));
      await tester.tap(find.text('Остальные задачи (1)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Редактировать'));
      await tester.tap(find.byTooltip('Редактировать'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('breakdown-materials')),
        'Собрать и проверить материалы',
      );
      await tester.ensureVisible(find.byTooltip('Удалить шаг 2'));
      await tester.tap(find.byTooltip('Удалить шаг 2'));
      await tester.tap(find.text('Добавить шаг'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).last,
        'Подготовить схему',
      );
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Сохранить'));
        await Hive.box<TaskList>('task_lists').flush();
      });
      await tester.pumpAndSettle();
      expect(parent.breakdownSteps, [
        'Собрать и проверить материалы',
        'Подготовить схему',
      ]);
      expect(parent.breakdownStepIds.first, 'materials');
      expect(parent.breakdownStepIds.last, isNot('slides'));

      final stepButton = find.byKey(const ValueKey('step-action-materials'));
      await tester.ensureVisible(stepButton);
      await tester.tap(stepButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('action-minutes')), findsOneWidget);
      await tester.tap(find.text('Создать действие'));
      await tester.pumpAndSettle();
      expect(
        find.text('Введите длительность от 1 до 1440 минут.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('action-minutes')),
        '20',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Создать действие'));
        await Hive.box<TaskList>('task_lists').flush();
      });
      await tester.pumpAndSettle();
      final action = appState.actionForStep(parent.id, 'materials')!;
      expect(action.effectiveDurationMinutes, 20);
      expect(appState.acceptedPlanForDay(today)!['selectedTaskIds'], isEmpty);

      await tester.ensureVisible(stepButton);
      await tester.tap(stepButton);
      await tester.pumpAndSettle();
      expect(find.text('Редактирование задачи'), findsOneWidget);
      expect(find.byKey(const ValueKey('action-minutes')), findsNothing);
      expect(appState.inboxList.tasks.length, 2);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Изменить план'));
      await tester.tap(find.text('Изменить план'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Добавить задачу'));
      await tester.tap(find.text('Добавить задачу'));
      await tester.pumpAndSettle();
      await tapWithStorage(
        tester,
        find.byKey(ValueKey('plan-add-${action.id}')),
      );
      expect(appState.planDraftForDay(today)!['selectedTaskIds'], [action.id]);
      expect(appState.acceptedPlanForDay(today)!['selectedTaskIds'], isEmpty);
      await confirmPlan(tester);

      final workingTile = find.byKey(ValueKey('working-task-${action.id}'));
      final checkbox = find.descendant(
        of: workingTile,
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(checkbox);
      await tester.runAsync(() async {
        await tester.tap(checkbox);
        await Hive.box<TaskList>('task_lists').flush();
        await Hive.box<Map>('analytics_events').flush();
      });
      await tester.pumpAndSettle();
      expect(action.isDone, isTrue);
      expect(parent.isDone, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'step edits stay local until saving and empty steps block saving',
    (tester) async {
      final parent = Task(
        id: 'project',
        title: 'Большое дело',
        breakdownSteps: ['Собрать материалы'],
        breakdownStepIds: ['materials'],
      );
      await tester.runAsync(() => appState.addTaskToInbox(parent));
      await showPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showTaskDialog(context, task: parent),
              child: const Text('Open task'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('breakdown-materials')),
        ' ',
      );
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Не удалось сохранить задачу: Заполните или удалите пустые шаги.',
        ),
        findsOneWidget,
      );
      expect(parent.breakdownSteps, ['Собрать материалы']);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open task'));
      await tester.pumpAndSettle();
      expect(find.text('Собрать материалы'), findsOneWidget);
      expect(parent.breakdownStepIds, ['materials']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'task form creates, edits and clears a deadline independently of the planned date',
    (tester) async {
      Task? editedTask;
      await showPage(
        tester,
        Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => showTaskDialog(context, task: editedTask),
                child: const Text('Open task'),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Open task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Task with deadline');
      await tester.tap(find.text('Дедлайн'));
      await tester.pumpAndSettle();
      final datePicker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      final deadline = DateUtils.dateOnly(datePicker.initialDate!);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Создать'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Создать'));
        await Hive.box<TaskList>('task_lists').flush();
      });
      await tester.pumpAndSettle();

      editedTask = appState.currentList.tasks.single;
      expect(editedTask.date, isNull);
      expect(editedTask.deadline, deadline);
      final plannedDate = DateTime(2026, 11, 9);
      editedTask.date = plannedDate;

      await tester.tap(find.text('Open task'));
      await tester.pumpAndSettle();
      expect(find.text('Убрать дедлайн'), findsOneWidget);
      await tester.tap(find.text('Убрать дедлайн'));
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Сохранить'));
        await Hive.box<TaskList>('task_lists').flush();
      });
      await tester.pumpAndSettle();

      expect(editedTask.deadline, isNull);
      expect(editedTask.date, plannedDate);
      expect(tester.takeException(), isNull);
    },
  );
}
