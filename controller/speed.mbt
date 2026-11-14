// controller/speed.mbt — 速度外环：从机械参数整定转速 PI，并给出 iq 给定。
//
// 电流环的对象已在 design.mbt 处理；速度环的对象换成机械方程：
//
//   ωm(J·s + B) = Te = Kt·iq,   Kt = 1.5·pp·ψf（SPMSM）
//   即 P(s) = Kt / (J·s + B)
//
// 电流环用零极点对消把 PI 零点放在电机电气极点 R/L 上；速度环**不**照抄这一手。
// 机械极点 B/J 通常只有零点几 rad/s（惯量主导），把它对消掉等于让环路退化成
// 纯积分对象 Kt/(J·s)，闭环阻尼全靠 Kp，剩下一个 ωn/(2ζ) 量级的慢模态：
// 负载阶跃后要几秒才回位。这里改成积分时间常数取带宽的五分之一：
//
//   Kp = ω_bw·J / Kt,   Ki = Kp·ω_bw / 5
//
// 环路增益在 ω_bw 处过 0 dB，PI 零点落在 ω_bw/5，比机械极点高，带来的
// 相位超前足以把慢模态消掉。B 只作为已知的稳态阻尼留给积分器去补。
//
// 速度环带宽必须明显低于电流环（一般取 1/5 到 1/10），否则两个环会互相顶。
// `speed_bandwidth_ok` 把这个比值写成判据，阈值由调用方给。

///|
/// 按目标带宽整定速度环 PI。`kt` 是转矩常数（N·m/A），`j` 是转动惯量，
/// `b` 只影响稳态阻尼、不参与增益（这里不对消机械极点，见文件头）。
///
/// `kt` 非正或非有限时返回零增益（没有转矩常数，这个环无从整定）；
/// `j` 非正夹到 1e-12；带宽非正或非有限返回零增益。
pub fn design_speed_loop(
  j : Double,
  b : Double,
  kt : Double,
  bandwidth_hz : Double,
) -> LoopGains {
  let j_safe = if design_finite(j) && j > 1.0e-12 { j } else { 1.0e-12 }
  let b_safe = if design_finite(b) && b > 0.0 { b } else { 0.0 }
  if !(design_finite(kt) && kt > 0.0) {
    return { kp: 0.0, ki: 0.0, }
  }
  if !(design_finite(bandwidth_hz) && bandwidth_hz > 0.0) {
    return { kp: 0.0, ki: 0.0, }
  }
  let omega = 2.0 * design_pi() * bandwidth_hz
  let kp = omega * j_safe / kt
  // b_safe 只用于解释稳态，不进入增益；显式读一次避免被当成死参数。
  let _ = b_safe
  { kp, ki: kp * omega / 5.0, }
}

///|
/// 速度环带宽是否相对电流环足够低。返回 `true` 表示 `ratio = f_speed / f_current`
/// 不超过给定上限（例如 0.2 表示速度环最多取电流环带宽的五分之一）。
pub fn speed_bandwidth_ok(
  speed_hz : Double,
  current_hz : Double,
  max_ratio : Double,
) -> Bool {
  if !(design_finite(speed_hz) &&
    design_finite(current_hz) &&
    design_finite(max_ratio)) {
    return false
  }
  if !(speed_hz > 0.0 && current_hz > 0.0 && max_ratio > 0.0) {
    return false
  }
  speed_hz / current_hz <= max_ratio
}

///|
/// 速度环本体：一个 PI 加 iq 限幅。输出直接作为电流环的 q 轴给定。
pub struct SpeedController {
  pi : @pi.Pi
  iq_min : Double
  iq_max : Double
  mut last : Double
}

///|
/// 构造速度环。`iq_min` / `iq_max` 是电流环能接受的 q 轴给定范围（安培）。
pub fn SpeedController::new(
  kp : Double,
  ki : Double,
  dt : Double,
  iq_min : Double,
  iq_max : Double,
) -> SpeedController {
  let lo = if iq_min < iq_max { iq_min } else { iq_max }
  let hi = if iq_min < iq_max { iq_max } else { iq_min }
  { pi: @pi.Pi::new(kp, ki, dt, lo, hi), iq_min: lo, iq_max: hi, last: 0.0, }
}

///|
/// 步进一拍：`omega_ref` 是转速给定（rad/s），`omega_meas` 是反馈。
///
/// 反馈或给定非有限时输出 0，并且不更新积分器——速度反馈丢一拍就退到零转矩，
/// 比按限幅值满转矩冲出去安全。
pub fn SpeedController::step(
  self : SpeedController,
  omega_ref : Double,
  omega_meas : Double,
) -> Double {
  if !(design_finite(omega_ref) && design_finite(omega_meas)) {
    return 0.0
  }
  self.last = self.pi.step(omega_ref - omega_meas)
  self.last
}

///|
/// 上一拍输出的 iq 给定（A）。
pub fn SpeedController::iq_ref(self : SpeedController) -> Double {
  self.last
}

///|
/// 清空积分器，并把输出归零。
pub fn SpeedController::reset(self : SpeedController) -> Unit {
  self.pi.reset()
  self.last = 0.0
}
