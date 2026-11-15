package com.aibookreader.ai_book_reader

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

object OcrManager {
    private const val TAG = "RaiderOcrManager"

    fun isAvailable(): Boolean {
        return true
    }

    suspend fun ocrPdfPages(
        filePath: String,
        startPage: Int = 0,
        endPage: Int = -1,
        maxPages: Int = 200
    ): List<Map<String, Any>> = withContext(Dispatchers.IO) {
        val file = File(filePath)
        if (!file.exists()) {
            Log.e(TAG, "File does not exist: $filePath")
            return@withContext emptyList()
        }

        val pfd = try {
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening PDF file descriptor: ${e.message}", e)
            return@withContext emptyList()
        }

        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val results = mutableListOf<Map<String, Any>>()

        try {
            PdfRenderer(pfd).use { renderer ->
                val totalPages = renderer.pageCount
                if (totalPages == 0) return@use

                val actualStart = startPage.coerceIn(0, totalPages - 1)
                val targetEnd = if (endPage < 0 || endPage >= totalPages) totalPages - 1 else endPage
                val actualEnd = targetEnd.coerceIn(actualStart, totalPages - 1)

                var processedCount = 0
                for (pageIndex in actualStart..actualEnd) {
                    if (processedCount >= maxPages) {
                        Log.d(TAG, "Reached maxPages limit of $maxPages")
                        break
                    }

                    try {
                        renderer.openPage(pageIndex).use { page ->
                            // 2.0x scale gives ~144-200 DPI, optimal for text clarity without excess memory
                            val scale = 2.0f
                            val width = (page.width * scale).toInt().coerceAtLeast(1)
                            val height = (page.height * scale).toInt().coerceAtLeast(1)

                            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                            bitmap.eraseColor(Color.WHITE) // White background for clean text contrast

                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

                            val inputImage = InputImage.fromBitmap(bitmap, 0)
                            try {
                                val visionText = Tasks.await(recognizer.process(inputImage))
                                val recognized = visionText.text.trim()
                                results.add(
                                    mapOf(
                                        "pageIndex" to pageIndex,
                                        "pageNumber" to (pageIndex + 1),
                                        "text" to recognized
                                    )
                                )
                                Log.d(TAG, "OCR page ${pageIndex + 1}/$totalPages: extracted ${recognized.length} chars")
                            } catch (e: Exception) {
                                Log.w(TAG, "OCR failed for page $pageIndex: ${e.message}")
                                results.add(
                                    mapOf(
                                        "pageIndex" to pageIndex,
                                        "pageNumber" to (pageIndex + 1),
                                        "text" to ""
                                    )
                                )
                            } finally {
                                bitmap.recycle()
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error rendering page $pageIndex: ${e.message}", e)
                    }

                    processedCount++
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "PdfRenderer error on $filePath: ${e.message}", e)
        } finally {
            try {
                recognizer.close()
            } catch (_: Exception) {}
            try {
                pfd.close()
            } catch (_: Exception) {}
        }

        results
    }

    suspend fun ocrImage(
        context: Context,
        imagePath: String
    ): String = withContext(Dispatchers.IO) {
        val file = File(imagePath)
        if (!file.exists()) return@withContext ""

        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            val uri = Uri.fromFile(file)
            val inputImage = InputImage.fromFilePath(context, uri)
            val visionText = Tasks.await(recognizer.process(inputImage))
            visionText.text.trim()
        } catch (e: Exception) {
            Log.e(TAG, "Failed OCR for image $imagePath: ${e.message}", e)
            ""
        } finally {
            try {
                recognizer.close()
            } catch (_: Exception) {}
        }
    }
}
