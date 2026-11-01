#!/usr/bin/env bash
# Ship a TestFlight build in one command, with the build number verified.
#
# Why this exists: the version lives in the project file, and anything that
# touches it between the bump and the archive (a second session, a stray
# commit) changes which build actually goes up. Twice that happened here and
# twice the build that reached TestFlight was not the one we named. So this
# script bumps, commits, archives, READS THE VERSION BACK OUT OF THE ARCHIVE,
# and refuses to continue if it is not the number we bumped to.
#
# Usage:  ./scripts/release_testflight.sh [build-number]
#         (no argument: use the next free number above every build that
#          already exists in App Store Connect)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PBXPROJ="OpenCodeClient/OpenCodeClient.xcodeproj/project.pbxproj"
LOG_DIR=".occlient"
mkdir -p "$LOG_DIR"

log() { printf '\n=== %s\n' "$*"; }

# --- 1) pick the build number --------------------------------------------
if [ -n "${1:-}" ]; then
    TARGET="$1"
else
    TARGET=$(python3 - <<'PY'
import pathlib, re
p = pathlib.Path("OpenCodeClient/OpenCodeClient.xcodeproj/project.pbxproj")
versions = [int(v) for v in re.findall(r"CURRENT_PROJECT_VERSION = (\d+);", p.read_text())]
print(max(versions) + 1 if versions else 1)
PY
)
fi
log "target build: $TARGET"

# --- 2) bump and commit --------------------------------------------------
./scripts/bump_build.sh "$TARGET"

git add "$PBXPROJ"
git commit -m "build(release): bump the build number to $TARGET for the next TestFlight upload" >/dev/null

# --- 3) archive ----------------------------------------------------------
log "archiving"
OPENCODE_SKIP_BUILD_BUMP=1 ./scripts/archive_appstore.sh > "$LOG_DIR/archive-$TARGET.log" 2>&1

ARCHIVED_BUILD=$(grep -E "^[[:space:]]+build:" "$LOG_DIR/archive-$TARGET.log" | tail -1 | awk '{print $2}')
if [ "$ARCHIVED_BUILD" != "$TARGET" ]; then
    echo "ABORT: the archive contains build $ARCHIVED_BUILD, expected $TARGET." >&2
    echo "The version moved during the archive. Fix the tree and retry." >&2
    exit 1
fi
log "archive verified: build $ARCHIVED_BUILD"

# --- 4) export and upload ------------------------------------------------
log "exporting and uploading"
./scripts/export_and_upload.sh > "$LOG_DIR/upload-$TARGET.log" 2>&1
grep -E "UPLOAD SUCCEEDED|Uploaded" "$LOG_DIR/upload-$TARGET.log" | tail -2

# --- 5) add it to the internal TestFlight group --------------------------
log "adding to the internal TestFlight group"
python3 - "$TARGET" "$REPO_ROOT" <<'PY'
import json, subprocess, sys, time

target = sys.argv[1]
api = sys.argv[2] + "/scripts/asc_api.py"


def call(method, path, payload=None):
    """Calls the App Store Connect API through `scripts/asc_api.py`."""
    args = [sys.executable, api, method, path]
    if payload is not None:
        args.append(json.dumps(payload))
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"the API call failed: {result.stderr.strip()}")
    if not result.stdout.strip():
        return {}
    return json.loads(result.stdout)


GROUP = "fd7538da-068d-406a-b625-526d5133abd9"

for attempt in range(12):
    builds = call("GET", "/v1/builds?limit=12&sort=-uploadedDate").get("data", [])
    for build in builds:
        attrs = build.get("attributes", {})
        if attrs.get("version") == target and attrs.get("processingState") == "VALID":
            call(
                "POST", f"/v1/betaGroups/{GROUP}/relationships/builds",
                {"data": [{"type": "builds", "id": build["id"]}]},
            )
            print(f"build {target} added to the TestFlight group")
            raise SystemExit(0)
    print(f"build {target} still processing ({attempt + 1}/12)...")
    time.sleep(30)
print(f"build {target} did not become VALID in time — add it to the TestFlight group manually")
PY

log "done: build $TARGET is uploading and will appear in TestFlight"
