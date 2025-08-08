package com.example.voipmicstreamer

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.provider.Settings
import android.widget.Button
import android.widget.EditText
import android.widget.Switch
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    private lateinit var inputHost: EditText
    private lateinit var inputPort: EditText
    private lateinit var toggleStart: Switch
    private lateinit var btnBattery: Button
    private lateinit var statusText: TextView

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { _ ->
            // no-op
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        inputHost = findViewById(R.id.input_host)
        inputPort = findViewById(R.id.input_port)
        toggleStart = findViewById(R.id.toggle_start)
        btnBattery = findViewById(R.id.btn_battery)
        statusText = findViewById(R.id.status_text)

        val prefs = getSharedPreferences("stream", Context.MODE_PRIVATE)
        inputHost.setText(prefs.getString("host", "10.0.2.2"))
        inputPort.setText(prefs.getInt("port", 5002).toString())

        requestNeededPermissions()

        toggleStart.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) startStreaming() else stopStreaming()
        }

        btnBattery.setOnClickListener {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:" + packageName)
                startActivity(intent)
            } catch (_: Exception) { }
        }
    }

    private fun requestNeededPermissions() {
        val perms = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= 33) perms.add(Manifest.permission.POST_NOTIFICATIONS)
        val need = perms.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (need.isNotEmpty()) permissionLauncher.launch(need.toTypedArray())
    }

    private fun startStreaming() {
        val host = inputHost.text.toString().trim()
        val port = inputPort.text.toString().toIntOrNull() ?: 5002
        val prefs = getSharedPreferences("stream", Context.MODE_PRIVATE)
        prefs.edit().putString("host", host).putInt("port", port).apply()

        val intent = Intent(this, AudioCaptureService::class.java).apply {
            action = AudioCaptureService.ACTION_START
            putExtra(AudioCaptureService.EXTRA_HOST, host)
            putExtra(AudioCaptureService.EXTRA_PORT, port)
        }
        ContextCompat.startForegroundService(this, intent)
        statusText.text = "Streaming → $host:$port"
    }

    private fun stopStreaming() {
        val intent = Intent(this, AudioCaptureService::class.java).apply { action = AudioCaptureService.ACTION_STOP }
        startService(intent)
        statusText.text = "Stopped"
    }
}