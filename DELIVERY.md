# 交付说明（DELIVERY）

这份文件回答一件事：**报名时申报书说的，和仓库现在的实际状态，差在哪。**

申报书是报名存档，不随实现更新；README 和 CHANGELOG 记录实现本身。三者容易出现
三个不同的数字，验收时对方按哪份对都对不上。这里把差异一次写清。

- 申报书：`12-知识库/03-竞赛/01-MoonBit黑客松/2026-11/moon-foc-申报书.md`（2026-10-19 原稿）
- 本文件对应提交：以仓库 HEAD 为准，最后核对时间见文末

## 一、申报 vs 现在

| 项 | 申报书（2026-10-19） | 现在 |
|---|---|---|
| 版本 | 0.1.3 | **0.1.13**（mooncakes 最新） |
| 单测 | 36 | **84**（四个后端各 84） |
| 后端覆盖 | wasm-gc / native / js 三后端 | **wasm / wasm-gc / js / native 四后端** |
| commits | 29 | 55 |
| 包 | `svpwm/` `coord/` `angle/` | 增加 **`pi/`** |
| 示例 | `examples/demo` | 增加 **`examples/waveform`**、**`examples/reject_demo`** |
| CI | check/build/test（wasm-gc）+ native/js 本地实测 | 三目标矩阵 `check --deny-warn` + build + test，示例真跑，发布元数据校验 |

## 二、申报之后新增了什么

1. **`pi/` 离散 PI 电流调节器**：误差 → 电压指令，条件积分抗饱和，非有限误差不进状态，
   `dt <= 0` 退化为纯 P。
   - 与申报书的关系：申报书「明确不做」写的是「dq 动态模型与闭环控制」。`pi/` 是
     **开环的误差→电压环节**，不含 dq 动态、不含闭环整定，属于同一方向的单步实现，
     不在「明确不做」范围内。这条边界是判断，不藏着。
2. **调制链路的完整性**：七段式开关序列 `switching_sequence` / `switching_sequence_of`、
   每相高电平时间 `on_time_of_phase`、死区补偿 `dead_time_compensation`、
   载波法第二条路径 `duties_from_voltages`、调制比 `modulation_index`、
   输入校验 `check_inputs` 与 `duties_checked`。
3. **角度反解**：`electrical_to_mechanical`（周期意义下的逆）。
4. **可运行的两类新示例**：波形报告（ASCII 七段式时序）与拒绝演示（非法输入）。

## 三、与申报书不符、需要主动说明的两处

| 申报书原文 | 现状 | 说明 |
|---|---|---|
| 「legacy wasm 受本机工具链环境限制未跑，不宣称四后端覆盖」 | wasm 已跑通，四后端各 84 测试 | 2026-11-11 工具链升级到 0.1.20261104 并补齐 core 的预编译 bundle 后解除，不是代码变化 |
| 「36 个单测」 | 84 | 新增包的测试 + 每轮修复补的回归用例 |

## 四、验证证据（可复现）

```bash
moon check --deny-warn --target wasm        # 四个目标逐个跑，下同
moon test --target wasm                    # 84/84
moon run examples/demo --target native     # 变换与占空比数值
moon run examples/waveform --target native # 七段式时序图
moon run examples/reject_demo --target native  # 每条拒绝路径
```

- 期望值**不取自本库输出**：`scripts/gen_fixtures.py` 用 Python 按教材公式独立算 20 组
  基准（`coord` 与 `svpwm` 各一组），硬编码进测试。
- 两条调制路径互相校验：线性区（m ≤ 1）偏差 1e-15；过调制区两者策略不同，README 已写明。

## 五、发布状态

- mooncakes：`Duckweed/moon-foc@0.1.13`（Latest）。
- GitHub tag 只到 **v0.1.3**，落后 10 个已发布版本。**以 mooncakes 上的版本为准**；
  tag 是早期手工打的，没有逐个补。

## 六、当前边界（不做的事，仍然是这些）

dq 动态模型与闭环整定、旋变 / 霍尔信号解析、C FFI、芯片厂商 SDK 绑定、GUI 与波形显示、
硬件在环。新增的 `pi/` 不改变这条边界。
