// controller/controller.mbt — 单拍 FOC 电流环控制器对象。
//
// 链路（每拍一次）：
//   采样 ia/ib/ic → Clarke → alpha/beta → Park(theta_e) → id/iq
//   → d/q 双 PI（误差 = 给定 − 观测）→ vd/vq → 反 Park → valpha/vbeta
//   → svpwm.duties → da/db/dc
//
// 边界：本包不含转速环、不含 d/q 解耦补偿、不含无感观测器；角度由调用方
// 给入（电角度，弧度）。PI 抗饱和与非有限误差处理复用 pi 包，不在这里
// 另写一套。

///|
/// 单拍 FOC 电流环控制器。d/q 各持一个 PI 实例，上一拍的观测值与电压
/// 指令留在对象里，供调试、日志与回归测试读取。
pub struct FocController {
  d_pi : @pi.Pi
  q_pi : @pi.Pi
  /// 开关周期（秒），透传给 SVPWM。
  ts : Double
  /// 母线电压（伏特），透传给 SVPWM。
  vdc : Double
  /// d/q 合成电压矢量的幅值上限（伏特）。0 表示不启用，只靠两轴各自的限幅。
  v_mag_max : Double
  /// 上一拍观测到的 d/q 电流（安培）。
  mut last_id : Double
  mut last_iq : Double
  /// 上一拍的 alpha/beta 电流与 d/q 电压指令。
  mut last_alpha : Double
  mut last_beta : Double
  mut last_vd : Double
  mut last_vq : Double
}

///|
/// 构造控制器。
///
/// - `kp_d/ki_d`、`kp_q/ki_q`：d/q 轴 PI 增益；
/// - `dt`：采样周期（秒），与 PI、SVPWM 共用；
/// - `vdc`：母线电压；
/// - `v_min/v_max`：d/q 电压指令限幅（伏特），写反时由 PI 内部交换。
pub fn FocController::new(
  kp_d : Double,
  ki_d : Double,
  kp_q : Double,
  ki_q : Double,
  dt : Double,
  vdc : Double,
  v_min : Double,
  v_max : Double,
) -> FocController {
  {
    d_pi: @pi.Pi::new(kp_d, ki_d, dt, v_min, v_max),
    q_pi: @pi.Pi::new(kp_q, ki_q, dt, v_min, v_max),
    ts: dt,
    vdc,
    v_mag_max: 0.0,
    last_id: 0.0,
    last_iq: 0.0,
    last_alpha: 0.0,
    last_beta: 0.0,
    last_vd: 0.0,
    last_vq: 0.0,
  }
}

///|
/// 带合成矢量限幅的构造。
///
/// 原来的 `new` 只把 d、q 两轴各自限在 `[v_min, v_max]`：两轴同时顶边时合成
/// 幅值是 `√2 · v_max`，交给 SVPWM 时已经进了过调制区，调制链路会整体缩放
/// T1/T2 把幅值削回来，而 PI 并不知道自己被削了，积分项继续按未削顶的误差
/// 累积。`v_mag_max` 给的是合成矢量的幅值上限（线性调制区取 `vdc/√3`），
/// 超过时按方向缩放，并按缩放后的指令回算积分项。传 0 或非有限值时退化成
/// 不启用，与 `new` 等价。
pub fn FocController::new_limited(
  kp_d : Double,
  ki_d : Double,
  kp_q : Double,
  ki_q : Double,
  dt : Double,
  vdc : Double,
  v_min : Double,
  v_max : Double,
  v_mag_max : Double,
) -> FocController {
  let mag_max = if finite(v_mag_max) && v_mag_max > 0.0 {
    v_mag_max
  } else {
    0.0
  }
  {
    d_pi: @pi.Pi::new(kp_d, ki_d, dt, v_min, v_max),
    q_pi: @pi.Pi::new(kp_q, ki_q, dt, v_min, v_max),
    ts: dt,
    vdc,
    v_mag_max: mag_max,
    last_id: 0.0,
    last_iq: 0.0,
    last_alpha: 0.0,
    last_beta: 0.0,
    last_vd: 0.0,
    last_vq: 0.0,
  }
}

///|
/// 合成电压矢量的幅值上限；0 表示不启用。
pub fn FocController::voltage_magnitude_limit(self : FocController) -> Double {
  self.v_mag_max
}

///|
/// 按幅值限幅一个电压矢量：方向不变，模长压到 `v_max`。
///
/// 输入非有限时返回零矢量（坏数不该进调制链路）；`v_max` 非正或非有限时
/// 原样返回，等价于不启用。
pub fn clamp_voltage_vector(
  vd : Double,
  vq : Double,
  v_max : Double,
) -> (Double, Double) {
  if !(finite(vd) && finite(vq)) {
    return (0.0, 0.0)
  }
  if !(finite(v_max) && v_max > 0.0) {
    return (vd, vq)
  }
  let largest = if vd.abs() > vq.abs() { vd.abs() } else { vq.abs() }
  if largest == 0.0 {
    return (vd, vq)
  }
  let d = vd / largest
  let q = vq / largest
  let norm = (d * d + q * q).sqrt()
  if largest <= v_max / norm {
    return (vd, vq)
  }
  (d * (v_max / norm), q * (v_max / norm))
}

///|
fn finite(x : Double) -> Bool {
  x == x && x.abs() <= 1.0e308
}

///|
/// 走一个采样拍。
///
/// 输入 `ia/ib/ic`（安培）、`theta_e`（电角度，弧度）、`id_ref/iq_ref`（给定
/// 安培）。返回 `(id, iq, vd, vq, da, db, dc)`：观测 d/q 电流、d/q 电压指令、
/// 三相占空比。
///
/// 任一输入非有限（NaN / ±Inf）时不进入 PI 状态，观测值与占空比一并返回
/// 零：坏采样不该把积分器或调制链路带偏。
pub fn FocController::step(
  self : FocController,
  ia : Double,
  ib : Double,
  ic : Double,
  theta_e : Double,
  id_ref : Double,
  iq_ref : Double,
) -> (Double, Double, Double, Double, Double, Double, Double) {
  if !(finite(ia) &&
    finite(ib) &&
    finite(ic) &&
    finite(theta_e) &&
    finite(id_ref) &&
    finite(iq_ref)) {
    return (0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  }
  let (alpha, beta) = @coord.clarke(ia, ib, ic)
  let (id, iq) = @coord.park(alpha, beta, theta_e)
  let err_d = id_ref - id
  let err_q = iq_ref - iq
  let mut vd = self.d_pi.step(err_d)
  let mut vq = self.q_pi.step(err_q)
  if self.v_mag_max > 0.0 {
    let (vd_lim, vq_lim) = clamp_voltage_vector(vd, vq, self.v_mag_max)
    if vd_lim != vd || vq_lim != vq {
      // 矢量方向被裁：SVPWM 过调制时会把 T1/T2 整体缩放，PI 却以为指令原样
      // 生效，接着按同一个误差继续积分。这里按裁完的指令回算积分项，
      // 误差反向时一步就能退饱和。
      self.d_pi.set_integral(vd_lim - self.d_pi.kp() * err_d)
      self.q_pi.set_integral(vq_lim - self.q_pi.kp() * err_q)
    }
    vd = vd_lim
    vq = vq_lim
  }
  let (valpha, vbeta) = @coord.inv_park(vd, vq, theta_e)
  let (da, db, dc) = @svpwm.duties(valpha, vbeta, self.ts, self.vdc)
  self.last_id = id
  self.last_iq = iq
  self.last_alpha = alpha
  self.last_beta = beta
  self.last_vd = vd
  self.last_vq = vq
  (id, iq, vd, vq, da, db, dc)
}

///|
/// 上一拍观测到的 d 轴电流。
pub fn FocController::last_id(self : FocController) -> Double {
  self.last_id
}

///|
/// 上一拍观测到的 q 轴电流。
pub fn FocController::last_iq(self : FocController) -> Double {
  self.last_iq
}

///|
/// 上一拍 alpha 电流。
pub fn FocController::last_alpha(self : FocController) -> Double {
  self.last_alpha
}

///|
/// 上一拍 beta 电流。
pub fn FocController::last_beta(self : FocController) -> Double {
  self.last_beta
}

///|
/// 上一拍 d 轴电压指令（伏特）。
pub fn FocController::last_vd(self : FocController) -> Double {
  self.last_vd
}

///|
/// 上一拍 q 轴电压指令（伏特）。
pub fn FocController::last_vq(self : FocController) -> Double {
  self.last_vq
}

///|
/// d 轴 PI 积分项（调试 / 观测用）。
pub fn FocController::d_integral(self : FocController) -> Double {
  self.d_pi.integral()
}

///|
/// q 轴 PI 积分项（调试 / 观测用）。
pub fn FocController::q_integral(self : FocController) -> Double {
  self.q_pi.integral()
}

///|
/// 清空 d/q 两侧积分器（重新使能、切模式时调用）。
pub fn FocController::reset(self : FocController) -> Unit {
  self.d_pi.reset()
  self.q_pi.reset()
}
