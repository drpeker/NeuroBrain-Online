# Camera and Vision

## Camera manager

Module: `neurobrain_modules/camera.py`.

Public API includes:

```text
camera_start()
capture_image(filename="/tmp/neurobrain_camera.jpg")
get_latest_frame()
camera_stop()
```

The manager continuously owns the C270 camera, stores the latest frame and performs local motion analysis.

## OLED motion path

```text
camera frame
   |
local motion analysis
   |
(x,y target)
   |
set_motion(...)
   |
OLED eyes
```

This path is local and does not consume cloud vision tokens.

## AI camera tool

Tool name:

```text
get_camera_view
```

GPT-OSS receives the tool with automatic tool selection. The user does not need to say an explicit camera keyword.

If GPT requests vision:

1. parse tool arguments, including its visual question
2. call local `get_camera_view(question)`
3. capture the current managed frame
4. base64 encode the JPEG
5. send it to `qwen/qwen3.8-27b`
6. return concise grounded visual facts as tool output
7. call GPT-OSS again with the tool result and `tool_choice="none"`
8. speak the final answer

## Grounding rule

GPT-OSS must not claim to see the current physical environment unless the camera tool was actually invoked for that request.

Qwen Vision must not invent unsupported objects or details.

## Known limitation

The latest frame can be blurred if the subject or camera is moving.

Planned improvement:

```text
vision requested
  |
sample 3-5 local frames
  |
Laplacian variance sharpness score
  |
select sharpest
  |
send ONE JPEG to Qwen
```

This improves input quality without continuously streaming frames or multiplying cloud-image calls.
