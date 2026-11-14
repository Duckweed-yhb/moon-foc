// controller/design_test.mbt — 电流环整定的回归：对消性质、交叉频率、相位裕度与延时损失。

///|
fn close_enough(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
/// 零极点对消：Ki/Kp 必须等于 R/L，否则相位裕度不再是 90°。
test "design: 对消比例 Ki/Kp = R/L" {
  let g = @controller.design_current_loop(0.5, 0.002, 1000.0)
  let ratio = g.ki() / g.kp()
  assert_true(close_enough(ratio, 0.5 / 0.002, 1.0e-9))
}

///|
/// 交叉频率应等于目标带宽：|C·P| 在 f_bw 处过 0 dB。
test "design: 交叉频率落在目标带宽" {
  let r = 0.5
  let l = 0.002
  let bw = 1000.0
  let g = @controller.design_current_loop(r, l, bw)
  let fc = @controller.crossover_hz(r, l, g.kp(), g.ki())
  assert_true(close_enough(fc, bw, bw * 1.0e-6))
  // 交叉点上环路增益幅值就是 1。
  let mag = @controller.loop_gain_mag(
    r,
    l,
    g.kp(),
    g.ki(),
    2.0 * 3.141592653589793 * fc,
  )
  assert_true(close_enough(mag, 1.0, 1.0e-9))
}

///|
/// 理想（无延时）相位裕度是 90°。
test "design: 理想相位裕度 90 度" {
  let r = 0.35
  let l = 0.0012
  let g = @controller.design_current_loop(r, l, 800.0)
  let pm = @controller.phase_margin_deg(r, l, g.kp(), g.ki())
  assert_true(close_enough(pm, 90.0, 1.0e-6))
}

///|
/// 延时损失 = 360·f_c·Ts，且实际裕度 = 理想裕度 − 损失。
test "design: 一拍延时相位损失换算" {
  let loss = @controller.delay_phase_loss_deg(4000.0, 50.0e-6)
  assert_true(close_enough(loss, 72.0, 1.0e-9))
  let r = 0.5
  let l = 0.002
  let g = @controller.design_current_loop(r, l, 4000.0)
  let pm = @controller.phase_margin_deg(r, l, g.kp(), g.ki())
  let after = @controller.margin_after_delay_deg(r, l, g.kp(), g.ki(), 50.0e-6)
  assert_true(close_enough(after, pm - 72.0, 1.0e-6))
}

///|
/// 可用性判据看的是计入延时后的裕度，不是理想裕度：90° 理想值挡不住高带宽。
test "design: 可用性判据计入延时" {
  let r = 0.5
  let l = 0.002
  // 4 kHz + 50 µs：理想 90°，实际 18°，45° 门槛下不可用。
  let fast = @controller.design_current_loop(r, l, 4000.0)
  assert_false(
    @controller.design_is_usable(r, l, fast.kp(), fast.ki(), 50.0e-6, 45.0),
  )
  // 1 kHz + 同样 50 µs：理想 90°，实际 72°，可用。
  let slow = @controller.design_current_loop(r, l, 1000.0)
  assert_true(
    @controller.design_is_usable(r, l, slow.kp(), slow.ki(), 50.0e-6, 45.0),
  )
}

///|
/// 带宽越大增益越大，但延时裕度越小。
test "design: 带宽单调性与裕度反向" {
  let r = 0.4
  let l = 0.0015
  let lo = @controller.design_current_loop(r, l, 500.0)
  let hi = @controller.design_current_loop(r, l, 2000.0)
  assert_true(hi.kp() > lo.kp())
  assert_true(hi.ki() > lo.ki())
  let m_lo = @controller.margin_after_delay_deg(r, l, lo.kp(), lo.ki(), 25.0e-6)
  let m_hi = @controller.margin_after_delay_deg(r, l, hi.kp(), hi.ki(), 25.0e-6)
  assert_true(m_lo > m_hi)
}

///|
/// 比例项不对消时裕度下降：把 Ki 抬到对消值的 4 倍，交叉点上积分器落后更多。
test "design: 偏离对消时裕度低于 90 度" {
  let r = 0.5
  let l = 0.002
  let g = @controller.design_current_loop(r, l, 1000.0)
  let pm_exact = @controller.phase_margin_deg(r, l, g.kp(), g.ki())
  let pm_off = @controller.phase_margin_deg(r, l, g.kp(), g.ki() * 4.0)
  assert_true(pm_off < pm_exact)
}

///|
/// 非法输入不产出 NaN 增益：负带宽、NaN 带宽一律零增益；非正电感夹到 1 nH。
test "design: 非法输入钳位" {
  let zero_bw = @controller.design_current_loop(0.5, 0.002, 0.0)
  assert_true(zero_bw.kp() == 0.0 && zero_bw.ki() == 0.0)
  let nan_bw = @controller.design_current_loop(0.5, 0.002, 0.0 / 0.0)
  assert_true(nan_bw.kp() == 0.0 && nan_bw.ki() == 0.0)
  // 负电阻按 0 处理：只剩比例项。
  let neg_r = @controller.design_current_loop(-1.0, 0.002, 1000.0)
  assert_true(neg_r.ki() == 0.0 && neg_r.kp() > 0.0)
  // 非正电感夹到 1 nH，仍给出有限增益。
  let bad_l = @controller.design_current_loop(0.5, 0.0, 1000.0)
  assert_true(bad_l.kp() > 0.0)
  let expected = 2.0 * 3.141592653589793 * 1000.0 * 1.0e-9
  assert_true(close_enough(bad_l.kp(), expected, 1.0e-12))
}

///|
/// 增益小到全程不过 0 dB 时没有交叉频率，返回 0 而不是编一个数出来。
test "design: 无交叉频率返回 0" {
  let fc = @controller.crossover_hz(0.5, 0.002, 1.0e-9, 0.0)
  assert_true(fc == 0.0)
}
