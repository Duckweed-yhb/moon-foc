///|
/// 造一个 NaN（inf - inf），不依赖 stdlib 是否提供常量。
fn nan_value() -> Double {
  let big = 1.0e308 * 10.0
  big - big
}

///|
/// 评审回归：README 承诺「`duties` 遇非法输入返回 (0,0,0)，不返回 NaN」。
///
/// 入口的 `finite` 只看得见原始输入，中间量却会先溢出：`alpha²` 在
/// |alpha| > 1.34e154 时已经是 Inf，`√3·ts/vdc` 在 vdc 极小时也会溢出，
/// 再乘 0 就变 NaN。旧实现把 NaN 直接交给调用方（会一路传到 PWM 比较寄存器）。
test "duties never returns NaN for extreme but finite inputs" {
  let nan = nan_value()
  let cases : Array[(Double, Double, Double, Double)] = [
    (1.0e155, 0.0, 0.0001, 24.0),
    (1.0e200, 0.0, 1.0, 24.0),
    (1.0, 0.0, 0.0001, 5.0e-324),
  ]
  for c in cases {
    let (da, db, dc) = @svpwm.duties(c.0, c.1, c.2, c.3)
    assert_eq(da != da, false)
    assert_eq(db != db, false)
    assert_eq(dc != dc, false)
  }
  let _ = nan
}

///|
/// `duties_checked` 不能把「算不出来、只能兜底返回零矢量」的输入报成 Ok。
test "duties_checked never reports Ok with NaN" {
  match @svpwm.duties_checked(1.0e200, 0.0, 0.0001, 24.0) {
    Ok(t) => {
      assert_eq(t.0 != t.0, false)
      assert_eq(t.1 != t.1, false)
      assert_eq(t.2 != t.2, false)
    }
    Err(_) => ()
  }
  // 平方会溢出的量级必须在入口就被拒，而不是算出零矢量再报 Ok
  assert_true(@svpwm.check_inputs(1.0e200, 0.0, 0.0001, 24.0) is Err(_))
  assert_true(@svpwm.check_inputs(0.0, 0.0, 0.0001, 5.0e-324) is Err(_))
  // 正常量级仍然通过
  assert_true(@svpwm.check_inputs(0.5, 0.5, 0.0001, 24.0) is Ok(_))
}

///|
/// 载波法路径同样不能返回 NaN（vdc 极小会让 half 下溢、除法溢出）。
test "duties_from_voltages never returns NaN" {
  let (da, db, dc) = @svpwm.duties_from_voltages(1.0, -0.5, -0.5, 5.0e-324)
  assert_eq(da != da, false)
  assert_eq(db != db, false)
  assert_eq(dc != dc, false)
}

///|
/// 评审回归：`switching_sequence` 不能把 NaN 当成「零时长段」丢掉后返回一个
/// 看起来正常的序列。非法输入一律返回空数组。
test "switching_sequence rejects NaN durations" {
  let nan = nan_value()
  assert_eq(@svpwm.switching_sequence(1, nan, 0.0001, 0.0001).length(), 0)
  assert_eq(@svpwm.switching_sequence(1, 0.0001, nan, 0.0001).length(), 0)
}

///|
/// 评审回归：容差必须是相对的。比例钳位后 t1+t2 = ts·(1±1e-16)，旧的绝对
/// 容差 1e-18 在 ts ≥ 0.01 s 时会把合法的过调制输入判成非法、返回空数组。
test "switching_sequence accepts clamped overmodulation at large ts" {
  for ts in [0.001, 0.01, 0.1, 1.0] {
    // 过调制边界：t1 = ts 整段，t2 = 0（比例钳位的退化情形）
    let seq = @svpwm.switching_sequence(1, ts, 0.0, ts)
    assert_true(seq.length() > 0)
  }
}
