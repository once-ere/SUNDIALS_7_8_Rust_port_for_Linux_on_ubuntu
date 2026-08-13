# SUNDIALS_7_8_Rust_port_for_Linux_on_ubuntu — workspace rules

Pure-Rust port of SUNDIALS 7.8.0. The upstream C tree is read-only and is
reached through the `upstream-c` symlink (or `$SUNDIALS_C_SRC`); a copy of
its `examples/` tree lives here so the harnesses can read the CMake tuples
and the reference `.out` files without leaving the repository.

Read `README.md` first, then `LIBM.md`. This workspace is its own git repo;
git is the undo mechanism.

## What is different about this repository

It inherits the crate tree of
[`SUNDIALS_7_8_Rust_port_for_Linux`](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux)
unchanged — all 141 translated modules and the 108 translated examples —
and changes exactly one thing: **no elementary function resolves to the
host C library any more.**

`crates/sundials_core/src/sundials_libm.rs` implements `exp`, `log`, `pow`,
`expm1`, `log1p`, `sin`, `cos`, `atan`, `asin`, `acos`, `sinh`, `cosh` and
`acosh` in pure Rust. Every call site — library and examples — is spelled
`x.sun_sin()`, `x.sun_exp()`, … through the `SunMath` trait, because Rust
resolves inherent methods before trait methods and `x.sin()` therefore
cannot be redirected.

The consequence is that this port's numerical output is a function of its
own source only. The sibling repositories had to scope every numerical
claim to one libm; this one does not.

## Target platform

Measured on **Ubuntu 26.04 LTS, x86-64, glibc 2.43, gcc 15.2.0,
rustc 1.96.1**. The Rust sources are portable (`std` only, no
`cfg(target_os)`/`cfg(target_arch)`, no build script). Results that *are*
platform-bound, and must be labelled as such:

* the `c-results/` outputs — they come from binaries built by the host gcc
  against the host glibc;
* therefore also `differences/`, which compares against them.

Results that are **not** platform-bound, and must not be labelled as if
they were: anything in `rust-results/`, and every accuracy figure in
`LIBM.md` that is expressed in ulp against the 113-bit reference.

## Hard rules

1. **Fidelity first.** Line-by-line faithful translation: control flow,
   constants, tolerances, heuristics, error/return codes, and argument
   lists (names, order, meaning) match the parent C function exactly.
   Preserve arithmetic order.
2. Zero `unsafe`, zero FFI, zero external crates (std only), zero warnings
   from `cargo build --workspace` **and** from
   `cargo build --workspace --features host-libm`.
3. Never stub a missing symbol — its definition is under `upstream-c/src/`
   or `upstream-c/include/`; port it into `sundials_core`.
4. Public API keeps exact C names and return-flag conventions
   (`CV_SUCCESS = 0`; negative = fatal, positive = recoverable). Crate
   roots carry `#![allow(non_snake_case, non_camel_case_types,
   non_upper_case_globals)]`.
5. All float output goes through
   `sundials_core::sundials_utils::{fmt_e, fmt_f, fmt_g}` — never `{:e}`.
6. C buffer aliasing (e.g. CVODE `cv_y` / user `yout`): copy back at
   **every** return path, including early-error and rootfinding exits.
7. **No `f64` transcendental method may appear anywhere in `crates/`**
   except inside `sundials_libm.rs` itself. The permitted inherent methods
   are `sqrt`, `mul_add`, `abs`, `ceil`, `floor`, `round`, `trunc`,
   `copysign`, `max`, `min` — all IEEE-754 specified. Check with:

   ```bash
   grep -rn --include=*.rs -E '\.(sin|cos|tan|asin|acos|atan|sinh|cosh|acosh|exp|ln|log|powf)\(' crates/ \
     | grep -v sundials_libm.rs | grep -v '\.sun_'
   ```

## The libm rules

* Constant tables come from `tools/gen_libm_constants.py` (Python stdlib
  only) or are transcribed from a named MIT/SunPro source. **Never write a
  table from memory.** Regenerate and diff before trusting one.
* Every function must be covered by `tools/libm_differential.sh`, which
  measures it against the host libm *and* against a 113-bit
  `__float128` reference. The test asserts either bit-identity with the
  host (when the algorithm is provably the same upstream source) or
  correct rounding — never a hand-picked tolerance.
* `--features host-libm` exists only for `tools/ab_host_libm.sh`. It is a
  diagnostic control, never a production configuration.

## Module layout

- Module = C file base name + `.rs`. Public `include/` headers fold into
  the matching module.
- Solver crates re-export every shared `sundials_core` module at root and
  provide a flat prelude (which includes `SunMath`) so examples can
  `use cvode_rs::prelude::*;`.
- One `[[example]]` entry per translated example; example name = C base
  name.

## The measurement pipeline

Run in this order; each step writes machine-readable state the next reads,
and none of it is edited by hand.

```bash
tools/c_requirements.sh              # what this machine has -> requirements.md
tools/c_build.sh                     # upstream C, out of source, into build/c
tools/c_examples_run.sh              # -> c-results/{index.tsv,raw/}
tools/rust_examples_run.sh           # -> rust-results/{index.tsv,raw/}
python3 tools/compare_results.py     # -> differences/{index.tsv,diffs/}
tools/ab_host_libm.sh                # -> differences/ab-host-libm.tsv
python3 tools/make_reports.py        # -> the .md files in all three
tools/libm_differential.sh           # -> logs/libm_differential.log, LIBM.md
```

**Never hand-edit a file under `c-results/`, `rust-results/` or
`differences/`.** They are generated. If a number there is wrong, the fix
is in the tool or in the port.

## Classifying a divergence

A Rust output that differs from the C output is a **port defect** only if
it still differs when the port is built `--features host-libm`. That is
what `tools/ab_host_libm.sh` decides.

**One carve-out, and only one.** The switch moves the libm and nothing
else, so it says nothing about the eleven `*_klu` examples: they run on the
pure-Rust sparse LU under *both* builds and differ either way by
construction. They are attributed instead by direct verification of the
replacement solver (`differences/ATTRIBUTION.md`). Any **other** variant
that survives the switch is a defect. Fix defects; document everything else
with its measured attribution.

## Workflow

- Commit after every ported file or coherent group.
- After EVERY build/test/run: `… 2>&1 | tee <log>` then **read the log**
  before the next edit.
- Max two attempts per failing command, then switch strategy.
- Read each in-scope C file exactly once, at translation time, completely.
  Never read excluded paths (GPU/MPI/KLU/LAPACK/Fortran/xbraid trees).
- Resume after context loss from this file + `README.md` + `git log`.
