#!/usr/bin/env bash
#
# mayhem/test.sh — RUN nchat's own unit tests (test001: word wrap/quote prefix, test002: config
# handling; built by build.sh via ctest) plus mayhem/selftest.cpp's known-answer checks.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

B=build/tests
for t in bin/test001 bin/test002 bin/mayhem_selftest; do
  [ -x "$B/$t" ] || { echo "missing $B/$t — mayhem/build.sh must build it" >&2; emit_ctrf "nchat-unittest" 0 1; exit 1; }
done

passed=0; failed=0
# Upstream unit tests signal failure by exit code (and print "exception: ..." on a failed expectation).
workdir="$(mktemp -d)"
for t in test001 test002; do
  out="$(cd "$workdir" && LC_ALL=C.UTF-8 "$SRC/$B/bin/$t" 2>&1)"; rc=$?
  echo "$out"
  if [ $rc -eq 0 ] && ! grep -q '^exception:' <<<"$out"; then passed=$((passed+1)); else failed=$((failed+1)); fi
done
rm -rf "$workdir"

# Selftest: every case must print its own PASS line; a program that exits 0 without running it fails.
out="$("$SRC/$B/bin/mayhem_selftest" 2>&1)"; rc=$?
echo "$out"
p=$(grep -c '^SELFTEST_PASS ' <<<"$out"); f=$(grep -c '^SELFTEST_FAIL ' <<<"$out")
expected=18
[ "$rc" -eq 0 ] || f=$((f+1))
[ "$p" -eq "$expected" ] || f=$((f + expected - p))
passed=$((passed + p)); failed=$((failed + f))

emit_ctrf "nchat-unittest" "$passed" "$failed"
