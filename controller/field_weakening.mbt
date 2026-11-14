// controller/field_weakening.mbt — 电压极限下的弱磁 id 给定。
//
// 电压方程在稳态（忽略 di/dt 与电阻压降）可以写成
//
//   vd ≈ −ωe·Lq·iq
//   vq ≈  ωe·(Ld·id + ψf)
//
// 合成矢量要被母线限制住：vd² + vq² ≤ Vmax²。转速升高时 ωe·ψf 一项自己就会
// 顶到边界，继续提速只能把 id 往负方向压，用 Ld·id 抵消一部分永磁磁链 - 这就是
// 弱磁。这里把它写成两个函数：
//
//   flux_headroom = sqrt(Vmax² − (ωe·Lq·iq)²) / |ωe| − ψf
//   id_ref        = flux_headroom / Ld（再钳到 [id_min, 0]）
//
// 只覆盖线性调制区与稳态近似：没有算电阻压降、没有算动态项、没有电流环带宽
// 之外的相位滞后；`vmax` 取 Vdc/√3 时与 `svpwm` 的线性区边界一致。

///|
/// 给定 q 轴电流与转速，返回电压极限允许的 d 轴磁链余量（Wb）。
///
/// 返回值为负表示永磁磁链已经超出电压极限，需要负的 id 去抵消；
/// 返回值为正表示还有余量，可以维持 id = 0。
/// 输入非有限、`vmax` 非正、`omega_e` 为 0 或 `ld` 非正时返回 0。
pub fn flux_headroom(
  omega_e : Double,
  ld : Double,
  lq : Double,
  psi_f : Double,
  iq : Double,
  vmax : Double,
) -> Double {
  if !(fw_finite(omega_e) &&
    fw_finite(ld) &&
    fw_finite(lq) &&
    fw_finite(psi_f) &&
    fw_finite(iq) &&
    fw_finite(vmax)) {
    return 0.0
  }
  if ld <= 0.0 || vmax <= 0.0 || omega_e == 0.0 {
    return 0.0
  }
  let speed = omega_e.abs()
  let vq_term = speed * lq * iq
  let square = vmax * vmax - vq_term * vq_term
  if square <= 0.0 {
    return -psi_f
  }
  square.sqrt() / speed - psi_f
}

///|
/// 电压极限下的 d 轴给定：`id = flux_headroom / Ld`，钳到 `[id_min, 0]`。
///
/// 返回 0 表示不需要弱磁（还在恒转矩区）；负值表示需要压 id 换转速。
/// `id_min` 是负的电流下限（一般取 −Imax），正值按 0 处理；其余非法输入返回 0。
pub fn field_weakening_id(
  omega_e : Double,
  ld : Double,
  lq : Double,
  psi_f : Double,
  iq : Double,
  vmax : Double,
  id_min : Double,
) -> Double {
  if !(fw_finite(id_min) &&
    fw_finite(omega_e) &&
    fw_finite(ld) &&
    fw_finite(lq) &&
    fw_finite(psi_f) &&
    fw_finite(iq) &&
    fw_finite(vmax)) {
    return 0.0
  }
  if ld <= 0.0 || vmax <= 0.0 || omega_e == 0.0 {
    return 0.0
  }
  let floor = if id_min < 0.0 { id_min } else { 0.0 }
  let speed = omega_e.abs()
  let vq_term = speed * lq * iq
  let square = vmax * vmax - vq_term * vq_term
  if square <= 0.0 {
    return floor
  }
  let headroom = square.sqrt() / speed - psi_f
  if headroom >= 0.0 {
    return 0.0
  }
  let id = headroom / ld
  if id < floor {
    floor
  } else {
    id
  }
}

///|
fn fw_finite(x : Double) -> Bool {
  x == x && x != 1.0 / 0.0 && x != -1.0 / 0.0
}
