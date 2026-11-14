// controller/feedforward.mbt — d/q 轴解耦前馈与电压矢量限幅（纯计算）。
//
// PI 电流环按误差调电压，但 PMSM 的 d 轴和 q 轴在旋转坐标系里并不独立：
//
//   vd = R·id + Ld·did/dt − ωe·Lq·iq
//   vq = R·iq + Lq·diq/dt + ωe·(Ld·id + ψf)
//
// 交叉项（−ωe·Lq·iq）与反电动势项（ωe·ψf）对 PI 来说是外部扰动。转速越高、
// 电感越大，这两项越难靠积分器「等出来」：积分器要先把误差积起来，才能长出
// 与扰动等值的输出，期间电流一直是偏的。把这两项按模型直接前馈出去，PI 只剩
// 电阻压降和动态项要管。
//
// 这里只做纯函数：算前馈项、和 PI 输出相加、按线性调制区限幅。控制器对象
// 不持有电机参数，前馈需要 R/L/ψ 的地方由调用方传进来。

///|
fn ff_finite(v : Double) -> Bool {
  v == v && v.abs() <= 1.0e308
}

///|
/// 反电动势幅值 `ωe·ψf`（伏）。零速或零磁链时为 0。
/// 非有限输入返回 0：宁可前馈少一项，也不要把 NaN 加进电压指令。
pub fn back_emf_voltage(omega_e : Double, psi_f : Double) -> Double {
  if !(ff_finite(omega_e) && ff_finite(psi_f)) {
    return 0.0
  }
  let v = omega_e * psi_f
  if ff_finite(v) {
    v
  } else {
    0.0
  }
}

///|
/// d/q 轴解耦前馈电压对 `(vd_ff, vq_ff)`，单位伏。
///
/// - `vd_ff = −ωe·Lq·iq`：q 轴电流在 d 轴上的交叉耦合；
/// - `vq_ff = +ωe·(Ld·id + ψf)`：d 轴电流的交叉耦合加上永磁反电动势。
///
/// 任一分量为非有限值时返回 `(0.0, 0.0)`。零速时两项都是零，与物理一致。
pub fn decoupling_terms(
  omega_e : Double,
  ld : Double,
  lq : Double,
  psi_f : Double,
  id : Double,
  iq : Double,
) -> (Double, Double) {
  if !(ff_finite(omega_e) &&
    ff_finite(ld) &&
    ff_finite(lq) &&
    ff_finite(psi_f) &&
    ff_finite(id) &&
    ff_finite(iq)) {
    return (0.0, 0.0)
  }
  let vd_ff = -(omega_e * lq * iq)
  let vq_ff = omega_e * (ld * id + psi_f)
  if ff_finite(vd_ff) && ff_finite(vq_ff) {
    (vd_ff, vq_ff)
  } else {
    (0.0, 0.0)
  }
}

///|
/// 把 PI 输出与前馈项相加，并按线性调制区限幅。
///
/// 限幅针对合成矢量的幅值 `sqrt(vd² + vq²)`，上限取 `Vdc/√3`（六边形内切圆，
/// 与 `svpwm` 的线性区同一条边界）。超限时按同一比例缩放两个分量，保持矢量
/// 方向不变——单独钳 vd、vq 会改变方向，等价于让电流环去追一个偏了角度的
/// 参考。`vdc` 非正或非有限时不做限幅，只返回相加结果（母线未知时用限幅
/// 等于凭空假设一个边界）。
pub fn apply_feedforward(
  vd_pi : Double,
  vq_pi : Double,
  vd_ff : Double,
  vq_ff : Double,
  vdc : Double,
) -> (Double, Double) {
  if !(ff_finite(vd_pi) &&
    ff_finite(vq_pi) &&
    ff_finite(vd_ff) &&
    ff_finite(vq_ff)) {
    return (0.0, 0.0)
  }
  let vd = vd_pi + vd_ff
  let vq = vq_pi + vq_ff
  if !(ff_finite(vdc) && vdc > 0.0) {
    return (vd, vq)
  }
  let limit = vdc / 3.0.sqrt()
  let mag = (vd * vd + vq * vq).sqrt()
  if !ff_finite(mag) || mag <= limit {
    return (vd, vq)
  }
  let scale = limit / mag
  (vd * scale, vq * scale)
}
