#!/bin/bash
# Compiles PcmMixer out of AudioCaptureService.swift and runs its checks.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
python3 - "$ROOT" "$TMP" <<'PY'
import sys
root, tmp = sys.argv[1], sys.argv[2]
s = open(f"{root}/macos/Runner/Services/AudioCaptureService.swift").read()
a = s.index("// MARK: PcmMixer begin"); b = s.index("// MARK: PcmMixer end")
open(f"{tmp}/PcmMixer.swift", "w").write("import Foundation\n" + s[a:b])
PY
cp "$ROOT/tool/native_tests/pcm_mixer_test.swift" "$TMP/main.swift"
swiftc "$TMP/main.swift" "$TMP/PcmMixer.swift" -o "$TMP/mixtest"
"$TMP/mixtest"
