#!/usr/bin/env bash
set -Eeuo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SETUP_DIR")"

FORCE="${FORCE:-0}"
ARCHIVE_URLS_FILE="${ARCHIVE_URLS_FILE:-$SETUP_DIR/archive-urls.txt}"
ARCHIVE_DIR="${ARCHIVE_DIR:-$ROOT_DIR/get}"
LOG_DIR="${ARCHIVE_LOG_DIR:-$SETUP_DIR/logs}"
SUCCESS_LOG="${ARCHIVE_SUCCESS_LOG:-$LOG_DIR/archives-success.log}"
MISSING_LOG="${ARCHIVE_MISSING_LOG:-$LOG_DIR/archives-missing.log}"
ARCHIVE_DOWNLOAD_JOBS="${ARCHIVE_DOWNLOAD_JOBS:-10}"
ARCHIVE_DOWNLOAD_LIMIT="${ARCHIVE_DOWNLOAD_LIMIT:-}"

usage() {
  cat <<'USAGE'
Usage: _setup/getArchives.sh [--force]

Options:
  -f, --force   Re-download existing archives and replace them on success.
  -h, --help    Show this help.

Environment:
  ARCHIVE_DOWNLOAD_JOBS   Parallel downloads per batch. Defaults to 10.
  ARCHIVE_DOWNLOAD_LIMIT  Optional maximum number of URLs to process.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -f|--force)
      FORCE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! [[ "$ARCHIVE_DOWNLOAD_JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "ARCHIVE_DOWNLOAD_JOBS must be a positive integer." >&2
  exit 2
fi

if [ -n "$ARCHIVE_DOWNLOAD_LIMIT" ] && ! [[ "$ARCHIVE_DOWNLOAD_LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ARCHIVE_DOWNLOAD_LIMIT must be a non-negative integer." >&2
  exit 2
fi

if [ ! -f "$ARCHIVE_URLS_FILE" ]; then
  echo "Missing archive URL index: $ARCHIVE_URLS_FILE" >&2
  exit 1
fi

mkdir -p "$ARCHIVE_DIR" "$LOG_DIR"
: > "$SUCCESS_LOG"
: > "$MISSING_LOG"

is_force_enabled() {
  case "$FORCE" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
  esac

  return 1
}

archive_name_from_url() {
  local url="$1"
  local clean="${url%%\?*}"
  local name

  clean="${clean%%#*}"
  name="${clean##*/}"
  name="${name%.tgz}"

  if [ -z "$name" ] || [ "$name" = "$clean" ]; then
    return 1
  fi

  printf '%s.tgz\n' "$name"
}

download_archive() {
  local original_url="$1"
  local archive_name
  local target
  local rel
  local tmp

  if ! archive_name="$(archive_name_from_url "$original_url")"; then
    printf 'invalid\t%s\n' "$original_url" >> "$MISSING_LOG"
    return 0
  fi

  target="$ARCHIVE_DIR/$archive_name"
  rel="${target#$ROOT_DIR/}"

  if [ -s "$target" ] && ! is_force_enabled; then
    printf 'present\t%s\t%s\n' "$rel" "$original_url" >> "$SUCCESS_LOG"
    return 0
  fi

  tmp="$(mktemp "${target}.tmp.XXXXXX")"

  if curl -fsSL --retry 2 --retry-delay 2 -o "$tmp" "$original_url"; then
    if [ -s "$tmp" ]; then
      mv "$tmp" "$target"
      printf 'downloaded\t%s\t%s\n' "$rel" "$original_url" >> "$SUCCESS_LOG"
      return 0
    fi

    printf 'empty\t%s\t%s\n' "$rel" "$original_url" >> "$MISSING_LOG"
  else
    printf 'missing\t%s\t%s\n' "$rel" "$original_url" >> "$MISSING_LOG"
  fi

  rm -f "$tmp"
  return 0
}

wait_for_batch() {
  local pid
  local status=0

  for pid in "${BATCH_PIDS[@]}"; do
    if ! wait "$pid"; then
      status=1
    fi
  done

  BATCH_PIDS=()
  BATCH_SIZE=0

  return "$status"
}

BATCH_PIDS=()
BATCH_SIZE=0
QUEUED=0
FAILED_BATCH=0

while IFS= read -r url || [ -n "$url" ]; do
  case "$url" in
    ''|\#*)
      continue
      ;;
  esac

  if [ -n "$ARCHIVE_DOWNLOAD_LIMIT" ] && [ "$QUEUED" -ge "$ARCHIVE_DOWNLOAD_LIMIT" ]; then
    break
  fi

  download_archive "$url" &
  BATCH_PIDS+=("$!")
  BATCH_SIZE=$((BATCH_SIZE + 1))
  QUEUED=$((QUEUED + 1))

  if [ "$BATCH_SIZE" -ge "$ARCHIVE_DOWNLOAD_JOBS" ]; then
    if ! wait_for_batch; then
      FAILED_BATCH=1
    fi
  fi
done < "$ARCHIVE_URLS_FILE"

if [ "$BATCH_SIZE" -gt 0 ]; then
  if ! wait_for_batch; then
    FAILED_BATCH=1
  fi
fi

SUCCESS_COUNT="$(wc -l < "$SUCCESS_LOG" | tr -d '[:space:]')"
MISSING_COUNT="$(wc -l < "$MISSING_LOG" | tr -d '[:space:]')"

echo "Done. Archive directory: ${ARCHIVE_DIR#$ROOT_DIR/}"
echo "Queued URLs: $QUEUED"
echo "Success log: ${SUCCESS_LOG#$ROOT_DIR/} ($SUCCESS_COUNT entries)"
echo "Missing log: ${MISSING_LOG#$ROOT_DIR/} ($MISSING_COUNT entries)"

exit "$FAILED_BATCH"
