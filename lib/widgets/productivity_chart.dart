// lib/widgets/productivity_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ProductivityChart extends StatelessWidget {
  const ProductivityChart({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final today = DateTime.now();
    final days = List<DateTime>.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final counts = days.map((d) => appState.completedCountOn(d)).toList();

    final hasAnyData = counts.any((c) => c > 0);
    if (!hasAnyData) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Нет данных для графика',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    final maxY = (maxCount + 1).toDouble();

    final barGroups = List<BarChartGroupData>.generate(7, (i) {
      final value = counts[i].toDouble();
      return BarChartGroupData(
        x: i,
        barsSpace: 6,
        barRods: [
          BarChartRodData(
            toY: value,
            width: 14,
            borderRadius: BorderRadius.circular(10),
            color: AppColors.accent,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: AppColors.border.withAlpha((0.45 * 255).round()),
            ),
          ),
        ],
      );
    });

    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxY,
          minY: 0,
          barGroups: barGroups,
          barTouchData: BarTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: BarTouchTooltipData(
              // У fl_chart разные версии имеют разные параметры.
              // Здесь используем максимально совместимые (без tooltipRoundedRadius).
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final d = days[group.x.toInt()];
                final label =
                    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
                final v = rod.toY.toInt();
                return BarTooltipItem(
                  '$label\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: 'Выполнено: $v',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: maxCount <= 4 ? 1 : (maxCount / 2).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx > 6) return const SizedBox.shrink();
                  final d = days[idx];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      d.day.toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxCount <= 4 ? 1 : (maxCount / 2).ceilToDouble(),
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.border.withAlpha((0.55 * 255).round()),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
