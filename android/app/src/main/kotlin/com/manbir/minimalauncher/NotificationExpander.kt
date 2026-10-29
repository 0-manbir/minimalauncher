package com.manbir.minimalauncher

import android.content.Context
import android.os.Build
import android.content.Intent
import android.util.Log
import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method

class NotificationExpander(private val context: Context) {

    private val TAG = "NotificationExpander"

    fun expand() {
        try {
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.N) {
                // For Android versions up to Nougat (7.0)
                context.sendBroadcast(Intent("android.intent.action.DOWNLOAD_NOTIFICATION_CLICKED"))
            } else {
                // For Android versions Oreo (8.0) and above
                val service = context.getSystemService(Context.STATUS_BAR_SERVICE)
                val statusBarManager = Class.forName("android.app.StatusBarManager")
                val methodName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    "expandNotificationsPanel"
                } else {
                    "expand"
                }
                val expandMethod: Method = statusBarManager.getMethod(methodName)
                expandMethod.invoke(service)
            }
        } catch (e: InvocationTargetException) {
            // Unwrap the InvocationTargetException to get the underlying exception
            val underlyingException = e.targetException
            Log.e(TAG, "Error while expanding notification panel", underlyingException)
            // Handle exception appropriately for your application
        } catch (e: Exception) {
            // Log an error message for other exceptions
            Log.e(TAG, "Error while expanding notification panel", e)
            // Handle exception appropriately for your application
        }
    }
}
