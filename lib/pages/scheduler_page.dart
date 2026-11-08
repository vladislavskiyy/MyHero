// lib/pages/scheduler_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/custom_app_bar.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class SchedulerPage extends StatefulWidget {
  static const routeName = '/scheduler';

  const SchedulerPage({super.key});

  @override
  State<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends State<SchedulerPage> {
  int _capacity = 120;
  DateTime _selectedDay = DateTime.now();
  final _controller = TextEditingController(text: '120');
  Map<String, dynamic>? _proposal;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runOptimization(BuildContext context) {
    final appState = context.read<AppState>();
    final allTasks = appState.lists.expand((l) => l.tasks).toList();
    final plan = appState.generatePlanForDay(
      _selectedDay,
      _capacity,
      tasks: allTasks,
    );
    setState(() => _proposal = plan);
    FocusScope.of(context).unfocus();
  }

  Future<void> _savePlan(BuildContext context) async {
    final appState = context.read<AppState>();
    if (_proposal == null) return;
    final plan = Map<String, dynamic>.from(_proposal!);
    await appState.savePlan(plan);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('План сохранён для этого дня')),
      );
  }

  Future<void> _exportJson(BuildContext context) async {
    final appState = context.read<AppState>();
    final payload = appState.exportAnalyticsJson();
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('JSON скопирован в буфер обмена')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedIds = (_proposal?['selectedTaskIds'] as List? ?? [])
        .whereType<String>()
        .toList();
    final dropped = (_proposal?['droppedTitles'] as List? ?? [])
        .whereType<String>()
        .toList();
    final totalMinutes = _proposal?['usedMinutes'] as int? ?? 0;
    final history = appState.savedPlans.take(3).toList();

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Планировщик', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(
                              (0.12 * 255).round(),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.accent.withAlpha(
                                (0.18 * 255).round(),
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'План на день',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.calendar_today_rounded,
                            title: 'Дата',
                            value:
                                '${_selectedDay.day.toString().padLeft(2, '0')}.${_selectedDay.month.toString().padLeft(2, '0')}.${_selectedDay.year}',
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDay,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _selectedDay = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '120',
                              labelText: 'Минут',
                              prefixIcon: Icon(Icons.timer_rounded),
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null) {
                                setState(() => _capacity = parsed);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _runOptimization(context),
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('Сгенерировать план'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    if (_proposal != null) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniPill(
                              color: AppColors.accent,
                              label: '${selectedIds.length} задач',
                              icon: Icons.checklist_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniPill(
                              color: const Color(0xFF10B981),
                              label: '$totalMinutes мин',
                              icon: Icons.timer_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _savePlan(context),
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Сохранить'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _exportJson(context),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Экспорт JSON'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_proposal != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Предлагаемый план',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedIds.isEmpty)
                        const Text(
                          'Ничего не вошло в план — попробуйте увеличить доступное время.',
                        )
                      else ...[
                        ...selectedIds.map((id) {
                          final task = appState.lists
                              .expand((list) => list.tasks)
                              .firstWhere(
                                (element) => element.id == id,
                                orElse: () =>
                                    Task(id: 'empty', title: 'Не найдено'),
                              );
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.pageBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (dropped.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Не вошли в план',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textMuted,
                              ),
                        ),
                        const SizedBox(height: 8),
                        ...dropped.map((title) => Text('• $title')),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'История планов',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (history.isEmpty)
                      const Text('Пока нет сохранённых планов')
                    else ...[
                      ...history.map((plan) {
                        final date =
                            DateTime.tryParse(plan['date'] as String? ?? '') ??
                            DateTime.now();
                        final selected =
                            (plan['selectedTaskIds'] as List? ?? []).length;
                        final used = plan['usedMinutes'] as int? ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.pageBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history_rounded,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$selected задач · $used мин',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;

  const _MiniPill({
    required this.color,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha((0.18 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
