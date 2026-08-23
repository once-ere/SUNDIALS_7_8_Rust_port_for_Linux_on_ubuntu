# SUNDIALS_7_8_Rust_port_for_Linux_on_ubuntu

A line-by-line translation of [SUNDIALS](https://github.com/LLNL/sundials)
7.8.0 into safe Rust — **no `unsafe`, no FFI, no external crates, no build
warnings** — and, unlike its predecessors, **no host C library on the
numerical path at all.**

Every elementary function the port evaluates (`exp`, `log`, `pow`, `expm1`,
`log1p`, `sin`, `cos`, `atan`, `asin`, `acos`, `sinh`, `cosh`, `acosh`) is
implemented in pure Rust in
[`crates/sundials_core/src/sundials_libm.rs`](crates/sundials_core/src/sundials_libm.rs),
and so is the sparse direct solver that replaces SuiteSparse KLU.

> ### This work is merged upstream
>
> All of it — the libm, the sparse LU, the eleven `*_klu` examples and the
> full measurement below — is now on the **`main` branch** of
> [**`SUNDIALS_7_8_Rust_port_for_Linux`**](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux),
> merged as
> [PR #1](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux/pull/1)
> (merge commit
> [`299a697`](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux/commit/299a697)).
> The result directories are vendored there **at the repository root**, the
> same layout they have here — [`c-results/`](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux/tree/main/c-results),
> [`rust-results/`](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux/tree/main/rust-results),
> [`differences/`](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux/tree/main/differences) and
> [`requirements.md`](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux/blob/main/requirements.md). They briefly lived under
> `evidence/ubuntu-2604-glibc243/`; that path is gone, and any link to it will
> 404.
>
> **Use that repository if you want the port.** This one is the working copy
> the measurement runs in: it holds the pipeline, the `upstream-c` symlink at
> the read-only SUNDIALS C tree, and the `build/` directories the scripts
> write to. The crate trees are the same code and the result directories are
> byte-identical — `tools/vendor_evidence.sh` there is a straight `rsync` from
> here, with no transformation at all now that both roots sit at the same
> depth.

## Headline results

All measured on **Ubuntu 26.04 LTS, x86-64, glibc 2.43, gcc 15.2.0,
cmake 4.2.3, rustc 1.96.1**.

| | result | evidence |
|---|---|---|
| C examples built and executed | **337 (example, argv) variants, all exit 0** | [`c-results/`](c-results/) |
| Rust examples built and executed | **199 variants: 190 ran, 9 have no counterpart** | [`rust-results/`](rust-results/) |
| C output vs Rust output | **175 of 190 comparable byte-for-byte identical (92.1 %)** | [`differences/`](differences/) |
| the other 15 | **8 are the libm, 7 are the sparse LU, 0 unaccounted for** → **0 port defects** | [`differences/ATTRIBUTION.md`](differences/ATTRIBUTION.md) |
| pure-Rust libm accuracy | **0.5000 ulp — correctly rounded — on all ten routines written here** | [`LIBM.md`](LIBM.md) |
| `exp`, `log`, `pow`, `acosh` vs host glibc | **100 % bit-identical** over 6 M + 25.9 M samples | [`LIBM.md`](LIBM.md) |
| `cargo build --workspace` | zero warnings, with and without `--features host-libm` | |
| `cargo test --workspace --lib` | **39 tests pass** across the workspace, 37 of them in `sundials_core` | |
| reproducibility | the pipeline was re-run from source and **every capture in the compared set came back byte-identical** | [`c-results/README.md`](c-results/README.md) |

Related: the same porting discipline and bit-identity methodology — applied
on Windows 11 via the sibling
[`SUNDIALS_7_8_Rust_port_for_Windows11`](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Windows11)
— also produced
[`rebound_rust`](https://github.com/once-ere/rebound_rust), a pure-Rust
translation of the [REBOUND](https://github.com/hannorein/rebound) 5.1.1
N-body code, verified bit-for-bit against its MSVC-compiled C reference.

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
wholesale — the solver translation itself was not re-derived. What is new
is that the port no longer depends on the host C library for anything
numerical, and the evidence for that. The tree now holds **144 modules and
119 examples**, the growth being the libm, the sparse LU and the eleven
`*_klu` examples they made portable.

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

**That claim has been measured, not just asserted.** The upstream repository
re-ran the same gate under the pure-Rust libm on **seven hosts** — every
distribution the original libm fingerprint sweep covered, including the one
excluded because of it, plus a second CPU architecture:

| build | host | glibc | gate |
|---|---|---|---|
| host libm | Debian 12 | 2.36 | 153 / 26 / 20 |
| host libm | Ubuntu 24.04 | 2.39 | 153 / 26 / 20 |
| host libm | Fedora 41 | 2.40 | 153 / 26 / 20 |
| host libm | Arch | 2.44 | **150 / 29 / 20** ← the problem |
| pure-Rust libm | Debian 12 | 2.36 | **145 / 34 / 20** |
| pure-Rust libm | Fedora 41 | 2.40 | **145 / 34 / 20** |
| pure-Rust libm | Debian 13 | 2.41 | **145 / 34 / 20** |
| pure-Rust libm | Ubuntu 26.04 | 2.43 | **145 / 34 / 20** |
| pure-Rust libm | Arch | 2.44 | **145 / 34 / 20** ← the fix |
| pure-Rust libm | Alpine 3.20.10 | **musl 1.2.5** | **145 / 34 / 20** ← a different libc entirely |
| pure-Rust libm | Debian 13 on **aarch64** *(emulated)* | 2.41 | **145 / 34 / 20** ← a different CPU architecture |

Same tally, and the *same 34 variants name for name*: the seven DIFF lists are
byte-identical files, all hashing to `6581e4918e5ab2c71ee6354f383a0f34`. That
spans glibc 2.36, 2.40, 2.41, 2.43, 2.44, musl 1.2.5 and aarch64, over two
rustc versions — so the result is toolchain-stable, **libc**-stable and
**architecture**-stable, not merely distribution-stable.

The aarch64 row is Debian 13 again — same image, same glibc, same rustc — so
its comparison against the x86-64 row of that image isolates the architecture
and nothing else. The two DIFF lists are byte-identical.

**Debian 13 has no host-libm row, and that is not an oversight.** The gate was
never run there under the host libm — only the fingerprint sweep was, and it
found 2.41 hashing the same as 2.39. The upstream documentation used to list
Debian 13 under "verified coverage" beside three distributions that *had* been
gate-run, which quietly promoted a prediction to a measurement; that has been
corrected upstream. Under the pure-Rust libm it is properly gate-run, which is
why the row exists on one side of the table only.

Arch is not an outlier any more — **nothing is**. The score no longer depends
on the host, which is the entire claim this repository was built to
establish.

The musl row is the one that makes the point hardest to argue with. Alpine
was previously excluded on evidence: a libm fingerprint sweep found it
disagreeing with glibc on `sin`, `cos`, `exp`, `log`, `asin`, `acos`, `atan`,
the hyperbolics *and* `pow` — everything except `sqrt`. That was a sound
reason to stay away while the port called those functions. It calls none of
them now, so the same row that condemned musl is the cleanest demonstration
of what the substitution bought: swap the entire C math library and not one
printed line moves.

Two limits on that, since the table invites over-reading. Only the reference
gate ran on Alpine — there is no C toolchain build there, so the
C-versus-Rust comparison in `differences/` and the libm differential were
**not** repeated on musl or on aarch64. And the aarch64 run is **QEMU
user-mode emulation on an x86-64 host, not arm64 silicon** — its log header
says `aarch64 [EMULATED]` for exactly that reason. QEMU implements `sqrt` and
fused multiply-add to the IEEE-754 specification, which pins them exactly, and
those are what the pure-Rust libm is built on, so a faithful emulator and real
hardware should agree; it cannot rule out an aarch64 codegen difference that
QEMU reproduces identically. Compiling for aarch64 is separately clean and
needs no emulation — `cargo check --target aarch64-unknown-linux-{gnu,musl}
--workspace --all-targets`, 0 errors and 0 warnings over 7 crates and 119
example targets.

The price is visible in the same table and is worth stating rather than
burying: 153 became 145 **everywhere**, not just on Arch. The eight variants
that flipped are exactly the eight the `host-libm` A/B attributes to the libm
(below), on all seven hosts, and they include the three that used to break
only on Arch. The port
stopped tracking the host's libm and now disagrees with eight stale
references instead — references generated by glibc routines that the next
section measures as *less* accurate. It is the right trade for reproducibility
and the wrong one for anyone whose acceptance criterion is "matches the
shipped `.out`". Evidence:
[`evidence/purerust-libm-gate/`](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux/tree/main/evidence/purerust-libm-gate).

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

Of 190 comparable example variants, 175 match the pristine C byte for byte.
The port is then rebuilt with `--features host-libm`, which changes exactly
one thing — the thirteen `SunMath` methods call the host C library — and
leaves every other line identical. 183 of the 190 match under that build.

So **8** of the 15 divergences are the libm, isolated with a single
controlled variable. Four of those eight are the ARKODE LSRK examples, the
same ones the predecessor saw break on glibc 2.44, for the same reason.

The remaining **7** are exactly the `*_klu` examples, and honesty requires
separating them: the switch does not touch the sparse linear solver, and
there is no KLU to switch back to, so no control build can reach them. They
are attributed instead by direct verification of the replacement — dense
Gaussian elimination agreement on 300 random systems, and, for
`idaHeat2D_klu`, its hand-packed CSC Jacobian checked entry by entry against
an independent reference and against finite differences of the residual.

One experiment and one argument, then, not two experiments. Nothing is left
unaccounted for, which is what "0 port defects" means here.

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
* 144 modules, one per upstream C file, keeping the exact C names and
  return-flag conventions (`CV_SUCCESS = 0`; negative fatal, positive
  recoverable). 119 examples.
* **Serial only.** No MPI, GPU, SuperLU, Fortran or XBraid backends — none
  of them is reachable without FFI.
* **KLU is no longer on that list.** SuiteSparse KLU is LGPL and could not
  be translated into this BSD-3 tree or called through FFI, so
  [`sundials_sparse_lu.rs`](crates/sundials_core/src/sundials_sparse_lu.rs)
  implements a left-looking sparse LU (Gilbert & Peierls) with KLU's
  documented threshold partial pivoting, under a faithful translation of
  SUNDIALS' own BSD-3 `sunlinsol_klu.c`. Nothing is derived from KLU,
  CSparse or any SuiteSparse source. **All 11 `*_klu` examples are ported
  and ran; 4 are byte-identical to the C.**
* What remains unported is the **9** SuperLU_MT `*_sps` / `*_slu` examples,
  and no comparison is lost with them: SuperLU_MT is not in the Ubuntu
  archive at any version, so the C side cannot build them either and there
  is no output on either side.

  See [`requirements.md`](requirements.md) §4 and §6.

### What is platform-bound and what is not

| | bound to this machine? |
|---|---|
| `c-results/` | **yes** — built by the host gcc against the host glibc |
| `differences/` | **yes** — it compares against `c-results/` |
| `rust-results/` | no — the port has no host dependence left |
| the sparse-LU verification | no — it is checked against dense elimination and finite differences, not against a host library |
| the ulp figures in `LIBM.md` | no — they are against a 113-bit reference |
| the *agreement* figures in `LIBM.md` | **yes** — they describe glibc 2.43 |
| the `.stderr` captures of the MPI examples | **yes** — see below |

**A worked example of that last row.** On 2026-08-14 a re-run moved 63
`.stderr` captures that had never moved before — every MPI example, each
gaining the same complaint from OpenMPI's topology layer:

```
hwloc 2.13.0 received invalid information.
Failed with error: intersection without inclusion
while inserting Group0 (P#16 subtype Cluster groupkind 222-0 ...)
```

That is hwloc mis-reading this CPU's hybrid core layout. Nothing in this
repository changed; the host's view of its own topology did. It is worth
knowing because 63 moved files look alarming in a `git diff`, and the reason
they are harmless is checkable rather than a matter of trust: none of them is
in the compared set, `tools/compare_results.py` opens only `.stdout`, and all
337 runs still exited 0 with unchanged `.stdout`.

```bash
git log --stat -1 08dd895 -- c-results | grep stderr | head
grep -rl hwloc c-results/raw --include='*.stderr' | wc -l
```

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
| [`VERIFICATION.md`](VERIFICATION.md) | the predecessor's per-variant matrix against the shipped `.out` files (inherited). **Not superseded by `differences/` — a different question.** See below. |
| [`POW_FMA_EXACTNESS.md`](POW_FMA_EXACTNESS.md) | how far the deterministic `pow` is bit-exact (inherited) |

## Two gates, not one score

`VERIFICATION.md` reports **145** of 199 byte-identical under the current
build (153 before the pure-Rust libm, and that older figure is what its
tables still show, captioned as historical); `differences/` reports 175 of
190. Both cover the same 199 `(example, argv)` variants, so it is easy to
read the second as a correction of the first. It is not — they compare Rust
against different things:

* **against the `.out` files shipped inside SUNDIALS 7.8.0**
  (`VERIFICATION.md`). Asks whether the port reproduces the *published*
  reference. External and unfakeable, but it charges the port for a decade of
  libm drift — which is precisely why it fell from 153 to 145 when the port
  stopped sharing glibc's rounding.
* **against the upstream C compiled from source on this machine minutes
  apart** (`differences/`, glibc 2.43, pure-Rust libm). Asks whether the
  translation agrees with its original, machine held fixed. Cannot be blamed
  for reference drift, but its reference is one this project built.

Neither supersedes the other, and the cross-tabulation says more than
either: **all 26** of the first gate's divergences are byte-identical to
pristine C rebuilt here, and the 8 variants the `host-libm` control build
names are *precisely* the 8 that flipped from IDENTICAL under it. Two
experiments sharing nothing but the source tree pick the same set. Run
`python3 tools/cross_gate.py` in the
[upstream repository](https://github.com/once-ere/SUNDIALS_7_8_Rust_port_for_Linux)
to print it.

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
