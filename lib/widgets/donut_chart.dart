// ponytail: 100% CustomPainter Donut Chart; add touch-hit sector selection when interactive drill-down is requested.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DonutChartWidget extends StatefulWidget {
  final Map<String, double> categoryData;
  final double totalAmount;

  const DonutChartWidget({
    super.key,
    required this.categoryData,
    required this.totalAmount,
  });

  static const Map<String, Color> categoryColors = {
    'Food': Color(0xFF10B981),        // Emerald
    'Transport': Color(0xFF3B82F6),   // Blue
    'Study': Color(0xFF8B5CF6),       // Purple
    'Shopping': Color(0xFFF59E0B),    // Amber
    'Entertainment': Color(0xFFEC4899), // Pink
    'Other': Color(0xFF64748B),       // Slate
  };

  @override
  State<DonutChartWidget> createState() => _DonutChartWidgetState();
}

class _DonutChartWidgetState extends State<DonutChartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant DonutChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryData != widget.categoryData || oldWidget.totalAmount != widget.totalAmount) {
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
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return Column(
      children: [
        SizedBox(
          height: 220,
          width: 220,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: _DonutChartPainter(
                  data: widget.categoryData,
                  total: widget.totalAmount,
                  progress: _animation.value,
                  theme: Theme.of(context),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Spent',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(widget.totalAmount),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: widget.categoryData.entries.map((e) {
            final color = DonutChartWidget.categoryColors[e.key] ?? const Color(0xFF64748B);
            final pct = widget.totalAmount > 0 ? (e.value / widget.totalAmount * 100).toStringAsFixed(0) : '0';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${e.key} ($pct%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final double total;
  final double progress;
  final ThemeData theme;

  _DonutChartPainter({
    required this.data,
    required this.total,
    required this.progress,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;
    const strokeWidth = 24.0;

    final backgroundPaint = Paint()
      ..color = theme.colorScheme.surfaceContainerHighest.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Draw background track
    canvas.drawCircle(center, radius, backgroundPaint);

    if (total <= 0 || data.isEmpty) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    double startAngle = -pi / 2;
    const gapAngle = 0.04; // Small gap between slices

    for (final entry in data.entries) {
      if (entry.value <= 0) continue;
      final sweepAngle = (entry.value / total) * 2 * pi * progress;
      if (sweepAngle <= 0) continue;

      final color = DonutChartWidget.categoryColors[entry.key] ?? const Color(0xFF64748B);
      final slicePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final effectiveSweep = max(0.01, sweepAngle - gapAngle);
      canvas.drawArc(rect, startAngle + (gapAngle / 2), effectiveSweep, false, slicePaint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.data != data || oldDelegate.total != total;
  }
}
