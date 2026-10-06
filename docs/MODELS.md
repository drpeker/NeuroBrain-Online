# Models and AI Services

## Provider

Current online AI provider: **Groq / GroqCloud**.

The secret is supplied through the environment:

```bash
export GROQ_API_KEY="..."
```

Never place the actual key in Git.

## Speech-to-text

```text
whisper-large-v3-turbo
```

Responsibilities:

- speech transcription
- automatic language detection

## Main brain

```text
openai/gpt-oss-20b
```

Known settings:

```text
temperature = 0.6
max_completion_tokens = 200
reasoning_effort = low
include_reasoning = false
```

Responsibilities:

- conversation
- reasoning
- same-language replies
- silent correction of obvious minor STT errors from context
- deciding whether the camera is useful
- tool invocation
- integrating visual facts into the final response

## Vision specialist

```text
qwen/qwen3.8-27b
```

Known settings:

```text
temperature = 0.2
max_completion_tokens = 300
reasoning_effort = none
```

Vision should describe only information supported by the current image and state uncertainty instead of inventing details.

## TTS

Current active system: Edge-TTS.

```text
Turkish voice: tr-TR-EmelNeural
English voice: en-US-JennyNeural
```

Known executable:

```text
/home/drpeker/oledtest/bin/edge-tts
```

Legacy Piper constants/models may remain in historical source but are not the active TTS path of this baseline.

## Local models are not part of the active online chain

Historical local GGUF models on the former SD card included Qwen and Phi variants, but the current online runtime does not depend on them. In particular, `qwen/qwen3.8-27b` is a Groq cloud vision model, not a model stored on the Pi.
