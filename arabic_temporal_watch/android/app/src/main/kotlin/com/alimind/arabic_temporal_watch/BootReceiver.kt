package com.alimind.arabic_temporal_watch

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receives BOOT_COMPLETED and MY_PACKAGE_REPLACED broadcasts.
 *
 * The manifest declares this receiver so the OS can wake the app after a
 * reboot or an update. Prayer times are recomputed from the device clock and
 * location every time the Flutter side starts, so there is no persistent
 * alarm state to restore here yet — the receiver exists so the declaration in
 * AndroidManifest.xml resolves to a real class (a missing one throws
 * ClassNotFoundException at boot) and so that scheduling logic has a single
 * obvious home when adhan notifications are added.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.i(TAG, "Received ${intent.action}; prayer schedule will be " +
                    "rebuilt on next app launch.")
            }
            else -> Unit
        }
    }

    private companion object {
        const val TAG = "BootReceiver"
    }
}
