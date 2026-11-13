///|
/// motor 模型单测：零电压保持、RL 一阶上升、极对数换算、三相电流和为零。

///|
fn near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
fn make_model() -> @motor.PmsmModel {
  // R=0.5 Ω，Ld=Lq=1 mH，ψf=0.05 Wb，4 极对，静止
  @motor.PmsmModel::new(0.5, 0.001, 0.001, 0.05, 4, 0.0)
}

///|
test "zero voltage holds zero current" {
  let m = make_model()
  let mut k = 0
  while k < 500 {
    m.step(0.0, 0.0, 1.0e-4)
    k += 1
  }
  assert_true(m.id().abs() < 1.0e-12)
  assert_true(m.iq().abs() < 1.0e-12)
}

///|
test "d axis current rises toward v over r on the first order rl" {
  let m = make_model()
  let vd = 2.0
  let r = 0.5
  let dt = 1.0e-4
  let mut k = 0
  // 静止无反电势，q 轴给定 0 电压；只看 d 轴
  while k < 3000 {
    m.step(vd, 0.0, dt)
    k += 1
  }
  // 稳态目标 v/R = 4 A；3000 步（0.3 s）后应在目标的 90% 以上，且不超过目标
  assert_true(m.id() > 0.9 * vd / r)
  assert_true(m.id() <= vd / r + 1.0e-9)
  // q 轴无激励、静止无反电势，保持在 0 附近
  assert_true(m.iq().abs() < 1.0e-6)
}

///|
test "pole pairs scale mechanical speed to electrical speed" {
  let m = make_model()
  m.set_speed(100.0) // 机械角速度 100 rad/s，4 极对
  assert_true(near(m.omega_e(), 400.0))
  let dt = 1.0e-4
  m.step(0.0, 0.0, dt)
  // 电角度推进 ωe·dt = 0.04 rad
  assert_true(near(m.theta_e(), 400.0 * dt))
}

///|
test "phase currents sum to zero" {
  let m = make_model()
  m.set_speed(50.0)
  let mut k = 0
  while k < 200 {
    m.step(1.0, 1.5, 1.0e-4)
    k += 1
  }
  let (ia, ib, ic) = m.phase_currents()
  assert_true(near(ia + ib + ic, 0.0))
}

///|
test "non finite voltage or non positive dt keeps the state" {
  let m = make_model()
  m.step(1.0, 1.0, 1.0e-4)
  let id0 = m.id()
  let iq0 = m.iq()
  let nan = 0.0 / 0.0
  m.step(nan, 1.0, 1.0e-4)
  assert_true(near(m.id(), id0))
  assert_true(near(m.iq(), iq0))
  m.step(1.0, 1.0, 0.0)
  assert_true(near(m.id(), id0))
  assert_true(near(m.iq(), iq0))
}
