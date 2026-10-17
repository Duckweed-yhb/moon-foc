# moon-foc

PMSM SVPWM modulation and coordinate transform numerical kernel in MoonBit.

Pure numerical core for field-oriented control: Clarke / Park / inverse-Park
transforms and space-vector PWM (sector detection, T1/T2 timing, overmodulation
clamping). No C FFI, no I/O — runs on wasm / wasm-gc / js / native.

## Install

```
moon add Duckweed/moon-foc
```

## Quick start

TODO

## Test

```
moon check --target wasm-gc
moon test --target wasm-gc
```

## MATLAB differential reproduction

TODO
