package com.alimind.arabic_temporal_watch

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keep the screen on while the watch face is displayed.
        // The Flutter side can also call `WakelockPlus.enable()` for finer
        // control, but setting the flag here ensures it is active from the
        // very first frame.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
