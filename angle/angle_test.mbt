/// angle 单测：归一化与机械→电角度。

fn approx_equal(x : Double, y : Double, eps : Double) -> Bool {
  (x - y).abs() < eps
}

let eps = 0.000000001
let pi = 3.141592653589793
let two_pi = 6.283185307179586

test "normalize: 0 stays 0" {
  assert_true(approx_equal(@angle.normalize_angle(0.0), 0.0, eps))
}

test "normalize: pi stays pi" {
  assert_true(approx_equal(@angle.normalize_angle(pi), pi, eps))
}

test "normalize: 2pi wraps to 0" {
  assert_true(approx_equal(@angle.normalize_angle(two_pi), 0.0, eps))
}

test "normalize: 3pi wraps to pi" {
  assert_true(approx_equal(@angle.normalize_angle(3.0 * pi), pi, eps))
}

test "normalize: -pi wraps to pi" {
  assert_true(approx_equal(@angle.normalize_angle(-pi), pi, eps))
}

test "normalize: -pi/2 wraps to 3pi/2" {
  assert_true(approx_equal(@angle.normalize_angle(-pi / 2.0), 3.0 * pi / 2.0, eps))
}

test "mech_to_elec: 0 rad mech → 0 elec" {
  assert_true(approx_equal(@angle.mechanical_to_electrical(0.0, 32), 0.0, eps))
}

test "mech_to_elec: pi/2 mech × 2 poles = pi elec" {
  assert_true(approx_equal(@angle.mechanical_to_electrical(pi / 2.0, 2), pi, eps))
}

test "mech_to_elec: pi mech × 2 poles = 2pi → 0" {
  assert_true(approx_equal(@angle.mechanical_to_electrical(pi, 2), 0.0, eps))
}
