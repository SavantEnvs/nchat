#!/usr/bin/env bash
#
# mayhem/build.sh — build nchat's fuzz harnesses (fuzz_strutil over lib/ncutil, fuzz_tdurl over the
# vendored TDLib) plus the project's unit tests and the mayhem selftest with NORMAL flags.
# Runs as `mayhem` in /mayhem; re-runnable and offline (system -dev packages come from the image).
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
# SanCov for the fuzzed libraries: $LIB_FUZZING_ENGINE only instruments the harness TU, and
# $SANITIZER_FLAGS carries no coverage flags. Unconditional, also in a no-sanitizer build.
COV_LIB_FLAGS="-fsanitize=fuzzer-no-link"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# Only nchat's core libs plus TDLib (for tdcore) are configured; the Go protocols are not needed.
# The compiler is taken from the exported CC/CXX, not -DCMAKE_C(XX)_COMPILER: under the ccache pre-fill CMake
# caches the masquerade path, and a later plain re-run passing -D...=clang would flush the cache and
# re-configure without these -D options.
CMAKE_COMMON=(-DHAS_WHATSAPP=OFF -DHAS_SIGNAL=OFF -DHAS_DUMMY=OFF -DCMAKE_BUILD_TYPE=Release)

# 1) Test suite + selftest with the project's NORMAL flags (build/ is gitignored upstream).
cmake -S . -B build/tests "${CMAKE_COMMON[@]}" -DHAS_TELEGRAM=OFF -DHAS_TESTS=ON \
      -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS"
cmake --build build/tests -j"$MAYHEM_JOBS" --target test001 test002
$CXX -O1 $COVERAGE_FLAGS -std=c++17 -Ilib/ncutil/src mayhem/selftest.cpp \
     -Lbuild/tests/lib -lncutil -Wl,-rpath,"$SRC/build/tests/lib" -o build/tests/bin/mayhem_selftest

# 2) TDLib's code generators (tl-parser, gperf drivers) are build tools: they are linked with
# `-Wl,--exclude-libs,ALL` (breaking ASan's operator new/delete interception) and trip UBSan, so run them
# from a normal-flags configure first. `prepare_cross_compiling` writes the generated sources into the
# source tree (TDLib's own .gitignore covers them), then the sanitized configure below treats TDLib as
# cross-compiled (CMAKE_SYSTEM_NAME set) and uses those sources without rebuilding the generators.
cmake -S . -B build/tdgen "${CMAKE_COMMON[@]}" -DHAS_TELEGRAM=ON -DHAS_TESTS=OFF -DHAS_SHARED_LIBS=OFF
cmake --build build/tdgen -j"$MAYHEM_JOBS" --target prepare_cross_compiling

# 3) Sanitized static libs. ncutil keeps the full DWARF<=3 flags. TDLib's ~1M-line generated API makes
# full debug info ~700MB per harness binary, so it is built with `-g1` (function + line tables, still
# DWARF 3, enough for sanitizer/triage backtraces to resolve project source lines).
cmake -S . -B build/fuzz-ncutil "${CMAKE_COMMON[@]}" -DHAS_TELEGRAM=OFF -DHAS_TESTS=OFF -DHAS_SHARED_LIBS=OFF \
      -DCMAKE_C_FLAGS="$SANITIZER_FLAGS $COV_LIB_FLAGS $DEBUG_FLAGS" -DCMAKE_CXX_FLAGS="$SANITIZER_FLAGS $COV_LIB_FLAGS $DEBUG_FLAGS"
cmake --build build/fuzz-ncutil -j"$MAYHEM_JOBS" --target ncutil

cmake -S . -B build/fuzz-td "${CMAKE_COMMON[@]}" -DHAS_TELEGRAM=ON -DHAS_TESTS=OFF -DHAS_SHARED_LIBS=OFF \
      -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR="$(uname -m)" \
      -DCMAKE_C_FLAGS="$SANITIZER_FLAGS $COV_LIB_FLAGS $DEBUG_FLAGS -g1" -DCMAKE_CXX_FLAGS="$SANITIZER_FLAGS $COV_LIB_FLAGS $DEBUG_FLAGS -g1"
cmake --build build/fuzz-td -j"$MAYHEM_JOBS" --target tdcore

# 4) Harnesses: libFuzzer binary + standalone reproducer, both with LeakSanitizer off.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o build/standalone_main.o
$CXX $SANITIZER_FLAGS $COV_LIB_FLAGS $DEBUG_FLAGS -c mayhem/lsan_off.cc -o build/lsan_off.o

TDD=lib/tgchat/ext/td
TD_INC=(-I$TDD -I$TDD/td/generate/auto -I$TDD/tdnet -I$TDD/tdutils -Ibuild/fuzz-td/$TDD/tdutils -I$TDD/tdactor -I$TDD/tddb)
SYSLIBS=(-lmagic -lsqlite3 -lxcb -lpng -lssl -lcrypto -lz -lpthread)

link_harness() {
  local name="$1" src="$2" archives_dir="$3"; shift 3
  local extra=("$@")
  mapfile -t archives < <(find "$archives_dir" -name '*.a' | sort)
  $CXX $SANITIZER_FLAGS $DEBUG_FLAGS -std=c++17 -O1 "${extra[@]}" $LIB_FUZZING_ENGINE "$src" build/lsan_off.o \
       -Wl,--start-group "${archives[@]}" -Wl,--end-group "${SYSLIBS[@]}" -o "$SRC/$name"
  $CXX $SANITIZER_FLAGS $COV_LIB_FLAGS $DEBUG_FLAGS -std=c++17 -O1 "${extra[@]}" "$src" build/standalone_main.o build/lsan_off.o \
       -Wl,--start-group "${archives[@]}" -Wl,--end-group "${SYSLIBS[@]}" -o "$SRC/$name-standalone"
}

link_harness fuzz_strutil mayhem/fuzz_strutil.cpp build/fuzz-ncutil -Ilib/ncutil/src
link_harness fuzz_tdurl mayhem/fuzz_tdurl.cpp build/fuzz-td "${TD_INC[@]}"
