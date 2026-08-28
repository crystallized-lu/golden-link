# Guardrails — Sovereign Photos

You are helping set up private photo backup. The photos are **sensitive personal
data**. These rules override convenience. If a step seems to require breaking one,
STOP and ask the human.

## Data sovereignty
- Image bytes, EXIF, geotags, and the person's name are **sensitive (Tier S)**: they
  must NEVER be sent to a cloud model, API, or third-party service — **including me**.
  All processing (export, dedup, face recognition) runs **locally**, or moves only
  between the user's own devices and the user's own Proton Drive.
- Face recognition uses an **on-device** model (e.g. InsightFace on Apple Silicon).
  Never call a hosted vision/face API.

## Don't destroy data
- **Copy, never sync.** `rclone copy` is additive; `rclone sync` deletes remote files to
  match local. Only ever `copy` here.
- Deleting anything remote, dropping files, or rewriting history needs the human's
  explicit go-ahead **in this session**. If a delete is denied, do not work around it.

## Don't leak personal data
- Never print the person's name, name-bearing filenames, geotags, or file contents to
  stdout, logs, or chat. Verify with **counts and opaque checks** (`wc -l`, `rclone size`),
  never by echoing paths.
- Logs must contain no personal data.

## Secrets
- Proton credentials live in the rclone config / OS keychain. Never put secrets in
  scripts, commits, or chat. Read them from the environment.

## Verify honestly
- Don't trust one tool's success signal. Proton's API can return a 422 on files that
  actually uploaded — cross-check with `rclone size` and the user's own view before
  declaring success or retrying anything.
- Report what you **verified** (ran it) vs **assumed** (didn't). "Should work" is not done.
