# golden-link

An agent skill for **sovereign photo backup** on a Mac: export one person's photos
from Apple Photos to *your own* Proton Drive, and seed an *on-device* face-recognition
model — with nothing sensitive ever leaving machines you control.

Hand this folder to a coding agent (Claude Code, or any agent that reads `AGENTS.md`)
and say *"set up sovereign photo backup"*. The agent loads [`SKILL.md`](SKILL.md),
installs the guardrails, and walks the steps. You can also just follow it yourself —
it's plain Markdown and shell.

## Why

Cloud photo services and cloud "AI photo" features mean handing your family's faces and
locations to someone else's model. This does the opposite: Apple Photos → your Proton
Drive via `rclone`, and any face recognition runs locally on Apple Silicon. No hosted
vision API, no third-party photo service.

## What's here

| File | Purpose |
|------|---------|
| [`SKILL.md`](SKILL.md) | The workflow an agent executes (7 steps + pre-flight). |
| [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) | **The guardrails.** Copy one into your project root so the agent inherits the data-safety rules. |
| [`REFERENCE.md`](REFERENCE.md) | Setup detail, pitfalls, and an always-on-box appendix. |
| [`scripts/export-local.sh`](scripts/export-local.sh) | Phase 1 — export photos already on disk → Proton. |
| [`scripts/export-missing.sh`](scripts/export-missing.sh) | Phase 2 — download iCloud-evicted originals, chunked + disk-guarded. |

## Quick start

```sh
brew install rclone
pipx install osxphotos
rclone config                      # add a "protondrive" remote
export PW_PHOTOS_PERSON="…"        # the exact Apple Photos person/face label
export PW_DEST="protondrive:PersonPhotos"
bash scripts/export-local.sh       # present photos
bash scripts/export-missing.sh     # evicted (iCloud-only) originals
```

Then verify: `rclone size "$PW_DEST"` against your local staged count. See
[`SKILL.md`](SKILL.md) for the full sequence and [`REFERENCE.md`](REFERENCE.md) for detail.

## ⚠️ Security & privacy — read before running

These are load-bearing, not boilerplate. Each one comes from a real failure mode:

- **Your photos are sensitive data.** Image bytes, EXIF, geotags, and the person's name
  must never be sent to a cloud model or hosted API. Local processing only.
- **`copy`, never `sync`.** `rclone copy` adds; `rclone sync` *deletes* remote files to
  match local. A stray `sync` can wipe your backup.
- **Don't trust one tool's "success."** Proton's API can return a `422` error on files
  that actually uploaded. Cross-check with `rclone size` and the Proton web UI before
  deleting or re-uploading anything.
- **Keep names out of logs and terminals.** Filenames and person labels are personal
  data — verify with counts (`wc -l`, `rclone size`), not by echoing paths.
- **Secrets live in the rclone config / keychain**, never in scripts or commits.
- **USB import needs an unlocked phone.** A locked phone exposes nothing over USB; an
  unattended import against a locked phone reads zero files and looks like a success.
- **Remote deletes need a human.** If an agent is driving this, deleting anything remote
  should stop and ask — never work around a denied delete.

## Requirements

Apple Silicon Mac · [`osxphotos`](https://github.com/RhetTbull/osxphotos) ·
[`rclone`](https://rclone.org) with a Proton Drive remote · a Proton Drive account.
Optional: [`pymobiledevice3`](https://github.com/doronz88/pymobiledevice3) for USB import;
InsightFace for the local face model.

## Status

The backup pipeline is real and in use. The local face-recognition step (Section 7 of
`SKILL.md`) is **forward-looking** — a documented starting point, not a finished pipeline.

## License

[MIT](LICENSE) © 2026 Crystallized Intelligence.
