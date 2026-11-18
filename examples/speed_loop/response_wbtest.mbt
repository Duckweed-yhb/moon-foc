///|
test "load-step speed dip and recovery at two bandwidths" {
  let fast = run_case(40.0)
  let slow = run_case(20.0)
  assert_true((fast.first_entry - 0.0835).abs() < 0.0002)
  for response in [fast, slow] {
    assert_eq(response.iq_ref_peak, 8.0)
    assert_true((response.iq_peak - 8.2765).abs() < 0.001)
  }
  // One integration step is 0.1 ms. Allow two steps for recovery timing.
  assert_true((fast.recovery - 0.0205).abs() <= 0.0002)
  assert_true((slow.recovery - 0.0626).abs() <= 0.0002)
  assert_true((fast.dip - 1.5511).abs() < 0.001)
  assert_true((slow.dip - 3.0639).abs() < 0.001)
}
