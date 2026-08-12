#!/usr/bin/env bash
# ab_host_libm.sh — attribute every C-vs-Rust divergence.
#
#   tools/ab_host_libm.sh
#
# The question this answers is the only one that matters when the Rust
# output differs from the C output: *is the translation wrong, or is it the
# deliberate libm substitution?*
#
# The experiment: rebuild the Rust examples with `--features host-libm`, so
# that `sun_sin`, `sun_exp`, … call the host C library exactly as the C
# examples do, while every other line of the port stays identical. Then run
# the whole variant set again and compare against c-results/.
#
#   * a variant that was divergent and is now IDENTICAL  -> the difference
#     is entirely the pure-Rust libm; the translation is faithful.
#   * a variant that is still divergent                  -> a real port
#     defect, and it must be fixed.
#
# Output: differences/ab-host-libm.tsv and differences/ATTRIBUTION.md
set -u

cd "$(dirname "$0")/.."
WS=$PWD
AB_TARGET=$WS/target-hostlibm
BINDIR=$AB_TARGET/release/examples
RAW=$WS/build/ab-raw
SCRATCH=$WS/build/ab-run
OUTTSV=$WS/differences/ab-host-libm.tsv
TIMEOUT=${SUNDIALS_EXAMPLE_TIMEOUT:-600}

exdir_of() {
  case "$1" in
    cvode_rs)  echo "cvode/serial" ;;
    cvodes_rs) echo "cvodes/serial" ;;
    kinsol_rs) echo "kinsol/serial" ;;
    ida_rs)    echo "ida/serial" ;;
    idas_rs)   echo "idas/serial" ;;
    arkode_rs) echo "arkode/C_serial" ;;
  esac
}
CRATES="cvode_rs cvodes_rs kinsol_rs ida_rs idas_rs arkode_rs"

parse_cmake() {
  local cml=$1
  [ -f "$cml" ] || return 0
  grep -v '^[[:space:]]*#' "$cml" | grep -o '"[^"]*\\;[^"]*"' \
    | sed -e 's/^"//' -e 's/"$//' \
    | while IFS= read -r tuple; do
        local name rest args
        name=${tuple%%\\;*}; rest=${tuple#*\\;}
        case "$rest" in *\\\;*) args=${rest%%\\;*} ;; *) args="" ;; esac
        printf '%s|%s\n' "${name%.c}" "$args"
      done
}
variant_id() { if [ -z "$2" ]; then printf '%s' "$1"; else printf '%s__%s' "$1" "$(printf '%s' "$2" | tr ' /' '__')"; fi; }

echo "== building the host-libm control build (separate target dir) =="
CARGO_TARGET_DIR=$AB_TARGET cargo build --release --workspace --examples \
  --features host-libm 2>&1 | tail -3

rm -rf "$RAW" "$SCRATCH"; mkdir -p "$RAW" "$SCRATCH" "$WS/differences"
printf 'dir\texample\targv\tvariant\tdefault_class\thost_libm_class\n' >"$OUTTSV"

same=0; still=0; skipped=0
for crate in $CRATES; do
  d=$(exdir_of "$crate")
  while IFS='|' read -r name args; do
    [ -z "$name" ] && continue
    bin=$BINDIR/$name
    vid=$(variant_id "$name" "$args")
    cref=$WS/c-results/raw/$d/$vid.stdout
    [ -x "$bin" ] || { skipped=$((skipped + 1)); continue; }
    [ -f "$cref" ] || { skipped=$((skipped + 1)); continue; }

    # what the default (pure-Rust libm) build scored
    def=$(awk -F'\t' -v d="$d" -v v="$vid" '$1==d && $4==v {print $5}' "$WS/differences/index.tsv")
    [ -z "$def" ] && def="?"

    mkdir -p "$RAW/$d" "$SCRATCH/$d/$vid"
    # shellcheck disable=SC2086
    ( cd "$SCRATCH/$d/$vid" && timeout "$TIMEOUT" "$bin" $args ) \
      >"$RAW/$d/$vid.stdout" 2>/dev/null

    if cmp -s "$cref" "$RAW/$d/$vid.stdout"; then cls=IDENTICAL; else cls=DIFFERS; fi
    [ "$cls" = IDENTICAL ] && same=$((same + 1)) || still=$((still + 1))
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$d" "$name" "$args" "$vid" "$def" "$cls" >>"$OUTTSV"
  done < <(parse_cmake "$WS/examples/$d/CMakeLists.txt")
done

echo
echo "host-libm control build vs the C binaries:"
echo "  IDENTICAL : $same"
echo "  DIFFERS   : $still"
echo "  skipped   : $skipped (not ported / no C run)"
echo
echo "variants that the pure-Rust libm alone accounts for:"
awk -F'\t' 'NR>1 && $5!="IDENTICAL" && $6=="IDENTICAL" {print "  " $1 "  " $4}' "$OUTTSV"
echo
echo "variants that remain divergent even with the host libm (real port defects):"
awk -F'\t' 'NR>1 && $6!="IDENTICAL" {print "  " $1 "  " $4 "  (default: " $5 ")"}' "$OUTTSV"
echo
echo "wrote $OUTTSV"
