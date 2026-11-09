// lib/state/app_state.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../models/day_plan_review.dart';
import '../models/task_list.dart';
import '../models/achievement.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';

class AppState extends ChangeNotifier {
  final Box _settingsBox = Hive.box('settings');
  final Box<Map> _dayPlansBox = Hive.box<Map>('day_plans');
  final Box<Map> _analyticsBox = Hive.box<Map>('analytics_events');
  final Box<TaskList> _listsBox = Hive.box<TaskList>('task_lists');
  final Box<Habit> _habitsBox = Hive.box<Habit>('habits');
  final Box<JournalEntry> _journalBox = Hive.box<JournalEntry>('journal_entries');
  final Box<Achievement> _achBox = Hive.box<Achievement>('achievements');

  // ===== XP и внутренняя валюта =====
  late int xpEarned;
  late int xpSpent;
  late int coins;

  late bool isDarkMode;
  late bool notificationsEnabled;

  final Set<String> purchasedItemIds = {};

  final List<TaskList> lists = [];
  int selectedListIndex = 0;

  final List<Habit> habits = [];
  final List<JournalEntry> journalEntries = [];
  final List<Achievement> achievements = [];

  String? currentUser;

  AppState({this.currentUser}) {
    xpEarned = _settingsBox.get('xpEarned', defaultValue: 0) as int;
    xpSpent = _settingsBox.get('xpSpent', defaultValue: 0) as int;
    coins = _settingsBox.get('coins', defaultValue: 0) as int;
    isDarkMode = _settingsBox.get('isDarkMode', defaultValue: false) as bool;
    notificationsEnabled = _settingsBox.get('notificationsEnabled', defaultValue: true) as bool;

    _loadSettings();
    _loadFromHive();
    applyDailyHabitPenalties();
  }

  // ================== Daily plan / analytics ==================

  static const maxPlanMinutes = 24 * 60;

  final Map<String, Map<String, dynamic>> _planDrafts = {};
  final Set<String> _savingPlanDays = {};

  String _planKey(DateTime day) =>
      'day_${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _copyPlan(Map plan) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(plan)) as Map);

  DateTime _planDate(Map<String, dynamic> plan) {
    final day = DateTime.tryParse(plan['date'] as String? ?? '');
    if (day == null) throw ArgumentError('У плана не указана корректная дата.');
    return DateUtils.dateOnly(day);
  }

  List<String> _planIds(Map<String, dynamic> plan) =>
      (plan['selectedTaskIds'] as List? ?? [])
          .whereType<String>()
          .toSet()
          .toList();

  DateTime _savedTime(Map plan) =>
      DateTime.tryParse(plan['savedAt'] as String? ?? '') ??
      DateTime.tryParse(plan['generatedAt'] as String? ?? '') ??
      DateTime(1970);

  List<Map<String, dynamic>> get savedPlans {
    final latest = <String, Map<String, dynamic>>{};
    for (final value in _dayPlansBox.values) {
      final plan = _copyPlan(value);
      if (plan['status'] != 'saved' && plan['status'] != 'accepted') continue;
      final day = DateTime.tryParse(plan['date'] as String? ?? '');
      if (day == null) continue;
      final key = _planKey(day);
      final previous = latest[key];
      if (previous == null ||
          !_savedTime(plan).isBefore(_savedTime(previous))) {
        latest[key] = plan;
      }
    }
    return latest.values.toList()
      ..sort((a, b) => _planDate(b).compareTo(_planDate(a)));
  }

  Map<String, dynamic>? acceptedPlanForDay(DateTime day) {
    for (final plan in savedPlans) {
      if (DateUtils.isSameDay(_planDate(plan), day)) return plan;
    }
    return null;
  }

  Map<String, dynamic>? planDraftForDay(DateTime day) {
    final draft = _planDrafts[_planKey(day)];
    return draft == null ? null : _copyPlan(draft);
  }

  bool isSavingPlan(DateTime day) => _savingPlanDays.contains(_planKey(day));

  bool _isPlanCandidate(Task task, DateTime day) {
    if (task.isDone) return false;
    final date = task.date;
    if (date == null) return true;
    if (task.recurrenceType != TaskRecurrenceType.none) {
      return task.appearsOn(day);
    }
    return !DateUtils.dateOnly(date).isAfter(DateUtils.dateOnly(day));
  }

  List<Task> candidatesForPlan(DateTime day) {
    final unique = <String, Task>{};
    for (final task in lists.expand((list) => list.tasks)) {
      if (_isPlanCandidate(task, day)) unique.putIfAbsent(task.id, () => task);
    }
    return unique.values.toList();
  }

  Map<String, dynamic> _taskSnapshot(Task task) => {
    'title': task.title,
    'durationMinutes': task.effectiveDurationMinutes,
    'date': task.date == null
        ? null
        : DateUtils.dateOnly(task.date!).toIso8601String(),
    'deadline': task.deadline == null
        ? null
        : DateUtils.dateOnly(task.deadline!).toIso8601String(),
    'recurrenceType': task.recurrenceType.index,
    'priority': task.priority,
  };

  DayPlanReview reviewPlan(Map<String, dynamic> plan) {
    final day = _planDate(plan);
    final allTasks = {
      for (final task in lists.expand((list) => list.tasks)) task.id: task,
    };
    final ids = _planIds(plan);
    final titles = (plan['selectedTitles'] as List? ?? [])
        .whereType<String>()
        .toList();
    final snapshots = plan['taskSnapshots'] as Map? ?? {};
    final entries = <PlanTaskEntry>[];
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      final task = allTasks[id];
      final snapshot = snapshots[id] as Map?;
      final oldTitle =
          snapshot?['title'] as String? ??
          (i < titles.length ? titles[i] : 'Удалённая задача');
      entries.add(
        PlanTaskEntry(
          id: id,
          task: task,
          title: task?.title ?? oldTitle,
          durationMinutes:
              task?.effectiveDurationMinutes ??
              (snapshot?['durationMinutes'] as int? ?? 0),
          hasChanged:
              task != null &&
              (snapshot == null
                  ? oldTitle != task.title
                  : jsonEncode(snapshot) != jsonEncode(_taskSnapshot(task))),
          isAvailable:
              task != null && (task.isDone || _isPlanCandidate(task, day)),
        ),
      );
    }
    return DayPlanReview(
      entries: entries,
      availableMinutes: plan['availableMinutes'] as int? ?? 0,
      savedUsedMinutes: plan['usedMinutes'] as int?,
    );
  }

  List<Task> remainingTasksForPlan(Map<String, dynamic> plan) {
    final ids = _planIds(plan).toSet();
    return candidatesForPlan(
      _planDate(plan),
    ).where((task) => !ids.contains(task.id)).toList();
  }

  void generatePlanDraft(DateTime day, int availableMinutes) {
    if (isSavingPlan(day)) return;
    _planDrafts[_planKey(day)] = generatePlanForDay(day, availableMinutes);
    notifyListeners();
  }

  void editAcceptedPlan(DateTime day) {
    if (isSavingPlan(day) || _planDrafts.containsKey(_planKey(day))) return;
    final plan = acceptedPlanForDay(day);
    if (plan == null) return;
    _planDrafts[_planKey(day)] = _copyPlan(plan)..['status'] = 'proposed';
    notifyListeners();
  }

  void discardPlanDraft(DateTime day) {
    if (isSavingPlan(day)) return;
    _planDrafts.remove(_planKey(day));
    notifyListeners();
  }

  void _editPlanDraft(DateTime day, void Function(Map<String, dynamic>) edit) {
    if (isSavingPlan(day)) return;
    final existing = _planDrafts[_planKey(day)] ?? acceptedPlanForDay(day);
    if (existing == null) return;
    final draft = _copyPlan(existing)..['status'] = 'proposed';
    // Preserve the ID/title mapping of older plans before moving entries.
    final snapshots = Map<String, dynamic>.from(
      draft['taskSnapshots'] as Map? ?? {},
    );
    for (final entry in reviewPlan(existing).entries) {
      snapshots.putIfAbsent(
        entry.id,
        () => entry.task == null
            ? {'title': entry.title, 'durationMinutes': entry.durationMinutes}
            : _taskSnapshot(entry.task!),
      );
    }
    draft['taskSnapshots'] = snapshots;
    edit(draft);
    final review = reviewPlan(draft);
    draft['selectedTaskIds'] = review.entries.map((entry) => entry.id).toList();
    draft['selectedTitles'] = review.entries
        .map((entry) => entry.title)
        .toList();
    draft['usedMinutes'] = review.usedMinutes;
    final remaining = remainingTasksForPlan(draft);
    draft['droppedTaskIds'] = remaining.map((task) => task.id).toList();
    draft['droppedTitles'] = remaining.map((task) => task.title).toList();
    _planDrafts[_planKey(day)] = draft;
    notifyListeners();
  }

  void setPlanBudget(DateTime day, int minutes) {
    RangeError.checkValueInInterval(
      minutes,
      1,
      maxPlanMinutes,
      'availableMinutes',
    );
    _editPlanDraft(day, (draft) => draft['availableMinutes'] = minutes);
  }

  void removeTaskFromPlan(DateTime day, String taskId) {
    _editPlanDraft(
      day,
      (draft) => draft['selectedTaskIds'] = _planIds(
        draft,
      ).where((id) => id != taskId).toList(),
    );
  }

  void addTaskToPlan(DateTime day, String taskId) {
    final task = candidatesForPlan(
      day,
    ).where((task) => task.id == taskId).firstOrNull;
    if (task == null) {
      throw StateError('Эта задача больше не подходит выбранному дню.');
    }
    _editPlanDraft(day, (draft) {
      draft['selectedTaskIds'] = {..._planIds(draft), taskId}.toList();
      final snapshots = Map<String, dynamic>.from(
        draft['taskSnapshots'] as Map? ?? {},
      );
      snapshots.putIfAbsent(taskId, () => _taskSnapshot(task));
      draft['taskSnapshots'] = snapshots;
    });
  }

  void movePlanTask(DateTime day, int from, int to) {
    _editPlanDraft(day, (draft) {
      final ids = _planIds(draft);
      RangeError.checkValidIndex(from, ids, 'from');
      RangeError.checkValidIndex(to, ids, 'to');
      final id = ids.removeAt(from);
      ids.insert(to, id);
      draft['selectedTaskIds'] = ids;
    });
  }

  Future<void> acceptPlanDraft(DateTime day) async {
    final draft = planDraftForDay(day);
    if (draft == null) return;
    await savePlan(draft);
  }

  List<Map<String, dynamic>> get analyticsEvents {
    final events = _analyticsBox.values
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    events.sort((a, b) {
      final aTime =
          DateTime.tryParse(
            (a['timestamp'] as String? ?? '1970-01-01T00:00:00.000'),
          ) ??
          DateTime(1970);
      final bTime =
          DateTime.tryParse(
            (b['timestamp'] as String? ?? '1970-01-01T00:00:00.000'),
          ) ??
          DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return events;
  }

  void logAnalyticsEvent(String type, Map<String, dynamic> payload) {
    final event = <String, dynamic>{
      'id': '${DateTime.now().millisecondsSinceEpoch}',
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      ...payload,
    };
    _analyticsBox.add(event);
    notifyListeners();
  }

  String exportAnalyticsJson() {
    final data = analyticsEvents;
    return jsonEncode(data);
  }

  Map<String, dynamic> generatePlanForDay(
    DateTime day,
    int availableMinutes, {
    List<Task>? tasks,
    String? notes,
  }) {
    if (availableMinutes < 0 || availableMinutes > maxPlanMinutes) {
      throw RangeError.range(
        availableMinutes,
        0,
        maxPlanMinutes,
        'availableMinutes',
      );
    }
    final candidates = (tasks ?? candidatesForPlan(day))
        .where((task) => _isPlanCandidate(task, day))
        .fold<Map<String, Task>>(
          {},
          (unique, task) => unique..putIfAbsent(task.id, () => task),
        )
        .values
        .toList();

    int urgencyScore(Task task) {
      final deadline = task.deadline;
      if (deadline == null) return 0;
      // Compare calendar dates, regardless of time of day or DST transitions.
      final diffDays = DateTime.utc(
        deadline.year,
        deadline.month,
        deadline.day,
      ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
      if (diffDays <= 0) return 100;
      if (diffDays <= 1) return 80;
      if (diffDays <= 3) return 60;
      if (diffDays <= 7) return 30;
      return 0;
    }

    final sorted = [...candidates]
      ..sort((a, b) {
        final urgency = urgencyScore(b).compareTo(urgencyScore(a));
        if (urgency != 0) return urgency;
        final priority = (b.priority ?? 0).compareTo(a.priority ?? 0);
        if (priority != 0) return priority;
        // Shorter tasks only win when urgency and user priority are equal.
        final duration = a.effectiveDurationMinutes.compareTo(
          b.effectiveDurationMinutes,
        );
        if (duration != 0) return duration;
        return a.id.compareTo(b.id);
      });

    final selected = <Task>[];
    int used = 0;
    for (final task in sorted) {
      final taskMinutes = task.effectiveDurationMinutes;
      if (used + taskMinutes <= availableMinutes) {
        selected.add(task);
        used += taskMinutes;
      }
    }

    final selectedIds = selected.map((task) => task.id).toList();
    final dropped = sorted
        .where((task) => !selectedIds.contains(task.id))
        .toList();

    final plan = <String, dynamic>{
      'id':
          'plan_${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}_${DateTime.now().millisecondsSinceEpoch}',
      'date': day.toIso8601String(),
      'availableMinutes': availableMinutes,
      'usedMinutes': used,
      'generatedAt': DateTime.now().toIso8601String(),
      'selectedTaskIds': selectedIds,
      'taskSnapshots': {
        for (final task in selected) task.id: _taskSnapshot(task),
      },
      'selectedTitles': selected.map((task) => task.title).toList(),
      'droppedTaskIds': dropped.map((task) => task.id).toList(),
      'droppedTitles': dropped.map((task) => task.title).toList(),
      'status': 'proposed',
      'notes': notes ?? 'Автоподбор задач по доступному времени',
      'algorithmVersion': 'priority-greedy-v2',
    };

    logAnalyticsEvent('plan_generated', {
      'date': day.toIso8601String(),
      'availableMinutes': availableMinutes,
      'selectedCount': selected.length,
      'droppedCount': dropped.length,
      'usedMinutes': used,
    });

    return plan;
  }

  Future<void> savePlan(Map<String, dynamic> plan) async {
    final day = _planDate(plan);
    final key = _planKey(day);
    if (!_savingPlanDays.add(key)) return;
    notifyListeners();
    try {
      final minutes = plan['availableMinutes'] as int? ?? -1;
      RangeError.checkValueInInterval(
        minutes,
        0,
        maxPlanMinutes,
        'availableMinutes',
      );
      final review = reviewPlan(plan);
      if (!review.canAccept) {
        throw StateError(review.blockingMessages.join(' '));
      }
      final normalized = _copyPlan(plan)
        ..['id'] = key
        ..['date'] = day.toIso8601String()
        ..['status'] = 'saved'
        ..['selectedTaskIds'] = review.entries.map((entry) => entry.id).toList()
        ..['selectedTitles'] = review.entries
            .map((entry) => entry.title)
            .toList()
        ..['usedMinutes'] = review.usedMinutes
        ..['taskSnapshots'] = {
          for (final entry in review.entries)
            entry.id: _taskSnapshot(entry.task!),
        };
      final remaining = remainingTasksForPlan(normalized);
      normalized['droppedTaskIds'] = remaining.map((task) => task.id).toList();
      normalized['droppedTitles'] = remaining
          .map((task) => task.title)
          .toList();
      final previous = acceptedPlanForDay(day);
      String content(Map<String, dynamic> value) => jsonEncode([
        value['availableMinutes'],
        _planIds(value),
        value['taskSnapshots'],
        value['notes'],
      ]);
      if (previous == null || content(previous) != content(normalized)) {
        normalized['savedAt'] = DateTime.now().toIso8601String();
        await _dayPlansBox.put(key, normalized);
        logAnalyticsEvent('plan_saved', {
          'date': normalized['date'],
          'availableMinutes': minutes,
          'selectedCount': review.entries.length,
        });
      }
      _planDrafts.remove(key);
    } finally {
      _savingPlanDays.remove(key);
      notifyListeners();
    }
  }

  Future<void> savePlanForDay(
    DateTime day,
    int availableMinutes, {
    required List<Task> plannedTasks,
    List<Task> droppedTasks = const [],
    String? notes,
  }) async {
    await savePlan({
      'date': DateUtils.dateOnly(day).toIso8601String(),
      'availableMinutes': availableMinutes,
      'selectedTaskIds': plannedTasks.map((task) => task.id).toList(),
      'notes': notes,
    });
  }

  List<Task> tasksForPlan(Map<String, dynamic> plan) {
    final allTasks = {
      for (final task in lists.expand((list) => list.tasks)) task.id: task,
    };
    return [
      for (final id in _planIds(plan))
        if (allTasks[id] != null) allTasks[id]!,
    ];
  }

  bool get isLoggedIn => currentUser != null;

  void setUser(String? login) {
    currentUser = login;
    _loadSettings();
    notifyListeners();
  }

  void addXp(int amount) {
    xpEarned += amount;
    _settingsBox.put('xpEarned', xpEarned);
    _checkAchievements();
    notifyListeners();
  }

  String _prefixed(String key) {
    final prefix = currentUser ?? 'guest';
    return '${prefix}_$key';
  }

  void _loadSettings() {
    xpEarned = _settingsBox.get(_prefixed('xpEarned'), defaultValue: 0) as int;
    xpSpent = _settingsBox.get(_prefixed('xpSpent'), defaultValue: 0) as int;
    coins = _settingsBox.get(_prefixed('coins'), defaultValue: 0) as int;
    isDarkMode = _settingsBox.get(_prefixed('isDarkMode'), defaultValue: false) as bool;
    notificationsEnabled = _settingsBox.get(_prefixed('notificationsEnabled'), defaultValue: true) as bool;
  }

  void _saveSettings() {
    _settingsBox.put(_prefixed('xpEarned'), xpEarned);
    _settingsBox.put(_prefixed('xpSpent'), xpSpent);
    _settingsBox.put(_prefixed('coins'), coins);
    _settingsBox.put(_prefixed('isDarkMode'), isDarkMode);
    _settingsBox.put(_prefixed('notificationsEnabled'), notificationsEnabled);
  }

  void toggleDarkMode(bool value) {
    isDarkMode = value;
    _settingsBox.put(_prefixed('isDarkMode'), value);
    notifyListeners();
  }

  void toggleNotifications(bool value) {
    notificationsEnabled = value;
    _settingsBox.put(_prefixed('notificationsEnabled'), value);
    notifyListeners();
  }

  // ================== Inbox helpers ==================
  static const String inboxId = 'inbox';

  TaskList get inboxList {
    for (final l in lists) {
      if (l.id == inboxId) return l;
    }
    // На всякий случай (если вызвали до _loadFromHive)
    final fallback = TaskList(id: inboxId, name: 'Inbox', color: Colors.deepPurple);
    return fallback;
  }

  void selectListById(String id) {
    for (int i = 0; i < lists.length; i++) {
      if (lists[i].id == id) {
        selectedListIndex = i;
        notifyListeners();
        return;
      }
    }
  }

  TaskList _listContainingTask(Task t) {
    // ищем по id (надежнее, чем по ссылке на объект)
    for (final l in lists) {
      if (l.tasks.any((x) => x.id == t.id)) return l;
    }
    return currentList;
  }


  void _loadFromHive() {
    lists
      ..clear()
      ..addAll(_listsBox.values);

    // 1) гарантируем Inbox
    final hasInbox = lists.any((l) => l.id == inboxId);
    if (!hasInbox) {
      final inbox = TaskList(id: inboxId, name: 'Inbox', color: Colors.deepPurple);
      _listsBox.put(inbox.id, inbox);
      lists.insert(0, inbox);
    }

    // 2) дефолтные списки (если только inbox есть или пусто)
    if (lists.length == 1 && lists.first.id == inboxId) {
      final defaults = [
        TaskList(id: 'my_day', name: 'Мой день', color: Colors.blue),
        TaskList(id: 'important', name: 'Важно', color: Colors.red),
        TaskList(id: 'home', name: 'Дом', color: Colors.green),
      ];
      for (var l in defaults) {
        _listsBox.put(l.id, l);
        lists.add(l);
      }
    }

    // selectedListIndex в безопасный диапазон
    if (selectedListIndex < 0 || selectedListIndex >= lists.length) {
      selectedListIndex = 0;
    }

    habits
      ..clear()
      ..addAll(_habitsBox.values);

    journalEntries
      ..clear()
      ..addAll(_journalBox.values);

    achievements
      ..clear()
      ..addAll(_achBox.values);

    if (achievements.isEmpty) {
      final defaults = [
        Achievement(
          id: 'first_task',
          title: 'Первая задача',
          description: 'Закройте вашу первую задачу',
          type: AchievementType.tasks,
          requiredCount: 1,
        ),
        Achievement(
          id: 'ten_tasks',
          title: 'Десятка',
          description: 'Закройте 10 задач',
          type: AchievementType.tasks,
          requiredCount: 10,
        ),
        Achievement(
          id: 'habit_3_days',
          title: 'Первые искры',
          description: 'Выдержи 3 дня подряд одну привычку',
          type: AchievementType.habitStreak,
          requiredHabitStreak: 3,
        ),
        Achievement(
          id: 'habit_7_days',
          title: 'Недельный мастер',
          description: 'Выдержи 7 дней подряд одну привычку',
          type: AchievementType.habitStreak,
          requiredHabitStreak: 7,
        ),
        Achievement(
          id: 'habit_30_days',
          title: 'Месячный стойкий',
          description: 'Выдержи 30 дней подряд одну привычку',
          type: AchievementType.habitStreak,
          requiredHabitStreak: 30,
        ),
        Achievement(
          id: 'reach_level_2',
          title: 'Подъём на 2-й',
          description: 'Достигните 2-го уровня',
          type: AchievementType.level,
          requiredLevel: 2,
        ),
        Achievement(
          id: 'reach_level_5',
          title: 'Пятизвёздочник',
          description: 'Достигните 5-го уровня',
          type: AchievementType.level,
          requiredLevel: 5,
        ),
        Achievement(
          id: 'reach_level_10',
          title: 'Десятка',
          description: 'Достигните 10-го уровня',
          type: AchievementType.level,
          requiredLevel: 10,
        ),
      ];
      for (var a in defaults) {
        _achBox.put(a.id, a);
        achievements.add(a);
      }
    }

    notifyListeners();
  }

  // ================== Задачи ==================

  TaskList get currentList => lists[selectedListIndex];

  void selectList(int i) {
    if (i >= 0 && i < lists.length) {
      selectedListIndex = i;
      notifyListeners();
    }
  }

  Future<void> addList(String name, Color color) async {
    final newList = TaskList(
      id: DateTime.now().toIso8601String(),
      name: name,
      color: color,
    );
    await _listsBox.put(newList.id, newList);
    lists.add(newList);
    selectedListIndex = lists.length - 1;
    notifyListeners();
  }

  Future<void> renameList(int i, String name, Color color) async {
    final list = lists[i];
    list.name = name;
    list.color = color;
    await _listsBox.put(list.id, list);
    notifyListeners();
  }

  Future<void> deleteList(int i) async {
    final list = lists.removeAt(i);
    await _listsBox.delete(list.id);
    if (selectedListIndex >= lists.length) selectedListIndex = max(0, lists.length - 1);
    notifyListeners();
  }

  Future<void> addTask(Task t, {String? listId}) async {
    TaskList target = currentList;
    if (listId != null) {
      for (final l in lists) {
        if (l.id == listId) {
          target = l;
          break;
        }
      }
    }
    target.tasks.insert(0, t);
    await _listsBox.put(target.id, target);
    notifyListeners();
  }

  Future<void> addTaskToInbox(Task t) => addTask(t, listId: inboxId);

  Future<void> updateTask(
    Task t, {
    required String title,
    DateTime? date,
    String? category,
    Color? color,
  }) async {
    t.title = title;
    t.date = date;
    t.category = category;
    t.color = color;

    final list = _listContainingTask(t);
    await _listsBox.put(list.id, list);
    notifyListeners();
  }

  Future<void> deleteTask(Task t) async {
    final list = _listContainingTask(t);
    list.tasks.removeWhere((x) => x.id == t.id);
    await _listsBox.put(list.id, list);
    notifyListeners();
  }

  Future<void> toggleDone(Task t, bool? done) async {
    final wasDone = t.isDone;
    final isDone = done ?? false;

    if (!wasDone && isDone) {
      xpEarned += 5;
    } else if (wasDone && !isDone) {
      xpEarned = max(xpEarned - 5, 0);
    }

    _saveSettings();
    t.isDone = isDone;
    _checkAchievements();

    final list = _listContainingTask(t);
    await _listsBox.put(list.id, list);
    notifyListeners();
  }

  List<Task> get pending => currentList.tasks.where((t) => !t.isDone).toList();
  List<Task> get completed => currentList.tasks.where((t) => t.isDone).toList();

  List<Task> tasksForDay(DateTime day) =>
      currentList.tasks.where((t) => t.date != null && isSameDay(t.date!, day)).toList();

  int get totalCompleted => lists.fold<int>(
        0,
        (sum, l) => sum + l.tasks.where((t) => t.isDone).length,
      );

  // ================== Достижения ==================

  void _checkAchievements() {
    for (var a in achievements) {
      if (a.isUnlocked) continue;
      switch (a.type) {
        case AchievementType.tasks:
          if (a.requiredCount != null && totalCompleted >= a.requiredCount!) {
            a.isUnlocked = true;
            _achBox.put(a.id, a);
          }
          break;
        case AchievementType.habitStreak:
          if (a.requiredHabitStreak != null &&
              habits.any((h) => _calculateStreak(h, DateTime.now()) >= a.requiredHabitStreak!)) {
            a.isUnlocked = true;
            _achBox.put(a.id, a);
          }
          break;
        case AchievementType.level:
          if (a.requiredLevel != null && level >= a.requiredLevel!) {
            a.isUnlocked = true;
            _achBox.put(a.id, a);
          }
          break;
      }
    }
  }

  // ================== XP и уровни ==================

  int get xpBalance => xpEarned - xpSpent;

  int get xpInLevel {
    int xp = xpEarned;
    if (xp < 25) return xp;
    xp -= 25;
    if (xp < 50) return xp;
    xp -= 50;
    if (xp < 75) return xp;
    xp -= 75;
    return xp % 100;
  }

  int get level {
    int xp = xpEarned;
    if (xp < 25) return 1;
    xp -= 25;
    if (xp < 50) return 2;
    xp -= 50;
    if (xp < 75) return 3;
    xp -= 75;
    return 4 + (xp ~/ 100);
  }

  int get xpRequiredForNextLevel {
    switch (level) {
      case 1:
        return 25;
      case 2:
        return 50;
      case 3:
        return 75;
      default:
        return 100;
    }
  }

  int get xpProgressInLevel {
    final int xpBefore;
    switch (level) {
      case 1:
        xpBefore = 0;
        break;
      case 2:
        xpBefore = 25;
        break;
      case 3:
        xpBefore = 25 + 50;
        break;
      case 4:
        xpBefore = 25 + 50 + 75;
        break;
      default:
        xpBefore = 25 + 50 + 75 + 100 * (level - 4);
    }
    return xpEarned - xpBefore;
  }

  int get xpToNextLevel {
    switch (level) {
      case 1:
        return 25 - xpInLevel;
      case 2:
        return 50 - xpInLevel;
      case 3:
        return 75 - xpInLevel;
      default:
        return 100 - xpInLevel;
    }
  }

  bool exchangeXpForCoins(int coinCount) {
    final cost = coinCount * 10;
    if (xpBalance < cost) return false;
    xpSpent += cost;
    coins += coinCount;
    _saveSettings();
    notifyListeners();
    return true;
  }

  bool purchaseItem(String id, int price) {
    if (coins < price || purchasedItemIds.contains(id)) return false;
    coins -= price;
    purchasedItemIds.add(id);
    _saveSettings();
    notifyListeners();
    return true;
  }

  bool isPurchased(String id) => purchasedItemIds.contains(id);

  // ================== Трекер привычек ==================

  Future<void> addHabit(Habit h) async {
    h.lives = 3;
    h.lastMissCheck = null;
    await _habitsBox.put(h.id, h);
    habits.add(h);
    notifyListeners();
  }

  Future<void> updateHabit(Habit h, {required String title, Color? color, IconData? icon}) async {
    h.title = title;
    if (color != null) h.color = color;
    if (icon != null) h.icon = icon;
    await _habitsBox.put(h.id, h);
    notifyListeners();
  }

  Future<void> deleteHabit(Habit h) async {
    habits.remove(h);
    await _habitsBox.delete(h.id);
    notifyListeners();
  }

  void applyDailyHabitPenalties() {
    final today = DateTime.now();
    final yesterday =
        DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));

    for (var h in habits) {
      if (h.lastMissCheck == null || !isSameDay(h.lastMissCheck!, today)) {
        if (!h.isDoneOn(yesterday)) {
          h.lives = max(h.lives - 1, 0);
          if (h.lives == 0) {
            xpEarned = 0;
            _settingsBox.put('xpEarned', xpEarned);
            h.lives = 3;
          }
        }
        h.lastMissCheck = today;
        _habitsBox.put(h.id, h);
      }
    }
    notifyListeners();
  }

  Future<void> toggleHabitDay(Habit h, DateTime day) async {
    final today = DateTime.now();
    final targetDay = DateTime(day.year, day.month, day.day);
    final wasDone = h.isDoneOn(targetDay);

    h.toggleDay(targetDay);

    if (isSameDay(targetDay, today)) {
      final nowDone = h.isDoneOn(targetDay);
      if (!wasDone && nowDone) {
        xpEarned += 2;
        _saveSettings();
        final streak = _calculateStreak(h, targetDay);
        if (streak > 0 && streak % 7 == 0) {
          coins += 1;
          _saveSettings();
        }
      } else if (wasDone && !nowDone) {
        xpEarned = max(xpEarned - 2, 0);
        _saveSettings();
      }
    }

    await _habitsBox.put(h.id, h);
    notifyListeners();
  }

  int _calculateStreak(Habit h, DateTime fromDay) {
    int count = 0;
    var d = DateTime(fromDay.year, fromDay.month, fromDay.day);
    while (h.isDoneOn(d)) {
      count++;
      d = d.subtract(const Duration(days: 1));
    }
    return count;
  }

  int habitCurrentStreak(Habit h) => _calculateStreak(h, DateTime.now());

  int habitCountThisMonth(Habit h) {
    final now = DateTime.now();
    return h.completedDates.where((d) => d.year == now.year && d.month == now.month).length;
  }

  // ================== Личный дневник ==================

  Future<void> addJournalEntry(JournalEntry entry) async {
    journalEntries.insert(0, entry);
    xpEarned += 3;
    _saveSettings();
    await _journalBox.put(entry.id, entry);
    notifyListeners();
  }

  Future<void> updateJournalEntry(JournalEntry entry,
      {required String title, required String content}) async {
    entry.title = title;
    entry.content = content;
    await _journalBox.put(entry.id, entry);
    notifyListeners();
  }

  Future<void> deleteJournalEntry(JournalEntry entry) async {
    journalEntries.remove(entry);
    await _journalBox.delete(entry.id);
    notifyListeners();
  }

  int completedCountOn(DateTime day) => lists
      .expand((l) => l.tasks)
      .where((t) => t.isDone && t.date != null && isSameDay(t.date!, day))
      .length;

  double averagePerDay() {
    final today = DateTime.now();
    final total = List.generate(7, (i) {
      final d = today.subtract(Duration(days: i));
      return completedCountOn(d);
    }).fold<int>(0, (sum, v) => sum + v);
    return total / 7.0;
  }

  int maxStreakThisWeek() {
    final today = DateTime.now();
    int streak = 0, maxStreak = 0;
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      if (completedCountOn(d) > 0) {
        streak++;
        maxStreak = max(streak, maxStreak);
      } else {
        streak = 0;
      }
    }
    return maxStreak;
  }

  List<Task> optimizeSchedule(List<Task> tasks, int capacityMinutes) {
    final available = tasks
        .where((t) => !t.isDone && t.durationMinutes != null && t.durationMinutes! > 0)
        .toList();

    int calculateUrgency(DateTime? date) {
      if (date == null) return 0;
      final today = DateTime.now();
      final dDay = DateTime(date.year, date.month, date.day);
      final tDay = DateTime(today.year, today.month, today.day);
      final diffDays = dDay.difference(tDay).inDays;
      if (diffDays <= 0) return 7;
      if (diffDays > 7) return 0;
      return 7 - diffDays;
    }

    final n = available.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(capacityMinutes + 1, 0));

    for (var i = 1; i <= n; i++) {
      final task = available[i - 1];
      final d = task.durationMinutes!;
      final p = task.priority ?? 0;
      final u = calculateUrgency(task.deadline);
      final effectiveValue = p + u;

      for (var w = 0; w <= capacityMinutes; w++) {
        if (d <= w) {
          dp[i][w] = max(dp[i - 1][w], dp[i - 1][w - d] + effectiveValue);
        } else {
          dp[i][w] = dp[i - 1][w];
        }
      }
    }

    var w = capacityMinutes;
    final result = <Task>[];
    for (var i = n; i > 0; i--) {
      if (dp[i][w] != dp[i - 1][w]) {
        final t = available[i - 1];
        result.add(t);
        w -= t.durationMinutes!;
      }
    }

    return result.reversed.toList();
  }
}
