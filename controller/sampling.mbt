///|
/// 电流采样侧：两相采样重构第三相、采样窗口判据与采样相选择。
///
/// 三相电流瞬时值之和为零（星形接法、无零序通路），所以硬件只需要两路
/// 电流传感器或两个采样电阻，第三相由 `ic = -ia - ib` 重构。这一步在真实
/// 控制器里紧跟 ADC，属于电流环入口的一部分，不是纯数学练习：
///
/// - 传感器坏一路时，三路都拿到数但和不为零，残差是排查传感器的第一手信号；
/// - 单电阻 / 双电阻采样要求该相的下管导通时间足够长（占空比不能贴近 1），
///   否则运放还没建立完 ADC 就转换了，采到的是开关噪声。`sample_window_margin`
///   把这条约束写成数字，`pick_sample_pair` 按余量挑一对相。

///|
/// 由两相重构第三相：`ic = -ia - ib`。
/// 任一路传入非有限值时返回 0，交由调用方的非法输入处理决定是否继续
/// （与 `FocController::step` 的「坏采样不进 PI」口径一致）。
pub fn reconstruct_third(ia : Double, ib : Double) -> Double {
  if !(finite(ia) && finite(ib)) {
    return 0.0
  }
  -ia - ib
}

///|
/// 三路电流之和。物理上恒为 0，非零即说明传感器偏置、断线或采样不同步。
/// 非有限输入返回 0（同上，坏数据不产出误导性的残差）。
pub fn zero_sequence_residual(ia : Double, ib : Double, ic : Double) -> Double {
  if !(finite(ia) && finite(ib) && finite(ic)) {
    return 0.0
  }
  ia + ib + ic
}

///|
/// 三路电流是否在容差内满足 `ia + ib + ic = 0`。
/// 容差取绝对值，量纲与电流一致。
pub fn currents_consistent(
  ia : Double,
  ib : Double,
  ic : Double,
  tol : Double,
) -> Bool {
  if !(finite(tol) && tol >= 0.0) {
    return false
  }
  zero_sequence_residual(ia, ib, ic).abs() <= tol
}

///|
/// 某相在开关周期内的「下管导通时间」余量：`(1 - duty)·ts - min_window`。
///
/// 正值表示 ADC 触发时刻之后仍有足够的建立时间；负值表示这一相不能用来
/// 采样。占空比先钳到 `[0, 1]`（调制器本身也会钳，这里不信任上游）；
/// `ts` 非正或 `min_window` 为负、非有限时返回一个足够负的余量，让判据
/// 直接失败而不是放行。
pub fn sample_window_margin(
  duty : Double,
  ts : Double,
  min_window : Double,
) -> Double {
  if !(finite(duty) && finite(ts) && finite(min_window)) {
    return -1.0
  }
  if ts <= 0.0 || min_window < 0.0 {
    return -1.0
  }
  let d = if duty < 0.0 { 0.0 } else if duty > 1.0 { 1.0 } else { duty }
  (1.0 - d) * ts - min_window
}

///|
/// 该相是否满足采样窗口约束（余量非负即认为够用，等于 0 属边界可用）。
pub fn window_ok(duty : Double, ts : Double, min_window : Double) -> Bool {
  sample_window_margin(duty, ts, min_window) >= 0.0
}

///|
/// 按占空比挑可用的采样相组合，返回 `(相A, 相B)` 下标对，按两相中较小余量
/// 从大到小排序。相的顺序固定为 a=0、b=1、c=2。
///
/// 返回空数组表示三相都不满足窗口，这一次采样应该被丢弃（或改用单电阻
/// 重构方案），而不是硬取一路噪声。
pub fn pick_sample_pair(
  duties : (Double, Double, Double),
  ts : Double,
  min_window : Double,
) -> Array[(Int32, Int32)] {
  let (da, db, dc) = duties
  let ma = sample_window_margin(da, ts, min_window)
  let mb = sample_window_margin(db, ts, min_window)
  let mc = sample_window_margin(dc, ts, min_window)
  let candidates : Array[((Int32, Int32), Double)] = []
  if ma >= 0.0 && mb >= 0.0 {
    candidates.push(((0, 1), if ma < mb { ma } else { mb }))
  }
  if ma >= 0.0 && mc >= 0.0 {
    candidates.push(((0, 2), if ma < mc { ma } else { mc }))
  }
  if mb >= 0.0 && mc >= 0.0 {
    candidates.push(((1, 2), if mb < mc { mb } else { mc }))
  }
  // 三对最多三组，直接按余量降序插入，避免引入排序依赖。
  let sorted : Array[((Int32, Int32), Double)] = []
  for c in candidates {
    let mut k = 0
    let mut placed = false
    while k < sorted.length() && !placed {
      if c.1 > sorted[k].1 {
        sorted.insert(k, c)
        placed = true
      } else {
        k += 1
      }
    }
    if !placed {
      sorted.push(c)
    }
  }
  let out : Array[(Int32, Int32)] = []
  for s in sorted {
    out.push(s.0)
  }
  out
}

///|
/// 把「按相号顺序给出的两路采样」还原成 a/b/c 三相电流。
///
/// `pair` 为 `pick_sample_pair` 给出的下标对（a=0、b=1、c=2），`i_first` /
/// `i_second` 依次对应 `pair.0` 与 `pair.1` 两相，第三相由
/// `ic = -ia - ib` 重构。相号非法（越界、两相相同）或采样非有限时返回
/// 全零，交由 `FocController::step` 的坏采样分支处理。
pub fn pair_currents(
  pair : (Int32, Int32),
  i_first : Double,
  i_second : Double,
) -> (Double, Double, Double) {
  let (p, q) = pair
  if p < 0 || p > 2 || q < 0 || q > 2 || p == q {
    return (0.0, 0.0, 0.0)
  }
  if !(finite(i_first) && finite(i_second)) {
    return (0.0, 0.0, 0.0)
  }
  let mut ia = 0.0
  let mut ib = 0.0
  let mut ic = 0.0
  if p == 0 {
    ia = i_first
  } else if p == 1 {
    ib = i_first
  } else {
    ic = i_first
  }
  if q == 0 {
    ia = i_second
  } else if q == 1 {
    ib = i_second
  } else {
    ic = i_second
  }
  let missing = 3 - p - q
  if missing == 0 {
    ia = -ib - ic
  } else if missing == 1 {
    ib = -ia - ic
  } else {
    ic = -ia - ib
  }
  (ia, ib, ic)
}

///|
/// 用任意一对相采样驱动一拍电流环。与 `step_from_two_phases` 的区别是采样
/// 相不固定为 a/b：单电阻采样在每拍按窗口挑相，挑到哪两相就把哪两相交给
/// 这里，内部按相号还原三相后调用 `step`。
pub fn FocController::step_from_pair(
  self : FocController,
  pair : (Int32, Int32),
  i_first : Double,
  i_second : Double,
  theta_e : Double,
  id_ref : Double,
  iq_ref : Double,
) -> (Double, Double, Double, Double, Double, Double, Double) {
  // 坏相号或坏采样在这里就挡住，不能交给 `step` 走「零电流」分支：那一支
  // 只拦非有限输入，全零是合法测量值，会带着上一拍的积分继续算，等于把
  // 一次坏采样当成「电流真的掉到 0」。
  let (p, q) = pair
  if p < 0 || p > 2 || q < 0 || q > 2 || p == q {
    return (0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  }
  if !(finite(i_first) && finite(i_second)) {
    return (0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  }
  let (ia, ib, ic) = pair_currents(pair, i_first, i_second)
  self.step(ia, ib, ic, theta_e, id_ref, iq_ref)
}

///|
/// 用两相采样驱动一拍电流环：内部重构第三相后调用 `FocController::step`。
/// 采样相由调用方按 `pick_sample_pair` 的结果给定，这里不做隐式挑选，
/// 避免把「这次采样该不该信」的决策藏在控制器里。
pub fn FocController::step_from_two_phases(
  self : FocController,
  ia : Double,
  ib : Double,
  theta_e : Double,
  id_ref : Double,
  iq_ref : Double,
) -> (Double, Double, Double, Double, Double, Double, Double) {
  let ic = reconstruct_third(ia, ib)
  self.step(ia, ib, ic, theta_e, id_ref, iq_ref)
}
