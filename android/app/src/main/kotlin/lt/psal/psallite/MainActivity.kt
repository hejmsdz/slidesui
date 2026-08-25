package lt.psal.psallite

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL_NAME = "lt.psal.psallite/filePicker"
        const val REQUEST_CODE = 54264
    }

    var source: File? = null
    var result: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
                .setMethodCallHandler { call, result ->
                    this.result = result
                    this.source = File(call.argument<String>("source")!!)
                    createDocument()
                }
    }

    private fun createDocument() {
        val fileName = source?.name
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.putExtra(Intent.EXTRA_TITLE, fileName)
        intent.type = "application/pdf"
        startActivityForResult(intent, REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, intent: Intent?) {
        super.onActivityResult(requestCode, resultCode, intent)

        if (requestCode == REQUEST_CODE) {
            when (resultCode) {
                Activity.RESULT_OK -> {
                    if (intent?.data != null) {
                        val destination = intent.data
                        moveFile(destination!!)
                    }
                }
                Activity.RESULT_CANCELED -> {
                    result?.success("")
                }
            }
        }
    }

    private fun moveFile(destination: Uri) {
        source?.inputStream().use { inStream ->
            contentResolver.openOutputStream(destination).use { outStream ->
                if (outStream != null) {
                    inStream?.copyTo(outStream)
                }
            }
        }
        source?.delete()
        result?.success("$destination")
    }
}
