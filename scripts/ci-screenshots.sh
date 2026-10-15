#!/usr/bin/env bash
# Boots a simulator, installs the demo build and captures one screenshot per
# key screen. Usage: scripts/ci-screenshots.sh <simulator-udid> <Glimpse.app> <out-dir>
set -euo pipefail

UDID="$1"
APP="$2"
OUT="$3"
BUNDLE_ID="com.itaybraha.glimpse"

mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 || true
xcrun simctl ui "$UDID" appearance dark || true
xcrun simctl install "$UDID" "$APP"

shoot() {
  local name="$1" wait="$2"
  shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demo "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null
  echo "captured $name"
}

shoot 01-welcome 5 -screen welcome
shoot 02-feed 14 -screen feed
shoot 03-match 14 -screen match
shoot 04-connections 7 -screen connections
shoot 05-chat 8 -screen chat
shoot 06-profile 8 -screen profile
shoot 07-liked-you 8 -screen likes
shoot 08-paywall 6 -screen paywall
shoot 09-settings 7 -screen settings
shoot 10-vibe-check 8 -screen chat

# A short screen recording of the feed playing video.
record() {
  local name="$1" secs="$2"
  shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demo "$@" >/dev/null
  sleep 6
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/$name.mp4" &
  local pid=$!
  sleep "$secs"
  kill -INT "$pid"
  wait "$pid" || true
  echo "recorded $name"
}

record 11-feed-video 12 -screen feed
