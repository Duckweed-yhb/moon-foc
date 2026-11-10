// pi/pi.mbt — 离散 PI 电流调节器（一个轴一个实例）。
//
// 这是 FOC 电流环里最常用的那一块：给定 q 轴（或 d 轴）电流误差，输出一个
// 电压指令，再交给 SVPWM。之所以单独成包、不并进 svpwm：调制是「电压 → 占空比」
// 的映射，PI 是「误差 → 电压」的反馈，两者的输入输出都不是一回事。
//
// 实现约定：
// - 增量式积分：`integ` 就是积分项对输出的贡献，`step` 里累加 `ki·err·dt`；
// - 抗饱和用条件积分：输出已经顶到限幅、且误差还在把它往同方向推时，
//   冻结积分器。否则积分项会在饱和期间越积越大，退饱和后要很久才拉回来；
// - 非有限误差（NaN / Inf）不进入状态：直接返回当前积分项的限幅值。

///|
/// 单轴离散 PI 调节器。
pub struct Pi {
  kp : Double
  ki : Double
  /// 采样周期（秒）。
  dt : Double
  out_min : Double
  out_max : Double
  /// 积分项对输出的贡献（已含 ki·dt 的量纲）。
  mut integ : Double
}

///|
/// 构造调节器。
///
/// - `dt <= 0` 按 0 处理（退化成纯 P），避免除零式语义混乱；
/// - `out_min > out_max` 时内部交换：限幅区间写反了不该产出一个上下颠倒的
///   输出，交换后的语义才是调用方想要的。
pub fn Pi::new(
  kp : Double,
  ki : Double,
  dt : Double,
  out_min : Double,
  out_max : Double,
) -> Pi {
  let step_time = if dt > 0.0 { dt } else { 0.0 }
  let lo = if out_min <= out_max { out_min } else { out_max }
  let hi = if out_min <= out_max { out_max } else { out_min }
  { kp, ki, dt: step_time, out_min: lo, out_max: hi, integ: 0.0, }
}

///|
/// 当前积分项（调试 / 观测用）。
pub fn Pi::integral(self : Pi) -> Double {
  return self.integ
}

///|
/// 清空积分器（重新使能、切换模式时调用）。
pub fn Pi::reset(self : Pi) -> Unit {
  self.integ = 0.0
}

///|
fn pi_clamp(v : Double, lo : Double, hi : Double) -> Double {
  if v > hi {
    hi
  } else if v < lo {
    lo
  } else {
    v
  }
}

///|
fn pi_finite(x : Double) -> Bool {
  // IEEE 754：NaN 自不相等，±Inf 的量级超界。
  x == x && x.abs() <= 1.0e308
}

///|
/// 走一个采样步：输入误差，返回限幅后的输出。
///
/// 抗饱和规则：输出顶到某侧限幅、且误差仍在把输出往**同一侧**推时冻结积分；
/// 误差反向时照常积分，这样退出饱和是一个采样步就能完成的事。
pub fn Pi::step(self : Pi, err : Double) -> Double {
  if !pi_finite(err) {
    // 坏采样不该污染状态：保持积分器不动，返回当前积分项的限幅值。
    return pi_clamp(self.integ, self.out_min, self.out_max)
  }
  let candidate = self.integ + self.ki * err * self.dt
  let raw = self.kp * err + candidate
  let out = pi_clamp(raw, self.out_min, self.out_max)
  let pushing_high = raw > self.out_max && err > 0.0
  let pushing_low = raw < self.out_min && err < 0.0
  if !(pushing_high || pushing_low) {
    self.integ = candidate
  }
  out
}
