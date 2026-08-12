# ATTRIBUTION — why each divergence happens, proved by experiment

`README.md` in this directory reports *how many* variants differ.
This file answers the only question that matters about them: **is the Rust
translation wrong, or is the difference the deliberate pure-Rust libm?**

The answer is not argued. It is measured, by an experiment anyone can
re-run in about a minute.

## The experiment

`crates/sundials_core` carries a cargo feature, `host-libm`, that changes
exactly one thing: the `SunMath` trait's thirteen methods call the host C
library (`f64::sin`, `f64::exp`, …) instead of
`crates/sundials_core/src/sundials_libm.rs`. Every other line of the port
— all 141 translated modules, all 108 translated examples — is byte for
byte the same code in both builds.

So if a variant differs from the C binary in the default build but matches
it in the `host-libm` build, the difference is caused by the libm
substitution and by nothing else. If it differs in *both*, the translation
itself is at fault and it is a defect to be fixed.

```bash
tools/ab_host_libm.sh
```

## The result

| build | comparable variants | byte-identical to the pristine C |
|---|---:|---:|
| default (pure-Rust libm) | 179 | **171** |
| `--features host-libm` | 179 | **179** |

**Zero variants remain divergent when the host libm is restored.**
That is the measurement behind the claim of **0 port defects**: it is not
an inspection result or a judgement, it is a controlled A/B with one
variable.

Raw data: [`ab-host-libm.tsv`](ab-host-libm.tsv), one row per variant, with
the default-build class and the host-libm-build class side by side.

## The eight variants, and what they have in common

| variant | worst relative difference | elementary functions on its hot path |
|---|---|---|
| `arkode/C_serial/ark_analytic_lsrk` | 2.8e-01 | `sinh`, `cosh`, `acosh`, `log` (LSRK stage-count formula) |
| `arkode/C_serial/ark_analytic_lsrk_varjac` | 2.0e-01 | same |
| `arkode/C_serial/ark_analytic_lsrk_domeigest` | 2.6e-01 | same |
| `arkode/C_serial/ark_analytic_lsrk_domeigest` (2nd argv) | 6.0e-01 | same |
| `arkode/C_serial/ark_kpr_mri` (argv variant) | 1.3e-03 | `sin`, `cos` in the reference solution |
| `cvodes/serial/cvsDiurnal_FSA_kry -sensi sim t` | (structural) | `sin` in the diurnal source term |
| `idas/serial/idasSlCrank_dns` | 7.4e-13 | `sin`, `cos` in the crank geometry |
| `idas/serial/idasSlCrank_FSA_dns` | (step counts) | same |

Four of the eight are the ARKODE **LSRK** examples. That is not a
coincidence and it was predictable: `SUNRsinh`, `SUNRcosh`, `SUNRacosh` and
`SUNRlog` are called from exactly one place in the whole library,
[`crates/arkode_rs/src/arkode_lsrkstep.rs:87`](../crates/arkode_rs/src/arkode_lsrkstep.rs:87),
and they feed the formula that chooses the *number of stages*. A last-bit
difference there changes an integer, which changes the method, which
changes everything downstream. The sibling Linux repository observed the
same four variants breaking on Arch's glibc 2.44 for the same reason —
glibc changed `sinh`, `cosh` and `acosh` between 2.41 and 2.44.

The other four are ordinary adaptive-integrator chaos: a one-ulp
difference in `sin` inside a right-hand side moves an error estimate,
which moves a step-size decision, which moves the whole trajectory. Note
what the magnitudes actually are — `idasSlCrank_dns` differs in the 13th
significant digit of one printed number, and `ark_kpr_mri` in the third
digit of one error estimate on one of 74 lines.

## Which side is closer to the true answer?

The pure-Rust one, measurably. `tools/libm_differential.sh` measures every
function against a 113-bit `__float128` reference (see
[`../LIBM.md`](../LIBM.md)):

| function | pure-Rust max error | host glibc 2.43 max error |
|---|---|---|
| `sin`, `cos`, `atan`, `asin`, `acos` | 0.5000 ulp | 0.5039 – 0.5185 ulp |
| `expm1`, `log1p` | 0.5000 ulp | 0.7420 – 0.7996 ulp |
| `sinh`, `cosh` | 0.5000 ulp | 0.9813 – 1.7510 ulp |
| `exp`, `log`, `acosh` | as glibc (same source) | same |

0.5000 ulp is correct rounding — the smallest error a binary64 result can
have. So on these eight variants the C column is not a target the Rust
column failed to hit; it is the less accurate of the two.

## What would count as a defect

Any row of `ab-host-libm.tsv` whose `host_libm_class` is `DIFFERS`.
There are none. If a future change introduces one, `tools/ab_host_libm.sh`
prints it under "variants that remain divergent even with the host libm
(real port defects)" and it must be fixed before the change lands
(`../CLAUDE.md` § "Classifying a divergence").
