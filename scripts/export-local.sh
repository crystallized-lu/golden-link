#!/bin/bash
# Phase 1 — export the photos of ONE person that are already on disk, with XMP
# sidecars, and COPY (never sync) them to your own Proton Drive.
# Copy-only and non-destructive. Requires: osxphotos, rclone (Proton remote configured).
#
# Env:
#   PW_PHOTOS_PERSON  (required)  exact Apple Photos person/face label. Kept out of stdout.
#   PW_DEST           (optional)  rclone remote:folder. Default: protondrive:PersonPhotos
#   PW_HOME           (optional)  working dir holding your .env, if you use one. Default: $HOME
set -u

cd "${PW_HOME:-$HOME}" || exit 1

PERSON="${PW_PHOTOS_PERSON:-}"
[ -z "$PERSON" ] && { echo "set PW_PHOTOS_PERSON (the person/face label)"; exit 1; }

DEST="${PW_DEST:-protondrive:PersonPhotos}"
STAGE="$HOME/Pictures/sovereign-staging"
LOG="$HOME/Library/Logs/sovereign-photos-p1.log"
DONE="$HOME/sovereign-photos-p1.done"
RC="$(command -v rclone)"
OSXPHOTOS="${OSXPHOTOS:-$(command -v osxphotos)}"

rm -f "$DONE"; rm -rf "$STAGE"; mkdir -p "$STAGE"
echo "[$(date)] PHASE1 local export start" > "$LOG"

# --export-as-hardlink keeps this cheap for photos ALREADY on disk (no byte copy).
# NOTE: hardlink mode is INCOMPATIBLE with --download-missing (evicted photos) -> phase 2.
# --person-keyword bakes the person label into the XMP sidecar (seeds local face recognition later).
"$OSXPHOTOS" export "$STAGE" --person "$PERSON" --update --export-as-hardlink \
  --directory "{created.year}/{created.mm}" --skip-original-if-edited \
  --sidecar xmp --person-keyword >> "$LOG" 2>&1
EXPRC=$?

# Count files WITHOUT echoing any filename (a filename can contain the person's name).
PHOTOS=$(find "$STAGE" -type f ! -name '*.xmp' ! -name '.*' | wc -l | tr -d ' ')
echo "[$(date)] export exit=$EXPRC photos=$PHOTOS" >> "$LOG"

if [ "$PHOTOS" -gt 0 ]; then
  # copy = additive. NEVER 'sync' here: sync deletes remote files to match local.
  "$RC" copy "$STAGE" "$DEST" --protondrive-replace-existing-draft=true \
    --retries 3 --low-level-retries 10 --transfers 4 >> "$LOG" 2>&1
  CPRC=$?
  echo "[$(date)] copy exit=$CPRC remote=$("$RC" size "$DEST" 2>/dev/null | tr '\n' ' ')" >> "$LOG"
  echo "phase1 export_exit=$EXPRC photos=$PHOTOS copy_exit=$CPRC" > "$DONE"
else
  echo "phase1 export_exit=$EXPRC photos=0 NO_SYNC" > "$DONE"
fi
echo "[$(date)] PHASE1 DONE" >> "$LOG"
