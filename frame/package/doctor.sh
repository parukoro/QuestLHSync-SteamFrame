#!/bin/sh
# Read-only checks. Run on the Steam Frame, without sudo.
failed=0
check() {
  if "$@"; then printf 'OK: %s\n' "$*"; else printf 'FAIL: %s\n' "$*"; failed=1; fi
}
check test "$(uname -m)" = aarch64
check test -x /opt/steamvr/bin/linuxarm64/vrpathreg
check test -r /persist/xrservice.json
check test -r /persist/device_config.json
check test -x "$HOME/.local/share/questlhsync/lhsyncd"
check test -r "$HOME/.local/share/questlhsync/questlhsync_frame/bin/linuxarm64/driver_questlhsync_frame.so"
check systemctl --user is-active --quiet questlhsync.service
check systemctl --user is-active --quiet steamvr.service
printf '\nRecent daemon logs (camera capture requires a connected PC and an awake headset):\n'
journalctl --user -u questlhsync.service -n 30 --no-pager
exit "$failed"
