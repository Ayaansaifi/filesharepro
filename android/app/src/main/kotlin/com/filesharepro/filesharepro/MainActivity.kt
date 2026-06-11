package com.filesharepro.filesharepro

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.view.WindowManager
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val STATUS_CHANNEL = "com.filesharepro/status_saver"
    private val SECURITY_CHANNEL = "com.filesharepro/security"
    private val DEVICE_INFO_CHANNEL = "com.filesharepro/device_info"
    private val SAF_REQUEST_CODE = 1001

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STATUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestSafPermission" -> {
                        pendingResult = result
                        requestSafPermission()
                    }
                    "getStatuses" -> {
                        val uri = call.argument<String>("uri")
                        if (uri != null) {
                            val statuses = getStatusesFromSaf(Uri.parse(uri))
                            result.success(statuses)
                        } else {
                            result.error("INVALID_URI", "URI is null", null)
                        }
                    }
                    "addToGallery" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            addToGallery(path)
                            result.success(true)
                        } else {
                            result.error("INVALID_PATH", "Path is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableSecureMode" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    "disableSecureMode" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSdkVersion" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestSafPermission() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )

            // Try to navigate to WhatsApp status directory
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val whatsappUri = Uri.parse(
                    "content://com.android.externalstorage.documents/document/primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2F.Statuses"
                )
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, whatsappUri)
            }
        }
        startActivityForResult(intent, SAF_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == SAF_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!

                // Take persistable permission
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )

                pendingResult?.success(uri.toString())
            } else {
                pendingResult?.error("CANCELLED", "User cancelled permission", null)
            }
            pendingResult = null
        }
    }

    private fun getStatusesFromSaf(treeUri: Uri): List<String> {
        val statusFiles = mutableListOf<String>()
        val cacheDir = File(cacheDir, "statuses")
        
        // Clear old cache to prevent stale/duplicate statuses
        if (cacheDir.exists()) {
            cacheDir.listFiles()?.forEach { it.delete() }
        } else {
            cacheDir.mkdirs()
        }

        try {
            val documentFile = DocumentFile.fromTreeUri(this, treeUri)
            if (documentFile != null && documentFile.exists()) {
                val files = documentFile.listFiles()
                for (file in files) {
                    if (file.isFile && file.name != null) {
                        val name = file.name!!
                        if (name.startsWith(".")) continue

                        val isMedia = name.endsWith(".jpg", true) ||
                                name.endsWith(".jpeg", true) ||
                                name.endsWith(".png", true) ||
                                name.endsWith(".mp4", true) ||
                                name.endsWith(".gif", true) ||
                                name.endsWith(".webp", true)

                        if (isMedia && file.uri != null) {
                            // Copy to cache for Flutter access
                            val cachedFile = File(cacheDir, name)
                            try {
                                contentResolver.openInputStream(file.uri)?.use { input ->
                                    FileOutputStream(cachedFile).use { output ->
                                        input.copyTo(output)
                                    }
                                }
                                statusFiles.add(cachedFile.absolutePath)
                            } catch (e: Exception) {
                                // Skip file on error
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // Return empty list on error
        }

        return statusFiles
    }

    private fun addToGallery(filePath: String) {
        try {
            val file = File(filePath)
            if (!file.exists()) return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Use MediaStore for Android 10+
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
                    put(MediaStore.MediaColumns.RELATIVE_PATH,
                        Environment.DIRECTORY_PICTURES + "/FileSharePro")

                    val mimeType = when {
                        file.name.endsWith(".mp4", true) -> "video/mp4"
                        file.name.endsWith(".jpg", true) ||
                        file.name.endsWith(".jpeg", true) -> "image/jpeg"
                        file.name.endsWith(".png", true) -> "image/png"
                        file.name.endsWith(".gif", true) -> "image/gif"
                        file.name.endsWith(".webp", true) -> "image/webp"
                        else -> "application/octet-stream"
                    }
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                }

                val collection = if (file.name.endsWith(".mp4", true)) {
                    MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                } else {
                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                }

                contentResolver.insert(collection, values)?.let { uri ->
                    contentResolver.openOutputStream(uri)?.use { output ->
                        file.inputStream().use { input ->
                            input.copyTo(output)
                        }
                    }
                }
            } else {
                // Legacy: scan file
                val intent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                intent.data = Uri.fromFile(file)
                sendBroadcast(intent)
            }
        } catch (e: Exception) {
            // Silently fail
        }
    }
}
