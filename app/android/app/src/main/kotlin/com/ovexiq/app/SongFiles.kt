package com.ovexiq.app

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Downloads stay in Ovexiq; no credential-bearing URL or browser handoff. */
class SongFiles(private val activity: Activity) {
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "com.ovexiq.app/song_files").setMethodCallHandler { call, result ->
            if (call.method !in listOf("open", "save", "share", "verify")) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val mime = call.argument<String>("mimeType")
            val name = call.argument<String>("fileName")
            val sha = call.argument<String>("sha256")
            if (path == null || mime == null || name == null || sha == null ||
                !isSupportedSongArtifactDescriptor(name, mime) ||
                !Regex("^[a-f0-9]{64}$").matches(sha) || Build.VERSION.SDK_INT < 29) {
                result.success(false)
                return@setMethodCallHandler
            }
            Thread {
                if (call.method == "verify") {
                    val valid = try {
                        verifySongArtifactFile(File(path), sha, File(activity.applicationInfo.dataDir))
                    } catch (_: Exception) { false }
                    activity.runOnUiThread { result.success(valid) }
                    return@Thread
                }
                val uri = try { store(File(path), name, mime, sha) } catch (_: Exception) { null }
                activity.runOnUiThread {
                    if (uri == null) { result.success(false); return@runOnUiThread }
                    try {
                        when (call.method) {
                            "open" -> activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, mime)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            })
                            "share" -> activity.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                                type = mime
                                putExtra(Intent.EXTRA_STREAM, uri)
                                clipData = android.content.ClipData.newRawUri(name, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }, null))
                        }
                        result.success(true)
                    } catch (_: Exception) { result.success(false) }
                }
            }.start()
        }
    }

    private fun store(source: File, name: String, mime: String, sha: String): Uri? {
        if (!isSupportedSongArtifactDescriptor(name, mime) ||
            !verifySongArtifactFile(source, sha, File(activity.applicationInfo.dataDir))) return null
        val prefs = activity.getSharedPreferences("song_downloads", 0)
        val resolver = activity.contentResolver
        val previous = prefs.getString(sha, null)?.let(Uri::parse)
        if (previous != null) {
            try { resolver.openInputStream(previous)?.use { return previous } } catch (_: Exception) { /* Re-save a deleted download. */ }
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, "Ovexiq-${source.parentFile!!.name.take(8)}-$name")
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/Ovexiq")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null
        return try {
            val destination = resolver.openOutputStream(uri) ?: throw IllegalStateException()
            destination.use { output -> source.inputStream().use { it.copyTo(output) } }
            resolver.update(uri, ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }, null, null)
            prefs.edit().putString(sha, uri.toString()).apply()
            uri
        } catch (_: Exception) { resolver.delete(uri, null, null); null }
    }
}
