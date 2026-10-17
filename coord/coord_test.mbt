/// coord 往返测试：Clarke ↔ invClarke，Park ↔ invPark，以及对称三相直流量。

fn approx_equal(x : Double, y : Double, eps : Double) -> Bool {
  (x - y).abs() < eps
}

let eps = 0.000000001

test "clarke: balanced three-phase DC" {
  // ia=1, ib=-0.5, ic=-0.5  →  alpha=1, beta=0
  let (a, b) = @coord.clarke(1.0, -0.5, -0.5)
  assert_true(approx_equal(a, 1.0, eps))
  assert_true(approx_equal(b, 0.0, eps))
}

test "clarke: zero sum → inv_clarke roundtrip" {
  let (ia, ib, ic) = (0.7, -0.3, -0.4)
  let (a, b) = @coord.clarke(ia, ib, ic)
  let (ia2, ib2, ic2) = @coord.inv_clarke(a, b)
  assert_true(approx_equal(ia2, ia, eps))
  assert_true(approx_equal(ib2, ib, eps))
  assert_true(approx_equal(ic2, ic, eps))
}

test "inv_clarke: ia+ib+ic == 0" {
  let (ia, ib, ic) = @coord.inv_clarke(0.3, 0.8)
  assert_true(approx_equal(ia + ib + ic, 0.0, eps))
}

test "park: theta=0 identity" {
  // theta=0 → d=alpha, q=beta
  let (d, q) = @coord.park(0.4, 0.9, 0.0)
  assert_true(approx_equal(d, 0.4, eps))
  assert_true(approx_equal(q, 0.9, eps))
}

test "park: theta=pi/2" {
  // cos(pi/2)=0, sin(pi/2)=1 → d=beta, q=-alpha
  let (d, q) = @coord.park(0.4, 0.9, 1.5707963267948966)
  assert_true(approx_equal(d, 0.9, eps))
  assert_true(approx_equal(q, -0.4, eps))
}

test "park / inv_park roundtrip" {
  let (d, q) = (0.6, -0.3)
  let theta = 0.7
  let (a, b) = @coord.inv_park(d, q, theta)
  let (d2, q2) = @coord.park(a, b, theta)
  assert_true(approx_equal(d2, d, eps))
  assert_true(approx_equal(q2, q, eps))
}
