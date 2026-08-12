#!/usr/bin/env bash
# c_examples_run.sh — execute every C example binary produced by
# tools/c_build.sh, once per (example, argv) variant declared in the
# upstream CMakeLists.txt files, and record exactly what happened.
#
#   tools/c_examples_run.sh [build-dir]     # default: build/c
#
# Output, all under c-results/:
#   raw/<dir>/<variant>.stdout   captured stdout            (byte for byte)
#   raw/<dir>/<variant>.stderr   captured stderr
#   raw/<dir>/<variant>.meta     argv, exit status, wall time, sha256
#   index.tsv                    one row per variant, tab separated
#
# Nothing here interprets or edits program output. The .stdout files are
# what the binaries printed, unmodified, so any claim made later in
# c-results/*.md can be checked against them with plain `cat` and `diff`.
set -u

cd "$(dirname "$0")/.."
WS=$PWD
BUILD=${1:-$WS/build/c}
OUT=$WS/c-results
RAW=$OUT/raw
IDX=$OUT/index.tsv
SCRATCH=$WS/build/c-run
TIMEOUT=${SUNDIALS_EXAMPLE_TIMEOUT:-600}

[ -d "$BUILD/examples" ] || { echo "no build at $BUILD — run tools/c_build.sh first"; exit 1; }

rm -rf "$RAW" "$SCRATCH"
mkdir -p "$RAW" "$SCRATCH" "$OUT"

# Parse one CMakeLists.txt into "name|args" rows. Upstream declares its
# examples as quoted, backslash-semicolon separated tuples:
#     "cvRoberts_dns\;\;develop"          -> name, args(empty), label
#     "cvsRoberts_FSA_dns\;-sensi sim t\;develop"
# A 2-field tuple is name/label with no argv. arkode spells names with a
# .c suffix. This is the same scan tools/verify_examples.sh uses, so the
# C side and the Rust side enumerate an identical variant set.
parse_cmake() {
  local cml=$1
  [ -f "$cml" ] || return 0
  grep -v '^[[:space:]]*#' "$cml" \
    | grep -o '"[^"]*\\;[^"]*"' \
    | sed -e 's/^"//' -e 's/"$//' \
    | while IFS= read -r tuple; do
        local name rest args
        name=${tuple%%\\;*}
        rest=${tuple#*\\;}
        case "$rest" in
          *\\\;*) args=${rest%%\\;*} ;;
          *)      args="" ;;
        esac
        name=${name%.c}; name=${name%.cpp}; name=${name%.f90}
        printf '%s|%s\n' "$name" "$args"
      done
}

variant_id() { # <name> <args>
  if [ -z "$2" ]; then printf '%s' "$1"
  else printf '%s__%s' "$1" "$(printf '%s' "$2" | tr ' /' '__')"; fi
}

printf 'dir\texample\targv\tvariant\tstatus\texit\tseconds\tstdout_bytes\tstdout_sha256\n' >"$IDX"

total=0; ok=0; failed=0
mapfile -t BINS < <(find "$BUILD/examples" -type f -perm -u+x ! -name '*.*' | sort)
echo "found ${#BINS[@]} example binaries"

for bin in "${BINS[@]}"; do
  rel=${bin#"$BUILD"/examples/}
  dir=$(dirname "$rel")
  name=$(basename "$rel")
  cml=$WS/examples/$dir/CMakeLists.txt

  # every argv variant this example is declared with; default: no argv
  mapfile -t VARIANTS < <(parse_cmake "$cml" | awk -F'|' -v n="$name" '$1==n {print $2}')
  [ ${#VARIANTS[@]} -eq 0 ] && VARIANTS=("")

  mkdir -p "$RAW/$dir"
  for args in "${VARIANTS[@]}"; do
    vid=$(variant_id "$name" "$args")
    run=$SCRATCH/$dir/$vid
    mkdir -p "$run"
    total=$((total + 1))

    start=$(date +%s.%N)
    # shellcheck disable=SC2086  # argv must word-split exactly as CMake declares it
    ( cd "$run" && timeout "$TIMEOUT" "$bin" $args ) \
      >"$RAW/$dir/$vid.stdout" 2>"$RAW/$dir/$vid.stderr"
    rc=$?
    end=$(date +%s.%N)
    secs=$(awk -v a="$start" -v b="$end" 'BEGIN{printf "%.3f", b-a}')

    case $rc in
      0)   status=OK ;;
      124) status=TIMEOUT ;;
      *)   status=NONZERO_EXIT ;;
    esac
    [ "$status" = OK ] && ok=$((ok + 1)) || failed=$((failed + 1))

    bytes=$(stat -c%s "$RAW/$dir/$vid.stdout")
    sha=$(sha256sum "$RAW/$dir/$vid.stdout" | cut -c1-16)
    {
      echo "example:  $name"
      echo "source:   examples/$dir/$name.c"
      echo "binary:   $bin"
      echo "argv:     $args"
      echo "cwd:      $run"
      echo "exit:     $rc ($status)"
      echo "seconds:  $secs"
      echo "stdout:   $bytes bytes, sha256 $(sha256sum "$RAW/$dir/$vid.stdout" | cut -d' ' -f1)"
      echo "stderr:   $(stat -c%s "$RAW/$dir/$vid.stderr") bytes"
    } >"$RAW/$dir/$vid.meta"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$dir" "$name" "$args" "$vid" "$status" "$rc" "$secs" "$bytes" "$sha" >>"$IDX"
  done
done

echo
echo "ran $total variants: $ok OK, $failed not-OK"
echo "index: $IDX"
