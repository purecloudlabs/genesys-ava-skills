# AVA Demo Video Reference

## Discovery Checklist

Collect these before recording:

- Kit path and demo script path.
- AVA name, version, org, and direct AI Studio Preview URL.
- Scenario persona, account/contact identifiers, and required start context.
- Caller lines and expected AVA responses.
- Branding source URL and any required logo/product naming rules.
- Intro and exit narration scripts.
- Target runtime and final format.
- Whether visuals must be real AI Studio Preview or may be generated/mocked.

## Visual Source Options

Always offer these when the user has not already chosen a source:

- **Live AI Studio Preview**: use authenticated Genesys UI capture. Best for customer-facing proof, requires login/MFA and a working Preview session.
- **Generated walkthrough**: render scripted visuals from kit artifacts. Fastest for storyboard review, not product-accurate UI evidence.
- **Hybrid**: generated intro/outro and explanatory cards around live AI Studio Preview. Best default for polished final demos.

If the user asks for AI Studio Preview or real AVA visuals, skip generated-only rendering and move directly to live or hybrid setup.

## Recording Checklist

Before recording:

- Confirm the user is logged into the correct Genesys org.
- Confirm AI Studio Preview is reset to the correct mode.
- Confirm AVA audio is audible to the recorder.
- Keep the browser open and avoid resetting authenticated Chrome profiles.
- Show the user the caller-line teleprompter.
- Enumerate AVFoundation devices and capture a still from the intended screen source before starting a live take.
- Inspect the still frame and reject the source if it shows Cursor, chat, terminal output, or any non-AVA window.
- State the exact selected `<screen-device>:<audio-device>` and crop/filter before recording.

During recording:

- Start screen/audio recording.
- Let the user speak each caller turn after the AVA finishes.
- Avoid automated caller speech unless the user asks for a fully automated pass.
- Stop when the user says `stop recording`.

After recording:

- Run `ffprobe` for duration and size.
- Play or inspect the output enough to confirm it contains video and audio.
- Extract a representative frame from the live recording and confirm it still shows AI Studio Preview.
- Stop and mark the take invalid if the MP4 is corrupt, has no audio, or captured the wrong window.
- Trim obvious dead air before final assembly.

## Browser Automation Pattern

Use Playwright against an existing Chrome remote-debugging session when MFA is involved:

```javascript
import { chromium } from "playwright";

const browser = await chromium.connectOverCDP("http://127.0.0.1:9222");
const context = browser.contexts()[0];
const page = context.pages().find((candidate) =>
  candidate.url().includes("/admin/ai-studio/")
) ?? context.pages()[0];

await page.bringToFront();
await page.screenshot({ path: "screenshots/preview.png", fullPage: true });
```

If locators fail in AI Studio Preview, inspect frames and shadow roots, then fall back to stable coordinate clicks only for screenshots or one-off captures.

## macOS Recording Pattern

Inspect AVFoundation devices:

```bash
ffmpeg -f avfoundation -list_devices true -i ""
```

Capture a one-frame source verification still:

```bash
ffmpeg -y \
  -f avfoundation -framerate 30 -i "<screen-device>:<audio-device>" \
  -frames:v 1 \
  "screenshots/source-probe.png"
```

Record screen and selected audio input:

```bash
ffmpeg -y \
  -f avfoundation -framerate 30 -i "<screen-device>:<audio-device>" \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
  -r 30 -pix_fmt yuv420p -c:v libx264 -preset veryfast -crf 23 \
  -c:a aac -ar 48000 -b:a 160k \
  "recordings/live-preview-take1.mp4"
```

Exact AVFoundation device indexes vary by machine. Recheck every session.

Stop the recording with an interrupt or `q` so MP4 metadata is written cleanly. If `ffprobe` reports `moov atom not found`, the take is not usable.

## Live Take Polishing

Compute the trim duration from source duration and requested trims:

```text
live_segment_seconds = source_duration_seconds - start_trim_seconds - end_trim_seconds
```

Trim and re-encode the live take:

```bash
ffmpeg -y \
  -ss 18 -i recordings/live-preview-take.mp4 -t 60.318 \
  -vf "setsar=1,format=yuv420p" \
  -r 30 -c:v libx264 -preset veryfast -crf 20 \
  -c:a aac -b:a 160k -ar 48000 -ac 1 \
  recordings/live-preview-take-trimmed.mp4
```

Use re-encoding for precise non-keyframe cuts and for consistent concat inputs.

Extract representative review frames:

```bash
ffmpeg -y -ss 30 -i recordings/final.mp4 -frames:v 1 -update 1 screenshots/review-live.png
ffmpeg -y -ss 71 -i recordings/final.mp4 -frames:v 1 -update 1 screenshots/review-exit.png
```

Write a small JSON manifest beside the final MP4 containing source path, trims, card paths, narration text/audio paths, result metadata, output path, duration, and size.

## Bookend Narration

Intro and exit cards should be narrated by default, even when the caller lines in the live Preview section are manually spoken by the user. Treat silent bookend cards as incomplete unless the user explicitly asks for silent title cards.

Keep the scripts short:

```text
Intro: Genesys AI Studio Preview. This demo shows <AVA name> detecting <capability> in a live conversation, then routing with context.
Exit: Result captured. The assistant classified <result>, persisted <state>, and escalated or routed with context.
```

Generate local narration audio before building the title-card video:

```bash
say -r 170 -o recordings/audio/intro-narration.aiff "Genesys AI Studio Preview. This demo shows the AVA detecting more than one customer need in a single turn."
say -r 170 -o recordings/audio/exit-narration.aiff "Result captured. The assistant classified both intents, persisted the context, and routed the call."
```

Probe the generated audio and set card duration to the narration length plus a short pad, typically `0.5s` to `0.8s`.

## Segment Normalization

Normalize each clip before concatenation:

```bash
ffmpeg -y -i input.mp4 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30,format=yuv420p" \
  -c:v libx264 -preset veryfast -crf 20 \
  -c:a aac -ar 48000 -b:a 160k \
  output-normalized.mp4
```

Generate narrated still-card video from a PNG:

```bash
ffmpeg -y -loop 1 -i card.png -i recordings/audio/intro-narration.aiff \
  -vf "scale=1920:1080,fps=30,format=yuv420p" \
  -af "apad" -t 11.8 \
  -c:v libx264 -preset veryfast -crf 18 \
  -c:a aac -ar 48000 -b:a 160k -shortest card.mp4
```

Use `anullsrc` only when the user explicitly requests a silent card or when creating a non-narrated spacer.

If `ffmpeg` lacks `drawtext` or local SVG conversion tools, render title cards as local HTML/CSS with Playwright:

```javascript
import { readFileSync } from "node:fs";
import { chromium } from "playwright";

const logoSvg = readFileSync("branding/genesys-logo-white.svg", "utf8");
const browser = await chromium.launch({ channel: "chrome" });
const page = await browser.newPage({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 1,
});

await page.setContent(`<!doctype html><style>body{margin:0;width:1920px;height:1080px}</style>${logoSvg}`);
await page.screenshot({ path: "recordings/title-cards/intro.png" });
await browser.close();
```

## Concatenation Pattern

Prefer filter concat:

```bash
ffmpeg -y \
  -i intro.mp4 -i montage.mp4 -i live-preview.mp4 -i outro.mp4 \
  -filter_complex "[0:v][0:a][1:v][1:a][2:v][2:a][3:v][3:a]concat=n=4:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
  -c:a aac -ar 48000 -b:a 160k \
  recordings/final.mp4
```

## Quality Gates

Final checks:

- Branding matches the official source site or known brand assets.
- Intro and exit are narrated unless silence was explicitly requested.
- Intro-to-live bridge has no obvious dead air.
- AVA and caller do not talk over each other.
- AVA voice is audible in the final MP4.
- Narration avoids known mispronunciations.
- Final card appears before or as the closing narration finishes.
- Output path, duration, size, review frames, manifest, narration scripts, and pending review notes are in the project handoff.
