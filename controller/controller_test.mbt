///|
/// controller 回归测试：单拍链路一致性、闭环跟踪、输出限幅、抗饱和、坏采样与复位。
///
/// 闭环用例里的被控对象是测试内联的一阶 RL 模型（d/q 各一阶、无反电势），
/// 不依赖 motor 包；真实简化模型在 motor 包内单测。

///|
fn near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
/// 测试内联一阶 RL 被控对象：theta 恒为 0，d/q 各自按 RL 一阶步进。
fn three_phase(id : Double, iq : Double) -> (Double, Double, Double) {
  let sqrt3 = 3.0.sqrt()
  (id, -id / 2.0 + iq * sqrt3 / 2.0, -id / 2.0 - iq * sqrt3 / 2.0)
}

///|
test "single beat chain matches direct coord and svpwm calls" {
  let dt = 1.0e-4
  let vdc = 24.0
  let ctrl = @controller.FocController::new(
    2.0, 100.0, 2.0, 100.0, dt, vdc, -12.0, 12.0,
  )
  let (ia, ib, ic) = (1.0, -0.5, -0.5)
  let theta = 0.7
  let (id, iq, vd, vq, da, db, dc) = ctrl.step(ia, ib, ic, theta, 0.3, 0.8)

  // 观测电流必须等于直接调 coord 的结果
  let (alpha, beta) = @coord.clarke(ia, ib, ic)
  let (d_exp, q_exp) = @coord.park(alpha, beta, theta)
  assert_true(near(id, d_exp))
  assert_true(near(iq, q_exp))
  assert_true(near(ctrl.last_alpha(), alpha))
  assert_true(near(ctrl.last_beta(), beta))

  // 首拍积分项从 0 起，PI 输出 = kp·err + ki·err·dt（与 pi 包步进口径一致）
  let vd_exp = 2.0 * (0.3 - d_exp) + 100.0 * (0.3 - d_exp) * dt
  let vq_exp = 2.0 * (0.8 - q_exp) + 100.0 * (0.8 - q_exp) * dt
  assert_true(near(vd, vd_exp))
  assert_true(near(vq, vq_exp))

  // 占空比必须等于「反 Park 后直接调 svpwm」的结果
  let (va, vb) = @coord.inv_park(vd, vq, theta)
  let (da_exp, db_exp, dc_exp) = @svpwm.duties(va, vb, dt, vdc)
  assert_true(near(da, da_exp))
  assert_true(near(db, db_exp))
  assert_true(near(dc, dc_exp))
}

///|
test "closed loop tracks q step and keeps d near zero" {
  let dt = 1.0e-4
  let vdc = 24.0
  let r = 0.5
  let l = 0.001
  let mut id = 0.0
  let mut iq = 0.0
  let ctrl = @controller.FocController::new(
    2.0, 1000.0, 2.0, 1000.0, dt, vdc, -12.0, 12.0,
  )
  let id_ref = 0.0
  let iq_ref = 2.0
  let mut k = 0
  while k < 2000 {
    let (ia, ib, ic) = three_phase(id, iq)
    let (_, _, vd, vq, da, db, dc) = ctrl.step(ia, ib, ic, 0.0, id_ref, iq_ref)
    // 一阶 RL 步进：di/dt = (v − R·i)/L
    id = id + (vd - r * id) / l * dt
    iq = iq + (vq - r * iq) / l * dt
    // 每拍占空比都必须在 [-1, 1] 内
    assert_true(da >= -1.0 - 1.0e-12 && da <= 1.0 + 1.0e-12)
    assert_true(db >= -1.0 - 1.0e-12 && db <= 1.0 + 1.0e-12)
    assert_true(dc >= -1.0 - 1.0e-12 && dc <= 1.0 + 1.0e-12)
    k += 1
  }
  // 收敛判据：q 轴跟踪到给定 ±0.15 A，d 轴压在 ±0.1 A 内
  assert_true((iq - iq_ref).abs() < 0.15)
  assert_true(id.abs() < 0.1)
  // 稳态 q 轴电压 ≈ R·iq = 1.0 V，未顶到 ±12 V 限幅
  assert_true(ctrl.last_vq().abs() < 12.0)
  assert_true(ctrl.last_vq() > 0.0)
}

///|
test "voltage command is clamped to the configured limit" {
  let dt = 1.0e-4
  // 限幅 ±2 V，大误差直接顶边
  let ctrl = @controller.FocController::new(
    10.0, 100.0, 10.0, 100.0, dt, 24.0, -2.0, 2.0,
  )
  let mut k = 0
  while k < 50 {
    let (_, _, vd, vq, _, _, _) = ctrl.step(0.0, 0.0, 0.0, 0.0, 5.0, 5.0)
    assert_true(vd <= 2.0 + 1.0e-12)
    assert_true(vq <= 2.0 + 1.0e-12)
    k += 1
  }
  // 反向误差同样被压到 −2 V
  let (_, _, vd2, vq2, _, _, _) = ctrl.step(0.0, 0.0, 0.0, 0.0, -5.0, -5.0)
  assert_true(vd2 >= -2.0 - 1.0e-12)
  assert_true(vq2 >= -2.0 - 1.0e-12)
}

///|
test "anti windup holds the integrator at the limit and reverses fast" {
  let dt = 1.0e-4
  let ctrl = @controller.FocController::new(
    10.0, 1.0, 10.0, 1.0, dt, 24.0, -1.0, 1.0,
  )
  let mut k = 0
  while k < 50 {
    let _ = ctrl.step(0.0, 0.0, 0.0, 0.0, 1.0, 1.0)
    k += 1
  }
  // 饱和期间积分项被冻住，不会涨到 5.0 这种量级
  assert_true(ctrl.d_integral() <= 1.0 + 1.0e-12)
  assert_true(ctrl.q_integral() <= 1.0 + 1.0e-12)
  // 误差反向后一个采样拍内退出饱和
  let (_, _, vd, vq, _, _, _) = ctrl.step(0.0, 0.0, 0.0, 0.0, -1.0, -1.0)
  assert_true(vd < 1.0)
  assert_true(vq < 1.0)
}

///|
test "non finite sample does not pollute the pi state" {
  let dt = 1.0e-4
  let ctrl = @controller.FocController::new(
    1.0, 10.0, 1.0, 10.0, dt, 24.0, -12.0, 12.0,
  )
  let _ = ctrl.step(1.0, -0.5, -0.5, 0.0, 0.0, 0.0)
  let id_before = ctrl.d_integral()
  let iq_before = ctrl.q_integral()
  let nan = 0.0 / 0.0
  let (id, iq, vd, vq, da, db, dc) = ctrl.step(nan, -0.5, -0.5, 0.0, 0.0, 0.0)
  assert_true(near(id, 0.0) && near(iq, 0.0))
  assert_true(near(vd, 0.0) && near(vq, 0.0))
  assert_true(near(da, 0.0) && near(db, 0.0) && near(dc, 0.0))
  assert_true(near(ctrl.d_integral(), id_before))
  assert_true(near(ctrl.q_integral(), iq_before))
  // 之后照常工作
  let (id2, _, _, _, _, _, _) = ctrl.step(1.0, -0.5, -0.5, 0.0, 0.0, 0.0)
  assert_true((id2 != id2) == false)
}

///|
test "vector clamp keeps the direction and caps the magnitude" {
  // 模长 5 的矢量（3, 4）：限幅 5 时原样返回
  match @controller.clamp_voltage_vector(3.0, 4.0, 5.0) {
    (vd, vq) => assert_true(near(vd, 3.0) && near(vq, 4.0))
  }
  // 限幅 2.5：方向不变（vq/vd = 4/3），模长正好压到 2.5
  match @controller.clamp_voltage_vector(3.0, 4.0, 2.5) {
    (vd, vq) => {
      assert_true(near(vd, 1.5) && near(vq, 2.0))
      assert_true(near((vd * vd + vq * vq).sqrt(), 2.5))
    }
  }
  // 限幅非正 / 非有限：不启用，原样返回
  match @controller.clamp_voltage_vector(3.0, 4.0, 0.0) {
    (vd, vq) => assert_true(near(vd, 3.0) && near(vq, 4.0))
  }
  // 坏数不进调制链路
  let nan = 0.0 / 0.0
  match @controller.clamp_voltage_vector(nan, 4.0, 5.0) {
    (vd, vq) => assert_true(near(vd, 0.0) && near(vq, 0.0))
  }
}

///|
test "vector limit keeps both axes inside the linear modulation range" {
  let dt = 1.0e-4
  let vdc = 24.0
  let v_linear = vdc / 3.0.sqrt()
  // 每轴 ±12 V，合成矢量可达 √2·12 ≈ 16.97 V > 13.86 V
  let ctrl = @controller.FocController::new_limited(
    10.0, 100.0, 10.0, 100.0, dt, vdc, -12.0, 12.0, v_linear,
  )
  let mut k = 0
  while k < 200 {
    let (_, _, vd, vq, _, _, _) = ctrl.step(0.0, 0.0, 0.0, 0.0, 5.0, 5.0)
    let mag = (vd * vd + vq * vq).sqrt()
    assert_true(mag <= v_linear + 1.0e-9)
    // 换成调制比看：不进过调制区
    let (valpha, vbeta) = @coord.inv_park(vd, vq, 0.0)
    assert_true(@svpwm.modulation_index(valpha, vbeta, vdc) <= 1.0 + 1.0e-9)
    k += 1
  }
  assert_true(ctrl.voltage_magnitude_limit() == v_linear)
}

///|
test "plain per axis limit lets the vector exceed the linear range" {
  // 同一组参数、每轴仍限 ±12 V、不启用矢量限幅：给定大误差时两轴同时顶边，
  // 合成 16.97 V 已经越过 13.86 V 的线性边界，交给 SVPWM 就是过调制。
  let ctrl = @controller.FocController::new(
    10.0, 100.0, 10.0, 100.0, 1.0e-4, 24.0, -12.0, 12.0,
  )
  let (_, _, vd, vq, _, _, _) = ctrl.step(0.0, 0.0, 0.0, 0.0, 5.0, 5.0)
  let (valpha, vbeta) = @coord.inv_park(vd, vq, 0.0)
  assert_true(@svpwm.modulation_index(valpha, vbeta, 24.0) > 1.0)
  assert_true(ctrl.voltage_magnitude_limit() == 0.0)
}

///|
test "vector saturation recalculates the integrator instead of winding up" {
  let dt = 1.0e-4
  let vdc = 24.0
  let v_linear = vdc / 3.0.sqrt()
  // 每轴限幅放到 ±100 V：只靠条件积分时两轴都不会顶边，积分照常累积，
  // 但合成矢量早已被裁在 13.86 V - 这是旧实现看不出来的 windup。
  let limited = @controller.FocController::new_limited(
    10.0, 100.0, 10.0, 100.0, dt, vdc, -100.0, 100.0, v_linear,
  )
  let plain = @controller.FocController::new(
    10.0, 100.0, 10.0, 100.0, dt, vdc, -100.0, 100.0,
  )
  let mut k = 0
  let mut integ_at_100 = 0.0
  while k < 200 {
    let (_, _, vd, vq, _, _, _) = limited.step(0.0, 0.0, 0.0, 0.0, 1.5, 1.5)
    let mag = (vd * vd + vq * vq).sqrt()
    assert_true(mag <= v_linear + 1.0e-9)
    let (_, _, vd_p, vq_p, _, _, _) = plain.step(0.0, 0.0, 0.0, 0.0, 1.5, 1.5)
    let (valpha, vbeta) = @coord.inv_park(vd_p, vq_p, 0.0)
    assert_true(@svpwm.modulation_index(valpha, vbeta, vdc) > 1.0)
    if k == 99 {
      integ_at_100 = limited.d_integral()
    }
    k += 1
  }
  // 回算后积分项停住，不再随采样拍增长
  assert_true((limited.d_integral() - integ_at_100).abs() < 1.0e-9)
  assert_true(limited.d_integral().abs() <= v_linear + 10.0 * 1.5 + 1.0e-9)
  // 旧实现同一组输入下积分项一直在涨
  assert_true(plain.d_integral() > integ_at_100)
}

///|
/// 矢量限幅的退饱和行为：给定回零后要在一拍内离开限幅区，而不是继续顶着
/// 上限几十拍。这个读数来自回算积分项，`--deny-warn` 看不出。
test "vector saturation releases within one step after reference returns to zero" {
  let dt = 1.0e-4
  let vdc = 24.0
  let v_linear = vdc / 3.0.sqrt()
  let ctrl = @controller.FocController::new_limited(
    10.0, 100.0, 10.0, 100.0, dt, vdc, -100.0, 100.0, v_linear,
  )
  let mut k = 0
  while k < 200 {
    let (_, _, vd, vq, _, _, _) = ctrl.step(0.0, 0.0, 0.0, 0.0, 1.5, 1.5)
    assert_true((vd * vd + vq * vq).sqrt() >= v_linear - 1.0e-9)
    k += 1
  }
  // 给定归零：积分项已被回算到 v_lim − kp·err，第一拍就不再裁幅
  let (_, _, vd0, vq0, _, _, _) = ctrl.step(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  assert_true((vd0 * vd0 + vq0 * vq0).sqrt() < v_linear - 1.0e-6)
  // 再走三拍，电压继续朝零收，不会反弹回限幅
  let mut j = 0
  while j < 3 {
    let (_, _, vd, vq, _, _, _) = ctrl.step(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    assert_true((vd * vd + vq * vq).sqrt() < v_linear)
    j += 1
  }
}

///|
test "reset clears both integrators" {
  let dt = 1.0e-4
  let ctrl = @controller.FocController::new(
    1.0, 10.0, 1.0, 10.0, dt, 24.0, -12.0, 12.0,
  )
  let _ = ctrl.step(1.0, -0.5, -0.5, 0.0, 0.0, 0.0)
  assert_true(ctrl.d_integral() != 0.0 || ctrl.q_integral() != 0.0)
  ctrl.reset()
  assert_true(near(ctrl.d_integral(), 0.0))
  assert_true(near(ctrl.q_integral(), 0.0))
}
