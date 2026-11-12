package com.example.transmission_numerique

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Enregistrement PDF via le sélecteur de documents Android (sans permission stockage). */
class MainActivity : FlutterActivity() {
    private val requestCodeSavePdf = 41027
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPdf: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "digital_logbook/pdf_saver"
        ).setMethodCallHandler { call, result ->
            if (call.method != "savePdf") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingResult != null) {
                result.error("BUSY", "Un enregistrement est déjà en cours.", null)
                return@setMethodCallHandler
            }
            val filename = call.argument<String>("fileName")
            val bytes = call.argument<ByteArray>("bytes")
            if (filename == null || !filename.matches(Regex("[A-Za-z0-9_.-]{1,100}\\.pdf")) ||
                bytes == null || bytes.size < 8 || bytes.size > 10_000_000 ||
                !bytes.copyOfRange(0, 4).contentEquals("%PDF".toByteArray())) {
                result.error("INVALID", "Fichier PDF invalide.", null)
                return@setMethodCallHandler
            }
            pendingResult = result
            pendingPdf = bytes
            try {
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/pdf"
                    putExtra(Intent.EXTRA_TITLE, filename)
                }
                startActivityForResult(intent, requestCodeSavePdf)
            } catch (error: Exception) {
                pendingResult = null
                pendingPdf = null
                result.error("PICKER", "Impossible d'ouvrir l'enregistrement : ${error.message}", null)
            }
        }
    }

    @Deprecated("Utilisé pour recevoir le résultat du sélecteur Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestCodeSavePdf) return
        val result = pendingResult
        val bytes = pendingPdf
        pendingResult = null
        pendingPdf = null
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(false) // Annulation de l'utilisateur.
            return
        }
        try {
            val uri = data.data ?: throw IllegalStateException("Destination manquante")
            val output = contentResolver.openOutputStream(uri, "w")
                ?: throw IllegalStateException("Impossible d'ouvrir le document")
            output.use { it.write(bytes ?: ByteArray(0)) }
            result.success(true)
        } catch (error: Exception) {
            result.error("WRITE", "Enregistrement échoué : ${error.message}", null)
        }
    }
}
