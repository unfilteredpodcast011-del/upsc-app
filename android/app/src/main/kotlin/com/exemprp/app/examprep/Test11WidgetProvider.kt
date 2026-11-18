package com.exemprp.app.examprep

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class Test11WidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.test11_widget_layout)

            // Ensure app icon is explicitly set
            views.setImageViewResource(R.id.widget_icon, R.mipmap.ic_launcher)

            // Read preferences written by Flutter
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val selectedExam = prefs.getString("flutter.target_exam", "UPSC") ?: "UPSC"
            val cachedTestsJson = prefs.getString("flutter.cached_widget_tests_$selectedExam", null)

            views.setTextViewText(R.id.widget_target_exam, "Target: $selectedExam Civil Services")

            if (!cachedTestsJson.isNullOrEmpty()) {
                try {
                    val array = JSONArray(cachedTestsJson)
                    if (array.length() > 0) {
                        val t1 = array.getJSONObject(0)
                        views.setTextViewText(R.id.widget_test1_title, t1.optString("title", "Practice Mock 1"))
                        views.setTextViewText(R.id.widget_test1_badge, "${t1.optInt("questions", 25)} Qs")
                    }
                    if (array.length() > 1) {
                        val t2 = array.getJSONObject(1)
                        views.setTextViewText(R.id.widget_test2_title, t2.optString("title", "Daily Mock 2"))
                        views.setTextViewText(R.id.widget_test2_badge, "${t2.optInt("duration", 30)} mins")
                    }
                    if (array.length() > 2) {
                        val t3 = array.getJSONObject(2)
                        views.setTextViewText(R.id.widget_test3_title, t3.optString("title", "Simulation 3"))
                        views.setTextViewText(R.id.widget_test3_badge, "${t3.optInt("duration", 120)} mins")
                    }
                } catch (e: Exception) {
                    // Fallback to default labels
                }
            } else {
                if (selectedExam == "TNPSC") {
                    views.setTextViewText(R.id.widget_test1_title, "TNPSC Group 1/2 Daily Prelims Mock (25 Qs)")
                    views.setTextViewText(R.id.widget_test2_title, "TNPSC General Tamil & Aptitude Mock (50 Qs)")
                    views.setTextViewText(R.id.widget_test3_title, "TNPSC Combined Comprehensive Simulation (100 Qs)")
                } else {
                    views.setTextViewText(R.id.widget_test1_title, "UPSC CSE Prelims CGS practice 2026 (25 Qs)")
                    views.setTextViewText(R.id.widget_test2_title, "UPSC CSE Prelims Daily Mock (Random 25)")
                    views.setTextViewText(R.id.widget_test3_title, "UPSC Ancient Indian History Deep Mock (50 Qs)")
                }
            }

            // Clicking any part of the widget launches the Flutter app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun refreshAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, Test11WidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (id in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }
}

