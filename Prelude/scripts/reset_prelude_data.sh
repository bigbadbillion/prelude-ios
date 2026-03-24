#!/usr/bin/env bash
# Wipe Prelude’s sandbox on the iOS Simulator by uninstalling the app (SwiftData store,
# UserDefaults, and all app files). Re-run from Xcode after this to get a clean install.
#
# Usage:
#   ./Prelude/scripts/reset_prelude_data.sh              # booted simulator only
#   ./Prelude/scripts/reset_prelude_data.sh <UDID>       # specific simulator
#   ./Prelude/scripts/reset_prelude_data.sh --all-sims   # every available simulator
#
# Physical device: delete the Prelude app from the home screen (or remove it in Xcode’s
# Devices window). There is no supported CLI wipe for arbitrary USB devices without extra tools.

set -euo pipefail

BUNDLE_ID="app.prelude.Prelude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

uninstall_one() {
  local dest="$1"
  if xcrun simctl uninstall "$dest" "$BUNDLE_ID" 2>/dev/null; then
    echo "Uninstalled $BUNDLE_ID from simulator $dest"
  else
    echo "(No install of $BUNDLE_ID on $dest, or uninstall skipped.)"
  fi
}

case "${1:-booted}" in
  -h|--help)
    sed -n '1,20p' "$0" | tail -n +2
    exit 0
    ;;
  --all-sims)
    python3 <<'PY'
import json, subprocess, sys

bundle = "app.prelude.Prelude"
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True)
data = json.loads(raw)
seen = set()
for _runtime, devices in data.get("devices", {}).items():
    for d in devices:
        if not d.get("isAvailable"):
            continue
        udid = d.get("udid")
        if not udid or udid in seen:
            continue
        seen.add(udid)
        r = subprocess.run(
            ["xcrun", "simctl", "uninstall", udid, bundle],
            capture_output=True,
            text=True,
        )
        if r.returncode == 0:
            print(f"Uninstalled {bundle} from {udid} ({d.get('name', '')})")
        else:
            err = (r.stderr or r.stdout or "").strip()
            if "not installed" in err.lower() or "invalid" in err.lower():
                pass
            elif err:
                print(f"{udid}: {err}", file=sys.stderr)
PY
    ;;
  *)
    uninstall_one "$1"
    ;;
esac

echo "Done. Physical device: remove the app manually to clear its data."
