package com.ovexiq.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private companion object {
        const val imageSaveChannel = "com.ovexiq.app/device_image_save"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SongFiles(this).register(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, imageSaveChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "savePng") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val localFilePath = call.argument<String>("localFilePath")?.trim()
                if (localFilePath.isNullOrEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.success(false)
                    return@setMethodCallHandler
                }

                Thread {
                    val saved = savePngToMediaStore(File(localFilePath))
                    runOnUiThread { result.success(saved) }
                }.start()
            }
    }

    private fun savePngToMediaStore(sourceFile: File): Boolean {
        if (!sourceFile.isFile) {
            return false
        }

        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "Ovexiq-${System.currentTimeMillis()}.png")
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(
                MediaStore.Images.Media.RELATIVE_PATH,
                "${Environment.DIRECTORY_PICTURES}/Ovexiq",
            )
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: return false

        return try {
            val output = resolver.openOutputStream(uri)
                ?: throw IOException("Could not open image destination")
            output.use { destination ->
                FileInputStream(sourceFile).use { source -> source.copyTo(destination) }
            }
            val completedValues = ContentValues().apply {
                put(MediaStore.Images.Media.IS_PENDING, 0)
            }
            resolver.update(uri, completedValues, null, null)
            true
        } catch (_: Exception) {
            resolver.delete(uri, null, null)
            false
        }
    }
}
