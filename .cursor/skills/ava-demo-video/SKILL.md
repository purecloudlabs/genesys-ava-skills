---
name: ava-demo-video
description: >
  Create polished demo videos for Genesys AI Virtual Assistants using a script,
  live AI Studio Preview capture, branded intro/exit narration, result-evidence
  cards, and ffmpeg assembly. Use when the user asks to build, record, stitch,
  revise, narrate, or brand an AVA demo video, especially when final output
  should include real AI Studio Preview visuals.
compatibility: ava-harness
metadata:
  version: 1.1.0
  author: Genesys Cloud Services, Inc.
license: MIT. See root LICENSE file.
---

# AVA Demo Video

Use this skill to turn an AVA demo script into a finished MP4 with accurate branding, narrated bookends, real AI Studio Preview visuals, and a clear business-result wrapup.

## Quick Start

1. Read the relevant project handoff/TODO file first, then read the requested demo script or kit README.
2. Identify the AVA, org, scenario, start context, caller lines, target runtime, branding source URL, and intro/exit narration goal.
3. If the user has not already specified the visual source, offer these options before rendering:
   - **Live AI Studio Preview**: authenticated Genesys UI capture; best for product-accurate demos.
   - **Generated walkthrough**: scripted product visuals; fastest first pass.
   - **Hybrid**: branded/generated intro and outro around live Preview for the conversation.
4. Capture actual AI Studio Preview visuals whenever the user chooses live or hybrid, or when they need product-accurate screens.
5. Before recording, explicitly verify the target capture source with a still frame and confirm it shows the AVA, not Cursor, chat, terminal output, or another window.
6. Let the user handle MFA/passkeys and, for voice demos, prefer user-spoken caller audio while the agent records only.
7. After the live take, trim requested or observed dead air, script and narrate the branded intro/exit cards, extract any conversation-result evidence, assemble with `ffmpeg`, verify with `ffprobe` and review frames, write a manifest, and update the project handoff with the final output path.

## Live Preview Option Gate

Before generating any non-live demo video, pause and make the source choice explicit unless the user already did.

Recommended wording:

```text
I can make this three ways:
1. Live AI Studio Preview recording using your authenticated Genesys session.
2. Generated walkthrough from the script and kit artifacts.
3. Hybrid: branded/generated intro and outro around live Preview recording.

For final customer-facing demos I recommend option 3 when we can access the Preview session.
```

If the user asks for "actual AVA", "AI Studio", "Preview", "real visuals", "live demo", or references a prior live capture, default to live or hybrid and proceed to authentication/setup instead of rendering generated visuals first.

## Recommended Output Path

Use a local working directory outside committed kit content:

```text
.tmp-<kit-or-agent>-real-capture/
  screenshots/
  recordings/
  recordings/audio/
  recordings/title-cards/
  recordings/branding/
```

Name final files descriptively:

```text
recordings/<kit>-complete-demo-real-preview-v<N>-<short-change-summary>.mp4
```

## Workflow

### 1. Plan The Video

- Use the script timestamps as intent, not as rigid automation timings.
- Preserve actual AVA behavior over perfect narration timing.
- Keep the final review loop incremental: `v1`, `v2`, `v3`, etc.
- Track what changed in each version in the project handoff.
- Script the intro and exit narration before final assembly. Silent bookends are incomplete unless the user explicitly asks for silence.

### 2. Capture AI Studio Preview

- Reuse an authenticated browser session; do not close or reset it unless the user asks.
- For Genesys MFA/passkey flows, have the user complete authentication manually.
- Use Genesys Cloud MCP or repository deployment metadata to find the org, region, agent ID, version, and start context when available.
- Use Playwright/CDP only to inspect, screenshot, or record the existing session.
- Never guess the display or window target. Before every live take, enumerate capture sources when needed, capture a one-frame still from the intended source, inspect it, and state the exact source index and crop/filter that will be used.
- If the still frame shows Cursor, the chat UI, terminal output, or any non-AVA window, mark that source as rejected and do not start the take.
- For voice-mode demos, fixed `say` timing for caller turns is brittle. Prefer:
  - Agent starts recorder only.
  - User speaks caller lines naturally after each AVA response.
  - Agent stops and verifies the MP4 when the user says to stop.
- Keep a teleprompter list of caller lines in chat while recording.
- Stop `ffmpeg` with an interrupt/quit path so the MP4 finalizes cleanly. If the output has `moov atom not found`, mark the take invalid and do not use it.
- After the take, capture at least one representative frame from the MP4 to verify the recording still shows the AVA window. If it captured Cursor or another screen, mark the take unusable and retake with explicit source verification.

### 3. Branding And Narration

For branded title cards:

- Fetch the brand site HTML/CSS with a browser-like user agent if headless Chrome is blocked.
- Extract CSS tokens, logo SVGs, fonts, hero images, button shapes, and header structure.
- Use the actual wordmark/logo asset when available.
- Avoid invented marks or palettes once a brand site is provided.
- If TTS mispronounces a word, rewrite the narration to avoid the ambiguous word rather than fighting phonetics.
- If local `ffmpeg` lacks `drawtext` or SVG conversion is unavailable, render branded cards as local HTML/CSS screenshots with Playwright, then convert the PNGs into video segments with `ffmpeg`.
- Always inspect final card screenshots before assembly. Watch for clipped text near the bottom of the 16:9 frame.
- Intro and exit cards must have scripted narration and an audio track unless the user explicitly asks for silent cards.
- Keep bookend narration concise. It should frame what the viewer is about to see, then summarize the result after the live demo without re-speaking the manual caller lines.

### 4. Assembly

Common segment structure:

1. Branded intro title card with narration.
2. Short actual-UI bridge or montage, if needed.
3. Live AI Studio Preview recording.
4. Branded exit card with narration and result summary.

For live-take polishing:

1. Probe source duration with `ffprobe`.
2. Calculate the live segment duration as `source_duration - start_trim_seconds - end_trim_seconds`.
3. Re-encode the trimmed live segment rather than stream-copying when cutting at non-keyframe boundaries.
4. Normalize every segment to `1920x1080`, `30 fps`, `yuv420p`, and AAC audio at `48000 Hz`.
5. Concatenate with a filter graph rather than assuming codecs/timebases match.
6. Write a JSON manifest with source, trims, segment durations, narration text/audio paths, result metadata, output path, and final `ffprobe` data.

### 5. Conversation Result Evidence

When the demo proves routing, classification, or state persistence:

- Extract the final `OutputVariables`, relevant `ToolData`, matched intent IDs, schema IDs, conversation IDs, record IDs, and routing summary from the successful run.
- Keep result cards concise and presenter-friendly: show the domain/category, human-readable intent names, and final routing outcome.
- Include technical identifiers in the manifest or handoff notes, not as the primary on-screen story unless the user asks.
- If the live run had data-action failures, record the exact cause and fix in the project handoff before using the take as final.
- The wrapup narration should explicitly describe the successful extraction, persistence, and routing result shown on the card.

### 6. Quality Gates

Use `ffprobe` to verify every source segment:

```bash
ffprobe -v error -show_entries format=duration,size -of json path/to/video.mp4
```

Use `ffmpeg` to normalize segments to:

- `1920x1080`
- `30 fps`
- `yuv420p`
- AAC audio at `48000 Hz`

Then concatenate with a filter graph rather than assuming codecs/timebases match.

Before closing:

- Inspect representative frames from the intro, live segment, and exit.
- Verify the final MP4 has both video and audio streams for the full duration.
- Confirm intro and exit narration are present unless silence was requested.
- Update the project handoff with output path, runtime/size, review frame paths, manifest path, narration scripts, and pending review notes.

## Lessons Learned

- Do not automate caller voice with fixed delays unless there is no alternative; it can trigger no-input escalation or talk over the AVA.
- If the user can hear the AVA, manual caller timing usually produces the best recording.
- Keep the bridge between branded intro and live Preview short; the user will notice even 2-3 seconds of dead air.
- Use actual brand assets from the target demo site, not generic colors or invented logos.
- Keep all credentials out of files, logs, and generated artifacts.
- AVFoundation screen indexes can change or be counterintuitive on macOS. Enumerate, capture stills, inspect, and state the exact source before recording.
- Some AI Studio Preview start-context values may include platform prefixes such as `co` on conversation IDs. Validate the expected schema, record ID, and conversation ID format before recording a final take, and patch Data Actions to normalize prefixes when appropriate.
- For trimmed live takes, preserve actual AVA behavior and use intro/exit cards to explain the business result rather than trying to overlay too much on the product UI.
- A polished demo with silent intro/exit title cards is incomplete by default. Script and render narration for the bookends even when the live AVA interaction itself depends on manual caller timing.

## Reference

For reusable checklists and command patterns, see [reference.md](reference.md).
