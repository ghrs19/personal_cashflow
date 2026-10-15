import 'package:flutter/material.dart';

/// Minimal cumulative-balance line chart (hand-rolled, no dependencies).
class BalanceTrendChart extends StatelessWidget {
  final List<double> series; // cumulative net per day
  const BalanceTrendChart({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 110,
      child: CustomPaint(
        painter: _TrendPainter(
          series: series,
          line: scheme.primary,
          fill: scheme.primary.withValues(alpha: 0.08),
          baseline: Theme.of(context).dividerTheme.color ?? scheme.outlineVariant,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> series;
  final Color line;
  final Color fill;
  final Color baseline;

  _TrendPainter({
    required this.series,
    required this.line,
    required this.fill,
    required this.baseline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // baseline
    final basePaint = Paint()
      ..color = baseline
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      basePaint,
    );
    if (series.length < 2) return;
    var min = series.first, max = series.first;
    for (final v in series) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    if (max - min < 0.001) {
      max += 1;
      min -= 1;
    }
    const topPad = 8.0, bottomPad = 6.0;
    final h = size.height - topPad - bottomPad;
    Offset point(int i) {
      final x = size.width * i / (series.length - 1);
      final t = (series[i] - min) / (max - min);
      return Offset(x, topPad + h * (1 - t));
    }

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < series.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    // soft area fill
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    // end dot
    final last = point(series.length - 1);
    canvas.drawCircle(last, 3, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.series != series;
}
