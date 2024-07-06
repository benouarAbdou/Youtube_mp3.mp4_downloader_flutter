package com.example.download_video


import android.content.Context
import androidx.annotation.NonNull
import com.example.download_video.FileUtils.requestPermission
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    // This name should be same which we defined in flutter
    private val CHANNEL ="com.example.androidstorage.android_12_flutter_storage/storage"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
           // This is the function
            if (call.method == "saveFile") {
                val hashMap = call.arguments as HashMap<*,*> //Get the arguments as a HashMap
                val path = hashMap["path"]
                FileUtils.saveBitmapToStorage(this@MainActivity as Context,path.toString())
            } else if (call.method == "requestStoragePermission") {
                requestPermission(this@MainActivity as Context)
            } else {
                result.notImplemented()
            }
        }
    }

}
