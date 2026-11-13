// motor/motor.mbt — 简化 PMSM 电气模型。
//
// d/q 轴一阶方程（表面贴装近似，忽略 d/q 交叉耦合项）：
//   did/dt = (vd − R·id) / Ld
//   diq/dt = (vq − R·iq − ωe·ψf) / Lq
// 角度由电角速度积分：θe ← θe + ωe·dt，归一化到 [0, 2π)。
//
// 这是给闭环仿真和回归测试用的简化被控对象：参数化、可步进、可读出
// 三相电流；真实电机的饱和、铁损、齿槽与反电势波形都不在本模型内。

///|
/// 简化 PMSM 电气模型状态。
pub struct PmsmModel {
  /// 相电阻（欧姆）。
  r : Double
  /// d/q 轴电感（亨利）。
  ld : Double
  lq : Double
  /// 永磁磁链（韦伯），只进 q 轴反电势 ωe·ψf。
  psi_f : Double
  /// 极对数；电角速度 = 机械角速度 × 极对数。
  pole_pairs : Int32
  /// 当前 d/q 电流（安培）。
  mut id : Double
  mut iq : Double
  /// 当前电角度（弧度，[0, 2π)）。
  mut theta_e : Double
  /// 电角速度（弧度 / 秒），外部给定，本模型不生成转速环。
  mut omega_e : Double
}

///|
/// 构造模型。`omega_m` 是初始机械角速度（弧度 / 秒）；`pole_pairs <= 0`
/// 按 1 处理；电感非正时夹到 1e-9 亨利，避免欧拉步进出现除零。
pub fn PmsmModel::new(
  r : Double,
  ld : Double,
  lq : Double,
  psi_f : Double,
  pole_pairs : Int32,
  omega_m : Double,
) -> PmsmModel {
  let pp = if pole_pairs > 0 { pole_pairs } else { 1 }
  let ld_safe = if ld > 1.0e-9 { ld } else { 1.0e-9 }
  let lq_safe = if lq > 1.0e-9 { lq } else { 1.0e-9 }
  {
    r,
    ld: ld_safe,
    lq: lq_safe,
    psi_f,
    pole_pairs: pp,
    id: 0.0,
    iq: 0.0,
    theta_e: 0.0,
    omega_e: omega_m * pp.to_double(),
  }
}

///|
/// 外部给定机械角速度（弧度 / 秒），内部换算成电角速度。
pub fn PmsmModel::set_speed(self : PmsmModel, omega_m : Double) -> Unit {
  self.omega_e = omega_m * self.pole_pairs.to_double()
}

///|
fn finite(x : Double) -> Bool {
  x == x && x.abs() <= 1.0e308
}

///|
/// 步进一个周期 `dt`（秒），施加 d/q 电压指令 `vd/vq`（伏特）。
///
/// 显式欧拉积分；`dt <= 0` 或电压非有限时状态保持不变。模型不限制电压
/// 幅值，限幅由上游控制器负责。
pub fn PmsmModel::step(
  self : PmsmModel,
  vd : Double,
  vq : Double,
  dt : Double,
) -> Unit {
  if !(finite(vd) && finite(vq) && finite(dt) && dt > 0.0) {
    return
  }
  let did = (vd - self.r * self.id) / self.ld
  let diq = (vq - self.r * self.iq - self.omega_e * self.psi_f) / self.lq
  self.id = self.id + did * dt
  self.iq = self.iq + diq * dt
  self.theta_e = @angle.normalize_angle(self.theta_e + self.omega_e * dt)
}

///|
/// 当前 d 轴电流。
pub fn PmsmModel::id(self : PmsmModel) -> Double {
  self.id
}

///|
/// 当前 q 轴电流。
pub fn PmsmModel::iq(self : PmsmModel) -> Double {
  self.iq
}

///|
/// 当前电角度（弧度）。
pub fn PmsmModel::theta_e(self : PmsmModel) -> Double {
  self.theta_e
}

///|
/// 当前电角速度（弧度 / 秒）。
pub fn PmsmModel::omega_e(self : PmsmModel) -> Double {
  self.omega_e
}

///|
/// 由 d/q 电流反 Park、反 Clarke 得到三相电流 `(ia, ib, ic)`（安培）。
/// 幅值不变约定下三相之和为 0。
pub fn PmsmModel::phase_currents(self : PmsmModel) -> (Double, Double, Double) {
  let (alpha, beta) = @coord.inv_park(self.id, self.iq, self.theta_e)
  @coord.inv_clarke(alpha, beta)
}
