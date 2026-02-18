#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/Sources/MacPiano/Resources/Samples/acoustic_grand_piano"
API_URL="https://api.github.com/repos/gleitz/midi-js-soundfonts/contents/FluidR3_GM/acoustic_grand_piano-mp3?per_page=200"
RAW_BASE="https://raw.githubusercontent.com/gleitz/midi-js-soundfonts/master/FluidR3_GM/acoustic_grand_piano-mp3"

mkdir -p "$OUT_DIR"

TMP_JSON="$(mktemp)"
TMP_LIST="$(mktemp)"
trap 'rm -f "$TMP_JSON" "$TMP_LIST"' EXIT

echo "Fetching sample index..."
curl -fsSL "$API_URL" -o "$TMP_JSON"

if command -v rg >/dev/null 2>&1; then
  rg -o '"name":\s*"[^"]+\.mp3"' "$TMP_JSON" | sed -E 's/.*"([^"]+)"/\1/' | sort -u > "$TMP_LIST"
else
  grep -oE '"name":[[:space:]]*"[^"]+\.mp3"' "$TMP_JSON" | sed -E 's/.*"([^"]+)"/\1/' | sort -u > "$TMP_LIST"
fi

TOTAL="$(wc -l < "$TMP_LIST" | tr -d ' ')"
if [ "${TOTAL}" = "0" ]; then
  echo "No sample files discovered from $API_URL"
  exit 1
fi

DOWNLOADED=0
SKIPPED=0
FAILED=0

while IFS= read -r FILE_NAME; do
  DEST="$OUT_DIR/$FILE_NAME"
  if [ -s "$DEST" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if curl -fLsS --retry 3 --retry-delay 1 "$RAW_BASE/$FILE_NAME" -o "$DEST"; then
    DOWNLOADED=$((DOWNLOADED + 1))
    echo "Downloaded: $FILE_NAME"
  else
    FAILED=$((FAILED + 1))
    echo "Failed: $FILE_NAME"
  fi
done < "$TMP_LIST"

echo
echo "Sample sync complete."
echo "Total listed: $TOTAL"
echo "Downloaded : $DOWNLOADED"
echo "Skipped    : $SKIPPED"
echo "Failed     : $FAILED"
echo "Output dir : $OUT_DIR"

if [ "$FAILED" -gt 0 ]; then
  exit 2
fi
