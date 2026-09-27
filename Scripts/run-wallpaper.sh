#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/lib/environment.sh"
log_path=${WALLWALL_PLAYER_LOG:-"$repo_dir/Builds/wallpaper-player.log"}

require_wallwall_app
mkdir -p "$(dirname "$log_path")"
if [ "${WALLWALL_WINDOWED:-0}" = 1 ]; then
    open "$app_path" --args --wallwall-windowed -screen-fullscreen 0 -logFile "$log_path"
else
    open "$app_path" --args -screen-fullscreen 0 -logFile "$log_path"
fi
echo "Started: $app_path"
echo "Player log: $log_path"
