package com.showconfigs.showdist

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var ar: ArMeasureController? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep the screen on for as long as the app is in the foreground —
        // measuring and levelling both involve holding the phone still and
        // looking at it, which a screen timeout would interrupt.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val controller = ArMeasureController(this, flutterEngine.dartExecutor.binaryMessenger)
        ar = controller
        flutterEngine.platformViewsController.registry.registerViewFactory(
            ArMeasureViewFactory.VIEW_TYPE,
            ArMeasureViewFactory(controller),
        )
    }

    override fun onPause() {
        ar?.onActivityPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        ar?.onActivityResume()
    }
}
