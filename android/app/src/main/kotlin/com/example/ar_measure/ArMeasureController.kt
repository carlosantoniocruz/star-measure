package com.example.ar_measure

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.UnavailableApkTooOldException
import com.google.ar.core.exceptions.UnavailableDeviceNotCompatibleException
import com.google.ar.core.exceptions.UnavailableSdkTooOldException
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the ARCore [Session] and bridges it to Dart.
 *
 * Method channel `ar_measure/ar`: start, stop, addPoint, undo, clear.
 * Event channel `ar_measure/frames`: one DoubleArray per camera frame (see [ArMeasureView]).
 */
class ArMeasureController(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    /** Guards [session] against being closed while the GL thread is inside `update()`. */
    val lock = Any()

    @Volatile
    var session: Session? = null
        private set

    @Volatile
    private var view: ArMeasureView? = null
    private var installRequested = false
    private var active = false
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, "ar_measure/ar").setMethodCallHandler(this)
        EventChannel(messenger, "ar_measure/frames").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "dirs" -> result.success(
                mapOf(
                    "files" to activity.filesDir.absolutePath,
                    "cache" to activity.cacheDir.absolutePath,
                ),
            )
            "start" -> result.success(start())
            "stop" -> {
                stop()
                result.success(null)
            }
            "addPoint" -> {
                view?.requestAddPoint()
                result.success(null)
            }
            "undo" -> {
                view?.undo()
                result.success(null)
            }
            "clear" -> {
                view?.clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun attach(v: ArMeasureView) {
        view = v
    }

    fun detach(v: ArMeasureView) {
        if (view === v) view = null
    }

    fun emit(data: DoubleArray) {
        main.post { sink?.success(data) }
    }

    @Suppress("DEPRECATION")
    fun displayRotation(): Int =
        if (Build.VERSION.SDK_INT >= 30) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            activity.windowManager.defaultDisplay.rotation
        }

    fun onActivityPause() {
        view?.onPause()
        synchronized(lock) { session?.pause() }
    }

    fun onActivityResume() {
        view?.onResume()
        if (!active) return
        synchronized(lock) {
            try {
                session?.resume()
            } catch (_: CameraNotAvailableException) {
                // The Dart side will surface this on the next start().
            }
        }
    }

    /** Returns a status string Dart switches on. */
    private fun start(): String = synchronized(lock) {
        try {
            if (session == null) {
                when (ArCoreApk.getInstance().requestInstall(activity, !installRequested)) {
                    ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                        installRequested = true
                        return "installRequested"
                    }
                    ArCoreApk.InstallStatus.INSTALLED -> Unit
                }
                if (activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                    return "cameraDenied"
                }
                session = Session(activity).also(::configure)
            }
            session?.resume()
            active = true
            "ready"
        } catch (_: UnavailableDeviceNotCompatibleException) {
            "unsupported"
        } catch (_: UnavailableUserDeclinedInstallationException) {
            "declined"
        } catch (_: UnavailableApkTooOldException) {
            "outdated"
        } catch (_: UnavailableSdkTooOldException) {
            "outdated"
        } catch (_: CameraNotAvailableException) {
            session?.close()
            session = null
            "cameraBusy"
        } catch (e: Exception) {
            Log.e(TAG, "Could not start the AR session", e)
            "error:${e::class.java.simpleName}: ${e.message ?: "no message"}"
        }
    }

    private fun stop() = synchronized(lock) {
        active = false
        session?.close()
        session = null
    }

    private companion object {
        const val TAG = "ArMeasure"
    }

    private fun configure(s: Session) {
        val config = Config(s).apply {
            planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
            lightEstimationMode = Config.LightEstimationMode.DISABLED
            updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            focusMode = Config.FocusMode.AUTO
            if (s.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                depthMode = Config.DepthMode.AUTOMATIC
            }
        }
        s.configure(config)
    }
}
