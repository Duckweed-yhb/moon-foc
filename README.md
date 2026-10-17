# moon-foc

PMSM SVPWM modulation and coordinate transform numerical kernel in MoonBit.

Pure numerical core for field-oriented control: space-vector PWM (six-sector
detection, T1/T2 active-vector timing, overmodulation clamping) plus Clarke /
Park / inverse-Park transforms and mechanical-to-electrical angle conversion.
No C FFI, no I/O — runs on wasm / wasm-gc / js / native.

## Install

```
moon add Duckweed/moon-foc
```

## Quick start

```moon
// examples/demo/main.mbt
let (alpha, beta) = @coord.clarke(1.0, -0.5, -0.5)   // → alpha=1, beta=0
let (d, q) = @coord.park(alpha, beta, 0.7)            // rotate by theta=0.7 rad
let sector = @svpwm.sector_of(alpha, beta)            // → 1
let (da, db, dc) = @svpwm.duties(alpha, beta, 0.0001, 24.0)  // Vdc=24V, Ts=100us
```

Run the bundled demo:

```
moon run examples/demo
```

Conventions:

- Amplitude-invariant Clarke: `alpha = (2/3)(ia - ib/2 - ic/2)`, `beta = (1/√3)(ib - ic)`.
- Park: `d = alpha*cosθ + beta*sinθ`, `q = -alpha*sinθ + beta*cosθ`.
- SVPWM duties are centered around 0 (range [-1, 1]); 0 means 50% on-time.
- Linear modulation limit: `|Vref| <= Vdc/√3`. Beyond that, T1/T2 are scaled
  so `T1+T2 = Ts`.

## Test

```
moon check --target wasm-gc
moon test --target wasm-gc
```

23 cases cover: Clarke balanced three-phase and round-trip, Park at θ=0 and
θ=π/2, Park/inverse-Park round-trip, SVPWM sector at three angles, linear and
overmodulation timing, duty range, and angle normalization.

## MATLAB differential reproduction

Expected values are hand-computed from the textbook formulas (not derived from
this library's own output). To reproduce independently:

1. Pick 20 fixed inputs `(ia, ib, ic, θ)` (e.g. from the 32-pole-pair /
   1250 Nm PMSM parameter set used in the eVTOL challenge project).
2. Compute `(alpha, beta)` with the Clarke formula above, then `(d, q)` with
   Park, then `(duty_a, duty_b, duty_c)` with SVPWM.
3. Hard-code the results as assertions in `coord/coord_test.mbt` and
   `svpwm/svpwm_test.mbt`.

The MATLAB script and the Simulink reference model (same motor parameters) are
maintained out-of-tree; this repository only carries the numeric fixtures.

## License

MIT © 2026 Duckweed-yhb
