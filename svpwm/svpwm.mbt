/// SVPWM 扇区判断与作用时间计算。
///
/// 标准七段式 SVPWM。输入 alpha/beta 参考矢量（幅值不变约定），
/// 输出扇区号 (1-6)、相邻基本矢量作用时间 T1/T2、零矢量时间 T0。
/// Ts 为开关周期（秒），Vdc 为母线电压（伏特）。
///
/// 过调制：当 T1+T2 > Ts 时按比例缩放，使 T1+T2=Ts。

/// 根据 alpha/beta 判断扇区（1-6）。
///
/// 直接用 atan2 算电角度 theta_e ∈ [0, 2pi)，再按 pi/3 分扇区。
/// 扇区 1 = [0, pi/3)，扇区 2 = [pi/3, 2pi/3)，...，扇区 6 = [5pi/3, 2pi)。
pub fn sector_of(alpha : Double, beta : Double) -> Int {
  let theta = @math.atan2(beta, alpha)
  let theta_pos = if theta < 0.0 { theta + 3.141592653589793 * 2.0 } else { theta }
  let sector = (theta_pos / (3.141592653589793 / 3.0)).floor().to_int() + 1
  if sector > 6 {
    return 6
  }
  sector
}

/// 计算相邻矢量作用时间 T1/T2（与 Ts 同单位）。
///
/// 返回 (T1, T2)。线性区按 sin 分解；当 T1+T2 > Ts 时按比例缩放使 T1+T2=Ts。
pub fn action_times(
  alpha : Double, beta : Double, sector : Int, ts : Double, vdc : Double,
) -> (Double, Double) {
  if vdc <= 0.0 || ts <= 0.0 {
    return (0.0, 0.0)
  }
  let vref = (alpha * alpha + beta * beta).sqrt()
  if vref <= 0.000000000001 {
    return (0.0, 0.0)
  }
  // theta_e 是参考矢量相对 alpha 轴的电角度（弧度）
  let theta_e = @math.atan2(beta, alpha)
  // 把 theta_e 折到 [0, pi/3) 内，对应当前扇区的局部角
  let sector_d = sector.to_double()
  let sector_start = (sector_d - 1.0) * 3.141592653589793 / 3.0
  let local_angle = theta_e - sector_start
  // 负角度折回来（跨扇区边界时 theta_e 可能 < sector_start）
  let local_norm = if local_angle < 0.0 {
    local_angle + 3.141592653589793 * 2.0 / 3.0
  } else {
    local_angle
  }
  // T1/T2 公式（幅值不变约定，系数 sqrt(3)）
  let k = 3.0.sqrt() * ts / vdc
  let t1 = k * vref * @math.sin(3.141592653589793 / 3.0 - local_norm)
  let t2 = k * vref * @math.sin(local_norm)
  // 过调制：按比例缩
  let sum = t1 + t2
  if sum > ts && sum > 0.0 {
    let scale = ts / sum
    return (t1 * scale, t2 * scale)
  }
  (t1, t2)
}

/// 扇区 + T1/T2 → 三相占空比 (da, db, dc) ∈ [-1, 1]。
///
/// 七段式对称发波：零矢量在两端和中点平分 T0。
pub fn duties(
  alpha : Double, beta : Double, ts : Double, vdc : Double,
) -> (Double, Double, Double) {
  let sector = sector_of(alpha, beta)
  let (t1, t2) = action_times(alpha, beta, sector, ts, vdc)
  let t0 = ts - t1 - t2
  // 各相在一个开关周期内的高电平时间（秒），按扇区映射
  let (ta, tb, tc) = match sector {
    1 => (t0 / 2.0 + t1 + t2, t0 / 2.0 + t2, t0 / 2.0)
    2 => (t0 / 2.0 + t1, t0 / 2.0 + t1 + t2, t0 / 2.0)
    3 => (t0 / 2.0, t0 / 2.0 + t1 + t2, t0 / 2.0 + t2)
    4 => (t0 / 2.0, t0 / 2.0 + t1, t0 / 2.0 + t1 + t2)
    5 => (t0 / 2.0 + t2, t0 / 2.0, t0 / 2.0 + t1 + t2)
    _ => (t0 / 2.0 + t1 + t2, t0 / 2.0, t0 / 2.0 + t1) // sector 6
  }
  // 占空比 = 2*T_on/Ts - 1，范围 [-1, 1]
  let da = 2.0 * ta / ts - 1.0
  let db = 2.0 * tb / ts - 1.0
  let dc = 2.0 * tc / ts - 1.0
  (da, db, dc)
}
