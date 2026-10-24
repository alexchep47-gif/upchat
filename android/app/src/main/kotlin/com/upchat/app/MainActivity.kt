package com.upchat.app

import android.bluetooth.BluetoothAdapter
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "upchat/device"
    private val requestEnableBluetoothCode = 4101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bluetoothState" -> result.success(bluetoothState())
                    "requestEnableBluetooth" -> {
                        try {
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            if (adapter == null) {
                                result.success(false)
                            } else if (adapter.isEnabled) {
                                result.success(true)
                            } else {
                                startActivityForResult(
                                    Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
                                    requestEnableBluetoothCode,
                                )
                                result.success(true)
                            }
                        } catch (securityError: SecurityException) {
                            result.error("BLUETOOTH_PERMISSION", securityError.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun bluetoothState(): String {
        return try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            when {
                adapter == null -> "unavailable"
                adapter.isEnabled -> "enabled"
                else -> "disabled"
            }
        } catch (_: SecurityException) {
            "unknown"
        }
    }
}
