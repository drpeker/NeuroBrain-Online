# Audio Pipeline

## Capture

Known microphone:

```text
ALSA device: hw:1,0
format: S16_LE
rate: 16000 Hz
channels: 1
```

The runtime keeps `arecord` alive and reads exact 20 ms PCM chunks.

Known robust chunk-read pattern:

```python
data = proc.stdout.read(BYTES - 0)
while len(data) < BYTES:
    more = proc.stdout.read(BYTES - len(data))
    if not more:
        break
    data += more
if len(data) != BYTES:
    continue
```

Do not replace this casually with a single read and assume the requested byte count always arrives.

## VAD

Known-good values are recorded in `CURRENT_STATE.md`.

The design uses:

1. microphone AGC warmup
2. room-noise calibration
3. speech start thresholds requiring repeated hits
4. prebuffer so initial phonemes are retained
5. silence duration to terminate utterance
6. slow noise-floor adaptation while silent

## Self-hearing prevention

While the robot generates and plays its own TTS, microphone PCM is drained/discarded. After playback there is a short acoustic-tail interval (~0.12 s) before normal listening resumes.

## ALSA overrun prevention

A blocking Groq request cannot be allowed to leave the `arecord` stdout pipe unread.

Known solution:

```text
Groq call
   |
worker thread ------> network
   |
main thread --------> continuously drains microphone pipe
```

Implemented by `groq_with_mic_drain()`.

This was physically verified to eliminate the observed `overrun!!!` during long vision operations.
