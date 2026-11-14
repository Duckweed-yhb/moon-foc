# moon-foc

[中文](./README.md) · English

PMSM field-oriented control numerical library in MoonBit: a closed current-loop
controller, a simplified motor model, plus SVPWM modulation and Clarke/Park transforms.

Pure numerical core for field-oriented control: space-vector PWM (six-sector
detection, T1/T2 active-vector timing, overmodulation clamping), Clarke /
Park / inverse-Park transforms, angle conversion, a `controller/` closed
current-loop object, a current-loop design layer that turns motor R/L plus a
target bandwidth into PI gains, two-phase current sampling (third-phase
reconstruction plus ADC sample-window checks), and a simplified `motor/`
electrical model for offline simulation. No C FFI, no I/O. Verified locally with MoonBit
0.1.20261104: wasm, wasm-gc, js and native all build, run the demo and pass
`moon test` (133/133 on each), with `moon check --deny-warn` clean on all four
targets.
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
  so `T1+T2 = Ts`, which keeps the reference direction and pushes the magnitude
  onto the hexagon edge.
- How much is clipped can be computed per direction: `hexagon_radius(alpha, beta,
  Vdc)` returns the hexagon boundary along that direction (exactly `Vdc/√3` on a
  sector axis, `2·Vdc/3` at a vertex), `project_to_hexagon` keeps the direction and
  lands the vector on that boundary, and `clipping_ratio` reports the fraction of
  magnitude removed. The proportional clamp and this geometry reach the same
  magnitude; the tests cross-check by projecting first and then running
  `action_times`, whose T1+T2 must come out at exactly Ts. Mode II (hold the
  magnitude, compress the phase, vertex-hold segments) needs per-fundamental angle
  state and is not implemented; only phase-preserving clipping is, so a 30 V
  reference is untouched at 0° and clipped by 7.62% at 30° with `Vdc = 48 V`.
  `examples/design_report` prints these boundary readings at the end.

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

Implemented and verified: d/q current tracking, voltage clamp, PI anti-windup,
the first-order dynamics of the simplified model, and model-based decoupling
feedforward. Not implemented (out of plan): speed loop, parameter identification,
sensorless observer, real I/O and FFI.

### Current-loop design

`controller/design.mbt` answers the inverse question: given the motor, what should
the gains be. The plant is taken as first order `P(s) = 1/(Ls + R)` and the
controller as `C(s) = Kp + Ki/s`; with zero-pole cancellation `Ki/Kp = R/L` the
loop magnitude reduces to `|C·P| = Kp/(L·ω)`, so the crossover lands at
`ω_c = Kp/(2πL)` with a 90° phase margin. Bandwidth therefore becomes a design
input:

```moon
let g = @controller.design_current_loop(0.5, 0.002, 800.0)  // R / L / target Hz
// g.kp() → 10.05 V/A, g.ki() → 2513 V/(A·s), Ki/Kp = 250 = R/L
let fc = @controller.crossover_hz(0.5, 0.002, g.kp(), g.ki())        // → 800 Hz
let pm = @controller.phase_margin_deg(0.5, 0.002, g.kp(), g.ki())    // → 90°
let loss = @controller.delay_phase_loss_deg(fc, 50.0e-6)             // → 14.4°
let after = @controller.margin_after_delay_deg(0.5, 0.002, g.kp(), g.ki(), 50.0e-6)  // → 75.6°
```

The 90° from the ideal model is only the starting point: a digital implementation
also carries one sample of delay (sampling plus PWM update), costing `360·f_c·Ts`
degrees. Pushing the same machine to 4 kHz with `Ts = 50 µs` burns 72° of that and
leaves 18°, which is what actually caps the achievable bandwidth.
`design_is_usable(..., ts, min_margin_deg)` judges against the post-delay margin;
the threshold is up to the caller's own engineering rules.

`examples/design_report` runs the whole flow: print the gains and margins, then feed
the same gains back into `FocController` + `PmsmModel`. Native local run
(2026-11-14, toolchain 0.1.20261104) with R=0.5 Ω, L=2 mH, Ts=50 µs, Vdc=48 V and a
target bandwidth of 800 Hz gives Kp=10.053 V/A, Ki=2513.3 V/(A·s), crossover 800 Hz,
ideal margin 90°, delay loss 14.4°, post-delay margin 75.6°, usable at a 45° floor;
the closed loop reaches iq=1.99999 A at 20 ms for a 2.0 A reference and settles to a
steady-state error of 2.2e-16 at 0.2 s.

```
moon run examples/design_report --target native
```

### Decoupling feedforward

The d and q axes are not independent in the rotating frame: `vd` carries
`−ωe·Lq·iq`, `vq` carries `ωe·(Ld·id + ψf)`. Both are disturbances from the PI's
point of view, and the faster the rotor turns the harder it is for the integrator
to grow them. `controller/feedforward.mbt` computes them from the motor data and
adds them before the voltage clamp:

```moon
let (vd_ff, vq_ff) = @controller.decoupling_terms(omega_e, ld, lq, psi_f, id, iq)
// ωe=400, Lq=1.2 mH, iq=5 A → vd_ff = -2.4 V
// Ld·id + ψf = 0.0524 Wb → vq_ff = 20.96 V
let (vd, vq) = @controller.apply_feedforward(vd_pi, vq_pi, vd_ff, vq_ff, 48.0)
```

`apply_feedforward` limits the magnitude of the combined vector
`sqrt(vd²+vq²)` to `Vdc/√3`, the same linear-region boundary `svpwm` uses. When the
sum exceeds it, both components are scaled by one factor so the direction is
preserved; clamping `vd` and `vq` separately would rotate the reference. A non-positive
or non-finite `vdc` disables the clamp and only sums, and non-finite components
return `(0, 0)` instead of injecting NaN.

`examples/feedforward_loop` runs the two variants side by side with identical
parameters and gains (iq step 0 → 5 A, Vdc 48 V, Ts 10 µs, PI tuned to 400 Hz).
Native local run (2026-11-14): at ωe=200 the time to enter the ±2 % band drops from
5.95 ms to 1.5 ms and the peak deviation from 4.999 A to 4.9157 A; at ωe=400 from
6.99 ms to 1.51 ms and 7.0343 A to 4.9357 A; at ωe=480 from 7.25 ms to 2.58 ms and
8.1312 A to 4.9691 A. All runs converge to 5 A at the end because the PI integrator
gives zero steady-state error anyway; the difference is entirely in the transient,
where the plain loop first has to integrate the back-EMF and overshoots on the way.

Limits: the feedforward uses nameplate model parameters, so any mismatch in
`Ld`/`Lq`/`ψf` shows up as residual error. There is no parameter identification,
no current prediction, and no dead-time term here; the module removes only these
two known disturbances.

### Current sampling

The three phase currents sum to zero at every instant, so production hardware
usually carries only two sensors or two shunt resistors and reconstructs the third
phase in software. `controller/sampling.mbt` exposes that step together with its
checks:

```moon
let ic = @controller.reconstruct_third(1.984, -0.972)          // → -1.012
let r = @controller.zero_sequence_residual(1.984, -0.972, ic)  // → 0
// single/double-shunt sampling needs a long enough low-side on-time
let margin = @controller.sample_window_margin(0.52, 50.0e-6, 1.5e-6)  // → 22.5 µs
let ok = @controller.window_ok(0.88, 50.0e-6, 1.5e-6)                 // → true, 4.5 µs left
let pairs = @controller.pick_sample_pair((0.52, 0.31, 0.88), 50.0e-6, 1.5e-6)
// → [(0, 1), (0, 2), (1, 2)], ranked by the smaller margin of each pair
```

An empty array from `pick_sample_pair` means none of the three phases has a usable
window, so this sample should be dropped rather than read as noise.
`zero_sequence_residual` is not part of the control path; it is the first signal for
an offset, a broken channel or two unsynchronised channels, and
`currents_consistent` turns that into a boolean against a tolerance.

`FocController::step_from_two_phases(ia, ib, θe, id_ref, iq_ref)` pushes the
reconstructed ic into one current-loop tick, with the sampled phases fixed to a/b.
When the pair changes tick to tick, `pair_currents(pair, i1, i2)` scatters the two
measurements back onto a/b/c and `FocController::step_from_pair(pair, i1, i2, θe,
id_ref, iq_ref)` drives a tick directly. The caller always chooses the pair; the
controller never picks it implicitly. An out-of-range index, a repeated phase or a
non-finite sample is rejected at the entry with a zero tuple instead of being fed
into the PI as a genuine zero current.

`examples/sampling_loop` closes the loop on two-phase sampling: one motor and one
set of design gains run two trajectories, A on three-phase ground truth and B on
two measured phases with the pair picked from the previous tick's duties. Local
native readings (2026-11-14): `|iq(A) − iq(B)|` stays at 0 across the whole run,
both settle at 1.9999999999999998 A by 0.2 s, the pair switches once (`(0,1)` to
`(0,2)`), and no tick lacks a usable pair. Adding a 0.02 A offset on phase a puts
iq at 1.98845 A, 0.01155 A off the reference; with only two sensors the residual
stays 0 - the third phase is computed, so that check cannot see a single-channel
offset; with an extra true phase c the residual reads 0.02 A.

```
moon run examples/sampling_loop --target native
```

`examples/design_report` prints these readings at the end: for duties
`(0.52, 0.31, 0.88)`, `Ts = 50 µs` and a 1.5 µs settling floor, the margins are
22.5 / 33 / 4.5 µs, the preferred pair is `(0,1)`, and the reconstruction gives
`ic = -1.012` with zero residual.

## Test

CI (`.github/workflows/ci.yml`) runs `moon fmt --check`, then a `wasm-gc` / `js` /
`native` matrix of `check --deny-warn` + `build` + `test`, plus a real run of
`moon run examples/demo --target native`. Local verification on 2026-11-14
(toolchain 0.1.20261104): `moon test` on wasm, wasm-gc, js and native each
report 133 passed / 0 failed, and `moon check --deny-warn` exits cleanly on all
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

133 cases cover: Clarke balanced three-phase and round-trip, Park at θ=0 and
θ=π/2, Park/inverse-Park round-trip, SVPWM sector detection across all six
sectors, linear and overmodulation timing, a hand-computed absolute baseline for
T1/T2 and the three-phase duties in the linear region, duty range and per-sector
order, angle normalization, 20 independent numeric fixtures, single-axis PI
proportional/integral/clamp/anti-windup, controller chain consistency and
closed-loop step tracking, the simplified motor model's first-order RL
response, pole-pair scaling, zero three-phase sum, and clamping of non-positive
pole pairs and inductance, plus 9 regressions on current-loop design (cancellation
ratio, crossover at target bandwidth, 90° ideal margin, delay loss conversion,
usability judged after delay, bandwidth monotonicity against margin, margin drop
when cancellation is off, invalid-input clamping, zero crossover when the loop
never crosses 0 dB), plus 12 regressions on current sampling (reconstruction closing
the three-phase sum, non-finite inputs clamped to zero, the sensor consistency
check including invalid tolerances, window margin as duty and period vary, invalid
window configuration rejected, sample-pair ranking, no candidate when all phases
are too narrow, the two-phase step matching the three-phase step bit for bit, phase-order restoration from a pair, a malformed pair or bad sample rejected, any pair matching the three-phase step, a bad pair leaving the PI state untouched, plus 7 regressions on overmodulation geometry (boundary equal to the inscribed radius on a sector axis, two thirds of the bus at a vertex, analytic boundary matching the clamped magnitude, projection preserving direction, a linear-region vector returned untouched, and a clipping ratio that is zero inside the linear region and positive beyond), plus 8 regressions on decoupling feedforward (back-EMF equal to ωe·ψf with zero speed and non-finite inputs degrading to zero, zero feedforward at standstill, the signs of the voltage equation including a negative vq shift when id is negative, a linear-region sum returned untouched, a magnitude clamp that keeps the direction, a bus-unknown case that only sums, and non-finite components kept out of the command).

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
