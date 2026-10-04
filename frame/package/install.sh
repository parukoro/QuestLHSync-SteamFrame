#!/bin/sh
# QuestLHSync for the Steam Frame: run on the headset (Desktop Mode's terminal, or ssh) from the unpacked folder.
# Needs no root: lhsyncd runs as a systemd user service, and the questlhsync_frame driver in the headset's own SteamVR
# lends it the camera buffers. Restarts SteamVR on the headset so it loads the driver.
set -e
RESTART=1
case "${1:-}" in
  "") ;;
  --no-restart) RESTART=0 ;;
  *) echo "usage: $0 [--no-restart]" >&2; exit 2 ;;
esac
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=$HOME/.local/share/questlhsync
UNIT=$HOME/.config/systemd/user/questlhsync.service
VRPATHREG=/opt/steamvr/bin/linuxarm64/vrpathreg
[ -x "$VRPATHREG" ] || { echo "SteamVR not found in /opt/steamvr: is this a Steam Frame?" >&2; exit 1; }
[ "$(uname -m)" = aarch64 ] || { echo "This package requires arm64 Steam Frame" >&2; exit 1; }
for f in lhsyncd questlhsync_frame/driver.vrdrivermanifest questlhsync_frame/bin/linuxarm64/driver_questlhsync_frame.so questlhsync.service; do
  [ -r "$HERE/$f" ] || { echo "Incomplete package: $f missing" >&2; exit 1; }
done
for f in /persist/xrservice.json /persist/device_config.json; do
  [ -r "$f" ] || { echo "Camera calibration unavailable: $f (unsupported OS build?)" >&2; exit 1; }
done

systemctl --user stop questlhsync.service 2>/dev/null || true
mkdir -p "$DEST/questlhsync_frame/bin/linuxarm64" "$(dirname "$UNIT")"
# new files next to the old ones, then renamed over them: SteamVR may have the old driver loaded
put() { cp "$HERE/$1" "$DEST/$1.new" && chmod "$2" "$DEST/$1.new" && mv -f "$DEST/$1.new" "$DEST/$1"; }
put lhsyncd 755
put questlhsync_frame/driver.vrdrivermanifest 644
put questlhsync_frame/bin/linuxarm64/driver_questlhsync_frame.so 755
cp "$HERE/questlhsync.service" "$UNIT"

"$VRPATHREG" adddriver "$DEST/questlhsync_frame" >/dev/null 2>&1 || { echo "vrpathreg adddriver failed" >&2; exit 1; }
systemctl --user daemon-reload
systemctl --user enable --now questlhsync.service
echo "lhsyncd installed in $DEST and running"
if [ "$RESTART" = 1 ] && systemctl --user is-active --quiet steamvr.service; then
  echo "restarting SteamVR on the headset to load the questlhsync_frame driver"
  systemctl --user restart steamvr.service
fi
[ "$RESTART" = 1 ] || echo "Restart SteamVR on the headset manually to load the driver"
echo "done: start SteamVR on the PC"
