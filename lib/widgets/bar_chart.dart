import 'package:flutter/material.dart';

/// A tiny hand-rolled grouped bar chart (cash-in vs cash-out per bucket).
/// Deliberately dependency-free so the build stays light.
class FlowBarChart extends StatelessWidget {
  final List<({String label, double cashIn, double cashOut})> data;
  final String inLabel;
  final String outLabel;

  const FlowBarChart({
    super.key,
    required this.data,
    required this.inLabel,
    required this.outLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var maxV = 0.0;
    for (final d in data) {
      if (d.cashIn > maxV) maxV = d.cashIn;
      if (d.cashOut > maxV) maxV = d.cashOut;
    }
    if (maxV <= 0) maxV = 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _legend(scheme.primary, inLabel),
            const SizedBox(width: 16),
            _legend(scheme.onSurface.withValues(alpha: 0.30), outLabel),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(d.cashIn / maxV, scheme.primary),
                          const SizedBox(width: 3),
                          _bar(d.cashOut / maxV, scheme.onSurface.withValues(alpha: 0.30)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.label,
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _bar(double fraction, Color color) {
    final h = (fraction.clamp(0.0, 1.0) * 118).toDouble();
    return Container(
      width: 12,
      height: h < 2 && fraction > 0 ? 2 : h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}
