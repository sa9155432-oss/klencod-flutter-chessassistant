package com.amr.chessassist // FILL: نفس package مالك

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private val REQ = 4242

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "amr/capture").setMethodCallHandler { call, res ->
            when (call.method) {
                "start" -> {
                    if (CaptureService.ready) { res.success(true); return@setMethodCallHandler }
                    pending = res
                    val mpm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    startActivityForResult(mpm.createScreenCaptureIntent(), REQ)
                }
                "grab" -> {
                    val f = CaptureService.grab()
                    if (f == null) res.error("nocap", "no frame", null) else res.success(f)
                }
                "toBack" -> { moveTaskToBack(true); res.success(true) }
                "stop" -> { stopService(Intent(this, CaptureService::class.java)); res.success(true) }
                else -> res.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(req: Int, code: Int, data: Intent?) {
        super.onActivityResult(req, code, data)
        if (req != REQ) return
        if (code != Activity.RESULT_OK || data == null) { pending?.success(false); pending = null; return }
        CaptureService.onReady = { pending?.success(true); pending = null }
        ContextCompat.startForegroundService(
            this, Intent(this, CaptureService::class.java).putExtra("code", code).putExtra("data", data)
        )
    }
}