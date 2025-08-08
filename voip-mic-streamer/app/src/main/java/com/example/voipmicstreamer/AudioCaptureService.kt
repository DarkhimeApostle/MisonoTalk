package com.example.voipmicstreamer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.*
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

class AudioCaptureService : Service() {

    companion object {
        const val ACTION_START = "com.example.voipmicstreamer.action.START"
        const val ACTION_STOP = "com.example.voipmicstreamer.action.STOP"
        const val EXTRA_HOST = "extra_host"
        const val EXTRA_PORT = "extra_port"
        private const val NOTIFY_ID = 1001
        private const val CHANNEL_ID = "streamer"
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var recordingJob: Job? = null
    private var udpSender: DatagramSocket? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private val isVoipActive = AtomicBoolean(false)

    private val playbackCallback = object : AudioManager.AudioPlaybackCallback() {
        override fun onPlaybackConfigChanged(configs: MutableList<AudioPlaybackConfiguration>?) {
            val active = configs?.any { it.isActive && it.audioAttributes.usage == AudioAttributes.USAGE_VOICE_COMMUNICATION } == true
            isVoipActive.set(active)
            if (active) {
                routeToSpeaker()
            }
            updateNotification(active)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFY_ID, buildNotification("Idle"))
        (getSystemService(Context.POWER_SERVICE) as PowerManager).let {
            wakeLock = it.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "vms:wakelock").apply { setReferenceCounted(false) }
        }
        (getSystemService(Context.AUDIO_SERVICE) as AudioManager).registerAudioPlaybackCallback(playbackCallback, null)
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRecording()
        (getSystemService(Context.AUDIO_SERVICE) as AudioManager).unregisterAudioPlaybackCallback(playbackCallback)
        releaseWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val host = intent.getStringExtra(EXTRA_HOST) ?: return START_NOT_STICKY
                val port = intent.getIntExtra(EXTRA_PORT, 5002)
                startRecording(host, port)
            }
            ACTION_STOP -> stopRecording()
        }
        return START_STICKY
    }

    private fun startRecording(host: String, port: Int) {
        if (recordingJob?.isActive == true) return
        acquireWakeLock()
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        routeToSpeaker()

        val sampleRate = 16000
        val frameMs = 20
        val frameSamples = sampleRate * frameMs / 1000 // 320 samples
        val frameBytes = frameSamples * 2 // mono 16-bit
        val minBuf = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val bufSize = maxOf(minBuf, frameBytes * 4)

        val recorder = AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                    .build()
            ).setBufferSizeInBytes(bufSize)
            .build()

        tryEnableEffects(recorder.audioSessionId)

        val inet = InetAddress.getByName(host)
        val socket = DatagramSocket()
        udpSender = socket

        recorder.startRecording()
        updateNotification(true)

        recordingJob = serviceScope.launch {
            val header = ByteBuffer.allocate(12)
            var seq: Long = 0
            val pcm = ByteArray(frameBytes)
            val packetBuf = ByteArray(12 + frameBytes)
            while (isActive) {
                val read = recorder.read(pcm, 0, pcm.size)
                if (read <= 0) continue
                header.clear()
                header.putInt(0x564D5301.toInt()) // 'VMS\x01'
                header.putInt((System.currentTimeMillis() % Int.MAX_VALUE).toInt())
                header.putInt((seq++ % Int.MAX_VALUE).toInt())
                System.arraycopy(header.array(), 0, packetBuf, 0, 12)
                System.arraycopy(pcm, 0, packetBuf, 12, read)
                val packet = DatagramPacket(packetBuf, 0, 12 + read, inet, port)
                try { socket.send(packet) } catch (_: Exception) { }
            }
            try { recorder.stop() } catch (_: Exception) { }
            recorder.release()
            socket.close()
        }
    }

    private fun stopRecording() {
        recordingJob?.cancel()
        recordingJob = null
        udpSender?.close()
        udpSender = null
        updateNotification(false)
        releaseWakeLock()
    }

    private fun tryEnableEffects(sessionId: Int) {
        try { AcousticEchoCanceler.create(sessionId)?.apply { enabled = true } } catch (_: Throwable) {}
        try { NoiseSuppressor.create(sessionId)?.apply { enabled = true } } catch (_: Throwable) {}
        try { AutomaticGainControl.create(sessionId)?.apply { enabled = true } } catch (_: Throwable) {}
    }

    private fun routeToSpeaker() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= 31) {
            val spk = am.availableCommunicationDevices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            if (spk != null) am.setCommunicationDevice(spk) else fallbackLegacySpeaker()
        } else fallbackLegacySpeaker()
    }

    private fun fallbackLegacySpeaker() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        @Suppress("DEPRECATION") am.mode = AudioManager.MODE_IN_COMMUNICATION
        @Suppress("DEPRECATION") am.isSpeakerphoneOn = true
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld != true) wakeLock?.acquire(60 * 60 * 1000L /*1h max*/)
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
    }

    private fun createNotificationChannel() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            val ch = NotificationChannel(CHANNEL_ID, "Streaming", NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(status: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle("Mic streaming")
            .setContentText(status)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(active: Boolean) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val text = if (active) "Streaming (voip=${isVoipActive.get()})" else "Idle"
        nm.notify(NOTIFY_ID, buildNotification(text))
    }
}