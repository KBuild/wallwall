# SPDX-License-Identifier: GPL-3.0-only
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class BuildFailureTests(unittest.TestCase):
    def test_native_failures_preserve_result_and_stop_pipeline(self):
        for failure in ('swiftc', 'clang', 'lipo'):
            with self.subTest(stage=failure), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                tools = root / 'tools'
                tools.mkdir()
                scratch = root / 'scratch'
                scratch.mkdir()
                trace = root / 'trace'
                fake = tools / 'xcrun'
                fake.write_text('''#!/bin/sh
set -eu
if [ "$1" = --find ]; then echo /unused/bin/swiftc; exit 0; fi
tool=$1
echo "$tool" >> "$TRACE"
output=
while [ "$#" -gt 0 ]; do
    case "$1" in -o|-output) shift; output=$1;; esac
    shift
done
if [ -n "$output" ]; then printf staged > "$output"; fi
if [ "$tool" = "$FAIL_AT" ]; then echo "injected $tool failure" >&2; exit 37; fi
''')
                fake.chmod(0o755)
                binary = root / 'output/WallwallDesktop.bundle/Contents/MacOS/WallwallDesktop'
                binary.parent.mkdir(parents=True)
                binary.write_bytes(b'last successful build')
                env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ['PATH'],
                           TMPDIR=str(scratch), TRACE=str(trace), FAIL_AT=failure)
                result = subprocess.run(['sh', str(ROOT / 'Scripts/desktop-plugin/build.sh'), str(root / 'output')],
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 37)
                self.assertIn('injected ' + failure + ' failure', result.stderr)
                self.assertEqual(trace.read_text().splitlines()[-1], failure)
                self.assertNotIn('WallwallDesktop.bundle', result.stdout)
                self.assertEqual(binary.read_bytes(), b'last successful build')
                self.assertEqual(list(scratch.iterdir()), [])

    def test_player_build_never_reports_stale_app_as_success(self):
        for failure, expected in [('import', 31), ('player', 32), ('missing', 1), ('signature', 33), ('none', 0)]:
            with self.subTest(stage=failure), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                scripts = root / 'Scripts'
                (scripts / 'lib').mkdir(parents=True)
                (scripts / 'desktop-plugin').mkdir()
                for source in ['build-macos.sh', 'lib/environment.sh']:
                    (scripts / source).write_bytes((ROOT / 'Scripts' / source).read_bytes())
                native = scripts / 'desktop-plugin/build.sh'
                native.write_text('#!/bin/sh\nexit 0\n')
                native.chmod(0o755)
                project = root / 'Port/ProjectSettings'
                project.mkdir(parents=True)
                (project / 'ProjectVersion.txt').write_text('fixture')
                (project / 'ProjectSettings.asset').write_text('  productName: WALLWALL\n')
                executable = root / 'Builds/WALLWALL.app/Contents/MacOS/WALLWALL'
                executable.parent.mkdir(parents=True)
                executable.write_text('existing app')
                executable.chmod(0o755)
                editor = root / 'editor'
                editor.write_text('''#!/bin/sh
set -eu
output=
while [ "$#" -gt 0 ]; do
    if [ "$1" = -buildOSXUniversalPlayer ]; then shift; output=$1; fi
    shift
done
if [ -z "$output" ]; then
    if [ "$FAIL_AT" = import ]; then exit 31; fi
    exit 0
fi
if [ "$FAIL_AT" = player ]; then exit 32; fi
if [ "$FAIL_AT" = missing ]; then exit 0; fi
mkdir -p "$output/Contents/MacOS"
printf 'new app' > "$output/Contents/MacOS/WALLWALL"
chmod +x "$output/Contents/MacOS/WALLWALL"
''')
                editor.chmod(0o755)
                signer = root / 'codesign'
                signer.write_text('#!/bin/sh\nif [ "$FAIL_AT" = signature ]; then exit 33; fi\nexit 0\n')
                signer.chmod(0o755)
                env = dict(os.environ, UNITY_EDITOR=str(editor), FAIL_AT=failure,
                           WALLWALL_APP_PATH=str(executable.parents[2]),
                           WALLWALL_PORT_DIR=str(project.parent),
                           WALLWALL_BUILD_LOG=str(root / 'Builds/build.log'),
                           PATH=str(root) + os.pathsep + os.environ['PATH'])
                result = subprocess.run(['sh', str(scripts / 'build-macos.sh')], env=env,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertEqual(executable.read_text(), 'new app' if expected == 0 else 'existing app')
                self.assertEqual('Built:' in result.stdout, expected == 0)
                self.assertFalse(list((root / 'Builds').glob('.wallwall-build.*')))

if __name__ == '__main__':
    unittest.main()
