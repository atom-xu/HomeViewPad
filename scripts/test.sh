#!/bin/sh
set -eu
# Pass an installed simulator UUID as the first argument.
: "${1:?Usage: scripts/test.sh SIMULATOR_UUID}"
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
result_dir="${TMPDIR:-/tmp}/HomePad-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project "$project_dir/HomePad.xcodeproj" -scheme HomePad \
  -destination "platform=iOS Simulator,id=$1" -parallel-testing-enabled NO \
  -collect-test-diagnostics never -derivedDataPath "${TMPDIR:-/tmp}/HomePadDerived" \
  -resultBundlePath "$result_dir" CODE_SIGNING_ALLOWED=NO test
printf 'Results: %s\n' "$result_dir"
