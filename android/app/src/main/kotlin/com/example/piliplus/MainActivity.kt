package com.example.piliplus

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.piliplus/native")
            .setMethodCallHandler { call, result ->
                if (call.method == "openInMt") {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        try {
                            val builder = android.os.StrictMode.VmPolicy.Builder()
                            android.os.StrictMode.setVmPolicy(builder.build())

                            val file = java.io.File(filePath)
                            val targetFile = if (file.isDirectory) file else (file.parentFile ?: file)
                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            intent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            intent.setPackage("bin.mt.plus")
                            intent.setDataAndType(android.net.Uri.fromFile(targetFile), "*/*")

                            val pm = packageManager
                            if (intent.resolveActivity(pm) != null) {
                                startActivity(intent)
                                result.success(true)
                            } else {
                                val fallback = android.content.Intent(android.content.Intent.ACTION_VIEW)
                                fallback.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                fallback.setDataAndType(android.net.Uri.fromFile(targetFile), "resource/folder")
                                if (fallback.resolveActivity(pm) != null) {
                                    startActivity(fallback)
                                    result.success(true)
                                } else {
                                    result.success(false)
                                }
                            }
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    } else {
                        result.error("BAD_ARGS", "path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
