///|
test "probe feedforward finite large input stays limited" {
  let (d, _) = @controller.apply_feedforward(1.0e200, 0.0, 0.0, 0.0, 48.0)
  assert_true(d.abs() <= 48.0 / 3.0.sqrt())
}

///|
test "feedforward sum overflow returns zero" {
  let (d, q) = @controller.apply_feedforward(1.0e308, 0.0, 1.0e308, 0.0, 48.0)
  assert_eq(d, 0.0)
  assert_eq(q, 0.0)
}

///|
test "feedforward huge vector keeps direction" {
  let (d, q) = @controller.apply_feedforward(3.0e200, -4.0e200, 0.0, 0.0, 48.0)
  let limit = 48.0 / 3.0.sqrt()
  assert_true((d - limit * 0.6).abs() < 1.0e-12)
  assert_true((q + limit * 0.8).abs() < 1.0e-12)
}
