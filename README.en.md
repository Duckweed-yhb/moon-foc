# moon-foc

[中文](./README.md) · English

PMSM field-oriented control numerical library in MoonBit: a closed current-loop
controller, a simplified motor model, plus SVPWM modulation and Clarke/Park transforms.

Pure numerical core for field-oriented control: space-vector PWM (six-sector
detection, T1/T2 active-vector timing, overmodulation clamping), Clarke /
Park / inverse-Park transforms, angle conversion, a `controller/` closed
current-loop object and a simplified `motor/` electrical model for offline
simulation. No C FFI, no I/O. Verified locally with MoonBit 0.1.20261104:
wasm, wasm-gc, js and native all build, run the demo and pass `moon test`
(97/97 on each), with `moon check --deny-warn` clean on all four targets.
On the simplified model, `examples/foc_sim` holds id_ref=0, iq_ref=2.0 A: a
native local run on 2026-11-13 tracks iq to 1.9999975 A within 20 ms with id=0,
and from 0.04 s reaches iq≈2.0 A, id=0, steady vq≈1.0 V.

## Install

Published to mooncakes as `Duckweed/moon-foc@0.1.13` (Latest 0.1.13, MIT,
published 2026-11-10):

```
moon add Duckweed/moon-foc@0.1.13
```

The bundled `examples/demo` can still be run directly from this repository
without installing the package.

## Quick start

```moon
// examples/demo/main.mbt
let (alpha, beta) = @coord.clarke(1.0, -0.5, -0.5)   // → alpha=1, beta=0
let (d, q) = @coord.park(alpha, beta, 0.7)            // rotate by theta=0.7 rad
let sector = @svpwm.sector_of(alpha, beta)            // → 1
let (da, db, dc) = @svpwm.duties(alpha, beta, 0.0001, 24.0)  // Vdc=24V, Ts=100us
```

Run the bundled demo (the default wasm target works, and other targets are
supported too):

```
moon run examples/demo                    # default wasm
moon run examples/demo --target native
moon run examples/demo --target js
```

Conventions:

- Amplitude-invariant Clarke: `alpha = (2/3)(ia - ib/2 - ic/2)`, `beta = (1/√3)(ib - ic)`.
- Park: `d = alpha*cosθ + beta*sinθ`, `q = -alpha*sinθ + beta*cosθ`.
- SVPWM duties are centered around 0 (range [-1, 1]); 0 means 50% on-time.
- Linear modulation limit: `|Vref| <= Vdc/√3`. Beyond that, T1/T2 are scaled
  so `T1+T2 = Ts`.

## Current-loop controller and simplified motor model

`controller/` wires the existing blocks into a per-step object: sample three-phase
currents → Clarke → Park → d/q dual PI → inverse Park → SVPWM, returning observed
d/q currents, d/q voltage commands and three-phase duties. Transforms, PI and
modulation reuse the packages above; this package only orchestrates the chain and
keeps internal state.

```moon
let ctrl = @controller.FocController::new(
  2.0, 1000.0,   // d-axis kp / ki
  2.0, 1000.0,   // q-axis kp / ki
  1.0e-4, 24.0,  // Ts / Vdc
  -12.0, 12.0,   // voltage command clamp
)
let (id, iq, vd, vq, da, db, dc) = ctrl.step(ia, ib, ic, theta_e, id_ref, iq_ref)
```

- If any sampled input is non-finite it does not enter PI state; observed values and
  duties return zero together; `reset()` clears both d/q integrators.
- `motor/` is an offline simplified PMSM model: R, Ld, Lq, ψf and pole pairs are
  parameterized; d/q first-order equations are integrated with explicit Euler, and
  electrical speed is given externally (the model itself does not run a speed loop).
- `examples/foc_sim` steps the current loop on this simplified model at standstill,
  iq_ref=2.0 A, id_ref=0 A; the native local convergence numbers are listed in the
  opening paragraph above.

```
moon run examples/foc_sim --target native
```

Implemented and verified: d/q current tracking, voltage clamp, PI anti-windup, and
the first-order dynamics of the simplified model. Not implemented (out of plan):
speed loop, d/q decoupling compensation, sensorless observer, real I/O and FFI.

## Test

CI (`.github/workflows/ci.yml`) runs `moon fmt --check`, then a `wasm-gc` / `js` /
`native` matrix of `check --deny-warn` + `build` + `test`, plus a real run of
`moon run examples/demo --target native`. Local verification on 2026-11-13
(toolchain 0.1.20261104): `moon test` on wasm, wasm-gc, js and native each
report 97 passed / 0 failed, and `moon check --deny-warn` exits cleanly on all
four targets. The wasm target is not in the CI matrix and is only verified
locally.

```
moon check --deny-warn --target wasm-gc
moon test --target wasm-gc
# local additional targets:
moon check --deny-warn --target wasm
moon test --target wasm
moon check --deny-warn --target native
moon test --target native
moon check --deny-warn --target js
moon test --target js
```

97 cases cover: Clarke balanced three-phase and round-trip, Park at θ=0 and
θ=π/2, Park/inverse-Park round-trip, SVPWM sector detection across all six
sectors, linear and overmodulation timing, a hand-computed absolute baseline for
T1/T2 and the three-phase duties in the linear region, duty range and per-sector
order, angle normalization, 20 independent numeric fixtures, single-axis PI
proportional/integral/clamp/anti-windup, controller chain consistency and
closed-loop step tracking, and the simplified motor model's first-order RL
response, pole-pair scaling, zero three-phase sum, and clamping of non-positive pole pairs and inductance.

## Independent numeric fixtures

`coord/coord_test.mbt` and `svpwm/svpwm_test.mbt` each carry 20 fixed cases whose
expected values were computed independently by `scripts/gen_fixtures.py` (plain
Python, textbook formulas), not taken from this library's output. The script
sweeps current amplitudes 1 / 5 / 10 / 20 A and Park angles from 0 to 1.9π, so a
few cases land in the overmodulation region and pin the `T1+T2 = Ts` clamping.

Regenerate the printed block if the formulas ever change:

```
python scripts/gen_fixtures.py
```

The numeric fixtures in this repository are the in-tree oracle, generated by the
Python script above. A MATLAB / Simulink model with the same motor parameters is
optional and not required to reproduce them.

## License

MIT © 2026 Duckweed-yhb

## AI tool usage

This project was built with AI assistance, but the goal, scope, quality boundaries, and
open-source compliance are controlled by the author:

- **AI assisted with**: boilerplate for Clarke / Park / SVPWM functions, test case generation,
  initial README draft.
- **Human controlled**: project selection (motor control numerical kernel), the pure-math
  boundary (no I/O), the differentiation from `hwlxmm/dsp` (SVPWM chain vs instantaneous
  power), the design of the 20 fixture inputs, hand-computed expected values.
- **How AI-generated code is verified**: each AI-generated test is checked against textbook
  formulas; Clarke/Park round-trip tests verify mathematical consistency; SVPWM sector
  detection uses 6 angle points; CI must be green before merge.
- **What is not done**: no code copied from TI C2000 / ST MCSDK (only math steps cross-referenced);
  no self-hosting expected values; no AI-generated test data taken as truth.
