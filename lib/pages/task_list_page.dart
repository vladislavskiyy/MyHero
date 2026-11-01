// lib/pages/task_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/task_tile.dart';
import '../dialogs/task_dialog.dart';
import '../theme/app_theme.dart';

enum SortOption { dateAsc, dateDesc, titleAsc, titleDesc }

class TaskListPage extends StatefulWidget {
  final int listIndex;
  const TaskListPage({super.key, required this.listIndex});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  bool _completedExpanded = true;

  bool _isSearching = false;
  String _searchQuery = '';

  SortOption _sortOption = SortOption.dateAsc;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().selectList(widget.listIndex);
    });
  }

  int _compareTasks(Task a, Task b) {
    switch (_sortOption) {
      case SortOption.dateAsc:
        return (a.date ?? DateTime(2100)).compareTo(b.date ?? DateTime(2100));
      case SortOption.dateDesc:
        return (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
      case SortOption.titleAsc:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case SortOption.titleDesc:
        return b.title.toLowerCase().compareTo(a.title.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final list = st.currentList;

    final categories = list.tasks
        .map((t) => t.category)
        .where((c) => c != null && c.isNotEmpty)
        .toSet()
        .cast<String>()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    List<Task> filter(List<Task> src) {
      final q = _searchQuery.trim().toLowerCase();
      return src
          .where((t) => !_isSearching || q.isEmpty || t.title.toLowerCase().contains(q))
          .where((t) => _categoryFilter == null || t.category == _categoryFilter)
          .toList()
        ..sort(_compareTasks);
    }

    final pending = filter(st.pending);
    final completed = filter(st.completed);

    void showXpSnack() {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('+5 XP за выполненную задачу!')));
    }

    return Scaffold(
      appBar: CustomAppBar(
        leading: const BackButton(color: Colors.white),
        title: Text(list.name, style: const TextStyle(color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskDialog(context),
        backgroundColor: list.color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Задача'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              // Верхняя панель: поиск + фильтры
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: list.color.withAlpha((0.12 * 255).round()),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: list.color.withAlpha((0.18 * 255).round()),
                            ),
                          ),
                          child: Icon(Icons.list_alt_rounded, color: list.color),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: _isSearching
                                ? TextField(
                                    key: const ValueKey('search'),
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: 'Поиск задач',
                                      prefixIcon: const Icon(Icons.search_rounded),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () => setState(() {
                                          _isSearching = false;
                                          _searchQuery = '';
                                        }),
                                      ),
                                    ),
                                    onChanged: (v) => setState(() => _searchQuery = v),
                                  )
                                : Row(
                                    key: const ValueKey('titleRow'),
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Задачи',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Поиск',
                                        icon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                                        onPressed: () => setState(() => _isSearching = true),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Chips: сортировка и фильтр по тегу
                    Row(
                      children: [
                        Expanded(
                          child: _Pill(
                            icon: Icons.sort_rounded,
                            label: _sortLabel(_sortOption),
                            onTap: () async {
                              final next = await _pickSort(context, _sortOption);
                              if (next != null) setState(() => _sortOption = next);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Pill(
                            icon: Icons.sell_rounded,
                            label: _categoryFilter ?? 'Все теги',
                            onTap: () async {
                              final next = await _pickCategory(context, _categoryFilter, categories);
                              setState(() => _categoryFilter = next);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Краткая статистика
                    Row(
                      children: [
                        _MiniStat(label: 'В работе', value: '${pending.length}', color: list.color),
                        const SizedBox(width: 10),
                        _MiniStat(label: 'Выполнено', value: '${completed.length}', color: const Color(0xFF10B981)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            _isSearching = false;
                            _searchQuery = '';
                            _categoryFilter = null;
                            _sortOption = SortOption.dateAsc;
                          }),
                          child: const Text('Сбросить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (pending.isEmpty)
                      _EmptyState(
                        title: 'Нет задач',
                        subtitle: _isSearching || _categoryFilter != null ? 'Попробуй изменить фильтры' : 'Добавь первую задачу',
                        color: list.color,
                      )
                    else
                      ...pending.map(
                        (t) => TaskTile(
                          t,
                          (tk, v) async {
                            final wasDone = tk.isDone;
                            await st.toggleDone(tk, v);
                            if (!wasDone && (v ?? false)) showXpSnack();
                          },
                          (tk) => showTaskDialog(context, task: tk),
                          (tk) => st.deleteTask(tk),
                        ),
                      ),

                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: _completedExpanded,
                            onExpansionChanged: (e) => setState(() => _completedExpanded = e),
                            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                            leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                            title: Text(
                              'Выполненные',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            subtitle: Text(
                              '${completed.length} задач',
                              style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                            children: [
                              for (final t in completed)
                                TaskTile(
                                  t,
                                  (tk, v) async {
                                    final wasDone = tk.isDone;
                                    await st.toggleDone(tk, v);
                                    if (!wasDone && (v ?? false)) showXpSnack();
                                  },
                                  (tk) => showTaskDialog(context, task: tk),
                                  (tk) => st.deleteTask(tk),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Helpers (UI) =====

  static String _sortLabel(SortOption o) {
    switch (o) {
      case SortOption.dateAsc:
        return 'Дата ↑';
      case SortOption.dateDesc:
        return 'Дата ↓';
      case SortOption.titleAsc:
        return 'Название ↑';
      case SortOption.titleDesc:
        return 'Название ↓';
    }
  }

  Future<SortOption?> _pickSort(BuildContext context, SortOption current) {
    return showModalBottomSheet<SortOption>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
      builder: (_) {
        Widget item(SortOption v, String title, IconData icon) {
          final selected = v == current;
          return ListTile(
            leading: Icon(icon, color: selected ? AppColors.accent : AppColors.textMuted),
            title: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
            onTap: () => Navigator.pop(context, v),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              item(SortOption.dateAsc, 'Дата (по возрастанию)', Icons.arrow_upward_rounded),
              item(SortOption.dateDesc, 'Дата (по убыванию)', Icons.arrow_downward_rounded),
              item(SortOption.titleAsc, 'Название (A → Z)', Icons.sort_by_alpha_rounded),
              item(SortOption.titleDesc, 'Название (Z → A)', Icons.sort_by_alpha_rounded),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _pickCategory(BuildContext context, String? current, List<String> categories) {
    return showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.all_inclusive_rounded, color: current == null ? AppColors.accent : AppColors.textMuted),
                title: Text(
                  'Все',
                  style: TextStyle(fontWeight: current == null ? FontWeight.w800 : FontWeight.w600),
                ),
                trailing: current == null ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
                onTap: () => Navigator.pop(context, null),
              ),
              if (categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Тегов пока нет', style: TextStyle(color: AppColors.textMuted)),
                )
              else
                ...categories.map((c) {
                  final selected = c == current;
                  return ListTile(
                    leading: Icon(Icons.sell_rounded, color: selected ? AppColors.accent : AppColors.textMuted),
                    title: Text(c, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                    trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
                    onTap: () => Navigator.pop(context, c),
                  );
                }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Pill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha((0.18 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha((0.12 * 255).round()),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha((0.18 * 255).round())),
            ),
            child: Icon(Icons.inbox_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
