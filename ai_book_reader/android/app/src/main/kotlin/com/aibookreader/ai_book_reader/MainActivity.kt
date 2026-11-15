package com.aibookreader.ai_book_reader

import android.Manifest
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aibookreader.ai_book_reader/incoming_files"
    private val REMINDER_CHANNEL = "com.aibookreader.ai_book_reader/reading_reminder"
    private var methodChannel: MethodChannel? = null
    private var reminderChannel: MethodChannel? = null
    private val pendingFilePaths = mutableListOf<String>()

    override fun getInitialRoute(): String {
        return "/splash"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ReadingReminderManager.createNotificationChannel(this)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFiles" -> {
                    val paths = ArrayList(pendingFilePaths)
                    pendingFilePaths.clear()
                    result.success(paths)
                }
                else -> result.notImplemented()
            }
        }

        // Setup Reading Reminder Method Channel
        val rChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDER_CHANNEL)
        reminderChannel = rChannel
        rChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleHourlyReminder" -> {
                    val goalMinutes = call.argument<Int>("goalMinutes")
                    val currentMinutes = call.argument<Int>("currentMinutes")
                    val isGoalMet = call.argument<Boolean>("isGoalMet")
                    if (goalMinutes != null && currentMinutes != null && isGoalMet != null) {
                        ReadingReminderManager.saveGoalStatus(
                            context = this,
                            isGoalMet = isGoalMet,
                            currentMinutes = currentMinutes,
                            goalMinutes = goalMinutes,
                            statDate = ReadingReminderManager.getTodayDateString(),
                            isEnabled = true
                        )
                    }
                    ReadingReminderManager.scheduleHourlyReminder(this)
                    result.success(true)
                }
                "cancelHourlyReminder" -> {
                    ReadingReminderManager.cancelHourlyReminder(this)
                    result.success(true)
                }
                "updateGoalStatus" -> {
                    val isGoalMet = call.argument<Boolean>("isGoalMet") ?: false
                    val currentMinutes = call.argument<Int>("currentMinutes") ?: 0
                    val goalMinutes = call.argument<Int>("goalMinutes") ?: 30
                    val date = call.argument<String>("date") ?: ReadingReminderManager.getTodayDateString()
                    val enabled = call.argument<Boolean>("enabled") ?: true

                    ReadingReminderManager.saveGoalStatus(
                        context = this,
                        isGoalMet = isGoalMet,
                        currentMinutes = currentMinutes,
                        goalMinutes = goalMinutes,
                        statDate = date,
                        isEnabled = enabled
                    )

                    if (enabled) {
                        if (isGoalMet) {
                            ReadingReminderManager.cancelHourlyReminder(this)
                        } else {
                            ReadingReminderManager.scheduleHourlyReminder(this)
                        }
                    } else {
                        ReadingReminderManager.cancelHourlyReminder(this)
                    }
                    result.success(true)
                }
                "showTestNotification" -> {
                    ReadingReminderManager.showTestNotification(this)
                    result.success(true)
                }
                "checkNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            1002
                        )
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // If files were buffered before the channel was attached, deliver them
        if (pendingFilePaths.isNotEmpty()) {
            val paths = ArrayList(pendingFilePaths)
            pendingFilePaths.clear()
            channel.invokeMethod("onFilesOpened", paths)
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val uris = mutableListOf<Uri>()

        when (intent.action) {
            Intent.ACTION_VIEW -> {
                intent.data?.let { uris.add(it) }
            }
            Intent.ACTION_SEND -> {
                val streamUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
                }
                val target = streamUri ?: intent.data
                target?.let { uris.add(it) }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val streamUris = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
                streamUris?.filterNotNull()?.let { uris.addAll(it) }
            }
        }

        val resolvedPaths = mutableListOf<String>()
        for (uri in uris) {
            val path = processUri(uri)
            if (path != null) {
                resolvedPaths.add(path)
            }
        }

        if (resolvedPaths.isNotEmpty()) {
            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod("onFilesOpened", resolvedPaths)
            } else {
                pendingFilePaths.addAll(resolvedPaths)
            }
        }
    }

    private fun processUri(uri: Uri): String? {
        return try {
            var displayName: String? = null
            if (uri.scheme == ContentResolver.SCHEME_CONTENT) {
                contentResolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME),
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1) {
                            displayName = cursor.getString(nameIndex)
                        }
                    }
                }
            }

            if (displayName.isNullOrBlank()) {
                val lastSegment = uri.lastPathSegment
                if (!lastSegment.isNullOrBlank()) {
                    displayName = if (lastSegment.contains('/')) {
                        lastSegment.substringAfterLast('/')
                    } else {
                        lastSegment
                    }
                }
            }

            if (displayName.isNullOrBlank()) {
                displayName = "book_${System.currentTimeMillis()}"
            }

            // Ensure extension is present or inferred from MIME type
            if (!displayName.contains('.')) {
                val mimeType = contentResolver.getType(uri)
                val ext = when (mimeType) {
                    "application/pdf" -> "pdf"
                    "application/epub+zip" -> "epub"
                    "text/plain" -> "txt"
                    "application/vnd.comicbook+zip", "application/x-cbz" -> "cbz"
                    "application/vnd.comicbook-rar", "application/x-cbr" -> "cbr"
                    "application/x-mobipocket-ebook", "application/x-mobi" -> "mobi"
                    "application/vnd.amazon.ebook", "application/x-mobi8-ebook" -> "azw3"
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "docx"
                    else -> MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
                }
                if (!ext.isNullOrBlank()) {
                    displayName = "$displayName.$ext"
                }
            }

            // If direct file access is possible
            if (uri.scheme == ContentResolver.SCHEME_FILE) {
                val path = uri.path
                if (!path.isNullOrBlank()) {
                    val file = File(path)
                    if (file.exists() && file.canRead()) {
                        return file.absolutePath
                    }
                }
            }

            val incomingDir = File(context.cacheDir, "incoming_books")
            if (!incomingDir.exists()) {
                incomingDir.mkdirs()
            }

            // Sanitize filename
            val safeName = displayName.replace(Regex("[/\\\\?%*:|\"<>]"), "_")
            val targetFile = File(incomingDir, safeName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (targetFile.exists() && targetFile.length() > 0) {
                targetFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
