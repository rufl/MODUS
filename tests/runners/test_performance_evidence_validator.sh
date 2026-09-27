#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d /tmp/modus_performance_validator.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/logs"

write_fixture() {
  local duplicate="$1"
  cat >"$tmp/logs/session.csv" <<CSV
Time,FPS,FrameTime,Memory,ActivePools,VisibleEnemies
0.0,60.0,16.67,100.0,0,0
1.0,60.0,16.67,100.0,0,0
${duplicate}2.0,60.0,16.67,100.0,0,0

# Statistics
avg_fps,60.0
min_fps,60.0
max_fps,60.0
avg_frame_time,16.67
max_frame_time,16.67
avg_memory,100.0
max_memory,100.0
total_frames,3
duration,61.0
CSV
}

write_fixture ""
(cd "$root" && tools/validate_performance_evidence.sh \
  --logs "$tmp/logs" --report "$tmp/pass.md" --strict >/dev/null)
grep -Fq -- '- Total samples: 3' "$tmp/pass.md"
grep -Fq -- '- Malformed rows/files: 0' "$tmp/pass.md"

write_fixture $'1.0,60.0,16.67,100.0,0,0\n'
set +e
(cd "$root" && tools/validate_performance_evidence.sh \
  --logs "$tmp/logs" --report "$tmp/fail.md" --strict >/dev/null)
status=$?
set -e
[[ "$status" -eq 1 ]]
grep -Fq -- '- Status: FAIL' "$tmp/fail.md"
grep -Fq -- '- Malformed rows/files: 1' "$tmp/fail.md"
printf 'Performance evidence validator self-check passed.\n'
