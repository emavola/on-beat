package com.example.on_beat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val audioHitChannel = "com.example.on_beat/audio_hit"
    private val audioConfigChannel = "com.example.on_beat/audio_config"
    private var audioHitDetector: AudioHitDetector? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, audioHitChannel)
        audioHitDetector = AudioHitDetector(eventChannel)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioConfigChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "setThreshold") {
                    val value = call.argument<Double>("threshold")
                    if (value != null) {
                        audioHitDetector?.setThreshold(value.toFloat())
                        result.success(null)
                    } else {
                        result.error("INVALID_ARG", "threshold missing", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
