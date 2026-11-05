#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
editor=${UNITY_EDITOR:-/Applications/Unity/Hub/Editor/6000.3.23f1/Unity.app/Contents/MacOS/Unity}
mono_dir=$(dirname "$editor")/../Resources/Scripting/MonoBleedingEdge
stage=$(mktemp -d "${TMPDIR:-/tmp}/wallwall-managed-tests.XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM
"$mono_dir/bin/mono" "$mono_dir/lib/mono/4.5/csc.exe" -nologo \
    -out:"$stage/tests.exe" "$here/DesktopPolicyTests.cs" "$here/../templates/WallwallDesktopPolicy.cs"
"$mono_dir/bin/mono" "$stage/tests.exe"
