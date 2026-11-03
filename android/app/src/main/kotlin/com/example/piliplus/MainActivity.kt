package com.example.piliplus

import android.content.ContentValues
import android.content.res.Configuration
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.nio.ByteBuffer

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
                when (call.method) {
                    "openInMt" -> {
                        val filePath = call.argument<String>("path")
                        if (filePath != null) {
                            try {
                                val builder = android.os.StrictMode.VmPolicy.Builder()
                                android.os.StrictMode.setVmPolicy(builder.build())

                                val file = File(filePath)
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
                    }
                    "mergeToMp4" -> {
                        val entryDirPath = call.argument<String>("entryDirPath")
                        val title = call.argument<String>("title") ?: "video"
                        if (entryDirPath == null) {
                            result.error("BAD_ARGS", "entryDirPath is null", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val outputPath = doMergeToMp4(entryDirPath, title)
                                runOnUiThread {
                                    result.success(mapOf("success" to true, "outputPath" to outputPath))
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.success(mapOf("success" to false, "error" to (e.message ?: e.toString())))
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun findMediaFiles(entryDir: File): Pair<File?, File?> {
        val directMp4 = File(entryDir, "0.mp4")
        if (directMp4.exists()) return Pair(directMp4, null)

        val directVideo = File(entryDir, "video.m4s")
        if (directVideo.exists()) {
            val audio = File(entryDir, "audio.m4s")
            return Pair(directVideo, if (audio.exists()) audio else null)
        }

        val subDirs = entryDir.listFiles { f -> f.isDirectory } ?: emptyArray()
        for (sub in subDirs) {
            val subMp4 = File(sub, "0.mp4")
            if (subMp4.exists()) return Pair(subMp4, null)

            val subVideo = File(sub, "video.m4s")
            if (subVideo.exists()) {
                val subAudio = File(sub, "audio.m4s")
                return Pair(subVideo, if (subAudio.exists()) subAudio else null)
            }
        }
        return Pair(null, null)
    }

    private fun mergeMediaFiles(videoFile: File, audioFile: File?, tempOutputFile: File) {
        val videoFis = FileInputStream(videoFile)
        val videoExtractor = MediaExtractor()
        videoExtractor.setDataSource(videoFis.fd)

        var videoTrackIndex = -1
        var videoTrackFormat: MediaFormat? = null
        for (i in 0 until videoExtractor.trackCount) {
            val format = videoExtractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("video/", ignoreCase = true)) {
                videoTrackIndex = i
                videoTrackFormat = format
                break
            }
        }

        if (videoTrackIndex < 0 || videoTrackFormat == null) {
            videoExtractor.release()
            videoFis.close()
            throw IOException("未能识别视频流信息")
        }

        var audioFis: FileInputStream? = null
        var audioExtractor: MediaExtractor? = null
        var audioTrackIndex = -1
        var audioTrackFormat: MediaFormat? = null

        if (audioFile != null && audioFile.exists()) {
            try {
                val aFis = FileInputStream(audioFile)
                val aExtractor = MediaExtractor()
                aExtractor.setDataSource(aFis.fd)
                for (i in 0 until aExtractor.trackCount) {
                    val format = aExtractor.getTrackFormat(i)
                    val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                    if (mime.startsWith("audio/", ignoreCase = true)) {
                        audioTrackIndex = i
                        audioTrackFormat = format
                        audioExtractor = aExtractor
                        audioFis = aFis
                        break
                    }
                }
                if (audioTrackIndex < 0) {
                    aExtractor.release()
                    aFis.close()
                }
            } catch (_: Exception) {
                audioExtractor?.release()
                audioExtractor = null
                audioFis?.close()
                audioFis = null
            }
        }

        val muxer = MediaMuxer(tempOutputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val muxerVideoTrack = muxer.addTrack(videoTrackFormat)
        val muxerAudioTrack = if (audioExtractor != null && audioTrackFormat != null) {
            muxer.addTrack(audioTrackFormat)
        } else -1

        try {
            muxer.start()
            videoExtractor.selectTrack(videoTrackIndex)
            audioExtractor?.selectTrack(audioTrackIndex)

            val maxBufferSize = 1024 * 1024
            val videoBuffer = ByteBuffer.allocate(maxBufferSize)
            val audioBuffer = ByteBuffer.allocate(maxBufferSize)
            val videoBufferInfo = MediaCodec.BufferInfo()
            val audioBufferInfo = MediaCodec.BufferInfo()

            var videoHasData: Boolean
            var audioHasData = audioExtractor != null && muxerAudioTrack >= 0

            var videoSampleTime = -1L
            var audioSampleTime = -1L

            fun readVideo(): Boolean {
                videoBufferInfo.offset = 0
                val size = videoExtractor.readSampleData(videoBuffer, 0)
                if (size < 0) return false
                videoBufferInfo.size = size
                videoBufferInfo.presentationTimeUs = videoExtractor.sampleTime
                videoBufferInfo.flags = videoExtractor.sampleFlags
                videoSampleTime = videoBufferInfo.presentationTimeUs
                return true
            }

            fun readAudio(): Boolean {
                if (audioExtractor == null) return false
                audioBufferInfo.offset = 0
                val size = audioExtractor.readSampleData(audioBuffer, 0)
                if (size < 0) return false
                audioBufferInfo.size = size
                audioBufferInfo.presentationTimeUs = audioExtractor.sampleTime
                audioBufferInfo.flags = audioExtractor.sampleFlags
                audioSampleTime = audioBufferInfo.presentationTimeUs
                return true
            }

            videoHasData = readVideo()
            if (audioHasData) {
                audioHasData = readAudio()
            }

            while (videoHasData || audioHasData) {
                if (videoHasData && (!audioHasData || videoSampleTime <= audioSampleTime)) {
                    muxer.writeSampleData(muxerVideoTrack, videoBuffer, videoBufferInfo)
                    videoExtractor.advance()
                    videoHasData = readVideo()
                } else if (audioHasData) {
                    muxer.writeSampleData(muxerAudioTrack, audioBuffer, audioBufferInfo)
                    audioExtractor!!.advance()
                    audioHasData = readAudio()
                }
            }
        } finally {
            try { muxer.stop() } catch (_: Exception) {}
            try { muxer.release() } catch (_: Exception) {}
            try { videoExtractor.release() } catch (_: Exception) {}
            try { videoFis.close() } catch (_: Exception) {}
            try { audioExtractor?.release() } catch (_: Exception) {}
            try { audioFis?.close() } catch (_: Exception) {}
        }
    }

    private fun saveMergedMp4(sourceFile: File, rawTitle: String): String {
        val cleanTitle = rawTitle.replace(Regex("[\\\\/:*?\"<>|\\r\\n]"), "_").trim()
            .ifEmpty { "video" }
            .take(100)
        val fileName = if (cleanTitle.endsWith(".mp4", ignoreCase = true)) cleanTitle else "$cleanTitle.mp4"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/PiliPlus")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("无法在公共存储创建 MP4 文件: $fileName")

            resolver.openOutputStream(uri)?.use { out ->
                sourceFile.inputStream().use { input ->
                    input.copyTo(out)
                }
            } ?: throw IOException("无法写入目标 MP4 文件: $uri")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            return File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "PiliPlus/$fileName").absolutePath
        } else {
            val downloadDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "PiliPlus")
            if (!downloadDir.exists()) downloadDir.mkdirs()
            val destFile = File(downloadDir, fileName)
            sourceFile.copyTo(destFile, overwrite = true)
            MediaScannerConnection.scanFile(this, arrayOf(destFile.absolutePath), arrayOf("video/mp4"), null)
            return destFile.absolutePath
        }
    }

    private fun doMergeToMp4(entryDirPath: String, title: String): String {
        val entryDir = File(entryDirPath)
        if (!entryDir.exists()) {
            throw IOException("缓存目录不存在: $entryDirPath")
        }

        val (videoFile, audioFile) = findMediaFiles(entryDir)
        if (videoFile == null) {
            throw IOException("未在目录中找到可合并的视频数据")
        }

        if (videoFile.name.equals("0.mp4", ignoreCase = true) || videoFile.extension.equals("mp4", ignoreCase = true)) {
            return saveMergedMp4(videoFile, title)
        }

        val tempOutput = File(cacheDir, "temp_merged_${System.currentTimeMillis()}.mp4")
        try {
            mergeMediaFiles(videoFile, audioFile, tempOutput)
            if (!tempOutput.exists() || tempOutput.length() == 0L) {
                throw IOException("合并完成但未生成有效视频文件")
            }
            val finalPath = saveMergedMp4(tempOutput, title)
            return finalPath
        } finally {
            if (tempOutput.exists()) {
                tempOutput.delete()
            }
        }
    }
}
