// ponytail: 100% CustomPainter Weekly Bar Chart; add pinch-to-zoom multi-month panning when year-to-date analysis is required.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

class DayExpense {
  final String dayLabel; // e.g. 'Mon', 'Tue' or 'T2', 'T3'
  final DateTime date;
  final double amount;
  final bool isToday;

  const DayExpense({
    required this.dayLabel,
    required this.date,
    required this.amount,
    required this.isToday,
  });
}

class WeeklyBarChartWidget extends StatefulWidget {
  final List<DayExpense> weeklyData;

  const WeeklyBarChartWidget({
    super.key,
    required this.weeklyData,
  });

  @override
  State<WeeklyBarChartWidget> createState() => _WeeklyBarChartWidgetState();
}

class _WeeklyBarChartWidgetState extends State<WeeklyBarChartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant WeeklyBarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weeklyData != widget.weeklyData) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.compact(locale: 'vi');
    final maxAmount = widget.weeklyData.fold(0.0, (prev, elem) => max(prev, elem.amount));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Trend (Last 7 Days)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              if (maxAmount > 0)
                Text(
                  'Max: ${currencyFormat.format(maxAmount)}đ',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WeeklyBarChartPainter(
                    data: widget.weeklyData,
                    progress: _animation.value,
                    theme: Theme.of(context),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChartPainter extends CustomPainter {
  final List<DayExpense> data;
  final double progress;
  final ThemeData theme;

  _WeeklyBarChartPainter({
    required this.data,
    required this.progress,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final bottomPadding = 28.0;
    final topPadding = 20.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final maxAmount = data.fold(0.0, (prev, elem) => max(prev, elem.amount));
    final effectiveMax = maxAmount > 0 ? maxAmount * 1.15 : 100.0; // 15% headroom

    final totalBars = data.length;
    final slotWidth = size.width / totalBars;
    final barWidth = min(slotWidth * 0.45, 24.0);

    // Draw grid guide lines
    final gridPaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha:0.3)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 2; i++) {
      final y = topPadding + (chartHeight * i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Baseline
    final baselineY = size.height - bottomPadding;
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      Paint()
        ..color = theme.colorScheme.outlineVariant
        ..strokeWidth = 1.2,
    );

    // Text painters for labels
    final textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    );

    final todayStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
    );

    for (int i = 0; i < totalBars; i++) {
      final item = data[i];
      final centerX = slotWidth * i + (slotWidth / 2);

      // Bar height
      final ratio = (item.amount / effectiveMax).clamp(0.0, 1.0);
      final barHeight = chartHeight * ratio * progress;
      final barRect = Rect.fromCenter(
        center: Offset(centerX, baselineY - (barHeight / 2)),
        width: barWidth,
        height: max(barHeight, 2.0),
      );

      final rrect = RRect.fromRectAndRadius(barRect, const Radius.circular(6));

      // Paint colors: Highlight today or highest
      final isMax = item.amount > 0 && item.amount == maxAmount;
      final barColor = item.isToday
          ? theme.colorScheme.primary
          : isMax
              ? theme.colorScheme.tertiary
              : theme.colorScheme.primary.withValues(alpha:0.35);

      final barPaint = Paint()..color = barColor;
      canvas.drawRRect(rrect, barPaint);

      // Amount label on top of bar if animated progress is high enough
      if (progress > 0.8 && item.amount > 0) {
        final compactFormat = NumberFormat.compact(locale: 'vi');
        final valueText = compactFormat.format(item.amount);
        final valPainter = TextPainter(
          text: TextSpan(
            text: valueText,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: item.isToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        valPainter.paint(
          canvas,
          Offset(centerX - (valPainter.width / 2), baselineY - barHeight - valPainter.height - 3),
        );
      }

      // Day label below
      final labelPainter = TextPainter(
        text: TextSpan(
          text: item.dayLabel,
          style: item.isToday ? todayStyle : textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      labelPainter.paint(
        canvas,
        Offset(centerX - (labelPainter.width / 2), baselineY + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.data != data;
  }
}
