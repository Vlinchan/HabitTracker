package com.example.habitflowai

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        android.util.Log.d("HabitWidget", "Main activity ready")
    }
}
