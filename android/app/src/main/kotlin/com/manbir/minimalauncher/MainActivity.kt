package com.manbir.minimalauncher

import android.app.Application
import android.app.NotificationManager
import android.app.SearchManager
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode.transparent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.LayerDrawable
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    
    private val TAG = "MainChannel"
    private val CHANNEL = "main_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        intent.putExtra("background_mode", transparent.toString())
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Request the WRITE_SETTINGS permission for Android 6.0 and higher
            if (!Settings.System.canWrite(applicationContext)) {
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivityForResult(intent, 200)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "expandNotis" -> {
                    NotificationExpander(this).expand()
                    result.success(null)
                }
                "changeLauncher" -> {
                    changeLauncher()
                    result.success(null)
                }
                "getAppIconPath" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val appIconPath = getAppIconPath(packageName)
                        result.success(appIconPath)
                    } else {
                        result.error("MISSING_PACKAGE_NAME", "Package name not provided", null)
                    }
                }
                "searchGoogle" -> {
                    val query = call.argument<String>("query")
                    if (query != null) {
                        searchGoogle(query)
                        result.success(null)
                    } else {
                        result.error("MISSING_ARGUMENT", "Query parameter is missing", null)
                    }
                }
                "showClock" -> {
                    val packageManager = applicationContext.packageManager
                    val alarmClockIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)

                    // Known Clock apps on different manufacturers
                    val clockImpls = arrayOf(
                        arrayOf("HTC Alarm Clock", "com.htc.android.worldclock", "com.htc.android.worldclock.WorldClockTabControl"),
                        arrayOf("Standard Alarm Clock", "com.android.deskclock", "com.android.deskclock.AlarmClock"),
                        arrayOf("Froyo Nexus Alarm Clock", "com.google.android.deskclock", "com.android.deskclock.DeskClock"),
                        arrayOf("Moto Blur Alarm Clock", "com.motorola.blur.alarmclock", "com.motorola.blur.alarmclock.AlarmClock"),
                        arrayOf("Samsung Galaxy Clock", "com.sec.android.app.clockpackage", "com.sec.android.app.clockpackage.ClockPackage"),
                        arrayOf("Sony Xperia Z", "com.sonyericsson.organizer", "com.sonyericsson.organizer.Organizer_WorldClock"),
                        arrayOf("ASUS Tablets", "com.asus.deskclock", "com.asus.deskclock.DeskClock")
                    )

                    var foundClockImpl = false

                    // Try to find a working clock implementation
                    for (clockImpl in clockImpls) {
                        val packageName = clockImpl[1]
                        val className = clockImpl[2]
                        try {
                            val cn = ComponentName(packageName, className)
                            packageManager.getActivityInfo(cn, PackageManager.GET_META_DATA)
                            alarmClockIntent.component = cn
                            foundClockImpl = true
                            break
                        } catch (e: PackageManager.NameNotFoundException) {
                            // Clock app not found, try the next
                        }
                    }

                    if (foundClockImpl) {
                        try {
                            startActivity(alarmClockIntent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Could not open the clock app.", null)
                        }
                    } else {
                        result.error("UNAVAILABLE", "Clock app not found", null)
                    }
                }
                else -> {
                    result.notImplemented()
                    Log.d(TAG, "Error: No method found for ${call.method}!")
                }
            }
        }
    }

    private fun changeLauncher() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val intent = Intent(Settings.ACTION_HOME_SETTINGS)
            startActivity(intent)
        } else {
            val intent = Intent(Settings.ACTION_SETTINGS)
            startActivity(intent)
        }
    }

    private fun searchGoogle(query: String) {
        try {
            val intent = Intent(Intent.ACTION_WEB_SEARCH)
            intent.putExtra(SearchManager.QUERY, query)
            intent.setPackage("com.google.android.googlequicksearchbox")
            startActivity(intent)
        } catch (e: Exception) {
            // Log an error
        }
    }

    // Method to get the app icon path
    private fun getAppIconPath(packageName: String): String? {
        return try {
            val packageManager: PackageManager = packageManager
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            val appIcon = appInfo.loadIcon(packageManager)

            return when (appIcon) {
                is BitmapDrawable -> saveBitmapToFile(appIcon.bitmap, packageName)
                is AdaptiveIconDrawable -> {
                    val width = appIcon.intrinsicWidth
                    val height = appIcon.intrinsicHeight

                    // Create a bitmap with an alpha channel
                    val resultBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(resultBitmap)

                    // Draw the adaptive icon on the transparent bitmap
                    appIcon.setBounds(0, 0, canvas.width, canvas.height)
                    appIcon.draw(canvas)

                    saveBitmapToFile(resultBitmap, packageName)
                }
                else -> {
                    // Handle other types of drawables as needed
                    null
                }
            }
        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun saveBitmapToFile(bitmap: Bitmap, packageName: String): String? {
        try {
            val iconFile = File(cacheDir, "icon_" + packageName + ".png")
            FileOutputStream(iconFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 80, out)
            }
            return iconFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
}