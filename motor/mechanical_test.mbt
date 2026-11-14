// motor/mechanical_test.mbt — 机械动力学与转矩换算的回归。

///|
fn mech_close(a : Double, b : Double) -> Bool {
  (a - b).abs() <= 1.0e-9 * (1.0 + b.abs())
}

///|
test "electromagnetic torque matches 1.5 pp psi iq for spmsm" {
  // pp = 4、ψf = 0.05、iq = 5 → 1.5·4·0.05·5 = 1.5 N·m
  let te = @motor.electromagnetic_torque(0.0, 5.0, 0.001, 0.001, 0.05, 4)
  assert_true(mech_close(te, 1.5))
  // 凸极项：Ld − Lq = 0.0002、id = 3 时多出 1.5·4·0.0002·3·5 = 0.018 N·m
  let te2 = @motor.electromagnetic_torque(3.0, 5.0, 0.0012, 0.001, 0.05, 4)
  assert_true(mech_close(te2, 1.518))
  // 非有限输入返回 0
  assert_eq(
    @motor.electromagnetic_torque(0.0 / 0.0, 5.0, 0.001, 0.001, 0.05, 4),
    0.0,
  )
}

///|
test "mechanical model accelerates under torque and holds without it" {
  let m = @motor.MechanicalModel::new(0.01, 0.0, 4, 0.0)
  // Te = 1 N·m、J = 0.01、0.1 s → ω = 10 rad/s
  for _ in 0..<1000 {
    m.step(1.0, 0.0, 1.0e-4)
  }
  assert_true(mech_close(m.omega_m(), 10.0))
  // 断电（Te = 0、无阻尼）转速保持
  for _ in 0..<10 {
    m.step(0.0, 0.0, 1.0e-4)
  }
  assert_true(mech_close(m.omega_m(), 10.0))
}

///|
test "load torque drags the speed down" {
  let m = @motor.MechanicalModel::new(0.01, 0.0, 2, 0.0)
  for _ in 0..<1000 {
    m.step(1.0, 0.0, 1.0e-4)
  }
  let before = m.omega_m()
  for _ in 0..<1000 {
    m.step(0.0, 1.0, 1.0e-4)
  }
  assert_true(before > 0.0)
  assert_true(m.omega_m() < before)
}

///|
test "viscous damping settles at the torque balance speed" {
  // Te = 1、B = 0.1 → 稳态 ω = Te/B = 10 rad/s
  let m = @motor.MechanicalModel::new(0.01, 0.1, 4, 0.0)
  for _ in 0..<200000 {
    m.step(1.0, 0.0, 1.0e-5)
  }
  // 显式欧拉 200k 拍后残差约 2e-8，稳态按 1e-6 判。
  assert_true((m.omega_m() - 10.0).abs() <= 1.0e-6)
}

///|
test "mechanical model rejects bad dt and clamps negative speed" {
  let m = @motor.MechanicalModel::new(0.01, 0.0, 4, 3.0)
  m.step(1.0, 0.0, 0.0)
  assert_true(mech_close(m.omega_m(), 3.0))
  m.step(0.0 / 0.0, 0.0, 1.0e-4)
  assert_true(mech_close(m.omega_m(), 3.0))
  // 负转矩把转速压到零后不再穿过去
  for _ in 0..<1000 {
    m.step(-2.0, 0.0, 1.0e-4)
  }
  assert_eq(m.omega_m(), 0.0)
  // 极对数换算
  let m2 = @motor.MechanicalModel::new(0.01, 0.0, 4, 25.0)
  assert_true(mech_close(m2.omega_e(), 100.0))
  assert_eq(m2.theta_m() >= 0.0, true)
}
