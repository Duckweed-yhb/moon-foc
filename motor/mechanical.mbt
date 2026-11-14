// motor/mechanical.mbt — 转子机械动力学（一阶惯性 + 负载转矩）。
//
// motor/motor.mbt 只管电气侧，转速由外部给定，所以那里跑不出速度环的真实行为。
// 这里补上机械方程：
//
//   J·dωm/dt = Te − TL − B·ωm
//   Te = 1.5·pp·(ψf·iq + (Ld − Lq)·id·iq)
//
// J 是转动惯量（kg·m²），B 是黏性阻尼（N·m·s/rad），TL 是负载转矩（N·m）。
// 显式欧拉积分，与电气模型同一套简化假设：不建模摩擦死区、齿槽、饱和。

///|
/// 转子机械状态。
pub struct MechanicalModel {
  /// 转动惯量（kg·m²），非正时夹到 1e-12，避免除零。
  j : Double
  /// 黏性阻尼系数（N·m·s/rad），负值按 0 处理。
  b : Double
  /// 极对数，与电气模型一致。
  pole_pairs : Int32
  /// 机械角速度（rad/s）。
  mut omega_m : Double
  /// 机械角度（rad，[0, 2π)）。
  mut theta_m : Double
}

///|
/// 构造机械模型。`omega_m` 为初始机械角速度；`pole_pairs <= 0` 按 1 处理。
pub fn MechanicalModel::new(
  j : Double,
  b : Double,
  pole_pairs : Int32,
  omega_m : Double,
) -> MechanicalModel {
  let j_safe = if j > 1.0e-12 { j } else { 1.0e-12 }
  let b_safe = if b >= 0.0 { b } else { 0.0 }
  let pp = if pole_pairs > 0 { pole_pairs } else { 1 }
  { j: j_safe, b: b_safe, pole_pairs: pp, omega_m, theta_m: 0.0, }
}

///|
fn mech_finite(x : Double) -> Bool {
  x == x && x.abs() <= 1.0e308
}

///|
/// 电磁转矩 `Te = 1.5·pp·(ψf·iq + (Ld − Lq)·id·iq)`（N·m）。
/// 表面贴装电机 `Ld ≈ Lq` 时退化为 `1.5·pp·ψf·iq`。非有限输入返回 0。
pub fn electromagnetic_torque(
  id : Double,
  iq : Double,
  ld : Double,
  lq : Double,
  psi_f : Double,
  pole_pairs : Int32,
) -> Double {
  if !(mech_finite(id) &&
    mech_finite(iq) &&
    mech_finite(ld) &&
    mech_finite(lq) &&
    mech_finite(psi_f)) {
    return 0.0
  }
  let pp = if pole_pairs > 0 { pole_pairs } else { 1 }
  let te = 1.5 * pp.to_double() * (psi_f * iq + (ld - lq) * id * iq)
  if mech_finite(te) {
    te
  } else {
    0.0
  }
}

///|
/// 步进一个机械周期 `dt`（秒）。`torque` 是电磁转矩，`load` 是负载转矩（N·m，
/// 与转向相反的阻力取正值），`b` 已在模型里。
///
/// 欧拉步进；`dt <= 0` 或输入非有限时状态保持不变。转速被钳在非负——
/// 本模型不做四象限，反转工况请另外建。
pub fn MechanicalModel::step(
  self : MechanicalModel,
  torque : Double,
  load : Double,
  dt : Double,
) -> Unit {
  if !(mech_finite(torque) && mech_finite(load) && mech_finite(dt) && dt > 0.0) {
    return
  }
  let acc = (torque - load - self.b * self.omega_m) / self.j
  let next = self.omega_m + acc * dt
  self.omega_m = if next < 0.0 { 0.0 } else { next }
  self.theta_m = @angle.normalize_angle(self.theta_m + self.omega_m * dt)
}

///|
/// 当前机械角速度（rad/s）。
pub fn MechanicalModel::omega_m(self : MechanicalModel) -> Double {
  self.omega_m
}

///|
/// 当前电角速度（rad/s），即机械角速度乘极对数。
pub fn MechanicalModel::omega_e(self : MechanicalModel) -> Double {
  self.omega_m * self.pole_pairs.to_double()
}

///|
/// 当前机械角度（rad，[0, 2π)）。
pub fn MechanicalModel::theta_m(self : MechanicalModel) -> Double {
  self.theta_m
}
