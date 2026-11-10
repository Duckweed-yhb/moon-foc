# moon-foc

[English](./README.en.md)

MoonBit 实现的 PMSM SVPWM 调制与坐标变换数值内核。

面向磁场定向控制（FOC）的纯数值核心：空间矢量 PWM（六扇区判断、T1/T2 有效矢量作用时间、过调制钳位），外加 Clarke / Park / 反 Park 变换，以及机械角度到电角度的换算。不使用 C FFI，不做任何 I/O。后端覆盖口径以本机 MoonBit 0.1.20261012 实测为准：native、wasm-gc 可构建、可运行示例、41 个用例全过；js 可构建、`check --deny-warn` 干净，但本机没有可用的 node，测试交给 CI；legacy wasm 未运行，原因是本机缺少 `core.core` 预编译产物（工具链环境问题，不是代码错误），因此不宣称「四后端测试矩阵本机全绿」。

## 安装

已发布到 mooncakes：`Duckweed/moon-foc@0.1.4`（Latest 0.1.4，MIT，2026-11-10 发布）：

```
moon add Duckweed/moon-foc@0.1.4
```

仓库自带的 `examples/demo` 也可以不安装包，直接在本仓库运行。

## 快速开始

```moon
// examples/demo/main.mbt
let (alpha, beta) = @coord.clarke(1.0, -0.5, -0.5)   // → alpha=1, beta=0
let (d, q) = @coord.park(alpha, beta, 0.7)            // 按 theta=0.7 rad 旋转
let sector = @svpwm.sector_of(alpha, beta)            // → 1
let (da, db, dc) = @svpwm.duties(alpha, beta, 0.0001, 24.0)  // Vdc=24V, Ts=100us
```

显式指定目标后端运行自带示例（裸默认目标 wasm 因本机缺 core bundle 无法运行）：

```
moon run examples/demo --target native
# 另一可运行目标：
moon run examples/demo --target js
```

约定：

- 幅值不变 Clarke：`alpha = (2/3)(ia - ib/2 - ic/2)`，`beta = (1/√3)(ib - ic)`。
- Park：`d = alpha*cosθ + beta*sinθ`，`q = -alpha*sinθ + beta*cosθ`。
- SVPWM 占空比以 0 为中心（范围 [-1, 1]）；0 表示 50% 导通时间。
- 线性调制区边界：`|Vref| <= Vdc/√3`；超出后对 T1/T2 做缩放，使 `T1+T2 = Ts`。

输入校验：

- `check_inputs(alpha, beta, ts, vdc) -> Result[Unit, String]`：四个输入必须全部有限，且 `ts > 0`、`vdc > 0`。
- `duties_checked(...) -> Result[(Double, Double, Double), String]`：同上校验通过再去算占空比；需要区分「算出来就是 0」与「输入不合法」时用它。
- `duties` 本身保持原签名：遇到 `ts <= 0` 或 `vdc <= 0` 时返回 `(0, 0, 0)`，不返回 NaN——控制环里 NaN 会一路传到 PWM 比较寄存器，故障点离源头很远。

## 测试

CI（`.github/workflows/ci.yml`）跑三件事：`moon fmt --check`；`wasm-gc` / `js` / `native` 三个目标各自的 `check --deny-warn` + `build` + `test`；以及 `moon run examples/demo --target native`。本机 2026-11-10 实测：`moon test --target native`、`--target wasm-gc` 均为 41 passed / 0 failed，三个目标的 `moon check --deny-warn` 与 `moon build` 全部干净退出；`js` 后端的测试本机跑不了（PATH 里没有可用的 node），交给 CI 验证，因此不宣称本机四后端全绿。legacy wasm 测试未运行（本机缺 core.core bundle，属工具链环境问题而非代码错误），不宣称四后端测试矩阵全绿。

```
moon check --deny-warn --target wasm-gc
moon test --target wasm-gc
# 与 CI 矩阵同口径的另外两个目标：
moon check --deny-warn --target native
moon test --target native
moon check --deny-warn --target js
moon test --target js          # 需要可用 node，CI 上由 runner 提供
```

41 个用例覆盖：Clarke 三相平衡与正逆往返、θ=0 与 θ=π/2 的 Park、Park / 反 Park 往返、六扇区全范围扇区判断、线性区与过调制区作用时间、线性区 T1/T2 与三相占空比的手算绝对基准、占空比范围与各扇区顺序、角度归一化与极对数边界，以及 20 组独立数值夹具，其期望值由库外独立算出。

## 独立数值夹具

`coord/coord_test.mbt` 与 `svpwm/svpwm_test.mbt` 各含 20 组固定用例，期望值由 `scripts/gen_fixtures.py`（纯 Python、教材公式）独立算出，不取自本库输出。脚本扫描电流幅值 1 / 5 / 10 / 20 A 与 Park 角 0 到 1.9π，因此少量用例落在过调制区，用于锁定 `T1+T2 = Ts` 的钳位行为。

公式若有变更，重新生成打印块：

```
python scripts/gen_fixtures.py
```

数值夹具由 `scripts/gen_fixtures.py` 生成，不依赖 MATLAB 即可复现；同参数的 MATLAB / Simulink 模型可选，不在本仓库内。

## 许可证

MIT © 2026 Duckweed-yhb

来源、第三方参考、测试数据与 AI 使用范围见 [`PROVENANCE.md`](PROVENANCE.md)。

## AI 工具使用说明

本项目在 AI 协助下建成，但选题、范围、质量边界与开源合规由作者把控：

- **AI 协助部分**：Clarke / Park / SVPWM 函数样板、测试用例生成、README 初稿。
- **人工把控部分**：选题（电机控制数值内核）、纯数学边界（不做 I/O）、与 `hwlxmm/dsp` 的区分（SVPWM 调制链 vs 瞬时功率）、20 组数值夹具的输入设计、手算期望值。
- **AI 生成代码的验证方式**：每个 AI 生成的测试都对照教材公式核验；Clarke/Park 往返测试验证数学一致性；SVPWM 扇区判断取 6 个角度点；合并前 CI 必须通过。
- **未做的事项**：未复制 TI C2000 / ST MCSDK 代码（只交叉参照数学步骤）；不自造自证的期望值；不把 AI 生成的测试数据当真值。
