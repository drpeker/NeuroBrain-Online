# Design Decisions

## Separate online repository

The online Groq-backed robot is maintained as `NeuroBrain-Online` rather than being folded into the older offline/experimental `NeuroBrain` repository. This prevents incompatible architectures and recovery instructions from becoming mixed.

## Live runtime separate from Git working tree

The robot runs from `/home/drpeker/neurobrain.py` and `/home/drpeker/neurobrain_modules`, while Git lives under `/home/drpeker/projects/NeuroBrain-Online`. This makes accidental Git operations less likely to destroy a physically working state.

## Local hardware, cloud cognition

Time-sensitive hardware ownership remains local. Cloud services provide STT, reasoning and vision rather than owning continuous camera/audio streams.

## Model-selected camera tool

The main model decides whether current visual information is useful. This is more general than a list of phrases such as "look" or "camera" and permits implicit visual references.

## One camera owner

A single continuous camera manager avoids device contention and simultaneously supports local OLED motion tracking and on-demand AI snapshots.

## GPT main model + Qwen specialist

GPT-OSS remains the conversational/reasoning authority. Qwen Vision returns visual observations to GPT rather than replacing the main conversational model.

## No hallucinated physical sight

Current environmental claims require an actual camera-tool result for the current request.

## Microphone draining is architectural

Continuous `arecord` plus blocking network calls produced ALSA overruns. The solution is to keep consuming PCM while the network request runs in a worker thread. This behavior must survive refactoring.

## Edge-TTS is the active voice path

Historical Piper-related material may remain for experimentation, but Edge-TTS with Emel/Jenny is the known current online voice configuration.

## Automatic language handling

Whisper language detection drives Turkish/English response behavior. An isolated misclassification should not trigger replacement with a brittle keyword router.

## Motor API before motor activation

The interface exists before physical actuation. This allows future reasoning/action architecture to be designed while keeping current hardware safe.

## Recovery before refactoring

A documented, restorable working robot is more valuable than source cleanup. Preserve a checkpoint before major architectural changes.
