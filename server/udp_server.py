#!/usr/bin/env python3
import socket, struct, time, wave, sys

HOST = '0.0.0.0'
PORT = 5002
OUT_WAV = 'capture.wav'
SAMPLE_RATE = 16000

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((HOST, PORT))

print(f"Listening on {HOST}:{PORT}")

wf = wave.open(OUT_WAV, 'wb')
wf.setnchannels(1)
wf.setsampwidth(2)
wf.setframerate(SAMPLE_RATE)

last_seq = None
recv_bytes = 0
start = time.time()
try:
    while True:
        data, addr = sock.recvfrom(12000)
        if len(data) < 12:
            continue
        magic, ts, seq = struct.unpack('!III', data[:12])
        if magic != 0x564D5301:
            continue
        pcm = data[12:]
        wf.writeframes(pcm)
        recv_bytes += len(pcm)
        if last_seq is not None and (seq - last_seq) != 1:
            print(f"seq jump: {last_seq}->{seq}")
        last_seq = seq
        if time.time() - start > 5:
            kbps = recv_bytes * 8 / 1000 / (time.time() - start)
            print(f"rate: {kbps:.1f} kbps")
            recv_bytes = 0
            start = time.time()
except KeyboardInterrupt:
    pass
finally:
    wf.close()
    sock.close()
    print('Saved to', OUT_WAV)