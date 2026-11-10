///|
/// PI 调节器测试：比例、积分累积、限幅、抗饱和、复位与坏采样。
///
/// 期望值全部手算：kp/ki/dt 取整便于口算，饱和边界取 ±1。

///|
/// 浮点比较容差（手算值是十进制整/半整数，1e-12 足够）。
fn near(actual : Double, expected : Double) -> Bool {
  (actual - expected).abs() < 1.0e-12
}

///|
test "proportional only follows the error" {
  // ki=0 → 纯 P：输出 = kp·err，不随历史变化
  let pi = @pi.Pi::new(2.0, 0.0, 0.001, -100.0, 100.0)
  assert_true(near(pi.step(1.0), 2.0))
  assert_true(near(pi.step(0.5), 1.0))
  assert_true(near(pi.step(0.0), 0.0))
  // 纯 P 不留积分
  assert_true(near(pi.integral(), 0.0))
}

///|
test "integral accumulates ki times err times dt" {
  // kp=0、ki=10、dt=0.1 → 每步累加 10·1.0·0.1 = 1.0
  let pi = @pi.Pi::new(0.0, 10.0, 0.1, -100.0, 100.0)
  assert_true(near(pi.step(1.0), 1.0))
  assert_true(near(pi.step(1.0), 2.0))
  assert_true(near(pi.step(1.0), 3.0))
  assert_true(near(pi.integral(), 3.0))
}

///|
test "output is clamped and the integrator does not wind up" {
  // kp=10、限幅 ±1、err=1 → 输出顶在 1，积分器必须被冻住（否则越积越大）
  let pi = @pi.Pi::new(10.0, 1.0, 0.1, -1.0, 1.0)
  let mut i = 0
  while i < 50 {
    assert_true(near(pi.step(1.0), 1.0))
    i += 1
  }
  // 抗饱和生效：积分项没有涨到 5.0 这种量级
  assert_true(pi.integral() <= 1.0 + 1.0e-12)
  // 误差反向后，输出应当在一个采样步内退出饱和
  let out = pi.step(-1.0)
  assert_true(out < 1.0)
}

///|
test "negative saturation works the same way" {
  let pi = @pi.Pi::new(10.0, 1.0, 0.1, -1.0, 1.0)
  let mut i = 0
  while i < 50 {
    assert_true(near(pi.step(-1.0), -1.0))
    i += 1
  }
  assert_true(pi.integral() >= -1.0 - 1.0e-12)
  assert_true(pi.step(1.0) > -1.0)
}

///|
test "reset clears the integrator" {
  let pi = @pi.Pi::new(0.0, 10.0, 0.1, -100.0, 100.0)
  let _ = pi.step(1.0)
  assert_true(near(pi.integral(), 1.0))
  pi.reset()
  assert_true(near(pi.integral(), 0.0))
  assert_true(near(pi.step(1.0), 1.0))
}

///|
test "non finite error does not pollute the state" {
  let pi = @pi.Pi::new(1.0, 10.0, 0.1, -100.0, 100.0)
  let _ = pi.step(1.0) // 积分项 = 1.0
  let nan = 0.0 / 0.0
  let out = pi.step(nan)
  // 状态冻结，输出是当前积分项的限幅值
  assert_true(near(pi.integral(), 1.0))
  assert_true(near(out, 1.0))
  // 之后照常工作
  assert_true(near(pi.step(1.0), 3.0))
}

///|
test "zero dt degrades to proportional" {
  // dt<=0 按 0 处理：不再累加积分
  let pi = @pi.Pi::new(2.0, 10.0, 0.0, -100.0, 100.0)
  assert_true(near(pi.step(1.0), 2.0))
  assert_true(near(pi.integral(), 0.0))
}
