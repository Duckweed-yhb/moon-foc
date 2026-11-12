# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与语义化版本。

## [Unreleased]

### Fixed

- **死区补偿量纲差 2 倍**：本包的占空比域是 `d ↔ d·Vdc/2` 的相电压（见 `phase_voltages`），死区丢掉的伏秒是 `Td·Vdc`，平均电压误差 `(Td/Ts)·Vdc`，换回占空比要乘 `2/Vdc`，即 `Δd = 2·Td/Ts`。旧实现是 `Td/Ts`，只补了一半，而测试把 `0.005` 一起写进了期望值，等于把错误锁住。**这是行为变更**：同一组电流/死区下补偿量翻倍。
- `duties` / `duties_from_voltages` 在极端但有限的输入下会返回 NaN：入口的 `finite` 只看得见原始输入，`alpha²` 在 `|alpha| > 1.34e154` 时已溢出成 Inf、`vdc` 极小时 `√3·ts/vdc` 也会溢出，再乘 0 就是 NaN。README 承诺「不返回 NaN」，现在两条路径都加了最终守卫（结果非有限则返回零矢量）。
- `angle/normalize_angle` 会返回恰好 `2π`：`-1e-17 + 2π` 在 double 里正好等于 `2π`，违反自己写的 `[0, 2π)`。极小负角是「两个接近的量相减」「编码器零位残差」的常见产物，调用方按 `floor(θ/(π/3))` 查扇区表会得到索引 6。
- `svpwm/switching_sequence`：① 「超时」判据用绝对容差 `1e-18`，而比例钳位后 `t1+t2 = ts·(1±1e-16)`，`ts ≥ 0.01 s` 时合法的过调制输入会被判非法、返回空数组，现在改成相对容差；② NaN 时长为被当成「零时长段」丢掉，返回一个段数合理、总时长等于 Ts 的假序列，现在直接返回空数组。
- `dead_time_compensation` 的 NaN 出口：`td`/`ts` 为 NaN 时穿过 `<= 0` 检查。
- `check_inputs` 的上界不敌平方溢出：`alpha² + beta²` 会先平方，`|alpha| > √DBL_MAX ≈ 1.34e154` 时平方已溢出成 Inf，而入口只判「是不是 Inf」，于是 `duties_checked` 会把一个只能兜底返回零矢量的输入报成 `Ok`。现在按「能安全平方」的范围挡（参考矢量与 ts/vdc 都限 1e154，vdc 另设 1e-300 下界）。

### Changed

- README 的「两条调制路径在 `m ≤ 1.1547` 内一致」是错的，真实一致性边界是 `m ≤ 1`：载波法的峰值占空比恰好等于 m，`m=1` 就开始削顶；`duties` 也是在 `m>1` 开始比例钳位。过调制区两者策略不同（一个保相位、一个逐相饱和），已写明不要混用。

## [0.1.13] - 2026-11-11

### Added

- `svpwm/switching_sequence_of`：从 `alpha/beta` 直接得到七段式开关序列，内部串起 `sector_of` → `action_times` → `switching_sequence`。手工三步最容易在扇区参数上传错、或漏掉输入校验；组合入口在非有限值 / `ts`、`vdc` 非正时返回空数组。3 条测试：与手工三步逐位一致、非法输入返回空、过调制同样钳位且总时长等于 Ts。

### Changed

- 测试数 74 → 77。

### Added

- `svpwm/overmodulation_test.mbt`：过调制钳位的性质测试。由作用时间反推合成矢量，断言两条隐含承诺：① 比例缩放保持 `t1:t2`，所以合成矢量方向与参考方向一致（相位不失真，误差 < 1e-9）；② 钳位后幅值落在内切圆 `Vdc/√3` 与外接圆 `2Vdc/3` 之间——低于内切圆说明压过头，高于外接圆说明没钳住。另外在线性区断言合成幅值等于参考幅值。

### Changed

- 测试数 72 → 74。

### Fixed

- `svpwm/switching_sequence` 丢掉零时长段：过调制边界（t0=0）或扇区边界（t1/t2=0）时七段式会退化，旧实现仍返回 7 段、其中若干时长为 0，下游照写就是一个零长度脉冲。现在返回的每一段时长都大于 0（过调制边界退化为 4 段：Vk、Vk+1、Vk+1、Vk）。

### Changed

- 测试数 70 → 72（零矢量段消失、零作用矢量段消失）。

## [0.1.12] - 2026-11-11

### Added

- `svpwm/switching_sequence`：七段式开关序列（0→Vk→Vk+1→7→Vk+1→Vk→0），返回 `(开关状态, 持续时间)`；`on_time_of_phase` 把序列折回每相高电平时间。占空比告诉 MCU「每相导通多久」，序列告诉它「按什么顺序切」，测试用「序列折算的高电平时间 == (duty+1)/2·ts」把两条路径钉在一起。
- 4 条测试：全圆 72 点序列时长之和 == ts、逐相与占空比一致、序列对称且首尾为零矢量、非法扇区/超时返回空。

### Changed

- 测试数 66 → 70。

### Added

- `scripts/check-release.ps1` + CI 的 `release-meta` job：校验 `moon.mod` 的 version、CHANGELOG 最新版本段标题、README 里所有 `<模块>@x.y.z` 与 `Latest x.y.z` 三处一致，并拒绝重复的版本段。发布时漏改任何一处都不会报错，只会让文档慢慢变成谎话；现在它们对不上就红。

## [0.1.11] - 2026-11-11

### Fixed

- `pi/Pi::new` 对写反的输出限幅（`out_min > out_max`）在内部交换：此前会产出一个上下颠倒的限幅区间，输出语义完全不成立。

### Changed

- `examples/demo` 增加 PI 演示：0.1 A 阶跃的三步响应，以及饱和后积分器被冻住（抗饱和）的输出。
- 测试数 65 → 66。

## [0.1.10] - 2026-11-11

### Added

- `pi/` 包：单轴离散 PI 电流调节器（`kp` / `ki` / `dt` / 输出限幅）。条件积分抗饱和——输出顶到限幅且误差继续同向推时冻结积分器，退饱和在一个采样步内完成；非有限误差不进状态。补 7 条单测（纯 P、积分累积、双向饱和、抗饱和、复位、坏采样、dt<=0）。

### Changed

- 测试数 58 → 65。

## [0.1.9] - 2026-11-11

### Fixed

- `svpwm/duties` 与 `svpwm/action_times` 对非有限输入（NaN / Inf）返回零矢量：主入口此前会把 NaN 一路送进 T1/T2 与占空比，控制环拿到 NaN 既不会报错也看不出问题。

### Changed

- 测试数 57 → 58。

## [0.1.8] - 2026-11-10

### Fixed

- `svpwm/phase_voltages` 对非正 / 非有限母线电压返回 `(0,0,0)`：此前 `vdc<0` 会给出负相电压，NaN 会原样穿出去。
- `svpwm/modulation_index` 对非有限输入返回 0 而不是 NaN：NaN 流进比较只会得到 false（"没进过调制"），比显式 0 更难查；需要区分时用 `check_inputs`。

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
