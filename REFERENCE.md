# Sovereign Photos — Reference

Detail and pitfalls behind the SKILL.md workflow. Read the guardrails
(`CLAUDE.md` / `AGENTS.md`) first — this file assumes them.

## The one idea

Personal photos are sensitive data. The whole pipeline is built so that the images,
their metadata, and the person's name only ever exist on machines the user controls:
the Mac, and the user's own Proton Drive. No cloud AI, no hosted face API, no
third-party photo service. Everything below serves that constraint.

---

## 1. rclone → Proton

Install and configure once:

```
brew install rclone
rclone config        # n) new remote → type: "protondrive" → your Proton login
rclone lsd protondrive:        # verify: lists your Proton Drive folders
```

- Proton credentials are stored in rclone's config (`~/.config/rclone/rclone.conf`) or
  the OS keychain. Treat that file as a secret; never commit it.
- 2FA: rclone will prompt; follow the protondrive backend docs for app-specific setup.
- **`copy`, never `sync`.** `rclone copy SRC DEST` only adds/updates. `rclone sync` makes
  DEST match SRC — it **deletes** remote files that are not in SRC. There is no reason to
  sync here, and a stray sync can wipe the backup.

### The Proton 422 false-negative

Proton's Drive API occasionally returns `422` ("file already exists" then "revision not
found") on a file that, in fact, uploaded correctly. rclone reports the copy as failed.
**Do not trust the failure blindly**: check `rclone size protondrive:<folder>` and the
Proton web UI. If the file is there, it is done — do not "fix" it by deleting and
re-uploading. This is the single most important verify-before-acting lesson in this skill.

---

## 2 & 3. Export from Apple Photos — and the hardlink trap

Two phases, because of one osxphotos constraint:

- **`--export-as-hardlink`** makes export nearly free for photos already on disk: it
  links to the existing file instead of copying bytes.
- **`--download-missing`** fetches originals that iCloud has evicted from local storage.
- **osxphotos refuses the two together.** Trying to combine them fails at argument
  parsing. So: phase 1 hardlinks what is present; phase 2 downloads the evicted rest.

Run them:

```
export PW_PHOTOS_PERSON="…"          # exact Apple Photos person label; keep it out of stdout
export PW_DEST="protondrive:PersonPhotos"
bash scripts/export-local.sh          # phase 1
bash scripts/export-missing.sh        # phase 2
```

Long runs (phase 2 downloads over the network) — launch detached and poll:

```
nohup bash scripts/export-missing.sh >/dev/null 2>&1 &
tail -f ~/Library/Logs/sovereign-photos-p2.log
```

### Why phase 2 is chunked with a disk-guard

`--download-missing` pulls evicted originals **into the Photos library**, and macOS does
not re-evict them afterwards — so the library grows by the full download size and stays
grown. On a machine with little free space that can fill the disk. `export-missing.sh`
therefore:

- processes **one year at a time**, staging to its own temp dir and deleting it after
  upload, so staging never holds more than one year at once;
- checks free space before each year and **aborts cleanly** if it would start below
  `MIN_FREE_G` (default 6 GiB).

Estimate the total first: `rclone size` is no help here (nothing uploaded yet), so expect
roughly the count of evicted photos × your average file size, and make sure the disk has
headroom for it plus the largest single year.

---

## 4. Verify

```
# local staged count (no filenames printed):
find "$HOME/Pictures/sovereign-staging" -type f ! -name '*.xmp' ! -name '.*' | wc -l
# remote:
rclone size protondrive:PersonPhotos
```

Compare. A small mismatch is usually the 422 false-negative above — confirm in the
Proton UI before doing anything. Never delete-and-retry on a single tool's say-so.

---

## 5. Import from an iPhone over USB (optional)

To pull the current camera roll straight off the phone (bypassing iCloud):

```
pipx install pymobiledevice3
# phone plugged in, UNLOCKED, and "Trust This Computer" accepted:
pymobiledevice3 afc ls /DCIM        # lists camera roll folders
```

Hard constraint: **the phone must be unlocked and trusting the Mac.** A locked phone
(e.g. sitting on the desk overnight) exposes nothing over USB. Do not schedule an
unattended import expecting a locked phone to work — it will read zero files and look
like a success.

---

## 6. Run on phone-connect (optional)

Instead of a timer, trigger the import only when the phone actually appears, using a
`launchd` agent that watches for the device. Sketch:

```
# ~/Library/LaunchAgents/lu.example.photo-import.plist
# ProgramArguments: /bin/bash /path/to/your-import.sh
# WatchPaths: /var/run/usbmuxd    (touched when an iOS device connects)
```

`launchctl load` it. The agent fires your import script on connect; the script should
itself check the phone is unlocked (step 5) and exit quietly if not.

---

## 7. Seed a local face-recognition model

The exports already carry the groundwork: `--person-keyword` wrote Apple's own person
labels into each XMP sidecar. That is a free, hand-verified training set.

Forward-looking approach (a starting point, not a finished pipeline):

1. Read the person keyword from each XMP sidecar → (image, label) pairs.
2. Run a **local** face embedder — e.g. InsightFace (`buffalo_l`) on Apple Silicon — to
   embed each labelled face. No hosted API.
3. Store embeddings locally (a vector index, or just a numpy array + labels).
4. For new photos, embed and nearest-neighbour against the enrolled set.

Everything runs on-device. The point of harvesting Apple's labels is to skip manual
tagging while never sending a face to anyone else's model.

---

## Appendix — offload to an always-on box

The single-Mac path above is the recommended default. If you want the pipeline to run
unattended on a dedicated always-on Mac ("the box"), the only additions are:

- **Reach it privately.** Put the box and your laptop on a private mesh (this project
  uses **NetBird**; Tailscale is equivalent). Drive the box over SSH on its mesh IP —
  don't expose SSH to the public internet.
- **Pin the host key.** On first connect, record the box's SSH host key and pin it
  (`~/.ssh/known_hosts` / `StrictHostKeyChecking accept-new` then verify), so a spoofed
  box can't silently intercept the session.
- **Post-quantum SSH.** Newer OpenSSH warns when a session isn't using a post-quantum key
  exchange ("store now, decrypt later"). For sensitive data, upgrade OpenSSH on both ends
  so the mesh SSH session negotiates a PQ KEX.
- **Secrets stay on the box.** The box keeps its own rclone config and its own `.env`;
  the laptop never carries the Proton credentials just to drive a remote job.
- **Disk.** An always-on box is often storage-constrained — the phase-2 disk-guard matters
  more here, not less.

Everything else (the two scripts, the guardrails) is identical; you are only changing
*where* they run.
