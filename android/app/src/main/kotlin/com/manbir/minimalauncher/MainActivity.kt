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
import java.util.Date
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
                "getAppInstallTime" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val installTime = getAppInstallTime(packageName)
                        if (installTime != null) {
                            result.success(installTime) // Return the install time in milliseconds
                        } else {
                            result.error("NOT_FOUND", "Package not found", null)
                        }
                    } else {
                        result.error("MISSING_PACKAGE_NAME", "Package name not provided", null)
                    }
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
                "canLaunchApp" -> {
                    val packageName: String? = call.argument("packageName")
                    if (packageName != null) {
                        val canLaunch = canLaunchApp(packageName)
                        result.success(canLaunch)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
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
                "searchPlayStore" -> {
                    val query = call.argument<String>("query")
                    if (query != null) {
                        searchPlayStore(query)
                        result.success(null)
                    } else {
                        result.error("MISSING_ARGUMENT", "Query parameter is missing", null)
                    }
                }
                "searchDefaultBrowser" -> {
                    val query = call.argument<String>("query")
                    if (query != null) {
                        searchDefaultBrowser(query)
                        result.success(null)
                    } else {
                        result.error("MISSING_ARGUMENT", "Query parameter is missing", null)
                    }
                }
                "openApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        openApp(packageName)
                        result.success(null)
                    } else {
                        result.error("MISSING_PACKAGE_NAME", "Package name not provided", null)
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

    private fun openApp(packageName: String) {
        val packageManager: PackageManager = packageManager

        try {
            val intent: Intent? = packageManager.getLaunchIntentForPackage(packageName)

            if (intent != null) {
                // The app exists, so launch it
                startActivity(intent)
            } else {
                // The app is not installed, open the app page on the Play Store
                val playStoreIntent = Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("market://details?id=$packageName")
                )
                startActivity(playStoreIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
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

    private fun canLaunchApp(packageName: String): Boolean {
        val packageManager = packageManager
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        return intent != null
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

    private fun searchPlayStore(query: String) {
        try {
            val encodedQuery = Uri.encode(query)
            val uri = Uri.parse("https://play.google.com/store/search?q=$encodedQuery")
            val intent = Intent(Intent.ACTION_VIEW, uri)
            intent.setPackage("com.android.vending") // Package name of Google Play Store app
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            // Log an error
        }
    }

    private fun searchDefaultBrowser(query: String) {
        try {
            val uri = if (query.contains(".")) {
                // Treat it as a URL
                Uri.parse(if (query.startsWith("http")) query else "https://$query")
            } else {
                // Treat it as a search query
                val encodedQuery = Uri.encode(query)
                Uri.parse("https://www.google.com/search?q=$encodedQuery")
            }
    
            val intent = Intent(Intent.ACTION_VIEW, uri)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            // Log an error
        }
    }
    
    private fun getAppInstallTime(packageName: String): Long? {
        return try {
            val packageManager: PackageManager = packageManager
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            packageInfo.firstInstallTime
        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
            null
        }
    }    
}