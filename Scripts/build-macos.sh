#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/lib/environment.sh"
project_dir=${WALLWALL_PORT_DIR:-"$repo_dir/Port"}
editor=${UNITY_EDITOR:-"/Applications/Unity/Hub/Editor/6000.3.23f1/Unity.app/Contents/MacOS/Unity"}
log_path=${WALLWALL_BUILD_LOG:-"$repo_dir/Builds/unity-build.log"}

if [ ! -f "$project_dir/ProjectSettings/ProjectVersion.txt" ]; then
    echo "Port is missing. Run Scripts/generate-port.py first." >&2
    exit 1
fi
if [ ! -x "$editor" ]; then
    echo "Unity 6000.3.23f1 Editor is missing. See Docs/REQUIREMENT.md." >&2
    exit 1
fi
if [ -d "$app_path" ]; then
    echo "Existing app: $app_path. Close it before rebuilding." >&2
fi

"$script_dir/desktop-plugin/build.sh" "$project_dir/Assets/Plugins/macOS"
mkdir -p "$(dirname "$app_path")" "$(dirname "$log_path")"
"$editor" -quit -batchmode -nographics \
    -projectPath "$project_dir" \
    -logFile "${log_path%.log}-import.log"
python3 - "$project_dir/ProjectSettings/ProjectSettings.asset" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
updated, count = re.subn(r"(?m)^  productName: .*$", "  productName: WALLWALL", source)
if count != 1:
    raise SystemExit(f"Expected one productName in {path}, found {count}")
path.write_text(updated, encoding="utf-8")
PY
"$editor" -quit -batchmode -nographics \
    -projectPath "$project_dir" \
    -buildTarget osxuniversal \
    -buildOSXUniversalPlayer "$app_path" \
    -logFile "$log_path"

if [ ! -x "$app_path/Contents/MacOS/WALLWALL" ]; then
    echo "Unity exited without a WALLWALL executable. Review $log_path." >&2
    exit 1
fi
echo "Built: $app_path"
echo "Build log: $log_path"
