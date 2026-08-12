# differences — C output versus Rust output, variant by variant

Every serial example was executed twice on this machine: once as the
upstream C binary (`c-results/`) and once as its pure-Rust translation
(`rust-results/`). This directory is the comparison of the two stdout
streams. Nothing here is asserted — every classification is computed by
[`../tools/compare_results.py`](../tools/compare_results.py) from the
captured bytes.

## Provenance

| item | value |
|---|---|
| generated | 2026-08-12 23:02:36 UTC |
| operating system | Ubuntu 26.04 LTS |
| kernel / platform | Linux-7.0.0-29-generic-x86_64-with-glibc2.43 |
| architecture | x86_64 |
| C library | ldd (Ubuntu GLIBC 2.43-2ubuntu2.3) 2.43 |
| C compiler | cc (Ubuntu 15.2.0-16ubuntu1) 15.2.0 |
| C++ compiler | c++ (Ubuntu 15.2.0-16ubuntu1) 15.2.0 |
| Fortran compiler | GNU Fortran (Ubuntu 15.2.0-16ubuntu1) 15.2.0 |
| CMake | cmake version 4.2.3 |
| rustc | rustc 1.96.1 (31fca3adb 2026-06-26) |
| cargo | cargo 1.96.1 (356927216 2026-06-26) |
| CPU cores | 24 |

## How to reproduce all of it

```bash
tools/c_build.sh && tools/c_examples_run.sh      # the C side
tools/rust_examples_run.sh                       # the Rust side
python3 tools/compare_results.py                 # the comparison
python3 tools/make_reports.py                    # these documents
```

## Headline result

**Of 185 comparable variants, 172 are byte-for-byte identical (93.0%).**

**With the elementary functions delegated back to the host C library (`--features host-libm`), 179 of 179 are identical — that is, all of them.** Every remaining difference is therefore caused by the deliberate pure-Rust libm and by nothing else: **0 port defects**, measured rather than asserted. See [ATTRIBUTION.md](ATTRIBUTION.md).

| class | variants | meaning |
|---|---:|---|
| IDENTICAL | 172 | the two stdout streams are equal byte for byte |
| WHITESPACE | 0 | every printed character matches; only column padding differs |
| NUMERIC | 12 | same text, same field count, at least one number differs |
| STRUCTURAL | 1 | different lines, words or field counts |
| NOT_PORTED | 14 | KLU / SuperLU_MT example, excluded by design on both sides |
| NO_C_RUN | 0 | the C example could not be built on this machine |

## How to read a difference

For every non-identical variant there is a unified diff, and for every
`NUMERIC` one there is also a `.numbers` file naming the single worst
field:

```bash
cat differences/diffs/<dir>/<variant>.diff
cat differences/diffs/<dir>/<variant>.numbers
```

`worst rel` below is the largest relative difference between any pair of
printed numbers, and `worst ulp` is the same pair measured in
representable double steps. One ulp is the smallest difference two
doubles can have — it is the granularity of the format itself, not an
error in either program.

## Attribution

[**ATTRIBUTION.md**](ATTRIBUTION.md) — the controlled experiment that
decides, for every divergent variant, whether the translation is wrong
or the libm substitution accounts for it. Raw data in
[`ab-host-libm.tsv`](ab-host-libm.tsv).

## Per-solver tables

* [ARKODE](by-solver/arkode_C_serial.md) — 73 identical of 78
* [CVODE](by-solver/cvode_serial.md) — 21 identical of 24
* [CVODES](by-solver/cvodes_serial.md) — 32 identical of 39
* [IDA](by-solver/ida_serial.md) — 11 identical of 14
* [IDAS](by-solver/idas_serial.md) — 14 identical of 22
* [KINSOL](by-solver/kinsol_serial.md) — 21 identical of 22

