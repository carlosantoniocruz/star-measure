package com.showconfigs.showdist

import android.content.Context
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.view.View
import com.google.ar.core.Anchor
import com.google.ar.core.DepthPoint
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Session
import com.google.ar.core.TrackingFailureReason
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.SessionPausedException
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.atomic.AtomicBoolean
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class ArMeasureViewFactory(private val controller: ArMeasureController) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        ArMeasureView(context, controller)

    companion object {
        const val VIEW_TYPE = "ar_measure/view"
    }
}

/**
 * Renders the camera feed and tracks measurement anchors. All drawing of points, lines and labels
 * happens in Flutter: each frame this view sends Dart a flat DoubleArray:
 *
 *   [0] tracking   0 = stopped, 1 = tracking, 2 = paused / lost
 *   [1] reason     0 none, 1 bad state, 2 too dark, 3 too fast, 4 few features, 5 camera unavailable
 *   [2] planes     number of tracked planes
 *   [3] reticle    1 if the screen centre hits a surface
 *   [4..6]         reticle hit, world x y z (metres)
 *   [7..8]         reticle hit, screen x y (0..1, origin top-left)
 *   [9] count      number of anchors, then per anchor: world x y z, screen x y, visible (0/1)
 */
class ArMeasureView(
    context: Context,
    private val controller: ArMeasureController,
) : PlatformView, GLSurfaceView.Renderer {

    private val glView = GLSurfaceView(context)
    private val background = BackgroundRenderer()

    private var width = 1
    private var height = 1
    private var geometryDirty = true
    private var boundSession: Session? = null

    // GL thread only. The view redraws at the display's rate (up to 120 Hz), but the camera
    // delivers ~30 images a second: hit testing and messaging Dart only happen on a new one.
    private var lastTimestamp = 0L
    private var newFrames = 0
    private var planes = 0

    // GL thread only.
    private val anchors = ArrayList<Anchor>()
    private val addRequested = AtomicBoolean(false)

    private val viewMatrix = FloatArray(16)
    private val projectionMatrix = FloatArray(16)
    private val viewProjection = FloatArray(16)
    private val point4 = FloatArray(4)
    private val clip4 = FloatArray(4)

    init {
        glView.preserveEGLContextOnPause = true
        glView.setEGLContextClientVersion(2)
        glView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        glView.setRenderer(this)
        glView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        controller.attach(this)
    }

    override fun getView(): View = glView

    override fun dispose() {
        controller.detach(this)
        glView.onPause()
    }

    fun onPause() = glView.onPause()

    fun onResume() = glView.onResume()

    fun requestAddPoint() = addRequested.set(true)

    fun undo() = glView.queueEvent {
        if (anchors.isNotEmpty()) anchors.removeAt(anchors.lastIndex).detach()
    }

    fun clear() = glView.queueEvent {
        anchors.forEach { it.detach() }
        anchors.clear()
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        background.createOnGlThread()
        boundSession = null // the camera texture was recreated, rebind it
    }

    override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) {
        GLES20.glViewport(0, 0, w, h)
        width = w
        height = h
        geometryDirty = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)

        synchronized(controller.lock) {
            val session = controller.session ?: return
            if (boundSession !== session) {
                session.setCameraTextureName(background.textureId)
                boundSession = session
                geometryDirty = true
                anchors.clear()
                lastTimestamp = 0L
                newFrames = 0
            }
            if (geometryDirty) {
                session.setDisplayGeometry(controller.displayRotation(), width, height)
                geometryDirty = false
            }

            val frame = try {
                session.update()
            } catch (_: CameraNotAvailableException) {
                return
            } catch (_: SessionPausedException) {
                return
            }
            background.draw(frame)
            if (frame.timestamp == lastTimestamp) return
            lastTimestamp = frame.timestamp
            newFrames++
            if (newFrames % MEMORY_CHECK_EVERY == 0) controller.checkMemory()
            controller.emit(buildPayload(session, frame))
        }
    }

    private fun buildPayload(session: Session, frame: Frame): DoubleArray {
        val camera = frame.camera
        val tracking = camera.trackingState == TrackingState.TRACKING

        // Only used for the "scan surfaces" hint, so a few times a second is plenty;
        // getAllTrackables allocates a fresh collection on every call.
        if (newFrames % PLANE_COUNT_EVERY == 1) {
            planes = 0
            for (plane in session.getAllTrackables(Plane::class.java)) {
                if (plane.trackingState == TrackingState.TRACKING && plane.subsumedBy == null) planes++
            }
        }

        if (tracking) {
            camera.getViewMatrix(viewMatrix, 0)
            camera.getProjectionMatrix(projectionMatrix, 0, NEAR, FAR)
            Matrix.multiplyMM(viewProjection, 0, projectionMatrix, 0, viewMatrix, 0)
        }

        val hit = if (tracking) bestHit(frame, width / 2f, height / 2f) else null
        if (addRequested.getAndSet(false) && hit != null && anchors.size < MAX_POINTS) {
            // session.createAnchor, not hit.createAnchor: a plane hit's anchor would be
            // attached to (and drift with) the plane's own pose as ARCore refines it in the
            // seconds after placement. A session anchor is fixed in world space instead.
            anchors.add(session.createAnchor(hit.hitPose))
        }

        val out = DoubleArray(HEADER + anchors.size * STRIDE)
        out[0] = when (camera.trackingState) {
            TrackingState.TRACKING -> 1.0
            TrackingState.PAUSED -> 2.0
            else -> 0.0
        }
        out[1] = when (camera.trackingFailureReason) {
            TrackingFailureReason.NONE -> 0.0
            TrackingFailureReason.BAD_STATE -> 1.0
            TrackingFailureReason.INSUFFICIENT_LIGHT -> 2.0
            TrackingFailureReason.EXCESSIVE_MOTION -> 3.0
            TrackingFailureReason.INSUFFICIENT_FEATURES -> 4.0
            TrackingFailureReason.CAMERA_UNAVAILABLE -> 5.0
        }
        out[2] = planes.toDouble()

        if (hit != null) {
            val p = hit.hitPose
            out[3] = 1.0
            out[4] = p.tx().toDouble()
            out[5] = p.ty().toDouble()
            out[6] = p.tz().toDouble()
            if (!project(p.tx(), p.ty(), p.tz(), out, 7)) out[3] = 0.0
        }

        out[9] = anchors.size.toDouble()
        anchors.forEachIndexed { i, anchor ->
            val o = HEADER + i * STRIDE
            val p = anchor.pose
            out[o] = p.tx().toDouble()
            out[o + 1] = p.ty().toDouble()
            out[o + 2] = p.tz().toDouble()
            val visible = tracking &&
                anchor.trackingState == TrackingState.TRACKING &&
                project(p.tx(), p.ty(), p.tz(), out, o + 3)
            out[o + 5] = if (visible) 1.0 else 0.0
        }
        return out
    }

    /** First hit on a plane inside its polygon, a depth point, or an oriented feature point. */
    private fun bestHit(frame: Frame, x: Float, y: Float): HitResult? {
        for (hit in frame.hitTest(x, y)) {
            when (val trackable = hit.trackable) {
                is Plane -> if (trackable.isPoseInPolygon(hit.hitPose)) return hit
                is DepthPoint -> return hit
                is Point -> if (trackable.orientationMode == Point.OrientationMode.ESTIMATED_SURFACE_NORMAL) return hit
                else -> Unit
            }
        }
        return null
    }

    /** Projects a world point to normalised screen coordinates (0..1, origin top-left). */
    private fun project(x: Float, y: Float, z: Float, out: DoubleArray, offset: Int): Boolean {
        point4[0] = x
        point4[1] = y
        point4[2] = z
        point4[3] = 1f
        Matrix.multiplyMV(clip4, 0, viewProjection, 0, point4, 0)
        if (clip4[3] <= 1e-4f) return false // behind the camera
        out[offset] = (clip4[0] / clip4[3] * 0.5f + 0.5f).toDouble()
        out[offset + 1] = (1f - (clip4[1] / clip4[3] * 0.5f + 0.5f)).toDouble()
        return true
    }

    private companion object {
        const val HEADER = 10
        const val STRIDE = 6
        const val MAX_POINTS = 24
        const val PLANE_COUNT_EVERY = 10 // new camera frames, ~3 times a second
        const val MEMORY_CHECK_EVERY = 90 // new camera frames, ~every 3 seconds
        const val NEAR = 0.05f
        const val FAR = 100f
    }
}
