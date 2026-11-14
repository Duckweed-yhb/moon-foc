///|
fn close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
test "reconstruct third phase closes the three-phase sum" {
  let ia = 1.5
  let ib = -0.5
  let ic = @controller.reconstruct_third(ia, ib)
  assert_true(close(ic, -1.0, 1.0e-12))
  assert_true(
    close(@controller.zero_sequence_residual(ia, ib, ic), 0.0, 1.0e-12),
  )
}

///|
test "reconstruct clamps non-finite input to zero" {
  assert_true(@controller.reconstruct_third(0.0 / 0.0, 1.0) == 0.0)
  assert_true(@controller.reconstruct_third(1.0, 1.0 / 0.0) == 0.0)
  // 全零输入仍然给出 0，不因为守卫把合法值也吃掉。
  assert_true(@controller.reconstruct_third(0.0, 0.0) == 0.0)
}

///|
test "sensor consistency check flags a broken channel" {
  // 正常：三路和为 0。
  assert_true(@controller.currents_consistent(0.8, -0.3, -0.5, 1.0e-9))
  // 一路掉线成 0：和三为 0.8，超过 1e-3 容差。
  assert_false(@controller.currents_consistent(0.8, 0.0, -0.5, 1.0e-3))
  // 容差非法时不放行。
  assert_false(@controller.currents_consistent(0.8, -0.3, -0.5, -1.0))
  assert_false(@controller.currents_consistent(0.8, -0.3, -0.5, 0.0 / 0.0))
}

///|
test "sample window margin follows duty and period" {
  let ts = 50.0e-6
  let min_window = 2.0e-6
  // 50% 占空比：下管导通 25 µs，减去 2 µs 建立时间还有 23 µs。
  assert_true(
    close(
      @controller.sample_window_margin(0.5, ts, min_window),
      23.0e-6,
      1.0e-12,
    ),
  )
  // 99% 占空比：只剩 0.5 µs，不够建立。
  assert_false(@controller.window_ok(0.99, ts, min_window))
  // 98% 占空比：1 µs 仍不够；97% 恰好 1.5 µs 也不够，96% 得 2 µs，边界可用。
  assert_false(@controller.window_ok(0.98, ts, min_window))
  assert_true(@controller.window_ok(0.96, ts, min_window))
  // 占空比越界先钳位：负占空比按 0 处理，>1 按 1 处理。
  assert_true(@controller.window_ok(-0.5, ts, min_window))
  assert_false(@controller.window_ok(1.2, ts, min_window))
}

///|
test "sample window rejects bad configuration" {
  assert_false(@controller.window_ok(0.5, 0.0, 0.0))
  assert_false(@controller.window_ok(0.5, 50.0e-6, -1.0))
  assert_false(@controller.window_ok(0.0 / 0.0, 50.0e-6, 2.0e-6))
  assert_false(@controller.window_ok(0.5, 1.0 / 0.0, 2.0e-6))
}

///|
test "pick sample pair ranks by window margin" {
  let ts = 50.0e-6
  let min_window = 2.0e-6
  // 余量：a = 43 µs、b = 23 µs、c = 0.5 µs。
  let pairs = @controller.pick_sample_pair((0.1, 0.5, 0.99), ts, min_window)
  // c 相不满足窗口，只剩 (a,b) 一对。
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0], (0, 1))
  // 三相都富余时，最小余量最大的那对排第一。
  let all = @controller.pick_sample_pair((0.1, 0.3, 0.5), ts, min_window)
  assert_eq(all.length(), 3)
  assert_eq(all[0], (0, 1))
  // (0,2) 与 (1,2) 的较小余量都是 23 µs，同余量按插入顺序保留，不引入随机性。
  assert_eq(all[1], (0, 2))
  assert_eq(all[2], (1, 2))
}

///|
test "pick sample pair gives nothing when all phases are too narrow" {
  let ts = 50.0e-6
  let min_window = 5.0e-6
  let pairs = @controller.pick_sample_pair((0.95, 0.96, 0.97), ts, min_window)
  assert_eq(pairs.length(), 0)
}

///|
test "two-phase step matches the three-phase controller" {
  let c1 = @controller.FocController::new(
    0.5, 20.0, 0.5, 20.0, 50.0e-6, 48.0, -24.0, 24.0,
  )
  let c2 = @controller.FocController::new(
    0.5, 20.0, 0.5, 20.0, 50.0e-6, 48.0, -24.0, 24.0,
  )
  let theta = 0.7
  let ia = 1.2
  let ib = -0.4
  let a = c1.step(ia, ib, -ia - ib, theta, 0.0, 2.0)
  let b = c2.step_from_two_phases(ia, ib, theta, 0.0, 2.0)
  let (a1, a2, a3, a4, a5, a6, a7) = a
  let (b1, b2, b3, b4, b5, b6, b7) = b
  assert_true(close(a1, b1, 1.0e-12))
  assert_true(close(a2, b2, 1.0e-12))
  assert_true(close(a3, b3, 1.0e-12))
  assert_true(close(a4, b4, 1.0e-12))
  assert_true(close(a5, b5, 1.0e-12))
  assert_true(close(a6, b6, 1.0e-12))
  assert_true(close(a7, b7, 1.0e-12))
}
