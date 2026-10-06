# Architecture

## Responsibility split

The Raspberry Pi owns real-time physical I/O and lifecycle management. Cloud models provide speech recognition, reasoning and visual interpretation.

### Local Pi responsibilities

- continuous microphone process
- VAD and noise calibration
- WAV capture
- camera ownership
- frame buffering
- local motion detection
- OLED animation
- TTS process orchestration
- audio playback
- GPIO/motor boundary
- clean shutdown
- microphone-pipe draining

### Groq responsibilities

- Whisper STT
- GPT-OSS conversation/reasoning/tool selection
- Qwen visual perception

## End-to-end flow

```text
SPEECH
  |
  v
C270 microphone
  |
  v
arecord hw:1,0
  |
  v
adaptive VAD
  |
  v
speech WAV
  |
  v
whisper-large-v3-turbo
  |
  v
transcript + language
  |
  v
openai/gpt-oss-20b
  |
  +---- no visual context needed ----> final text
  |
  +---- visual context useful
            |
            v
      get_camera_view
            |
            v
       camera manager
            |
            v
       current JPEG
            |
            v
     qwen/qwen3.8-27b
            |
            v
       grounded facts
            |
            v
       GPT-OSS second pass
            |
            v
          final text
            |
            v
         Edge-TTS
            |
            v
          speaker
```

## Camera ownership rule

Exactly one long-lived component should open `/dev/video0`: `neurobrain_modules/camera.py`.

Vision requests consume a snapshot from the manager. They must not create a second `VideoCapture(0)` while the manager is running.

## Sensory tool philosophy

Camera access is a model-selected tool rather than a hard-coded phrase router. GPT-OSS may decide to look when a request implicitly depends on something physically visible, held, displayed, positioned, illuminated or occurring around the robot.

The main system prompt must also prohibit claims of physical sight unless the camera tool was actually called for the current request.

## Concurrency

Long network operations must not block consumption of the `arecord` stdout pipe. `groq_with_mic_drain()` therefore moves the blocking network operation to a worker thread while the main thread drains PCM data.

This architecture is intentional, not merely an optimization.

## Hardware action boundary

Language-model reasoning should not directly become unrestricted motor GPIO commands. The current motor API is deliberately inactive until a deterministic local action/safety layer is designed and physically tested.
