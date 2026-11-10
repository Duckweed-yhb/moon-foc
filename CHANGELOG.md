# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与语义化版本。

## [Unreleased]

### Fixed

- `svpwm/phase_voltages` 对非正 / 非有限母线电压返回 `(0,0,0)`：此前 `vdc<0` 会给出负相电压，NaN 会原样穿出去。
- `svpwm/modulation_index` 对非有限输入返回 0 而不是 NaN：NaN 流进比较只会得到 false（"没进过调制"），比显式 0 更难查；需要区分时用 `check_inputs`。
- 1 条测试覆盖上述两条（负电压、NaN 输入）。

### Changed

- 测试数 56 → 57。
## [0.1.7] - 2026-11-11

### Fixed

- `svpwm/action_times` 扇区越界不再静默算出负作用时间：传 0 或 7 时局部角会落到 `[0, π/3)` 之外，T1/T2 变负而调用方无感。现在扇区不在 1..6 时返回 `(0, 0)`，与「零矢量」同值，需要区分时用 `sector_of` 自行校验。
- `svpwm/dead_time_compensation` 跳过补偿的分支也做钳位：此前 `td<=0` 或 `ts<=0` 时原样返回，越界占空比会漏到下游。

### Changed

- 文档补充输入前提：`duties_from_voltages` 要求输入有限（NaN 会穿过钳位，因为 NaN 比较恒为 false），需要入口校验时用 `check_inputs`。
- 测试数 54 → 56。
## [0.1.6] - 2026-11-10

### Added

- `svpwm/duties_from_voltages`：载波法 SVPWM（零序注入 `(vmax+vmin)/2`），与空间矢量路径 `duties(α, β)` 在 `m ≤ 1.1547` 内数值一致（实测 72 个角度点最大偏差 1e-15），过调制区饱和到 ±1。
- `svpwm/dead_time_compensation`：按电流方向补偿死区，`sign(i)·td/ts`，钳位到 ±1；三相同号时是共模偏移，线电压不变。
- 7 条测试：两条调制路径的等价性（线性区内 72 点、过调制区饱和、零序注入中点对称）、死区补偿符号约定、缺省不补偿、钳位、共模不改变线电压。
## [0.1.5] - 2026-11-10

### Added

- `angle/electrical_to_mechanical`：电角度 → 机械角度（周期意义下的逆，输出落在 `[0, 2π/p)`，往返后电角度不变）；`pole_pairs <= 0` 返回 0。
- `svpwm/modulation_index` 与 `is_overmodulated`：调制比 m = |Vref|/(Vdc/√3) 与是否削顶。此前钳位只保证 T1+T2=Ts，调用方无从判断「已经进入过调制」。
- `svpwm/phase_voltages` 与 `line_voltages`：占空比 → 相电压 / 线电压，供观测器与反电势估算使用；线电压三者之和恒为 0。
- 6 条不变量测试：全圆 360 点占空比落在 [-1,1]、过调制区 T1+T2 ≤ Ts、扇区边界占空比连续、调制比边界 m=1、线电压和为零、电角度往返。

## [0.1.4] - 2026-11-10

### Added

- `svpwm/check_inputs`：校验 alpha / beta / ts / vdc 全部有限且 `ts > 0`、`vdc > 0`，不合法返回结构化 `Err`。NaN 判定用 IEEE 754 的 `x != x`、无穷用 `|x| > 1e308`，跨 wasm-gc / js / native 语义一致。
- `svpwm/duties_checked`：校验后再算占空比，让调用方能区分「算出来就是 0」与「输入不合法」。补 5 条单测（正常点、ts=0 / vdc=0 / 负 ts、NaN / Inf、退化输入返回零而非 NaN）。
- `duties` 对 `ts <= 0` 或 `vdc <= 0` 返回 `(0, 0, 0)`：此前会在 `2*T_on/Ts` 处产生 inf/NaN。

### Changed

- CI 从「只跑 wasm-gc」扩成矩阵：`wasm-gc` / `js` / `native` 三个目标各自 `check --deny-warn` + `build` + `test`，另加一个 job 用 `moon run examples/demo --target native` 把「可运行示例」变成 CI 事实。本包无 C FFI，三个目标行为应一致，逐个跑是让「跨后端可用」可验证而非声明。
- README 测试口径订正：此前写「33 passed」，实际已是 36 个用例（0.1.3 加的极对数边界与负角度归一化）；同时删掉「native / js 不属于 CI」的旧说法。本机 2026-11-10 复跑 native 36/36、wasm-gc 36/36；js 因本机没有可用 node，测试交给 CI。
- `examples/demo` 补极对数换算（机械角 0.1 rad × 32 极对 → 3.2 rad），覆盖 `angle/` 包；此前 demo 只用到 Clarke / Park / SVPWM。

## [0.1.3] - 2026-11-10

### Added

- `angle/` 补极对数边界（`pole_pairs = 0`）与负机械角度归一化用例；测试数 33 → 36。

### Changed

- `moon fmt` 全仓格式化；CI 增加 `moon fmt --check` 步骤。

## [0.1.2] - 2026-11-09

### Changed

- 英文 README 的夹具措辞与安装版本对齐到 0.1.2。
- `moon fmt` 全仓格式化；CI 增加 `moon fmt --check`。

## [0.1.1] - 2026-11-09

### Added

- `scripts/gen_fixtures.py`：20 组由 Python 按教材公式独立算出的数值基准，覆盖线性区与过调制区，期望值不取自本库输出。
- 六扇区全覆盖的扇区判断测试，以及 θ=π/6 的 T1/T2 与三相占空比手算绝对值基准。

### Changed

- 测试数 23 → 33；README 的测试命令补显式 `--target`。

## [0.1.0] - 2026-11-08

### Added

- 首次发布：`coord/` 的 Clarke / Park / 反变换，`svpwm/` 的扇区判断、T1/T2 与过调制限幅，`angle/` 的机械角度到电角度换算，`examples/demo`。
