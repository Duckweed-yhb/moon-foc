// controller/feedforward_test.mbt — 解耦前馈与限幅的回归。
//
// 锁住三件事：① 前馈项符号与电压方程一致；② 限幅只缩幅值不改方向；
// ③ 非有限输入不把 NaN 带进电压指令。

///|
fn ff_close(a : Double, b : Double) -> Bool {
  (a - b).abs() <= 1.0e-9 * (1.0 + b.abs())
}

///|
test "back emf follows omega times flux" {
  let pi = 3.141592653589793
  // 100 Hz 电频率、ψf = 0.1 Wb → 62.83 V
  let v = @controller.back_emf_voltage(2.0 * pi * 100.0, 0.1)
  assert_true(ff_close(v, 2.0 * pi * 10.0))
  assert_eq(@controller.back_emf_voltage(0.0, 0.1), 0.0)
  assert_eq(@controller.back_emf_voltage(1000.0, 0.0), 0.0)
}

///|
test "back emf degrades to zero on non finite input" {
  assert_eq(@controller.back_emf_voltage(0.0 / 0.0, 0.1), 0.0)
  assert_eq(@controller.back_emf_voltage(1000.0, 1.0 / 0.0), 0.0)
}

///|
test "decoupling terms vanish at zero speed" {
  let (vd, vq) = @controller.decoupling_terms(
    0.0, 0.0008, 0.0012, 0.05, 3.0, 5.0,
  )
  assert_eq(vd, 0.0)
  assert_eq(vq, 0.0)
}

///|
test "decoupling terms carry the signs of the voltage equation" {
  // ωe = 400 rad/s，Lq = 1.2 mH，iq = 5 A → vd_ff = -2.4 V
  // Ld·id = 0.0008·3 = 0.0024，加 ψf = 0.05 → vq_ff = 400·0.0524 = 20.96 V
  let (vd, vq) = @controller.decoupling_terms(
    400.0, 0.0008, 0.0012, 0.05, 3.0, 5.0,
  )
  assert_true(ff_close(vd, -2.4))
  assert_true(ff_close(vq, 20.96))
  // d 轴电流为负时 vq_ff 下降；反电动势项仍在。
  let (_, vq2) = @controller.decoupling_terms(
    400.0, 0.0008, 0.0012, 0.05, -3.0, 5.0,
  )
  assert_true(ff_close(vq2, 400.0 * (0.05 - 0.0024)))
}

///|
test "apply feedforward passes through inside the linear region" {
  // |v| = sqrt(3²+4²) = 5 V，远低于 48 V 母线的 27.7 V 边界
  let (vd, vq) = @controller.apply_feedforward(1.0, 2.0, 2.0, 2.0, 48.0)
  assert_eq(vd, 3.0)
  assert_eq(vq, 4.0)
}

///|
test "apply feedforward clamps magnitude and keeps direction" {
  // 合成 (30, 40) → 幅值 50 V，超过 27.7128 V
  let (vd, vq) = @controller.apply_feedforward(30.0, 40.0, 0.0, 0.0, 48.0)
  let limit = 48.0 / 3.0.sqrt()
  let mag = (vd * vd + vq * vq).sqrt()
  assert_true(mag <= limit + 1.0e-9)
  assert_true(ff_close(mag, limit))
  // 方向不变：vd/vq 仍是 3:4
  assert_true(ff_close(vd / vq, 0.75))
}

///|
test "apply feedforward without a bus limit only sums" {
  // 母线未知（0）时限幅无意义，只相加。
  let (vd, vq) = @controller.apply_feedforward(30.0, 40.0, 0.0, 0.0, 0.0)
  assert_eq(vd, 30.0)
  assert_eq(vq, 40.0)
  // 母线非有限时同样只相加。
  let (vd2, vq2) = @controller.apply_feedforward(
    30.0,
    40.0,
    0.0,
    0.0,
    1.0 / 0.0,
  )
  assert_eq(vd2, 30.0)
  assert_eq(vq2, 40.0)
}

///|
test "apply feedforward rejects non finite inputs" {
  let (vd, vq) = @controller.apply_feedforward(0.0 / 0.0, 1.0, 1.0, 1.0, 48.0)
  assert_eq(vd, 0.0)
  assert_eq(vq, 0.0)
  let (vd2, vq2) = @controller.apply_feedforward(1.0, 1.0, 1.0 / 0.0, 0.0, 48.0)
  assert_eq(vd2, 0.0)
  assert_eq(vq2, 0.0)
  // 前馈项本身非有限时，decoupling_terms 已经返回零，这里再确认零不污染。
  let (vd3, vq3) = @controller.apply_feedforward(1.0, 1.0, 0.0, 0.0, 48.0)
  assert_eq(vd3, 1.0)
  assert_eq(vq3, 1.0)
}
