#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/lib/environment.sh"
video_path=${WALLWALL_VIDEO_PATH:-"$repo_dir/Builds/WALLWALL.mp4"}
seconds=${WALLWALL_VIDEO_SECONDS:-30}
fps=${WALLWALL_VIDEO_FPS:-30}
ffmpeg=${WALLWALL_FFMPEG:-ffmpeg}
log_path=${WALLWALL_VIDEO_LOG:-"$repo_dir/Builds/video-export.log"}

require_wallwall_app
ffmpeg_path=$(command -v "$ffmpeg" || true)
if [ -z "$ffmpeg_path" ]; then
    echo "FFmpeg is missing. Install it separately or set WALLWALL_FFMPEG." >&2
    exit 1
fi
case "$ffmpeg_path" in
    /*) ;;
    *) ffmpeg_path=$(CDPATH= cd -- "$(dirname -- "$ffmpeg_path")" && pwd)/$(basename -- "$ffmpeg_path") ;;
esac

case "$video_path" in
    /*) ;;
    *) video_path="$PWD/$video_path" ;;
esac
mkdir -p "$(dirname -- "$video_path")" "$(dirname -- "$log_path")"
if [ -e "$video_path" ]; then
    echo "Output already exists: $video_path" >&2
    exit 1
fi

"$app_path/Contents/MacOS/WALLWALL" \
    -screen-fullscreen 0 -screen-width 1920 -screen-height 1080 \
    -logFile "$log_path" \
    --wallwall-export-video "$video_path" \
    --wallwall-ffmpeg "$ffmpeg_path" \
    --wallwall-seconds "$seconds" --wallwall-fps "$fps"

if [ ! -s "$video_path" ]; then
    echo "Video export did not finish. Review $log_path." >&2
    exit 1
fi
echo "Exported: $video_path"
