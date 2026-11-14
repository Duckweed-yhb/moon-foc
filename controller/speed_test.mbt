// controller/speed_test.mbt — 速度环整定与 iq 给定的回归。

///|
fn sp_close(a : Double, b : Double) -> Bool {
  (a - b).abs() <= 1.0e-9 * (1.0 + b.abs())
}

///|
test "speed gains follow bandwidth and inertia" {
  // J = 0.01 kg·m²、Kt = 0.3 N·m/A、50 Hz
  // ω_bw = 314.159 → Kp = 314.159·0.01/0.3 = 10.472
  // 积分时间常数取带宽的五分之一 → Ki = Kp·ω_bw/5 = 657.97
  let g = @controller.design_speed_loop(0.01, 0.001, 0.3, 50.0)
  assert_true(sp_close(g.kp(), 10.471975511965978))
  assert_true((g.ki() - 657.973627).abs() <= 1.0e-5)
}

///|
test "speed gains are zero without a torque constant or bandwidth" {
  assert_eq(@controller.design_speed_loop(0.01, 0.001, 0.0, 50.0).kp(), 0.0)
  assert_eq(@controller.design_speed_loop(0.01, 0.001, 0.3, 0.0).ki(), 0.0)
  assert_eq(
    @controller.design_speed_loop(0.01, 0.001, 0.0 / 0.0, 50.0).ki(),
    0.0,
  )
}

///|
test "speed gains clamp a non-positive inertia" {
  // J 非正夹到 1e-12，算出来的 Kp 应该极小但有限。
  let g = @controller.design_speed_loop(0.0, 0.001, 0.3, 50.0)
  assert_true(g.kp() > 0.0)
  assert_true(g.kp() < 1.0e-8)
}

///|
test "speed bandwidth must stay below the current loop" {
  assert_true(@controller.speed_bandwidth_ok(50.0, 400.0, 0.2))
  assert_false(@controller.speed_bandwidth_ok(100.0, 400.0, 0.2))
  assert_false(@controller.speed_bandwidth_ok(0.0, 400.0, 0.2))
  // 非法比值一律判不可用。
  assert_false(@controller.speed_bandwidth_ok(50.0, 400.0, 0.0 / 0.0))
}

///|
test "speed controller outputs current reference with the right sign" {
  let ctrl = @controller.SpeedController::new(10.0, 5.0, 1.0e-4, -8.0, 8.0)
  // 给定高于反馈 → 正转矩
  let up = ctrl.step(100.0, 0.0)
  assert_true(up > 0.0)
  ctrl.reset()
  // 反馈高于给定 → 负转矩（减速）
  let down = ctrl.step(0.0, 100.0)
  assert_true(down < 0.0)
}

///|
test "speed controller respects the current limit and rejects bad feedback" {
  let ctrl = @controller.SpeedController::new(10.0, 5.0, 1.0e-4, -8.0, 8.0)
  let v = ctrl.step(1000.0, 0.0)
  assert_true(v <= 8.0 && v >= -8.0)
  // 反馈非有限：输出 0，不把满转矩推出去。
  assert_eq(ctrl.step(100.0, 0.0 / 0.0), 0.0)
  // 给定非有限同理。
  assert_eq(ctrl.step(1.0 / 0.0, 10.0), 0.0)
}

///|
test "speed controller reset clears the integral state" {
  let ctrl = @controller.SpeedController::new(10.0, 5.0, 1.0e-4, -8.0, 8.0)
  for _ in 0..<20 {
    let _ = ctrl.step(100.0, 0.0)
  }
  assert_true(ctrl.iq_ref() > 0.0)
  ctrl.reset()
  assert_eq(ctrl.iq_ref(), 0.0)
  // 复位后零误差不再输出残留。
  assert_eq(ctrl.step(50.0, 50.0), 0.0)
}
