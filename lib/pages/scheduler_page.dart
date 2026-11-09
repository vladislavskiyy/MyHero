import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/day_plan_editor.dart';

class SchedulerPage extends StatefulWidget {
  static const routeName = '/scheduler';
  final DateTime? initialDay;

  const SchedulerPage({super.key, this.initialDay});

  @override
  State<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends State<SchedulerPage> {
  late DateTime _selectedDay = widget.initialDay ?? DateTime.now();

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) setState(() => _selectedDay = picked);
  }

  Future<void> _exportJson() async {
    final payload = context.read<AppState>().exportAnalyticsJson();
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON скопирован в буфер обмена')),
    );
  }

  String _formatDay(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.savedPlans.take(3).toList();
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
              OutlinedButton.icon(
                key: const ValueKey('plan-day-picker'),
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text('Дата: ${_formatDay(_selectedDay)}'),
              ),
              const SizedBox(height: 12),
              DayPlanEditor(day: _selectedDay),
              const SizedBox(height: 16),
              Container(
                decoration: AppDecorations.card(),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'История планов',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    if (history.isEmpty)
                      const Text('Пока нет принятых планов')
                    else
                      for (final plan in history)
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: const Icon(Icons.history_rounded),
                            title: Text(
                              _formatDay(
                                DateTime.parse(plan['date'] as String),
                              ),
                            ),
                            subtitle: Text(
                              '${state.reviewPlan(plan).entries.length} задач · ${state.reviewPlan(plan).usedMinutes} мин',
                            ),
                            onTap: () => setState(
                              () => _selectedDay = DateTime.parse(
                                plan['date'] as String,
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _exportJson,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Экспорт JSON'),
                    ),
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
