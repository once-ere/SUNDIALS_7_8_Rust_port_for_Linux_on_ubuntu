#!/usr/bin/env bash
# c_build.sh — build the unmodified upstream SUNDIALS 7.8.0 C library and
# every example this machine has the dependencies for.
#
#   tools/c_build.sh [build-dir]        # default: build/c
#
# The upstream C source tree is located, in order, from:
#   1. $SUNDIALS_C_SRC
#   2. ./upstream-c            (a symlink this repository ships)
#   3. ..                      (the layout the sibling repositories use)
#
# Nothing is written into that tree; the build is entirely out of source.
#
# Which backends get switched on is decided by probing the machine, and the
# decision is *printed and logged* so the example results can be read
# against it. Anything that could not be enabled is reported by
# tools/c_requirements.sh and listed in requirements.md.
set -u

cd "$(dirname "$0")/.."
WS=$PWD
BUILD=${1:-$WS/build/c}
LOG=$WS/logs/c_build.log
mkdir -p "$WS/logs" "$(dirname "$BUILD")"

SRC=${SUNDIALS_C_SRC:-}
if [ -z "$SRC" ] || [ ! -f "$SRC/CMakeLists.txt" ]; then
  if [ -f "$WS/upstream-c/CMakeLists.txt" ]; then
    SRC=$WS/upstream-c
  elif [ -f "$WS/../CMakeLists.txt" ]; then
    SRC=$(cd .. && pwd)
  fi
fi
[ -n "$SRC" ] && [ -f "$SRC/CMakeLists.txt" ] || {
  echo "ERROR: no upstream SUNDIALS C tree found."
  echo "       set SUNDIALS_C_SRC=/path/to/sundials-7.8.0 and re-run."
  exit 1
}
SRC=$(cd "$SRC" && pwd)

# ---- probe optional backends -------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
have_hdr() { for d in /usr/include /usr/local/include; do [ -f "$d/$1" ] && return 0; done; return 1; }
have_lib() { ls /usr/lib/x86_64-linux-gnu/$1 >/dev/null 2>&1; }

OPT=()
note() { printf '  %-14s %s\n' "$1" "$2"; }

echo "== probing optional backends ==" | tee "$LOG"
if have mpicc && have_hdr mpi.h; then OPT+=(-DENABLE_MPI=ON); note MPI on
else OPT+=(-DENABLE_MPI=OFF); note MPI "off (no mpicc + mpi.h)"; fi

if have_lib 'liblapack.so*' && have_lib 'libblas.so*'; then
  OPT+=(-DENABLE_LAPACK=ON); note LAPACK on
else OPT+=(-DENABLE_LAPACK=OFF); note LAPACK off; fi

if have_hdr suitesparse/klu.h || have_hdr klu.h; then
  OPT+=(-DENABLE_KLU=ON); note KLU on
else OPT+=(-DENABLE_KLU=OFF); note KLU "off (libsuitesparse-dev)"; fi

if have_hdr hypre/HYPRE.h || have_hdr HYPRE.h; then
  OPT+=(-DENABLE_HYPRE=ON); note hypre on
else OPT+=(-DENABLE_HYPRE=OFF); note hypre "off (libhypre-dev)"; fi

# OpenMP comes from the compiler itself
OPT+=(-DENABLE_OPENMP=ON); note OpenMP on
OPT+=(-DENABLE_PTHREAD=ON); note pthread on

if have gfortran; then OPT+=(-DBUILD_FORTRAN_MODULE_INTERFACE=ON); note Fortran on
else OPT+=(-DBUILD_FORTRAN_MODULE_INTERFACE=OFF); note Fortran off; fi

echo | tee -a "$LOG"
echo "source: $SRC"   | tee -a "$LOG"
echo "build:  $BUILD" | tee -a "$LOG"
echo "cc:     $(cc --version | head -1)" | tee -a "$LOG"
echo "cmake:  $(cmake --version | head -1)" | tee -a "$LOG"
echo | tee -a "$LOG"

cmake -S "$SRC" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DEXAMPLES_ENABLE_C=ON \
  -DEXAMPLES_ENABLE_CXX=ON \
  -DEXAMPLES_INSTALL=OFF \
  -DBUILD_ARKODE=ON -DBUILD_CVODE=ON -DBUILD_CVODES=ON \
  -DBUILD_IDA=ON -DBUILD_IDAS=ON -DBUILD_KINSOL=ON \
  -DSUNDIALS_ENABLE_MONITORING=ON \
  "${OPT[@]}" \
  >>"$LOG" 2>&1 || {
  echo "CONFIGURE FAILED — retrying serial-only" | tee -a "$LOG"
  cmake -S "$SRC" -B "$BUILD" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DEXAMPLES_ENABLE_C=ON -DEXAMPLES_INSTALL=OFF \
    -DBUILD_ARKODE=ON -DBUILD_CVODE=ON -DBUILD_CVODES=ON \
    -DBUILD_IDA=ON -DBUILD_IDAS=ON -DBUILD_KINSOL=ON \
    -DENABLE_MPI=OFF -DENABLE_OPENMP=OFF -DENABLE_PTHREAD=OFF \
    -DENABLE_KLU=OFF -DENABLE_LAPACK=OFF -DENABLE_SUPERLUMT=OFF \
    -DSUNDIALS_ENABLE_MONITORING=ON \
    >>"$LOG" 2>&1 || { echo "CONFIGURE FAILED — see $LOG"; tail -30 "$LOG"; exit 1; }
}

cmake --build "$BUILD" -j "$(nproc)" >>"$LOG" 2>&1 || {
  echo "BUILD had failures — see $LOG (continuing; per-example status is recorded)"
}

n=$(find "$BUILD/examples" -type f -perm -u+x ! -name '*.*' 2>/dev/null | wc -l)
echo "built $n example binaries under $BUILD/examples" | tee -a "$LOG"
