# requirements.md — what this machine has, and what it is missing

**Machine of record.** Ubuntu 26.04 LTS ("Resolute Raccoon"), x86-64,
glibc 2.43, gcc 15.2.0, cmake 4.2.3, rustc/cargo 1.96.1, 24 cores.
Everything in `c-results/`, `rust-results/` and `differences/` was produced
on this machine.

Regenerate this table yourself at any time — it needs no root and installs
nothing:

```bash
tools/c_requirements.sh
```

---

## 1. Status table (probed, not assumed)

| component | status | what it unlocks | apt package |
|---|---|---|---|
| C compiler (cc) | present | everything | `gcc` |
| C++ compiler | present | `examples/*/CXX_*` | `g++` |
| Fortran compiler | present | `examples/*/F2003_*` | `gfortran` |
| CMake | present | the whole C build | `cmake` |
| OpenMP runtime | present | `examples/*/C_openmp` | ships with `gcc` |
| libquadmath | present | the ulp figures in `LIBM.md` | ships with `gcc` |
| BLAS | present | the `*_dnsL` / `*_bndL` examples | `libblas-dev` |
| LAPACK | present | the `*_dnsL` / `*_bndL` examples | `liblapack-dev` |
| MPI compiler wrapper | present (`/usr/bin/mpicc`) | — | — |
| **MPI headers (`mpi.h`)** | **MISSING** | `examples/*/parallel`, `C_parallel`, `CXX_parallel` (≈30 examples) | `libopenmpi-dev` |
| **KLU (SuiteSparse)** | **MISSING** | the 11 `*_klu` examples | `libsuitesparse-dev` |
| **SuperLU_MT** | **MISSING** | the 9 `*_sps` / `*_slu` examples | _not packaged for Ubuntu_ |
| **SuperLU_DIST** | **MISSING** | `examples/cvode/superludist`, `arkode/CXX_superludist` | `libsuperlu-dist-dev` |
| **hypre** | **MISSING** | `examples/*/parhyp`, `C_parhyp`, `CXX_parhyp` | `libhypre-dev` |
| **PETSc** | **MISSING** | `examples/*/petsc`, `C_petsc` | `petsc-dev` |
| **Trilinos (Tpetra)** | **MISSING** | `examples/ida/trilinos` | `libtrilinos-tpetra-dev` |
| **CUDA (`nvcc` on `PATH`)** | **MISSING from `PATH`** — the toolkit is installed at `/usr/local/cuda` | `examples/*/cuda`, `mpicuda` | already installed; see §3 |
| **Kokkos** | **MISSING** | `examples/cvode/kokkos` | `libkokkos-dev` |
| **MAGMA** | **MISSING** | `examples/cvode/magma` | `libmagma-dev` |
| **Ginkgo** | **MISSING** | `examples/cvode/ginkgo` | _not packaged for Ubuntu_ |
| **RAJA** | **MISSING** | `examples/*/raja`, `mpiraja` | _not packaged for Ubuntu_ |
| **oneMKL / SYCL (`icpx`)** | **MISSING** | `examples/cvode/CXX_onemkl`, `CXX_sycl` | _not packaged for Ubuntu_ |
| **XBraid** | **MISSING** | `examples/arkode/CXX_xbraid` | _not packaged for Ubuntu_ |

## 2. What to install

Nothing below is required for the **C-versus-Rust comparison**, which is
built entirely from the six *serial* example directories. They widen how
much of the upstream example suite can be built and run at all.

```bash
sudo apt install libopenmpi-dev libsuitesparse-dev libhypre-dev petsc-dev libsuperlu-dist-dev libtrilinos-tpetra-dev libkokkos-dev libmagma-dev
```

Ordered by how many examples each unlocks:

| package | examples unlocked | note |
|---|---|---|
| `libopenmpi-dev` | ≈30 | largest single win; `mpicc` is present but `mpi.h` is not |
| `libsuitesparse-dev` | 11 | the `*_klu` sparse-direct examples |
| `libhypre-dev` | 6 | needs MPI as well |
| `petsc-dev` | 5 | needs MPI as well |
| `libsuperlu-dist-dev` | 3 | needs MPI as well |
| `libtrilinos-tpetra-dev` | 2 | |
| `libkokkos-dev` | 2 | |
| `libmagma-dev` | 1 | needs CUDA |

## 3. Cannot be fixed with apt

| component | why | consequence |
|---|---|---|
| **SuperLU_MT** | not in the Ubuntu archive at any version; upstream ships source only | the 9 `*_sps` / `*_slu` examples cannot be built here. These are 9 of the 20 examples the Rust port excludes by design, so the comparison is unaffected. |
| **Ginkgo, RAJA, XBraid, oneMKL** | not in the Ubuntu archive | 8 GPU/parallel-framework examples cannot be built. None has a serial Rust counterpart. |
| **CUDA on `PATH`** | the toolkit *is* installed (`/usr/local/cuda/bin/nvcc`) but is not on `PATH`, so CMake does not find it | fix without installing anything: <br>`export PATH=/usr/local/cuda/bin:$PATH` and re-run `tools/c_build.sh`. GPU examples additionally need a working device at run time. |

## 4. Rust-side requirements

The Rust workspace deliberately has **no dependencies at all** — no
external crates, no build script, no system library beyond what `std`
itself links:

```bash
cargo build --workspace        # nothing is downloaded
cargo test  --workspace --lib
```

`cargo` was therefore never used to install a package, and no package name
needs to be added to this file on the Rust side. That is a design
constraint of the port (`CLAUDE.md` hard rule 2), not an accident.

Optional, and only for regenerating documentation rather than for building:

| tool | used by | needed? |
|---|---|---|
| `python3` (stdlib only) | `tools/gen_libm_constants.py` | only to regenerate the libm constant tables |
| `python3` + `mpmath` | independent cross-check of those tables | optional; `pip install mpmath` |
| `libquadmath` (ships with gcc) | `tools/libm_oracle.c` | without it the differential still runs, but reports agreement only, not ulp accuracy |
