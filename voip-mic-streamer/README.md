# VoIP Mic Streamer (Android, Kotlin)

A minimal app to capture microphone audio in real-time and stream via UDP to a server, with auto VoIP detection and speaker routing for "external playback capture" during third-party calls.

## Features
- Foreground service, Android 9+ (minSdk 28)
- Auto-detect voice communication playback and route to speaker (Android 12+ `setCommunicationDevice` fallback to legacy)
- `AudioRecord` (VOICE_RECOGNITION), AEC/NS/AGC if available
- UDP streaming with tiny header (magic, timestamp, sequence)
- Simple UI to set host/port and start/stop

## Build
- Open `voip-mic-streamer` in Android Studio (Giraffe+), let it generate/update Gradle wrapper if needed
- Run on device; grant microphone permission and ignore battery optimization

## Server
```
python3 server/udp_server.py
```
It writes raw PCM16 mono 16 kHz to `capture.wav` and prints bitrate.

## Notes
- This captures the microphone. For third-party VoIP (e.g., WeChat), the app will attempt to auto route audio to speaker; you will primarily record via air path. Bluetooth HFP calls cannot be captured; the app will try to re-route but may require user action.
- Replace UDP+PCM with Opus/QUIC later if needed.