package com.example.on_beat

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTimestamp
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

class AudioHitDetector(channel: EventChannel) : EventChannel.StreamHandler {

    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        const val SAMPLE_RATE = 16000
        const val THRESHOLD = 0.15f   // amplitude [0-1], tune via test page
        const val COOLDOWN_MS = 150L
    }

    init {
        channel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startRecording()
    }

    override fun onCancel(arguments: Any?) {
        stopRecording()
        eventSink = null
    }

    private fun startRecording() {
        val minBytes = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        // Use 2× min buffer: small enough for low latency, large enough to be stable.
        val bufferBytes = minBytes * 2

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferBytes,
        )

        val record = audioRecord ?: return
        record.startRecording()

        var lastHitMs = 0L
        var totalFrames = 0L
        val bufferSamples = bufferBytes / 2   // 16-bit = 2 bytes per sample
        val buffer = ShortArray(bufferSamples)
        val audioTimestamp = AudioTimestamp()

        recordingThread = Thread {
            while (record.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                val read = record.read(buffer, 0, bufferSamples)
                if (read <= 0) continue

                // Monotonic nanosecond time right after the blocking read returns.
                val bufferEndNs = System.nanoTime()
                totalFrames += read

                // Find peak amplitude and onset index in this buffer.
                var peak = 0f
                var onsetIndex = -1
                for (i in 0 until read) {
                    val amp = buffer[i].toFloat() / Short.MAX_VALUE.toFloat()
                    val absAmp = if (amp < 0) -amp else amp
                    if (absAmp > peak) peak = absAmp
                    if (onsetIndex < 0 && absAmp > THRESHOLD) onsetIndex = i
                }

                if (peak <= THRESHOLD || onsetIndex < 0) continue

                // Calculate onset time using AudioTimestamp for hardware precision.
                // Falls back to simple back-calculation from bufferEndNs if unavailable.
                val onsetNs: Long
                val gotTimestamp = record.getTimestamp(
                    audioTimestamp, AudioTimestamp.TIMEBASE_MONOTONIC
                )
                if (gotTimestamp == AudioRecord.SUCCESS) {
                    val onsetFrame = totalFrames - read + onsetIndex
                    onsetNs = audioTimestamp.nanoTime +
                            (onsetFrame - audioTimestamp.framePosition) *
                            1_000_000_000L / SAMPLE_RATE
                } else {
                    // Fallback: back-calculate from buffer end time.
                    val framesAfterOnset = (read - onsetIndex).toLong()
                    onsetNs = bufferEndNs - framesAfterOnset * 1_000_000_000L / SAMPLE_RATE
                }

                // Convert monotonic ns → wall-clock ms (matches Dart's DateTime.now()).
                val onsetWallMs = System.currentTimeMillis() -
                        (System.nanoTime() - onsetNs) / 1_000_000L

                if (onsetWallMs - lastHitMs > COOLDOWN_MS) {
                    lastHitMs = onsetWallMs
                    val magnitude = peak.toDouble()
                    // EventSink must be called on the main thread.
                    mainHandler.post {
                        eventSink?.success(listOf(onsetWallMs.toDouble(), magnitude))
                    }
                }
            }
        }.also { it.isDaemon = true; it.start() }
    }

    private fun stopRecording() {
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        recordingThread?.join(500)
        recordingThread = null
    }
}
