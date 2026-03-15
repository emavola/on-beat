package com.example.on_beat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val audioHitChannel = "com.example.on_beat/audio_hit"
    private var audioHitDetector: AudioHitDetector? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, audioHitChannel)
        audioHitDetector = AudioHitDetector(channel)
    }
}
