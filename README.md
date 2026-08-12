# SUNDIALS_7_8_Rust_port_for_Linux_on_ubuntu

A line-by-line translation of [SUNDIALS](https://github.com/LLNL/sundials)
7.8.0 into safe Rust — **no `unsafe`, no FFI, no external crates, no build
warnings** — and, unlike its predecessors, **no host C library on the
numerical path at all.**

Every elementary function the port evaluates (`exp`, `log`, `pow`, `expm1`,
`log1p`, `sin`, `cos`, `atan`, `asin`, `acos`, `sinh`, `cosh`, `acosh`) is
implemented in pure Rust in
[`crates/sundials_core/src/sundials_libm.rs`](crates/sundials_core/src/sundials_libm.rs).

## Headline results

All measured on **Ubuntu 26.04 LTS, x86-64, glibc 2.43, gcc 15.2.0,
cmake 4.2.3, rustc 1.96.1**.

| | result | evidence |
|---|---|---|
| C examples built and executed | **337 (example, argv) variants, all exit 0** | [`c-results/`](c-results/) |
| Rust examples built and executed | **179 variants, all exit 0** (+20 excluded by design) | [`rust-results/`](rust-results/) |
| C output vs Rust output | **171 of 179 byte-for-byte identical (95.5 %)** | [`differences/`](differences/) |
| the other 8 | **all become identical when the port is rebuilt `--features host-libm`** → **0 port defects** | [`differences/ATTRIBUTION.md`](differences/ATTRIBUTION.md) |
| pure-Rust libm accuracy | **0.5000 ulp — correctly rounded — on all ten routines written here** | [`LIBM.md`](LIBM.md) |
| `exp`, `log`, `pow`, `acosh` vs host glibc | **100 % bit-identical** over 6 M + 25.9 M samples | [`LIBM.md`](LIBM.md) |
| `cargo build --workspace` | zero warnings, with and without `--features host-libm` | |
| `cargo test --workspace --lib` | **33 tests pass** across the workspace (31 in `sundials_core`: 25 inherited + 6 new libm) | |

## Quick start

```bash
cargo build --workspace
cargo run --release -p cvode_rs --example cvRoberts_dns
cargo test --workspace --lib
```

```rust
use cvode_rs::prelude::*;
```

Nothing is downloaded: the workspace has **zero dependencies**.

## What is new here, and why

This repository inherits the crate tree of
[`SUNDIALS_7_8_Rust_port_for_Linux`](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux)
wholesale — all 141 translated modules, all 108 translated examples. Not a
line of solver code was re-derived. What is new is that the port no longer
depends on the host libm, and the evidence for that.

The problem it solves is concrete. Rust documents `f64::sin`, `f64::exp`,
… as having *unspecified precision*: they forward to whatever C library the
binary links against. Inside an adaptive integrator, one ulp of difference
forks the step-size trajectory and therefore the printed output. The
predecessor repository measured exactly that — its gate scores
153 / 26 / 20 on glibc 2.36 through 2.41, but **150 / 29 / 20 on Arch**,
because glibc 2.44 changed `sinh`, `cosh` and `acosh`, which ARKODE's LSRK
stepper calls from a single line.

Routing every call through `sundials_libm` removes that dependence. The
port's output is now a function of its own source.

### The accuracy is better, not merely different

`tools/libm_differential.sh` measures each function against a 113-bit
`__float128` reference over 24,000,000 samples:

| function | pure Rust | host glibc 2.43 |
|---|---:|---:|
| `exp`, `log` | 0.5003 – 0.5071 ulp | identical (same ARM optimized-routines source) |
| `acosh` | 0.5000 ulp | 0.5000 ulp |
| `sin`, `cos`, `atan`, `asin`, `acos` | **0.5000 ulp** | 0.5042 – 0.5186 ulp |
| `expm1`, `log1p` | **0.5000 ulp** | 0.7783 – 0.8414 ulp |
| `sinh`, `cosh` | **0.5000 ulp** | 0.9883 – 1.7848 ulp |

0.5000 ulp is correct rounding — the smallest error binary64 admits. So on
the inputs where the two disagree, the pure-Rust answer is the right one.
Full table, method and provenance in [`LIBM.md`](LIBM.md).

### "0 port defects" is an experiment, not an opinion

Of 179 comparable example variants, 171 match the pristine C byte for byte.
For the other 8 the port is rebuilt with `--features host-libm`, which
changes exactly one thing — the thirteen `SunMath` methods call the host C
library — and leaves every other line identical. All 179 then match.

That isolates the cause to the libm substitution with a single controlled
variable. Four of the eight are the ARKODE LSRK examples, the same ones the
predecessor saw break on glibc 2.44, for the same reason.

```bash
tools/ab_host_libm.sh        # re-runs the experiment in about a minute
```

## Reproducing everything

Every number in this repository comes out of this pipeline. No file under
`c-results/`, `rust-results/` or `differences/` is hand-written.

```bash
tools/c_requirements.sh              # what this machine has -> requirements.md
tools/c_build.sh                     # upstream C, out of source, into build/c
tools/c_examples_run.sh              # -> c-results/{index.tsv,raw/}
tools/rust_examples_run.sh           # -> rust-results/{index.tsv,raw/}
python3 tools/compare_results.py     # -> differences/{index.tsv,diffs/}
tools/ab_host_libm.sh                # -> differences/ab-host-libm.tsv
python3 tools/make_reports.py        # -> the .md files in all three
tools/libm_differential.sh 1000000   # -> logs/libm_differential.log
tools/pow_differential.sh all        # -> logs/pow_differential.log
```

The C side needs the upstream SUNDIALS 7.8.0 tree, reached through the
`upstream-c` symlink or `$SUNDIALS_C_SRC`. See
[`requirements.md`](requirements.md) for what this machine has and what it
is missing.

### Checking a single claim by hand

```bash
cat c-results/raw/cvode/serial/cvRoberts_dns.meta        # what was run
diff c-results/raw/cvode/serial/cvRoberts_dns.stdout \
     rust-results/raw/cvode/serial/cvRoberts_dns.stdout  # silent = identical
```

## Scope

* 7 crates: `sundials_core` plus `cvode_rs`, `cvodes_rs`, `kinsol_rs`,
  `ida_rs`, `idas_rs`, `arkode_rs`.
* 142 modules, one per upstream C file, keeping the exact C names and
  return-flag conventions (`CV_SUCCESS = 0`; negative fatal, positive
  recoverable).
* **Serial only.** No MPI, GPU, KLU, SuperLU, Fortran or XBraid backends —
  none of them is reachable without FFI.
* The 20 KLU / SuperLU_MT examples are therefore not ported, and that is a
  real gap rather than a bookkeeping artefact:
  * the **9** SuperLU_MT examples cannot be built on the C side either —
    SuperLU_MT is not in the Ubuntu archive at any version — so nothing is
    lost by their absence;
  * the **11** KLU examples *do* build and run on the C side, so for those
    the C column exists and the Rust column does not. Closing that gap
    means implementing a sparse direct solver in `sundials_core`, which is
    a separate project.

  See [`requirements.md`](requirements.md) §4 and §6.

### What is platform-bound and what is not

| | bound to this machine? |
|---|---|
| `c-results/` | **yes** — built by the host gcc against the host glibc |
| `differences/` | **yes** — it compares against `c-results/` |
| `rust-results/` | no — the port has no host dependence left |
| the ulp figures in `LIBM.md` | no — they are against a 113-bit reference |
| the *agreement* figures in `LIBM.md` | **yes** — they describe glibc 2.43 |

## Documentation

| file | contents |
|---|---|
| [`LIBM.md`](LIBM.md) | the pure-Rust elementary functions: algorithms, provenance, measured accuracy |
| [`requirements.md`](requirements.md) | what this machine has, what is missing, and the `apt` line for it |
| [`c-results/README.md`](c-results/README.md) | every C example run, with provenance |
| [`rust-results/README.md`](rust-results/README.md) | every Rust example run, with provenance |
| [`differences/README.md`](differences/README.md) | the comparison, variant by variant |
| [`differences/ATTRIBUTION.md`](differences/ATTRIBUTION.md) | the controlled experiment behind "0 port defects" |
| [`CLAUDE.md`](CLAUDE.md) | workspace rules for future work here |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | handle model, porting patterns, deviation classes (inherited) |
| [`PROGRESS.md`](PROGRESS.md) | per-file port status (inherited) |
| [`sundials.md`](sundials.md) | the public guide to the port (inherited) |
| [`VERIFICATION.md`](VERIFICATION.md) | the predecessor's per-variant matrix against the shipped `.out` files (inherited; superseded here by `differences/`) |
| [`POW_FMA_EXACTNESS.md`](POW_FMA_EXACTNESS.md) | how far the deterministic `pow` is bit-exact (inherited) |

## Licence

Derivative work of SUNDIALS, **BSD-3-Clause**, Copyright © 2002–2026
Lawrence Livermore National Security, Southern Methodist University,
University of Maryland Baltimore County and the SUNDIALS contributors.

`exp`, `log` and `pow` in `sundials_libm.rs` are pure-Rust translations of
the ARM optimized-routines kernels taken via musl's `src/math/` — **MIT**,
Copyright © 2018 Arm Limited. glibc ≥ 2.28 ships the same algorithm. The
double-double core and the ten routines built on it are original to this
repository; their constant tables are generated by
`tools/gen_libm_constants.py`. See [`NOTICE`](NOTICE).

Not an LLNL product; not endorsed by the SUNDIALS project.
