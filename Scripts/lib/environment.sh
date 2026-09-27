# SPDX-License-Identifier: GPL-3.0-only
# Source after the caller defines script_dir. This file performs no mutations.
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
app_path=${WALLWALL_APP_PATH:-"$repo_dir/Builds/WALLWALL.app"}

require_wallwall_app() {
    if [ ! -x "$app_path/Contents/MacOS/WALLWALL" ]; then
        echo "WALLWALL app is missing: $app_path. Run Scripts/build-macos.sh first." >&2
        exit 1
    fi
}
