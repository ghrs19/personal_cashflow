import 'package:home_widget/home_widget.dart';

/// Pushes the current balance snapshot to the Android home-screen widget
/// (CashflowWidgetProvider). Best-effort: silently no-ops when no widget
/// is placed or the platform call fails.
class WidgetService {
  static Future<void> sync({
    required String balance,
    required String monthIn,
    required String monthOut,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('balance', balance);
      await HomeWidget.saveWidgetData<String>('month_in', monthIn);
      await HomeWidget.saveWidgetData<String>('month_out', monthOut);
      await HomeWidget.updateWidget(name: 'CashflowWidgetProvider');
    } catch (_) {
      // Widget not placed / platform unavailable — nothing to do.
    }
  }
}
