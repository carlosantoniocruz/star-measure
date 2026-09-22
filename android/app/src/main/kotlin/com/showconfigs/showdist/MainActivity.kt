package com.showconfigs.showdist

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var ar: ArMeasureController? = null

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
