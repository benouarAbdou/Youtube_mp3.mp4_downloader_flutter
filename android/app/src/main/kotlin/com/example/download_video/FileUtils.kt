package com.example.download_video


import android.app.Activity
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import java.io.File

object FileUtils {

    fun requestPermission(context: Context) {
        ActivityCompat.requestPermissions(
            context as Activity, arrayOf(
                android.Manifest.permission.READ_EXTERNAL_STORAGE,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE,
                android.Manifest.permission.ACCESS_MEDIA_LOCATION
            ), 101
        );
    }

    fun checkPermissionForExternalStorage(context: Context): Boolean {
        return ActivityCompat.checkSelfPermission(
            context, android.Manifest.permission.WRITE_EXTERNAL_STORAGE

        ) === PackageManager.PERMISSION_GRANTED
    }

    fun saveBitmapToStorage(context: Context, bitmap: String): Uri? {
        var result: Uri? = null
        if (checkPermissionForExternalStorage(context)) {
            var filename: File? = null
            val outputStream: java.io.OutputStream?
            val DEFAULT_IMAGE_NAME: String = java.util.UUID.randomUUID().toString()
            try {

/*Check if the android version is equal or greater than Android 10*/
                if (Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                    val resolver: ContentResolver = context.getContentResolver()
                    val contentValues = ContentValues()
                    contentValues.put(MediaStore.Audio.Media.DISPLAY_NAME, DEFAULT_IMAGE_NAME)
                    contentValues.put(MediaStore.Audio.Media.TITLE, DEFAULT_IMAGE_NAME)
                    contentValues.put(
                        MediaStore.Audio.Media.MIME_TYPE,
                        getMIMEType(context, bitmap)
                    )
                    contentValues.put(MediaStore.Audio.Media.RELATIVE_PATH, "Music/" + "AppName")
                    val imageUri: Uri? =
                        resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, contentValues)
                    var file = File(bitmap);

                    outputStream = resolver.openOutputStream(imageUri!!)
                    val bytesArray: ByteArray = file.readBytes()

                    outputStream!!.write(bytesArray)
                    outputStream!!.flush()
                    result = imageUri
                    Log.d("FileUtils", bitmap);
                    SingleMediaScanner(context, file)
                } else {
                }
            } catch (e: java.lang.Exception) {
                Log.d("FileUtils", e.message!!);
                e.printStackTrace()
            }
        }
        return result
    }

    fun getMIMEType(con: Context, url: String?): String? {

        var mType: String? = null
        val mExtension = MimeTypeMap.getFileExtensionFromUrl(url)
        if (mExtension != null) {
            mType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(mExtension)
        }
        return mType
    }

}