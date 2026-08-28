---
name: sovereign-photos
description: Set up sovereign (fully self-hosted, no-cloud-AI) photo backup and a local face-recognition seed on a Mac. Exports one person's photos from Apple Photos to the user's own Proton Drive via rclone, handles iCloud-evicted originals safely, and seeds a LOCAL face model. Use when a user wants to back up or organise personal/family photos privately, mirror Apple Photos to Proton Drive, keep photos out of cloud AI, run osxphotos/rclone/pymobiledevice3, or build local (on-device) face recognition.
---

# Sovereign Photos

Back up one person's photos from Apple Photos to the user's OWN Proton Drive, and
seed an on-device face-recognition model — with nothing sensitive ever leaving
machines the user controls.

## Before anything: install the guardrails

Copy `CLAUDE.md` and `AGENTS.md` from this skill into the target project root
(`CLAUDE.md` for Claude Code; `AGENTS.md` for other agents). They are not optional —
they encode the data-safety rules every step below assumes. **Read them now.**

## Pre-flight checklist

- [ ] Guardrails installed (above) and read.
- [ ] Confirmed with the user this is THEIR data on THEIR accounts.
- [ ] Apple Silicon Mac; `osxphotos` + `rclone` installed
      (`brew install rclone`, `pipx install osxphotos`).
- [ ] `rclone config` has a Proton Drive remote (REFERENCE.md → "rclone → Proton").
- [ ] `PW_PHOTOS_PERSON` = the exact Apple Photos person/face label. Never echo it.
- [ ] Chosen `PW_DEST` (e.g. `protondrive:PersonPhotos`).

## Workflow

1. **rclone → Proton.** Configure/verify the remote; test with `rclone lsd <remote>:`.
   Rule: `copy`, **never** `sync`. See REFERENCE.md.
2. **Export photos already on disk.** Run `scripts/export-local.sh` — hardlink export +
   XMP sidecars, `rclone copy` to Proton. Cheap: no byte-copy for present photos.
3. **Export iCloud-evicted originals.** Run `scripts/export-missing.sh` — chunked by
   year with a disk-guard, `--download-missing`. Hardlink and download-missing are
   INCOMPATIBLE, which is why this is a separate phase. See REFERENCE.md.
4. **Verify.** Compare the local staged count to `rclone size <dest>`. Don't trust a
   single tool's "success" — Proton can report a false 422 on files that actually
   landed. Cross-check before retrying anything, especially a delete.
5. **(Optional) Import from iPhone over USB.** `pymobiledevice3` reads the camera roll
   ONLY when the phone is unlocked and trusts the Mac. See REFERENCE.md.
6. **(Optional) Run on phone-connect.** A `launchd` agent so the Mac imports only when
   the phone appears. See REFERENCE.md.
7. **Seed local face recognition.** `--person-keyword` already baked Apple's person
   labels into the XMP sidecars; feed those + the images to a LOCAL InsightFace model
   on the M1. Forward-looking — a starting point, not a finished pipeline. See REFERENCE.md.

## Scripts

- `scripts/export-local.sh` — phase 1 (present photos). Env: `PW_PHOTOS_PERSON`, `PW_DEST`.
- `scripts/export-missing.sh` — phase 2 (evicted). Env: adds `MIN_FREE_G`, optional `YEARS`.

Both are copy-only and non-destructive, and write a `*.done` marker plus a log under
`~/Library/Logs/`. For long runs, launch with `nohup … &` and poll the log.

## Detail & pitfalls

See [REFERENCE.md](REFERENCE.md) — rclone/Proton setup, the hardlink/download-missing
trap, USB import, launchd, the local face model, and an appendix for offloading to an
always-on box (SSH + NetBird).
