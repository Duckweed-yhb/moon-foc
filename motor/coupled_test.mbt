///|
/// 电机模型可选 d/q 交叉耦合项：默认关闭、开启后 d 轴被 q 轴电流拖动、
/// 解耦前馈能把耦合抵消、开关可读可关。
///
/// 这几条锁住的是「开关默认关闭不改变既有读数」与「开启后方程真的多了一项」。

///|
fn cc_near(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn cc_model() -> @motor.PmsmModel {
  // 与 motor_test 的 make_model 同参数：R=0.5，Ld=Lq=1 mH，ψf=0.05，4 极对
  @motor.PmsmModel::new(0.5, 0.001, 0.001, 0.05, 4, 0.0)
}

///|
/// 把 q 轴电流拉到 2 A（静止、零磁链时一阶 RL 的稳态是 vq/R = 2 A）。
fn cc_settle_iq(m : @motor.PmsmModel) -> Unit {
  let mut k = 0
  while k < 800 {
    m.step(0.0, 1.0, 1.0e-4)
    k += 1
  }
}

///|
/// 开启耦合后，iq 在 d 轴上产生 +ωe·Lq·iq 的拖动项；同构但未开启的模型 id 恒为 0。
test "cross coupling pulls d axis current while iq is nonzero" {
  let coupled = cc_model()
  let plain = cc_model()
  assert_true(!coupled.cross_coupling_enabled())
  // ψf 暂不影响本用例关心的 d 轴拖动，静止先把 iq 拉到 2 A
  cc_settle_iq(coupled)
  cc_settle_iq(plain)
  assert_true(cc_near(coupled.iq(), 2.0, 1.0e-6))
  assert_true(cc_near(plain.iq(), 2.0, 1.0e-6))
  coupled.enable_cross_coupling()
  assert_true(coupled.cross_coupling_enabled())
  coupled.set_speed(12.5) // 4 极对 → ωe = 50 rad/s
  plain.set_speed(12.5)
  let mut k = 0
  // vq 取 R·iq + ωe·ψf = 3.5 V，让 q 轴本身大致站住，单独看 d 轴被拖动
  while k < 100 {
    coupled.step(0.0, 3.5, 1.0e-4)
    plain.step(0.0, 3.5, 1.0e-4)
    k += 1
  }
  assert_true(coupled.id() > 0.05)
  assert_true(plain.id() == 0.0)
}

///|
/// 用 decoupling_terms 作 vd、vq_ff + R·iq 作 vq 时，交叉项与反电势被抵消：
/// id 贴在 0、iq 贴在 2 A；同一个初态下不加前馈，单步 id 就被拖动。
test "decoupling feedforward cancels the cross coupling" {
  let m = cc_model()
  cc_settle_iq(m)
  assert_true(cc_near(m.iq(), 2.0, 1.0e-6))
  m.set_speed(100.0) // ωe = 400 rad/s
  m.enable_cross_coupling()
  let id0 = m.id()
  let iq0 = m.iq()
  // 单步对照：不加前馈，vd = 0，vq 取稳态值（R·iq + ωe·ψf）
  m.step(0.0, 0.5 * iq0 + 400.0 * 0.05, 1.0e-5)
  assert_true(m.id() > 0.005)

  // 另起一台同参数模型，从同样的 iq 出发，每步用前馈抵消
  let ff = cc_model()
  cc_settle_iq(ff)
  ff.set_speed(100.0)
  ff.enable_cross_coupling()
  let mut k = 0
  while k < 2000 {
    let (vd_ff, vq_ff) = @controller.decoupling_terms(
      400.0,
      0.001,
      0.001,
      0.05,
      ff.id(),
      ff.iq(),
    )
    ff.step(vd_ff, vq_ff + 0.5 * ff.iq(), 1.0e-5)
    k += 1
  }
  assert_true(cc_near(ff.id(), id0, 1.0e-12))
  assert_true(cc_near(ff.iq(), iq0, 1.0e-9))
}

///|
/// 开关状态可读可关：关掉之后 d 轴不再被拖动，读数回到 0。
test "cross coupling switch can be turned off again" {
  let m = cc_model()
  cc_settle_iq(m)
  m.set_speed(12.5)
  m.enable_cross_coupling()
  m.step(0.0, 1.0, 1.0e-4)
  assert_true(m.id() > 0.0)
  m.disable_cross_coupling()
  assert_true(!m.cross_coupling_enabled())
  let before = m.id()
  let mut k = 0
  while k < 100 {
    m.step(0.0, 1.0, 1.0e-4)
    k += 1
  }
  // 关掉后 d 轴方程只剩 −R·id，id 按 L/R 时间常数单调回落
  assert_true(m.id() < 0.9 * before)
  assert_true(m.id() >= 0.0)
}
