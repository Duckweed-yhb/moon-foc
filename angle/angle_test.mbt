///|
/// angle 单测：归一化与机械→电角度。
fn approx_equal(x : Double, y : Double, eps : Double) -> Bool {
  (x - y).abs() < eps
}

///|
let eps = 0.000000001

///|
let pi = 3.141592653589793

///|
let two_pi = 6.283185307179586

///|
test "normalize: 0 stays 0" {
  assert_true(approx_equal(@angle.normalize_angle(0.0), 0.0, eps))
}

///|
test "normalize: pi stays pi" {
  assert_true(approx_equal(@angle.normalize_angle(pi), pi, eps))
}

///|
test "normalize: 2pi wraps to 0" {
  assert_true(approx_equal(@angle.normalize_angle(two_pi), 0.0, eps))
}

///|
test "normalize: 3pi wraps to pi" {
  assert_true(approx_equal(@angle.normalize_angle(3.0 * pi), pi, eps))
}

///|
test "normalize: -pi wraps to pi" {
  assert_true(approx_equal(@angle.normalize_angle(-pi), pi, eps))
}

///|
test "normalize: -pi/2 wraps to 3pi/2" {
  assert_true(
    approx_equal(@angle.normalize_angle(-pi / 2.0), 3.0 * pi / 2.0, eps),
  )
}

///|
test "mech_to_elec: 0 rad mech → 0 elec" {
  assert_true(approx_equal(@angle.mechanical_to_electrical(0.0, 32), 0.0, eps))
}

///|
test "mech_to_elec: pi/2 mech × 2 poles = pi elec" {
  assert_true(
    approx_equal(@angle.mechanical_to_electrical(pi / 2.0, 2), pi, eps),
  )
}

///|
test "mech_to_elec: pi mech × 2 poles = 2pi → 0" {
  assert_true(approx_equal(@angle.mechanical_to_electrical(pi, 2), 0.0, eps))
}

///|
test "normalize: -3pi/2 wraps to pi/2" {
  assert_true(
    approx_equal(@angle.normalize_angle(-3.0 * pi / 2.0), pi / 2.0, eps),
  )
}

///|
test "mech_to_elec: negative mechanical angle normalizes" {
  // -pi/4 × 2 = -pi/2 → 3pi/2
  assert_true(
    approx_equal(
      @angle.mechanical_to_electrical(-pi / 4.0, 2),
      3.0 * pi / 2.0,
      eps,
    ),
  )
}

///|
test "mech_to_elec: zero pole pairs yields zero" {
  assert_true(approx_equal(@angle.mechanical_to_electrical(1.234, 0), 0.0, eps))
}

///|
test "electrical to mechanical is the inverse within one electrical period" {
  // 32 极对：一个电周期对应 2π/32 机械弧度。反解只能回到一个周期内。
  let p = 32
  for m in [0.0, 0.01, 0.05, 0.1] {
    let e = @angle.mechanical_to_electrical(m, p)
    let back = @angle.electrical_to_mechanical(e, p)
    let e2 = @angle.mechanical_to_electrical(back, p)
    assert_true((e - e2).abs() < 1.0e-12)
    assert_true(back >= 0.0)
    assert_true(back < 6.283185307179586 / 32.0 + 1.0e-12)
  }
  // 极对数为 0 时机械角没有意义，约定返回 0。
  assert_eq(@angle.electrical_to_mechanical(1.0, 0), 0.0)
}
