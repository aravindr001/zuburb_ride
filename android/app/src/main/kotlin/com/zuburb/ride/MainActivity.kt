package com.zuburb.ride

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "zuburb/native_config"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"getMapsApiKey" -> {
						try {
							val appInfo = applicationContext.packageManager.getApplicationInfo(
								applicationContext.packageName,
								PackageManager.GET_META_DATA
							)
							val key = appInfo.metaData?.getString("com.google.android.geo.API_KEY")
							result.success(key)
						} catch (e: Exception) {
							result.success(null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}
}
