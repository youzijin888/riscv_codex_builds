#!/usr/bin/env bash
set -u -o pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <v8-version> [jobs]" >&2
  echo "env: INTERVAL=30 MIN_AVAILABLE_MIB=2048 MAX_SWAP_MIB=512 AUTO_DOWNGRADE=1" >&2
  exit 2
fi

V8_VERSION="$1"
JOBS_NOW="${2:-${JOBS:-4}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RUST_TARGET="${RUST_TARGET:-riscv64gc-unknown-linux-gnu}"
INTERVAL="${INTERVAL:-30}"
MIN_AVAILABLE_MIB="${MIN_AVAILABLE_MIB:-2048}"
MAX_SWAP_MIB="${MAX_SWAP_MIB:-512}"
AUTO_DOWNGRADE="${AUTO_DOWNGRADE:-1}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/work/logs}"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/rusty-v8-v${V8_VERSION}-$(date +%Y%m%d-%H%M%S).log"
SRC_DIR="$ROOT_DIR/work/rusty_v8-v${V8_VERSION}"
GN_OUT="$SRC_DIR/target/$RUST_TARGET/release/gn_out"
NINJA_BIN="${NINJA:-$ROOT_DIR/work/tools/root/usr/bin/ninja}"

mem_available_mib() {
  awk '/MemAvailable:/ {print int($2 / 1024)}' /proc/meminfo
}

swap_used_mib() {
  awk '
    /SwapTotal:/ {total=$2}
    /SwapFree:/ {free=$2}
    END {print int((total - free) / 1024)}
  ' /proc/meminfo
}

remaining_steps() {
  if [ -x "$NINJA_BIN" ] && [ -d "$GN_OUT" ]; then
    "$NINJA_BIN" -C "$GN_OUT" -n rusty_v8 2>/dev/null | wc -l
  else
    echo "unknown"
  fi
}

print_status() {
  local available swap_used remaining
  available="$(mem_available_mib)"
  swap_used="$(swap_used_mib)"
  remaining="$(remaining_steps)"

  echo
  echo "[$(date '+%F %T')] jobs=$JOBS_NOW remaining=$remaining mem_available=${available}MiB swap_used=${swap_used}MiB log=$LOG_FILE"
  ps -C cc1plus -C ninja -C cargo -o pid,stat,etime,%cpu,%mem,comm 2>/dev/null || true
  if [ -f "$GN_OUT/.ninja_log" ]; then
    echo "recent ninja_log:"
    tail -n 8 "$GN_OUT/.ninja_log" || true
  fi
}

stop_build() {
  local pid="$1"
  echo "Stopping build pid=$pid ..."
  if [ "${STARTED_WITH_SETSID:-0}" = 1 ]; then
    kill -INT -- "-$pid" 2>/dev/null || true
  else
    kill -INT "$pid" 2>/dev/null || true
  fi
}

run_once() {
  STARTED_WITH_SETSID=0
  echo "Starting rusty_v8 v$V8_VERSION with JOBS=$JOBS_NOW"
  echo "Build log: $LOG_FILE"

  if command -v setsid >/dev/null 2>&1; then
    STARTED_WITH_SETSID=1
    setsid env \
      JOBS="$JOBS_NOW" \
      CARGO_VERBOSE="${CARGO_VERBOSE:-0}" \
      DISABLE_CLANG="${DISABLE_CLANG:-1}" \
      "$SCRIPT_DIR/build-rusty-v8.sh" "$V8_VERSION" >>"$LOG_FILE" 2>&1 &
  else
    env \
      JOBS="$JOBS_NOW" \
      CARGO_VERBOSE="${CARGO_VERBOSE:-0}" \
      DISABLE_CLANG="${DISABLE_CLANG:-1}" \
      "$SCRIPT_DIR/build-rusty-v8.sh" "$V8_VERSION" >>"$LOG_FILE" 2>&1 &
  fi

  local pid="$!"
  local restart=0

  while kill -0 "$pid" 2>/dev/null; do
    sleep "$INTERVAL" || true
    print_status

    local available swap_used
    available="$(mem_available_mib)"
    swap_used="$(swap_used_mib)"

    if [ "$JOBS_NOW" -gt 1 ] &&
       [ "$AUTO_DOWNGRADE" = 1 ] &&
       { [ "$available" -lt "$MIN_AVAILABLE_MIB" ] || [ "$swap_used" -gt "$MAX_SWAP_MIB" ]; }; then
      echo "Memory guard triggered: available=${available}MiB swap_used=${swap_used}MiB."
      stop_build "$pid"
      wait "$pid" 2>/dev/null || true
      JOBS_NOW="$((JOBS_NOW - 1))"
      echo "Restarting with JOBS=$JOBS_NOW."
      restart=1
      break
    fi
  done

  if [ "$restart" = 1 ]; then
    return 75
  fi

  wait "$pid"
}

while true; do
  run_once
  status="$?"
  if [ "$status" = 75 ]; then
    continue
  fi
  if [ "$status" = 0 ]; then
    echo
    echo "Build finished successfully."
    tail -n 20 "$LOG_FILE" || true
    exit 0
  fi

  echo
  echo "Build failed with exit code $status."
  echo "Last log lines:"
  tail -n 80 "$LOG_FILE" || true
  exit "$status"
done
