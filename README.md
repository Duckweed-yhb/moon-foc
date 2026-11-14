# moon-foc

[English](./README.en.md)

MoonBit 实现的 PMSM 磁场定向控制（FOC）数值库：闭环电流环控制器、简化电机模型，以及底层 SVPWM 调制与坐标变换。

面向磁场定向控制（FOC）的纯数值核心：空间矢量 PWM（六扇区判断、T1/T2 有效矢量作用时间、过调制钳位），Clarke / Park / 反 Park 变换，机械角度到电角度的换算，外加串起整条电流环的 `controller/` 控制器对象、从电机参数整定 PI 增益的设计层、电流采样侧的第三相重构与采样窗口判据，以及离线仿真用的简化 `motor/` 电气模型。不使用 C FFI，不做任何 I/O。后端覆盖以本机 MoonBit 0.1.20261104 实测为准：wasm、wasm-gc、js、native 四个后端均可构建、151 个用例全过、`check --deny-warn` 干净。

## 安装

已发布到 mooncakes：`Duckweed/moon-foc@0.1.13`（Latest 0.1.13，MIT，2026-11-10 发布）：

```
moon add Duckweed/moon-foc@0.1.13
```

仓库自带的 `examples/demo` 也可以不安装包，直接在本仓库运行。

> 交付说明（申报书 vs 现状、与「明确不做」的边界、验证证据）：[DELIVERY.md](./DELIVERY.md)。

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

## 看一眼输出：一个开关周期的三相桥臂时序

数字表看不出「三相什么时候开、开多久」。`examples/waveform` 把一个开关周期的
七段式序列直接画出来：

```
moon run examples/waveform --target native
```

```
=== 线性区 m=0.8, theta=30deg ===
|Vref| = 11.085125168440817 V,  m = 0.8,  sector = 1
duties  a=0.8  b=0  c=-0.8
seq     [0 5e-6][4 2e-5][6 2e-5][7 1e-5][6 2e-5][4 2e-5][0 5e-6]
a  |...######################################################...|
b  |...............##############################...............|
c  |...........................######...........................|

=== 过调制 m=1.5, theta=30deg ===
duties  a=1  b=0  c=-1
seq     [4 2.5e-5][6 2.5e-5][6 2.5e-5][4 2.5e-5]     ← 零矢量段消失，退化为 4 段
```

三件事一眼可查：扇区对不对（`seq` 里是 0→V1→V2→7→…）、七段式是否对称
（首尾两段等长）、三相是否互补（`a` 与 `c` 镜像，`b` 居中）。

约定：

- 幅值不变 Clarke：`alpha = (2/3)(ia - ib/2 - ic/2)`，`beta = (1/√3)(ib - ic)`。
- Park：`d = alpha*cosθ + beta*sinθ`，`q = -alpha*sinθ + beta*cosθ`。
- SVPWM 占空比以 0 为中心（范围 [-1, 1]）；0 表示 50% 导通时间。
- 线性调制区边界：`|Vref| <= Vdc/√3`；超出后对 T1/T2 按比例缩放，使 `T1+T2 = Ts`——比例保持，所以合成矢量**方向不变**（相位不失真），幅值被压到六边形边上，落在 `[Vdc/√3, 2Vdc/3]`。这是「比例钳位」而非 MPE/顶点保持策略，测试里两条性质都钉住了。
  `modulation_index` 给出 m = |Vref|/(Vdc/√3)，`is_overmodulated` 在 m > 1 时返回 true
  （钳位只保证 T1+T2=Ts，不告诉调用方「已经削顶了」，需要报警/降额时看这两个）。
- 削顶多少可以分方向算：`hexagon_radius(alpha, beta, Vdc)` 给出该方向上的六边形边界幅值（扇区轴线恰为 `Vdc/√3`，顶点方向为 `2·Vdc/3`），`project_to_hexagon` 保持方向把矢量压到边界，`clipping_ratio` 给出被削掉的幅值比例。比例钳位与这条几何落在同一个幅值上，测试里用「投影后再算 `action_times`，T1+T2 刚好等于 Ts」互证。**模式 II**（幅值保持、相位压缩与顶点保持段）需要跨基波周期维护角度状态，本库没做，这里只有保持相位的削顶 - 同一个幅值在扇区轴线方向会被削、在顶点方向不会。`examples/design_report` 末尾打印这组边界读数：`Vdc = 48 V` 时内切圆 27.7128 V、顶点 32 V，30 V 的矢量在 0° 方向不削顶、在 30° 方向被削 7.62%、投影后幅值 27.7128 V。
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

## 电流环控制器与简化电机模型

`controller/` 把现有环节串成一个逐拍调用的对象：采样三相电流 → Clarke → Park → d/q 双 PI → 反 Park → SVPWM，返回观测 d/q 电流、d/q 电压指令与三相占空比。坐标变换、PI、调制都复用前面的包，本包只做链路编排与内部状态保存。

```moon
let ctrl = @controller.FocController::new(
  2.0, 1000.0,   // d 轴 kp / ki
  2.0, 1000.0,   // q 轴 kp / ki
  1.0e-4, 24.0,  // Ts / Vdc
  -12.0, 12.0,   // 电压指令限幅
)
let (id, iq, vd, vq, da, db, dc) = ctrl.step(ia, ib, ic, theta_e, id_ref, iq_ref)
```

- 任一采样输入非有限时不进 PI 状态，观测值与占空比一并返回零；`reset()` 清空 d/q 两侧积分器。
- `motor/` 是离线仿真用的简化 PMSM 模型：R、Ld、Lq、ψf、极对数参数化，d/q 一阶方程显式欧拉积分，电角速度外部给定。另有 `motor/mechanical.mbt` 的单惯量机械方程（`J·dωm/dt = Te − TL − B·ωm`），把电流算出的电磁转矩积成转速，供速度环用。
- `examples/foc_sim` 在这个简化模型上跑电流环时域步进：静止、iq 给定 2.0 A、id 给定 0 A。本机 native 实测（2026-11-13，工具链 0.1.20261104）：20 ms 内 iq 跟踪到 1.9999975 A，id 保持 0；0.04 s 起 iq≈2.0 A、id=0、稳态 vq≈1.0 V。

```
moon run examples/foc_sim --target native
```

已实现并验证的边界：电流环 d/q 跟踪、电压限幅、PI 抗饱和、简化模型一阶动态、解耦前馈、速度外环与单惯量机械方程、电压极限下的弱磁给定（稳态近似）。仍未实现（计划外）：无感观测器、四象限运行、真实 I/O 与 FFI。

### 电流环整定

`controller/design.mbt` 回答的是上一节的反问题：手上这台电机，增益取多少。被控对象按一阶 `P(s) = 1/(Ls + R)`，控制器 `C(s) = Kp + Ki/s`，取零极点对消 `Ki/Kp = R/L`，环路增益幅值化为 `|C·P| = Kp/(L·ω)`，交叉频率落在 `ω_c = Kp/(2πL)`、相位裕度 90°。所以带宽可以直接当设计输入：

```moon
let g = @controller.design_current_loop(0.5, 0.002, 800.0)  // R / L / 目标带宽 Hz
// g.kp() → 10.05 V/A, g.ki() → 2513 V/(A·s)，Ki/Kp = 250 = R/L
let fc = @controller.crossover_hz(0.5, 0.002, g.kp(), g.ki())        // → 800 Hz
let pm = @controller.phase_margin_deg(0.5, 0.002, g.kp(), g.ki())    // → 90°
let loss = @controller.delay_phase_loss_deg(fc, 50.0e-6)             // → 14.4°
let after = @controller.margin_after_delay_deg(0.5, 0.002, g.kp(), g.ki(), 50.0e-6)  // → 75.6°
```

理想模型算出的 90° 只是起点，数字实现还有一拍延时（采样 + PWM 更新），相位按 `360·f_c·Ts` 下降。同一组参数把带宽抬到 4 kHz、`Ts = 50 µs`，延时吃掉 72°，实际只剩 18° —— 这就是「带宽能开到多高」的硬约束。`design_is_usable(..., ts, min_margin_deg)` 按计入延时后的裕度判断，门槛值由调用方按自己的规范给。

`examples/design_report` 把这套流程走完一遍：先打印增益与裕度，再把同一组增益接回 `FocController` + `PmsmModel` 闭环。本机 native 实测（2026-11-14，工具链 0.1.20261104）：R=0.5 Ω、L=2 mH、Ts=50 µs、Vdc=48 V、目标带宽 800 Hz → Kp=10.053 V/A、Ki=2513.3 V/(A·s)、交叉频率 800 Hz、理想裕度 90°、延时损失 14.4°、计入延时 75.6°、45° 门槛下可用；闭环 iq 给定 2.0 A，20 ms 到 1.99999 A，0.2 s 稳态误差 2.2e-16。

```
moon run examples/design_report --target native
```

### 解耦前馈

d 轴和 q 轴在旋转坐标系里不独立：`vd` 里有 `−ωe·Lq·iq`，`vq` 里有 `ωe·(Ld·id + ψf)`。这两项对 PI 都是外部扰动，转速越高越难靠积分器「等出来」。`controller/feedforward.mbt` 按电机参数把它们直接算出来，先与前馈相加再限幅：

```moon
let (vd_ff, vq_ff) = @controller.decoupling_terms(omega_e, ld, lq, psi_f, id, iq)
// ωe=400、Lq=1.2 mH、iq=5 A → vd_ff = -2.4 V
// Ld·id + ψf = 0.0524 Wb → vq_ff = 20.96 V
let (vd, vq) = @controller.apply_feedforward(vd_pi, vq_pi, vd_ff, vq_ff, 48.0)
```

`apply_feedforward` 的限幅针对合成矢量幅值 `sqrt(vd²+vq²)`，上限取 `Vdc/√3`（与 `svpwm` 的线性区同一条边界）；超限时按同一比例缩放两个分量，方向不变 - 单独钳 `vd`、`vq` 会改掉矢量方向，等于让电流环去追一个偏了角的参考。`vdc` 非正或非有限时不限幅，只做相加：母线不知道的时候，限幅等于凭空假设一个边界。任一分量非有限时返回 `(0, 0)`，不把 NaN 加进指令。

`examples/feedforward_loop` 把加与不加前馈并排跑（同一组参数、同一组增益，iq 0 → 5 A，Vdc 48 V，Ts 10 µs，PI 按 400 Hz 整定）。本机 native 实测（2026-11-14）：ωe=200 时进入 ±2% 带从 5.95 ms 缩短到 1.5 ms，最大偏差 4.999 A → 4.9157 A；ωe=400 时 6.99 ms → 1.51 ms，最大偏差 7.0343 A → 4.9357 A；ωe=480 时 7.25 ms → 2.58 ms，最大偏差 8.1312 A → 4.9691 A。三者末拍都收敛到 5 A（PI 有积分，稳态误差本来就为零），差别全在起步这一段：不加前馈时 PI 得先把反电动势「积」出来，过程中 iq 冲过头再拉回。

边界：前馈用的是模型参数，`Ld`/`Lq`/`ψf` 与实际电机的偏差会直接变成残差；这里没有参数辨识、没有电流预测、也没有把占空比死区算进去，前馈只负责把交叉项与反电动势这两项已知扰动扣掉。

### 速度外环与机械模型

前面几节都停在电流层。`motor/mechanical.mbt` 补上机械方程，`controller/speed.mbt` 在其上做转速 PI，两者串起来才有「速度给 iq 给定、电流环跟 iq」的级联：

```moon
let mech = @motor.MechanicalModel::new(0.002, 0.0005, 4, 0.0)   // J / B / 极对数 / 初速
let te = @motor.electromagnetic_torque(id, iq, ld, lq, psi_f, pole_pairs)
mech.step(te, 1.0, 1.0e-4)   // 转矩 / 负载 / 步长，J·dωm/dt = Te − TL − B·ωm

let g = @controller.design_speed_loop(0.002, 0.0005, 0.3, 40.0)  // J / B / Kt / 带宽 Hz
let sc = @controller.SpeedController::new(g.kp(), g.ki(), 1.0e-4, -8.0, 8.0)
let iq_ref = sc.step(100.0, mech.omega_m())
```

整定口径和电流环不一样：电流环对消电气极点 `R/L`，速度环不对消机械极点。`B/J` 一般只有零点几 rad/s，把它对消掉会让环路退化成纯积分对象，阻尼全压在 `Kp` 上，剩下一个极慢的模态 - 这个数是在 `examples/speed_loop` 里实跑出来的（负载阶跃后 1 s 只回到 98.3 rad/s，iq 已经到稳态值，看着像稳态误差，其实是慢模态没走完），不是纸面推导。改成积分时间常数取带宽的五分之一：`Kp = ω_bw·J/Kt`，`Ki = Kp·ω_bw/5`。

`examples/speed_loop` 的参数：R=0.5 Ω、Ld=0.8 mH、Lq=1.2 mH、ψf=0.05 Wb、pp=4（Kt=0.3 N·m/A）、J=2e-3 kg·m²、B=5e-4、Vdc=48 V、Ts=0.1 ms、电流环 400 Hz、速度环 40 Hz、iq 限幅 ±8 A。本机 native 实测（2026-11-14，工具链 0.1.20261104）：

- 0 → 100 rad/s：10% 时刻 8.7 ms，进 ±2% 带 83.5 ms，峰值 100.4662 rad/s（超调 0.47%），iq 峰值顶到 8 A 限幅。
- 1.0 s 加 1 N·m 负载：最大跌落 1.5511 rad/s，20.5 ms 回到 ±1% 带。
- 末段 0.2 s 转速稳在 100 rad/s，末拍 iq = 3.5 A（1 N·m / Kt = 3.333 A，再加阻尼项 B·ω/Kt = 0.167 A）。

```
moon run examples/speed_loop --target native
```

边界：机械模型是单惯量、摩擦只留线性 `B`、转速钳非负（不做四象限与反转），欧拉积分步长要调用方自己保证稳定；速度环只有 PI 与输出限幅，没有加速度前馈、没有观测器、没有弱磁。示例里的电气模型没有 d/q 交叉项，所以电压前馈只补反电动势一项 - 硬塞 `vd_ff` 等于给模型注入一个它不存在的扰动，读数会假。

### 弱磁给定

转速升到基速以上，`ωe·ψf` 自己就把电压吃满，靠 PI 硬顶只会撞限幅。`controller/field_weakening.mbt` 按稳态电压方程 `vd = −ωe·Lq·iq`、`vq = ωe·(Ld·id + ψf)` 与 `vd² + vq² ≤ Vmax²` 反解 d 轴给定：

```moon
let h = @controller.flux_headroom(600.0, 0.0008, 0.0012, 0.05, 0.0, 27.7128)  // → −0.003812 Wb
let id = @controller.field_weakening_id(600.0, 0.0008, 0.0012, 0.05, 0.0, 27.7128, -8.0)
// → −4.7650 A
```

`flux_headroom = sqrt(Vmax² − (ωe·Lq·iq)²)/|ωe| − ψf`，为正说明还在恒转矩区，`field_weakening_id` 直接返回 0；为负才把 `id = headroom/Ld` 压下去，并钳在 `[id_min, 0]` 内。同一转速带 iq 负载时电压预算更紧：ωe=600、iq=5 A 时 `(ωe·Lq·iq)` 先占掉 3.6 V，弱磁到 −5.2542 A。母线余量不够解方程（`Vmax² − (ωe·Lq·iq)² ≤ 0`）时直接给到电流下限，不去装一个解出来的值。

边界：这里只做稳态近似，没算电阻压降、没算 `di/dt`、没算电流环带宽之外的相位滞后，也不含弱磁区的电流分配优化；`vmax` 取 `Vdc/√3` 时与 `svpwm` 的线性区边界同一条。

### 电流采样侧

三相电流瞬时值之和恒为零，所以硬件通常只装两路传感器或两个采样电阻，第三相由软件重构。`controller/sampling.mbt` 把这一步和它的判据都做成函数：

```moon
let ic = @controller.reconstruct_third(1.984, -0.972)          // → -1.012
let r = @controller.zero_sequence_residual(1.984, -0.972, ic)  // → 0
// 单/双电阻采样要求该相下管导通时间足够长，否则运放还没建立完 ADC 就转换了
let margin = @controller.sample_window_margin(0.52, 50.0e-6, 1.5e-6)  // → 22.5 µs
let ok = @controller.window_ok(0.88, 50.0e-6, 1.5e-6)                 // → true，余量 4.5 µs
let pairs = @controller.pick_sample_pair((0.52, 0.31, 0.88), 50.0e-6, 1.5e-6)
// → [(0, 1), (0, 2), (1, 2)]，按两相中较小余量降序
```

`pick_sample_pair` 返回空数组表示三相的窗口都不够，这一拍采样应该丢弃，而不是硬取一路噪声。`zero_sequence_residual` 不参与控制，它是排查传感器的第一手信号：偏置、断线、两路不同步都会让三路之和偏离 0，`currents_consistent` 把这层判断按容差写成布尔值。

`FocController::step_from_two_phases(ia, ib, θe, id_ref, iq_ref)` 把重构后的 ic 直接送进一拍电流环，采样相固定为 a/b；真实按窗口挑相时用 `pair_currents(pair, i1, i2)` 先还原成 a/b/c 三相，或直接 `FocController::step_from_pair(pair, i1, i2, θe, id_ref, iq_ref)`。采样相始终由调用方给定，控制器不隐式挑相。相号越界、两相相同、任一路非有限都在入口挡住并返回零元组，不把坏采样当成「电流真的是 0」喂进 PI。

`examples/design_report` 末尾会打印这组读数：三相占空比 `(0.52, 0.31, 0.88)`、`Ts = 50 µs`、最小建立时间 1.5 µs 下，余量分别为 22.5 / 33 / 4.5 µs，优先采样相 `(0,1)`，两相重构 `ic = -1.012`、残差 0。

`examples/sampling_loop` 把两相采样接进闭环：同一台电机、同一组整定增益跑两条轨迹，A 喂三相真值，B 只采两相、按上一拍占空比挑相、第三相重构。本机 native 实测（2026-11-14）：全程 `|iq(三相) − iq(两相)|` 最大值为 0，0.2 s 两边都是 1.9999999999999998 A，采样相切换 1 次（起手 `(0,1)`，稳定后 `(0,2)`），没有任何一拍三相都不满足窗口。给 a 相加 0.02 A 传感器偏置后，iq 落到 1.98845 A（偏离给定 0.01155 A）；此时只采两相的残差恒为 0 - 第三相是算出来的，这个判据看不出单路偏置；再给一路 c 相真值，残差才等于 0.02 A。

```
moon run examples/sampling_loop --target native
```

## 测试

CI（`.github/workflows/ci.yml`）跑四件事：`moon fmt --check`；`wasm-gc` / `js` / `native` 三个目标各自的 `check --deny-warn` + `build` + `test`；`moon run examples/demo --target native`；以及 `moon run examples/waveform --target native`。本机 2026-11-14 实测（工具链 0.1.20261104）：wasm、wasm-gc、js、native 四个后端 `moon test` 均为 151 passed / 0 failed，四个目标 `moon check --deny-warn` 全部干净退出。wasm 目标未进 CI 矩阵，只在本机实测。

```
moon check --deny-warn --target wasm-gc
moon test --target wasm-gc
# 与 CI 矩阵同口径的另外两个目标：
moon check --deny-warn --target native
moon test --target native
moon check --deny-warn --target js
moon test --target js          # 需要可用 node，CI 上由 runner 提供
```

151 个用例覆盖：Clarke 三相平衡与正逆往返、θ=0 与 θ=π/2 的 Park、Park / 反 Park 往返、六扇区全范围扇区判断、线性区与过调制区作用时间、线性区 T1/T2 与三相占空比的手算绝对基准、占空比范围与各扇区顺序、角度归一化与极对数边界，20 组独立数值夹具（期望值由库外独立算出），PI 单轴调节器的比例 / 积分 / 限幅 / 抗饱和，控制器单拍链路一致性、闭环阶跃跟踪、输出限幅与坏采样隔离，简化电机模型的零电压保持、RL 一阶上升、极对数换算、三相电流和为零、非正极对数与非正电感钳位，以及电流环整定的 9 条回归（对消比例、交叉频率落在目标带宽、理想裕度 90°、延时损失换算、可用性判据计入延时、带宽单调性与裕度反向、偏离对消时裕度下降、非法输入钳位、无交叉频率返回 0），以及电流采样侧的 12 条回归（两相重构闭合三相和、非有限采样钳位、传感器一致性判据含非法容差、采样窗口余量随占空比与周期变化、非法窗口配置拒绝、候选采样相排序、三相全窄无候选、两相 step 与三相 step 逐位一致、按相号还原三相电流、坏相号与坏采样作废、任意一对相驱动与三相驱动等价、坏相号不碰 PI 状态），以及过调制几何的 7 条回归（扇区轴线处边界等于内切圆、顶点方向等于 2/3 母线、解析边界与 `action_times` 钳位后的幅值一致、投影保方向且落在边界、线性区投影原样返回、削顶比例在线性区为零且超界为正），以及解耦前馈的 8 条回归（反电动势等于 ωe·ψf 且零速/非有限输入归零、零速前馈为零、前馈项符号与电压方程一致含 id 为负时的 vq_ff、线性区相加原样返回、超限只缩幅值不改方向、母线未知只相加、非有限分量不进指令），以及机械模型的 5 条回归（SPMSM 与凸极转矩换算、转矩驱动加速与断电保持、负载拖低转速、阻尼在 Te/B 处收敛、非法步长与非有限输入钳位、负速钳位与极对数换算），以及速度环的 7 条回归（增益随惯量与带宽、无转矩常数或零带宽返回零增益、惯量钳位、带宽比值判据、输出符号随误差方向、限幅与坏反馈输出为零且不更新积分器、reset 清状态），以及弱磁给定的 6 条回归（基速以下余量为正且 id 给 0、基速以上余量为负并按 headroom/Ld 给出 id、q 轴电流占掉电压预算后弱磁更深、id 钳在电流下限内、母线余量不足直接给下限、零速/零母线/零电感与非有限输入返回 0）。

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
