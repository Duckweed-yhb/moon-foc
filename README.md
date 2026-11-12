# moon-foc

[English](./README.en.md)

MoonBit 实现的 PMSM SVPWM 调制与坐标变换数值内核。

面向磁场定向控制（FOC）的纯数值核心：空间矢量 PWM（六扇区判断、T1/T2 有效矢量作用时间、过调制钳位），外加 Clarke / Park / 反 Park 变换，以及机械角度到电角度的换算。不使用 C FFI，不做任何 I/O。后端覆盖以本机 MoonBit 0.1.20261104 实测为准：wasm、wasm-gc、js、native 四个后端均可构建、77 个用例全过、`check --deny-warn` 干净。

## 安装

已发布到 mooncakes：`Duckweed/moon-foc@0.1.13`（Latest 0.1.13，MIT，2026-11-10 发布）：

```
moon add Duckweed/moon-foc@0.1.13
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

运行自带示例（默认 wasm 后端即可，也可显式指定其它后端）：

```
moon run examples/demo                    # 默认 wasm
moon run examples/demo --target native
moon run examples/demo --target js
```

约定：

- 幅值不变 Clarke：`alpha = (2/3)(ia - ib/2 - ic/2)`，`beta = (1/√3)(ib - ic)`。
- Park：`d = alpha*cosθ + beta*sinθ`，`q = -alpha*sinθ + beta*cosθ`。
- SVPWM 占空比以 0 为中心（范围 [-1, 1]）；0 表示 50% 导通时间。
- 线性调制区边界：`|Vref| <= Vdc/√3`；超出后对 T1/T2 按比例缩放，使 `T1+T2 = Ts`——比例保持，所以合成矢量**方向不变**（相位不失真），幅值被压到六边形边上，落在 `[Vdc/√3, 2Vdc/3]`。这是「比例钳位」而非 MPE/顶点保持策略，测试里两条性质都钉住了。
  `modulation_index` 给出 m = |Vref|/(Vdc/√3)，`is_overmodulated` 在 m > 1 时返回 true
  （钳位只保证 T1+T2=Ts，不告诉调用方「已经削顶了」，需要报警/降额时看这两个）。
- 角度：`mechanical_to_electrical(mech, p)` 给出电角度；`electrical_to_mechanical(elec, p)`
  是**周期意义下**的逆，输出落在 `[0, 2π/p)`，满足往返后回到同一个电角度。
- 第二条调制路径：`duties_from_voltages(va, vb, vc, Vdc)` 用载波法（零序注入 `(vmax+vmin)/2`）
  算占空比，与 `duties(α, β)` 在 **`m ≤ 1`** 内数值一致（实测偏差 1e-15），超出后
  饱和到 ±1 而不是外推。**不是 1.1547**：载波法的峰值占空比恰好等于 m
  （注入后峰值相值 `√3·Vm/2`，除以 `Vdc/2` 得 `√3·Vm/Vdc = m`），所以 m=1 就开始削顶；
  `duties` 在 `T1+T2 > Ts` 即 m>1 开始比例钳位，两条路径的一致性边界就是 m=1。
  过调制区两者策略不同（`duties` 保相位、载波法逐相饱和会失真相位），不要混用。
  两条路径互证：任一条改了扇区映射，另一条立刻报差异。
- 死区补偿：`dead_time_compensation(da, db, dc, ia, ib, ic, td, ts)` 按电流方向加
  `sign(i)·2·td/ts` 并钳位到 ±1（占空比域是 `d ↔ d·Vdc/2` 的相电压，死区丢的伏秒是
  `Td·Vdc`，换回占空比要乘 `2/Vdc`）；三相同号时是共模偏移，线电压不变（测试锁住这条性质）。
- 开关序列：`switching_sequence(sector, t1, t2, ts)` 给七段式的 `(开关状态, 持续时间)` 序列（0→Vk→Vk+1→7→Vk+1→Vk→0），零时长段会被丢掉（过调制边界退化时不会给出零脉冲）；`on_time_of_phase` 把序列折回每相高电平时间——与 `duties` 自洽，测试里两条路径互相校验。手工三步（`sector_of` → `action_times` → `switching_sequence`）最容易把扇区传错，`switching_sequence_of(alpha, beta, ts, vdc)` 是它们的组合入口，输入不合法时返回空数组。
- 输出侧：`phase_voltages(da, db, dc, Vdc)` = duty·Vdc/2；`line_voltages` 给出
  (vab, vbc, vca)，三者之和恒为 0（零序分量的一次差分），观测器与反电势估算用它。

输入校验：

- `check_inputs(alpha, beta, ts, vdc) -> Result[Unit, String]`：四个输入必须全部有限，且 `ts > 0`、`vdc > 0`。
- `duties_checked(...) -> Result[(Double, Double, Double), String]`：同上校验通过再去算占空比；需要区分「算出来就是 0」与「输入不合法」时用它。
- `duties` 本身保持原签名：遇到 `ts <= 0`、`vdc <= 0` 或输入非有限（NaN / Inf）时返回 `(0, 0, 0)`，不返回 NaN——控制环里 NaN 会一路传到 PWM 比较寄存器，故障点离源头很远。

## 电流环 PI

`pi/` 包是 FOC 电流环的「误差 → 电压指令」环节，和调制分开：调制是「电压 → 占空比」的映射，PI 是反馈。

```moon
let iq_pi = @pi.Pi::new(0.5, 20.0, 1.0e-4, -12.0, 12.0)   // kp / ki / dt / 下限 / 上限
let vq = iq_pi.step(iq_ref - iq_meas)
iq_pi.reset()                                              // 切模式 / 重新使能时清积分
```

- 抗饱和用条件积分：输出顶到限幅、且误差还在把它往同方向推时冻结积分器；误差反向就照常积分，退饱和在一个采样步内完成。
- 非有限误差（NaN / Inf）不进入状态，返回当前积分项的限幅值——坏采样不会污染调节器。
- `dt <= 0` 按 0 处理，退化成纯 P。

## 测试

CI（`.github/workflows/ci.yml`）跑三件事：`moon fmt --check`；`wasm-gc` / `js` / `native` 三个目标各自的 `check --deny-warn` + `build` + `test`；以及 `moon run examples/demo --target native`。本机 2026-11-11 实测（工具链 0.1.20261104）：wasm、wasm-gc、js、native 四个后端 `moon test` 均为 77 passed / 0 failed，四个目标 `moon check --deny-warn` 与 `moon build` 全部干净退出。

```
moon check --deny-warn --target wasm-gc
moon test --target wasm-gc
# 与 CI 矩阵同口径的另外两个目标：
moon check --deny-warn --target native
moon test --target native
moon check --deny-warn --target js
moon test --target js          # 需要可用 node，CI 上由 runner 提供
```

77 个用例覆盖：Clarke 三相平衡与正逆往返、θ=0 与 θ=π/2 的 Park、Park / 反 Park 往返、六扇区全范围扇区判断、线性区与过调制区作用时间、线性区 T1/T2 与三相占空比的手算绝对基准、占空比范围与各扇区顺序、角度归一化与极对数边界，以及 20 组独立数值夹具，其期望值由库外独立算出。

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
