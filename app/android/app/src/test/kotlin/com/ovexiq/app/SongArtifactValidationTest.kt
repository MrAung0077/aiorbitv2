package com.ovexiq.app

import java.io.File
import java.security.MessageDigest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SongArtifactValidationTest {
    @Test
    fun descriptorAcceptsDurableNamesAndSupportedMimePairs() {
        assertTrue(isSupportedSongArtifactDescriptor("assetpreview2.ogg", "audio/ogg"))
        assertTrue(isSupportedSongArtifactDescriptor("converted_vocal_01.flac", "audio/flac"))
        assertTrue(isSupportedSongArtifactDescriptor("song9.mp3", "audio/mpeg"))
        assertTrue(isSupportedSongArtifactDescriptor("youtube2.mp4", "video/mp4"))
        assertTrue(isSupportedSongArtifactDescriptor("lyrics2.txt", "text/plain"))
    }

    @Test
    fun descriptorRejectsTraversalMismatchAndUnsupportedTypes() {
        assertFalse(isSupportedSongArtifactDescriptor("../song.mp3", "audio/mpeg"))
        assertFalse(isSupportedSongArtifactDescriptor("song.mp3", "audio/flac"))
        assertFalse(isSupportedSongArtifactDescriptor("song.wav", "audio/wav"))
        assertFalse(isSupportedSongArtifactDescriptor("song.mp3.exe", "audio/mpeg"))
    }

    @Test
    fun verifierAcceptsOnlyMatchingNonEmptyFileInsidePrivateArtifactRoot() {
        val root = createTempDir(prefix = "ovexiq-song-validation-")
        try {
            val allowed = File(root, "app_flutter/song_artifacts/project-1").apply { mkdirs() }
            val file = File(allowed, "asset9.flac").apply { writeBytes(byteArrayOf(1, 2, 3, 4)) }
            val sha = MessageDigest.getInstance("SHA-256")
                .digest(file.readBytes())
                .joinToString("") { "%02x".format(it.toInt() and 255) }

            assertTrue(verifySongArtifactFile(file, sha, root))
            assertFalse(verifySongArtifactFile(file, "0".repeat(64), root))

            val empty = File(allowed, "empty.flac").apply { writeBytes(byteArrayOf()) }
            val emptySha = MessageDigest.getInstance("SHA-256")
                .digest(byteArrayOf())
                .joinToString("") { "%02x".format(it.toInt() and 255) }
            assertFalse(verifySongArtifactFile(empty, emptySha, root))

            val outside = File(root, "outside.flac").apply { writeBytes(byteArrayOf(1, 2, 3)) }
            val outsideSha = MessageDigest.getInstance("SHA-256")
                .digest(outside.readBytes())
                .joinToString("") { "%02x".format(it.toInt() and 255) }
            assertFalse(verifySongArtifactFile(outside, outsideSha, root))
        } finally {
            root.deleteRecursively()
        }
    }
}
