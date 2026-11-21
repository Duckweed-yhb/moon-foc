///|
/// Examples/stability_scan 背后的性质：同一套 400 Hz 增益，步长从 100 µs 变到
/// 1 ms，响应从无超调退化到持续振荡。这里锁住三段读数，防止以后改积分或限幅
/// 时把采样步长的稳定性边界悄悄挪走。
fn stability_scan(dt : Double) -> (Double, Double) {
  let r = 0.5
  let ld = 0.001
  let lq = 0.001
  let psi_f = 0.05
  let pole_pairs = 4
  let vdc = 24.0
  let iq_ref = 2.0
  let gains = @controller.design_current_loop(r, ld, 400.0)
  let kp = gains.kp()
  let ki = gains.ki()
  let motor = @motor.PmsmModel::new(r, ld, lq, psi_f, pole_pairs, 0.0)
  let ctrl = @controller.FocController::new(
    kp, ki, kp, ki, dt, vdc, -12.0, 12.0,
  )
  let total = (0.05 / dt).to_int()
  let mut k = 0
  let mut peak = 0.0
  while k < total {
    let (ia, ib, ic) = motor.phase_currents()
    let (_, _iq, vd, vq, _, _, _) = ctrl.step(
      ia,
      ib,
      ic,
      motor.theta_e(),
      0.0,
      iq_ref,
    )
    motor.step(vd, vq, dt)
    if motor.iq().abs() > peak {
      peak = motor.iq().abs()
    }
    k += 1
  }
  (peak, (motor.iq() - iq_ref).abs())
}

///|
/// 100 µs：跟得上，超调可以忽略，末拍误差在 1e-6 以内。
test "stability scan at 100 us settles cleanly" {
  let (peak, final_err) = stability_scan(100.0e-6)
  assert_true(peak <= 2.01)
  assert_true(final_err < 1.0e-6)
}

///|
/// 500 µs：同一套增益已经出现明显超调，说明采样步长而不是带宽在限制响应。
test "stability scan at 500 us shows overshoot" {
  let (peak, _) = stability_scan(500.0e-6)
  assert_true(peak >= 2.8)
}

///|
/// 1 ms：显式欧拉在这个增益下发散成持续振荡；幅值必须仍然有界（不是 NaN 或
/// 无限增长），并且明显超过给定值。
test "stability scan at 1 ms oscillates but stays finite" {
  let (peak, final_err) = stability_scan(1.0e-3)
  assert_true(peak >= 5.0)
  assert_true(peak <= 20.0)
  assert_true(final_err == final_err)
}
