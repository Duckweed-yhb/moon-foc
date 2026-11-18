///|
test "load-step speed dip and recovery at two bandwidths" {
  let (fast_dip, fast_recovery) = run_case(40.0)
  let (slow_dip, slow_recovery) = run_case(20.0)
  // One integration step is 0.1 ms. Allow two steps for recovery timing.
  assert_true((fast_recovery - 0.0205).abs() <= 0.0002)
  assert_true((slow_recovery - 0.0626).abs() <= 0.0002)
  assert_true((fast_dip - 1.5511).abs() < 0.001)
  assert_true((slow_dip - 3.0639).abs() < 0.001)
}
