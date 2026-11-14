// controller/design.mbt — 电流环整定：从电机参数与目标带宽算 d/q 轴 PI 增益。
//
// 前面几个包回答的是「给一组增益，这一拍照出来是什么」；这里回答前一个问题：
// 「手上这台电机，增益该取多少」。缺了这一步，使用者只能抄一组别人的数，
// 换个电感就整定不出来——这也是「只有坐标变换和调制」这个评价里最实的一块短板。
//
// 被控对象（单轴，忽略 d/q 交叉耦合，与 motor 包的一阶模型同一假设）：
//   P(s) = 1 / (L·s + R)
// 控制器：
//   C(s) = Kp + Ki / s
//
// 取零极点对消，令 Ki / Kp = R / L，则
//   C(s)·P(s) = Kp(1 + R/(L s)) / (L s + R) = Kp / (L s)
// 环路增益幅值 |C·P| = Kp / (L·ω)，在 ω_c = Kp / L 处过 0 dB，
// 且该点相位恰为 −90°，相位裕度 90°。
// 于是把「带宽」当成设计输入：
//   Kp = ω_bw·L,  Ki = ω_bw·R,  ω_bw = 2π·f_bw
//
// 数字实现还有一拍延时（采样 + PWM 更新），相位按 −ω·Ts 下降：
//   f_c = 4 kHz、Ts = 50 µs 时延时吃掉 72°，90° 只剩 18°。
// 这个换算放在 `delay_phase_loss_deg` / `margin_after_delay_deg`，让「带宽能开到
// 多高」变成可以直接读出来的数，而不是凭经验拍。

///|
/// 一组 d/q 轴 PI 增益（辐条：比例项与积分项，伏特每安培 / 伏特每安培秒）。
pub struct LoopGains {
  kp : Double
  ki : Double
}

///|
/// 比例增益（V/A）。
pub fn LoopGains::kp(self : LoopGains) -> Double {
  self.kp
}

///|
/// 积分增益（V/(A·s)）。
pub fn LoopGains::ki(self : LoopGains) -> Double {
  self.ki
}

///|
fn design_finite(x : Double) -> Bool {
  x == x && x.abs() <= 1.0e308
}

///|
fn design_pi() -> Double {
  3.141592653589793
}

///|
/// 按目标带宽整定单轴电流环 PI 增益。
///
/// - `r`：相电阻（欧姆），负值按 0 处理（无源网络里没有负电阻，写负号通常
///   是单位或符号搞错了，钳到 0 得到纯比例，至少不会把环路变成正反馈）；
/// - `l`：轴电感（亨利），非正或非有限时夹到 1 nH，与 `motor` 包的构造守卫
///   同一个下限，避免除零；
/// - `bandwidth_hz`：目标闭环带宽（赫兹）。非正或非有限时返回零增益：
///   零增益控制器是「不动作」，比拿一个 NaN 增益去打 PI 安全。
///
/// `Ki / Kp = R / L` 是这条路径的核心约束，改比值就不再是零极点对消，
/// 相位裕度也不再是 90°（那种情况用 `phase_margin_deg` 直接算）。
pub fn design_current_loop(
  r : Double,
  l : Double,
  bandwidth_hz : Double,
) -> LoopGains {
  let r_safe = if design_finite(r) && r > 0.0 { r } else { 0.0 }
  let l_safe = if design_finite(l) && l > 1.0e-9 { l } else { 1.0e-9 }
  if !(design_finite(bandwidth_hz) && bandwidth_hz > 0.0) {
    return { kp: 0.0, ki: 0.0, }
  }
  let omega = 2.0 * design_pi() * bandwidth_hz
  { kp: omega * l_safe, ki: omega * r_safe, }
}

///|
/// 环路增益幅值 `|C(jω)·P(jω)|`（无量纲）。供交叉频率搜索与自检使用。
pub fn loop_gain_mag(
  r : Double,
  l : Double,
  kp : Double,
  ki : Double,
  omega : Double,
) -> Double {
  if !(design_finite(omega) && omega > 0.0) {
    return 0.0
  }
  let l_safe = if design_finite(l) && l > 1.0e-9 { l } else { 1.0e-9 }
  let r_safe = if design_finite(r) && r >= 0.0 { r } else { 0.0 }
  // C(jω) = kp − j·ki/ω
  let cr = kp
  let ci = -(ki / omega)
  // P(jω) = (r − jωL) / (r² + (ωL)²)
  let d = r_safe * r_safe + omega * l_safe * (omega * l_safe)
  let pr = r_safe / d
  let pi_ = -(omega * l_safe) / d
  let rr = cr * pr - ci * pi_
  let ri = cr * pi_ + ci * pr
  (rr * rr + ri * ri).sqrt()
}

///|
/// 环路增益相位（弧度），`arg(C(jω)·P(jω))`，落在 (−π, π]。
pub fn loop_gain_phase(
  r : Double,
  l : Double,
  kp : Double,
  ki : Double,
  omega : Double,
) -> Double {
  if !(design_finite(omega) && omega > 0.0) {
    return 0.0
  }
  let l_safe = if design_finite(l) && l > 1.0e-9 { l } else { 1.0e-9 }
  let r_safe = if design_finite(r) && r >= 0.0 { r } else { 0.0 }
  let cr = kp
  let ci = -(ki / omega)
  let d = r_safe * r_safe + omega * l_safe * (omega * l_safe)
  let pr = r_safe / d
  let pi_ = -(omega * l_safe) / d
  let rr = cr * pr - ci * pi_
  let ri = cr * pi_ + ci * pr
  @math.atan2(ri, rr)
}

///|
/// 交叉频率（赫兹）：环路增益幅值首次降到 1 的频率。
///
/// 对数轴二分，从 1e-3 Hz 到 1e9 Hz，60 次迭代把区间压到浮点分辨率以内。
/// 幅值在两端同号（都 ≥1 或都 <1，比如增益小到全程不过 0 dB）时返回 0：
/// 「没有交叉频率」与「交叉频率是 0 Hz」是两件事，调用方应看 0 判无效。
pub fn crossover_hz(r : Double, l : Double, kp : Double, ki : Double) -> Double {
  let mut lo = 1.0e-3
  let mut hi = 1.0e9
  let mag_lo = loop_gain_mag(r, l, kp, ki, 2.0 * design_pi() * lo)
  let mag_hi = loop_gain_mag(r, l, kp, ki, 2.0 * design_pi() * hi)
  if !(mag_lo >= 1.0 && mag_hi < 1.0) {
    return 0.0
  }
  let mut i = 0
  while i < 60 {
    let mid = (lo * hi).sqrt()
    let mag = loop_gain_mag(r, l, kp, ki, 2.0 * design_pi() * mid)
    if mag >= 1.0 {
      lo = mid
    } else {
      hi = mid
    }
    i += 1
  }
  lo
}

///|
/// 相位裕度（度）：`180° + arg(C·P)` 在交叉频率处。
///
/// 零极点对消成立时应得 90°；返回负值表示环路在交叉频率已经过了 −180°，
/// 那是发散的风险，不是「裕度小的另一种写法」。
pub fn phase_margin_deg(
  r : Double,
  l : Double,
  kp : Double,
  ki : Double,
) -> Double {
  let fc = crossover_hz(r, l, kp, ki)
  if fc <= 0.0 {
    return 0.0
  }
  let arg = loop_gain_phase(r, l, kp, ki, 2.0 * design_pi() * fc)
  let pm = 180.0 + arg * 180.0 / design_pi()
  if design_finite(pm) {
    pm
  } else {
    0.0
  }
}

///|
/// 一拍延时（采样 + PWM 更新）在交叉频率处吃掉的相位（度）。
///
/// 纯延时 Ts 的相移是 −ωTs，折成度即 `360·f_c·Ts`。`ts <= 0` 或非有限返回 0。
pub fn delay_phase_loss_deg(crossover_hz : Double, ts : Double) -> Double {
  if !(design_finite(crossover_hz) && crossover_hz > 0.0) {
    return 0.0
  }
  if !(design_finite(ts) && ts > 0.0) {
    return 0.0
  }
  360.0 * crossover_hz * ts
}

///|
/// 计入一拍延时后的实际相位裕度（度）：`phase_margin_deg − delay_phase_loss_deg`。
///
/// 这是工程上要看的那个数——理想模型算出的 90° 只是起点，数字实现真正拿到的
/// 是减去延时损失之后的值。
pub fn margin_after_delay_deg(
  r : Double,
  l : Double,
  kp : Double,
  ki : Double,
  ts : Double,
) -> Double {
  let pm = phase_margin_deg(r, l, kp, ki)
  let fc = crossover_hz(r, l, kp, ki)
  pm - delay_phase_loss_deg(fc, ts)
}

///|
/// 给定开关周期与允许的最小相位裕度，判断这条整定是否可用。
///
/// 判据是「计入延时后仍不低于 `min_margin_deg`」，而不是只看理想裕度。
/// `min_margin_deg` 取多少由调用方按自己的工程规范定（通常 45°），这里不预设。
pub fn design_is_usable(
  r : Double,
  l : Double,
  kp : Double,
  ki : Double,
  ts : Double,
  min_margin_deg : Double,
) -> Bool {
  if !design_finite(min_margin_deg) {
    return false
  }
  margin_after_delay_deg(r, l, kp, ki, ts) >= min_margin_deg
}
