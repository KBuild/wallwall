#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$here/../desktop-plugin/tests/run.sh"
sh "$here/run-managed.sh"
python3 "$here/BuildFailureTests.py"
