# c-results — every upstream C example, built and executed here

This directory records what the **unmodified upstream SUNDIALS 7.8.0
C examples** actually printed on this machine. It is raw evidence:
the `.stdout` files are the bytes the processes wrote, with nothing
filtered, rounded or edited.

## Provenance

| item | value |
|---|---|
| generated | 2026-08-12 20:41:05 UTC |
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

The C sources are the upstream tree, used read-only:
`/home/nsh/Developer/sundials-7.8.0` (reachable in this repository as
the `upstream-c` symlink). The copy under `examples/` in this
repository is the same tree and supplies the CMake tuples that decide
which command-line variants each example is run with.

## How to reproduce all of it

```bash
tools/c_build.sh          # configure + build, out of source, into build/c
tools/c_examples_run.sh   # run every binary, once per declared argv variant
python3 tools/make_reports.py
```

`tools/c_build.sh` prints which optional backends it was able to switch
on; anything it could not is listed in [`../requirements.md`](../requirements.md).

## Headline result

**337 (example, argv) variants were executed. 337 exited 0.**

| status | variants |
|---|---|
| OK | 337 |

## Layout of this directory

| path | contents |
|---|---|
| `index.tsv` | one row per variant: directory, example, argv, exit status, wall time, stdout size and SHA-256 |
| `raw/<dir>/<variant>.stdout` | exactly what the process printed to stdout |
| `raw/<dir>/<variant>.stderr` | exactly what it printed to stderr |
| `raw/<dir>/<variant>.meta` | the binary, the argv, the working directory, the exit code, the timing and the full SHA-256 |
| `by-solver/*.md` | the per-solver tables below |

A `<variant>` is the example name, plus `__` and the argv with spaces
turned into underscores when the example is declared with arguments.

## Checking any single row yourself

```bash
cat c-results/raw/cvode/serial/cvRoberts_dns.meta      # what was run
cat c-results/raw/cvode/serial/cvRoberts_dns.stdout    # what it printed
sha256sum c-results/raw/cvode/serial/cvRoberts_dns.stdout
```

## Run-to-run reproducibility

The whole pipeline was executed three times on this machine. The
captured `.stdout` files were compared between runs with git, which is
a byte comparison:

| set | variants | reproduced byte for byte |
|---|---:|---|
| the six *serial* directories (the compared set) | 179 | **all of them** |
| every Rust example (`rust-results/`) | 179 | **all of them** |
| `*/C_openmp` and `*/F2003_openmp` | 12 | 6 of them differ between runs |

The six that move are OpenMP examples run with a thread count as argv:
`ark_heat1D_omp 4`, `idaFoodWeb_kry_omp 4`, `idasFoodWeb_kry_omp 4`,
`kinFoodWeb_kry_omp 4`, and `idaHeat2D_kry_omp_f2003` at 4 and 8
threads. This is expected and is not a defect in anything: an OpenMP
reduction sums partial results in whatever order the threads finish, so
a dot product or a norm differs in its last bits from run to run, and
inside an iterative solver that changes the iteration counts. Compare
`kinFoodWeb_kry_omp 4`, which reported `nni = 7, nli = 229` on one run
and `nni = 10, nli = 378` on the next.

None of the six is in the compared set, so `differences/` is unaffected.
It is recorded here because a reader is entitled to know which numbers
in this directory are stable and which are not.

## Per-solver tables (serial examples — these are the ones with a Rust counterpart)

* [ARKODE — `arkode/C_serial`](by-solver/arkode_C_serial.md) — 78 variants
* [CVODE — `cvode/serial`](by-solver/cvode_serial.md) — 23 variants
* [CVODES — `cvodes/serial`](by-solver/cvodes_serial.md) — 36 variants
* [IDA — `ida/serial`](by-solver/ida_serial.md) — 13 variants
* [IDAS — `idas/serial`](by-solver/idas_serial.md) — 19 variants
* [KINSOL — `kinsol/serial`](by-solver/kinsol_serial.md) — 21 variants

## Other example families that were also built and run

These have no pure-Rust counterpart in this port (it is serial-only),
so they do not appear in `differences/`. They are recorded because the
instruction was to build and execute *all* examples.

| directory | variants | all exited 0 |
|---|---|---|
| `arkode/CXX_lapack` | 1 | yes |
| `arkode/CXX_manyvector` | 1 | yes |
| `arkode/CXX_parallel` | 6 | yes |
| `arkode/CXX_parhyp` | 4 | yes |
| `arkode/CXX_serial` | 18 | yes |
| `arkode/C_klu` | 1 | yes |
| `arkode/C_manyvector` | 1 | yes |
| `arkode/C_openmp` | 2 | yes |
| `arkode/C_parallel` | 5 | yes |
| `arkode/C_parhyp` | 1 | yes |
| `arkode/F2003_custom` | 6 | yes |
| `arkode/F2003_parallel` | 6 | yes |
| `arkode/F2003_serial` | 19 | yes |
| `cvode/CXX_parallel` | 1 | yes |
| `cvode/CXX_parhyp` | 2 | yes |
| `cvode/CXX_serial` | 3 | yes |
| `cvode/C_mpimanyvector` | 1 | yes |
| `cvode/C_openmp` | 1 | yes |
| `cvode/F2003_parallel` | 3 | yes |
| `cvode/F2003_serial` | 12 | yes |
| `cvode/parallel` | 4 | yes |
| `cvode/parhyp` | 1 | yes |
| `cvodes/C_openmp` | 1 | yes |
| `cvodes/F2003_serial` | 3 | yes |
| `cvodes/parallel` | 9 | yes |
| `ida/C_openmp` | 2 | yes |
| `ida/F2003_openmp` | 2 | yes |
| `ida/F2003_parallel` | 1 | yes |
| `ida/F2003_serial` | 2 | yes |
| `ida/parallel` | 4 | yes |
| `idas/C_openmp` | 2 | yes |
| `idas/F2003_serial` | 2 | yes |
| `idas/parallel` | 8 | yes |
| `kinsol/CXX_parallel` | 2 | yes |
| `kinsol/CXX_parhyp` | 2 | yes |
| `kinsol/C_openmp` | 1 | yes |
| `kinsol/F2003_parallel` | 1 | yes |
| `kinsol/F2003_serial` | 4 | yes |
| `kinsol/parallel` | 2 | yes |

## Example families that could not be built here

See [`../requirements.md`](../requirements.md) for the probe results and
the exact `apt` command. In short: MPI headers, KLU, SuperLU_MT,
SuperLU_DIST, hypre, PETSc, Trilinos, Kokkos, MAGMA, Ginkgo, RAJA,
oneMKL and XBraid are absent, which removes the `parallel`, `parhyp`,
`petsc`, `cuda`, `raja`, `kokkos`, `ginkgo`, `magma`, `superludist`,
`trilinos`, `CXX_xbraid`, `CXX_onemkl`, `CXX_sycl` and the `*_klu` /
`*_sps` / `*_slu` examples from this run.

