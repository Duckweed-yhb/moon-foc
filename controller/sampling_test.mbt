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

///|
test "pair currents place the measured values on the named phases" {
  // pair (0,2)：a、c 实测，b 重构。
  let (ia, ib, ic) = @controller.pair_currents((0, 2), 1.5, -0.7)
  assert_true(close(ia, 1.5, 1.0e-12))
  assert_true(close(ic, -0.7, 1.0e-12))
  assert_true(close(ib, -0.8, 1.0e-12))
  // pair (1,2)：b、c 实测，a 重构。
  let (ja, jb, jc) = @controller.pair_currents((1, 2), 0.9, 0.4)
  assert_true(close(jb, 0.9, 1.0e-12))
  assert_true(close(jc, 0.4, 1.0e-12))
  assert_true(close(ja, -1.3, 1.0e-12))
  // 还原后三相仍满足和为零。
  assert_true(@controller.currents_consistent(ia, ib, ic, 1.0e-12))
  assert_true(@controller.currents_consistent(ja, jb, jc, 1.0e-12))
}

///|
test "pair currents reject a malformed pair or a bad sample" {
  // 相号越界、两相相同都当成坏采样，返回全零而不是猜一个相。
  let (a1, b1, c1) = @controller.pair_currents((0, 3), 1.0, 2.0)
  assert_true(close(a1, 0.0, 1.0e-12))
  assert_true(close(b1, 0.0, 1.0e-12))
  assert_true(close(c1, 0.0, 1.0e-12))
  let (a2, b2, c2) = @controller.pair_currents((1, 1), 1.0, 2.0)
  assert_true(close(a2 + b2 + c2, 0.0, 1.0e-12))
  assert_true(close(b2, 0.0, 1.0e-12))
  // 任一路 NaN 也让整组作废。
  let (a3, _, _) = @controller.pair_currents(
    (0, 1),
    1.0 / 0.0 - 1.0 / 0.0,
    -0.5,
  )
  assert_true(close(a3, 0.0, 1.0e-12))
}

///|
fn measured_for_pair(
  pair : (Int32, Int32),
  ia : Double,
  ib : Double,
  ic : Double,
) -> (Double, Double) {
  let (p, q) = pair
  let v1 = if p == 0 { ia } else if p == 1 { ib } else { ic }
  let v2 = if q == 0 { ia } else if q == 1 { ib } else { ic }
  (v1, v2)
}

///|
test "step from pair matches the three-phase controller for any pair" {
  let theta = 0.35
  let ia = 1.1
  let ib = -0.25
  let ic = -ia - ib
  for pair in [(0, 1), (0, 2), (1, 2)] {
    let c1 = @controller.FocController::new(
      0.5, 20.0, 0.5, 20.0, 50.0e-6, 48.0, -24.0, 24.0,
    )
    let c2 = @controller.FocController::new(
      0.5, 20.0, 0.5, 20.0, 50.0e-6, 48.0, -24.0, 24.0,
    )
    let (f1, f2, _, _, f5, f6, f7) = c1.step(ia, ib, ic, theta, 0.0, 2.0)
    let (ma, mb) = measured_for_pair(pair, ia, ib, ic)
    let (t1, t2, _, _, t5, t6, t7) = c2.step_from_pair(
      pair, ma, mb, theta, 0.0, 2.0,
    )
    assert_true(close(f1, t1, 1.0e-12))
    assert_true(close(f2, t2, 1.0e-12))
    assert_true(close(f5, t5, 1.0e-12))
    assert_true(close(f6, t6, 1.0e-12))
    assert_true(close(f7, t7, 1.0e-12))
  }
}

///|
test "step from pair leaves the controller untouched on a bad pair" {
  let c = @controller.FocController::new(
    0.5, 20.0, 0.5, 20.0, 50.0e-6, 48.0, -24.0, 24.0,
  )
  let _ = c.step(1.2, -0.4, -0.8, 0.7, 0.0, 2.0)
  let before = c.q_integral()
  let out = c.step_from_pair((0, 0), 1.2, -0.4, 0.7, 0.0, 2.0)
  let (o1, o2, _, _, o5, _, _) = out
  assert_true(close(o1, 0.0, 1.0e-12))
  assert_true(close(o2, 0.0, 1.0e-12))
  assert_true(close(o5, 0.0, 1.0e-12))
  assert_true(close(c.q_integral(), before, 1.0e-12))
}
