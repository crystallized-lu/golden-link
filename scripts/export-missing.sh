#!/bin/bash
# Phase 2 — download EVICTED (iCloud-only) photos of one person, export copies + XMP,
# and COPY them to Proton. Chunked by year with a disk-guard so a large download cannot
# fill the disk. Copy-only and non-destructive.
#
# Why separate from phase 1: osxphotos refuses --export-as-hardlink together with
# --download-missing. Phase 1 hardlinks what is on disk; phase 2 downloads the rest.
#
# Env:
#   PW_PHOTOS_PERSON  (required)  exact Apple Photos person/face label. Kept out of stdout.
#   PW_DEST           (optional)  rclone remote:folder. Default: protondrive:PersonPhotos
#   PW_HOME           (optional)  working dir. Default: $HOME
#   MIN_FREE_G        (optional)  abort a chunk if free GiB would start below this. Default: 6
#   YEARS             (optional)  space-separated years to process. Default: auto-detect
#                                 (the years that actually have evicted photos).
set -u

cd "${PW_HOME:-$HOME}" || exit 1

PERSON="${PW_PHOTOS_PERSON:-}"
[ -z "$PERSON" ] && { echo "set PW_PHOTOS_PERSON (the person/face label)"; exit 1; }

DEST="${PW_DEST:-protondrive:PersonPhotos}"
LOG="$HOME/Library/Logs/sovereign-photos-p2.log"
DONE="$HOME/sovereign-photos-p2.done"
RC="$(command -v rclone)"
OSXPHOTOS="${OSXPHOTOS:-$(command -v osxphotos)}"
MIN_FREE_G="${MIN_FREE_G:-6}"

rm -f "$DONE"
echo "[$(date)] PHASE2 start" > "$LOG"

# Which years have evicted photos? Compute once (one library load). Years are numeric,
# so plain word-splitting is safe and no personal data is emitted.
if [ -n "${YEARS:-}" ]; then
  YEAR_LIST="$YEARS"
else
  YEAR_LIST="$("$OSXPHOTOS" query --person "$PERSON" --missing \
      --field yr "{created.year}" 2>/dev/null | grep -E '^[0-9]{4}$' | sort -u | tr '\n' ' ')"
fi
echo "[$(date)] years to process: $YEAR_LIST" >> "$LOG"

total_up=0
for Y in $YEAR_LIST; do
  FREE=$(df -g "$HOME" | tail -1 | awk '{print $4}')
  echo "[$(date)] year=$Y free=${FREE}GiB" >> "$LOG"
  if [ "$FREE" -lt "$MIN_FREE_G" ]; then
    echo "[$(date)] ABORT: free ${FREE}GiB < ${MIN_FREE_G}GiB before year $Y" >> "$LOG"
    echo "phase2 ABORTED_LOW_DISK year=$Y free=${FREE}" > "$DONE"; exit 1
  fi

  STAGE="$HOME/Pictures/sovereign-p2-$Y"
  rm -rf "$STAGE"; mkdir -p "$STAGE"

  # --download-missing pulls evicted originals from iCloud. NO --export-as-hardlink.
  "$OSXPHOTOS" export "$STAGE" --person "$PERSON" --year "$Y" --missing \
    --download-missing --update \
    --directory "{created.year}/{created.mm}" --skip-original-if-edited \
    --sidecar xmp --person-keyword >> "$LOG" 2>&1
  EXPRC=$?

  N=$(find "$STAGE" -type f ! -name '*.xmp' ! -name '.*' | wc -l | tr -d ' ')
  echo "[$(date)] year=$Y export_exit=$EXPRC media=$N" >> "$LOG"

  if [ "$N" -gt 0 ]; then
    # copy = additive; never sync.
    "$RC" copy "$STAGE" "$DEST" --protondrive-replace-existing-draft=true \
      --retries 5 --low-level-retries 10 --transfers 2 --update >> "$LOG" 2>&1
    echo "[$(date)] year=$Y copy_exit=$?" >> "$LOG"
    total_up=$((total_up + N))
  fi

  rm -rf "$STAGE"   # reclaim staging before the next chunk
done

echo "[$(date)] PHASE2 DONE uploaded=$total_up remote=$("$RC" size "$DEST" 2>/dev/null | tr '\n' ' ')" >> "$LOG"
echo "phase2 uploaded=$total_up" > "$DONE"
