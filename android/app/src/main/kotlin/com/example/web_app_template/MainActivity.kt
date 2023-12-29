package com.example.web_app_template

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugins.GeneratedPluginRegistrant
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity() : FlutterActivity() {
    private val CHANNEL = "intent"
    private val METHOD_GET_APP_URL = "getAppUrl"
    private val METHOD_GET_MARKET_URL = "getMarketUrl"
    private val GOOGLE_STORE_PREVIOS_URL = "https://play.google.com/store/apps/details?id="

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if(call.method == METHOD_GET_APP_URL) {
                val intent = Intent.parseUri(call.argument("url"), Intent.URI_INTENT_SCHEME)

                result.success(intent.dataString)
            }
            if(call.method == METHOD_GET_MARKET_URL) {
                val intent = Intent.parseUri(call.argument("url"), Intent.URI_INTENT_SCHEME)

                result.success(GOOGLE_STORE_PREVIOS_URL + intent.`package`)
            }
        }
    }
}
