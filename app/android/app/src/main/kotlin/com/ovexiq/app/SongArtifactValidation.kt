package com.ovexiq.app

import java.io.File
import java.security.MessageDigest

private val mimeByExtension = mapOf(
    "mp3" to "audio/mpeg",
    "flac" to "audio/flac",
    "ogg" to "audio/ogg",
    "mp4" to "video/mp4",
    "txt" to "text/plain",
)

internal fun isSupportedSongArtifactDescriptor(name: String, mime: String): Boolean {
    if (!Regex("^[A-Za-z0-9_-]{1,100}\\.(mp3|flac|ogg|mp4|txt)$").matches(name)) {
        return false
    }
    val extension = name.substringAfterLast('.')
    return mimeByExtension[extension] == mime
}

internal fun verifySongArtifactFile(source: File, sha256: String, appDataDir: File): Boolean {
    if (!Regex("^[a-f0-9]{64}$").matches(sha256)) return false

    val allowedRoot =
        File(appDataDir, "app_flutter/song_artifacts").canonicalPath + File.separator
    val canonicalSource = source.canonicalFile
    if (!canonicalSource.path.startsWith(allowedRoot) ||
        !canonicalSource.isFile ||
        canonicalSource.length() <= 0L ||
        canonicalSource.length() > 256L * 1024 * 1024
    ) {
        return false
    }

    val digest = MessageDigest.getInstance("SHA-256")
    canonicalSource.inputStream().use { input ->
        val buffer = ByteArray(65536)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            digest.update(buffer, 0, count)
        }
    }
    val actual = digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
    return actual == sha256
}
