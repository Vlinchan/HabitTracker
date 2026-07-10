package com.example.habitflowai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HabitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: MutableMap<String, String>) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_widget_layout).apply {
                val title = widgetData["widget_title"] ?: "Journal"
                val date = widgetData["widget_date"] ?: "Today"
                val count = widgetData["widget_count"] ?: "0 entries"
                val summary = widgetData["widget_summary"] ?: "Tap to open your journal"

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_date, date)
                setTextViewText(R.id.widget_count, count)
                setTextViewText(R.id.widget_summary, summary)

                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, launchIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
