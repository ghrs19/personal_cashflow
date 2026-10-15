package com.gherdev.personal_cashflow

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget: total balance + this month's in/out, fed from
/// Flutter via the home_widget plugin (keys: balance, month_in, month_out).
class CashflowWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.cashflow_widget).apply {
                setTextViewText(R.id.widget_balance, widgetData.getString("balance", "—"))
                setTextViewText(R.id.widget_in, widgetData.getString("month_in", "—"))
                setTextViewText(R.id.widget_out, widgetData.getString("month_out", "—"))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
