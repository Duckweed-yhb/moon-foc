# Provenance and licensing

This file records where the code, the design references, and the test data of
`moon-foc` come from.

## Origin of the source code

All MoonBit source under `svpwm/`, `coord/`, `angle/`, `pi/`, `controller/`,
`motor/`, and `examples/` was written for this project. No source file was
copied from another project.

## Design references

| Reference | Licence | What was taken |
|---|---|---|
| Public motor-control textbooks (Clarke / Park / SVPWM derivations) | — | The mathematical formulas and the amplitude-invariant convention. Implemented independently. |
| TI C2000 Motor Control SDK documentation | TI public documentation | Step-by-step cross-check of the SVPWM sequence (sector detection, T1/T2, zero-vector placement). No code copied. |
| ST Motor Control SDK documentation | ST public documentation | Same role: behaviour cross-check for the modulation chain. No code copied. |

`moon search svpwm` and `moon search pmsm` returned no MoonBit module at the time
of writing; `hwlxmm/dsp` provides Clarke / Park transforms for instantaneous
power, which this project does not duplicate. See the README for the boundary.

## Test data

- `scripts/gen_fixtures.py` is an in-house Python script. It computes the 20
  fixture cases from the textbook formulas and prints the assertions; the
  expected values are generated outside the MoonBit library and pasted into
  `coord/coord_test.mbt` and `svpwm/svpwm_test.mbt`.
- The hand-computed baseline at θ=π/6 was calculated by hand from the same
  formulas.
- No third-party capture, corpus, or dataset is included.

## AI assistance

AI coding tools were used for formula boilerplate, test drafts, and
documentation drafts. The project scope, the pure-math boundary, the choice of
fixtures, and the verification of expected values were done by the author.
AI-generated tests were checked against the textbook formulas before being kept.

## Identity

All commits are authored by `Duckweed-yhb`, the same person who registered the
project. Most commits use `3071974740@qq.com`; one early commit used a
placeholder address (`duckweed@example.com`) from a default Git configuration.
Both are the same author; no other person's name or account is used.

## Licence

MIT. See `LICENSE`.
