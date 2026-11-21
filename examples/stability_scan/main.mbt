///|
/// 采样步长扫描：固定一套电流环增益，改变仿真步长 `dt`，看阶跃响应的超调与
/// 调节时间，把「显式欧拉的时间步上限」变成可复现的数字。
///
/// 对象取离线演示参数：R=0.5 Ω，Ld=Lq=1 mH，ψf=0.05 Wb，4 极对，静止；
/// 增益按 400 Hz 带宽整定一次，之后不再随 dt 改。Vdc=24 V，限幅 ±12 V。
/// 运行：`moon run examples/stability_scan --target native`
fn main {
  let r = 0.5
  let ld = 0.001
  let lq = 0.001
  let psi_f = 0.05
  let pole_pairs = 4
  let vdc = 24.0
  let iq_ref = 2.0
  let bandwidth = 400.0
  let gains = @controller.design_current_loop(r, ld, bandwidth)
  let kp = gains.kp()
  let ki = gains.ki()
  println(
    "gains at " +
    bandwidth.to_string() +
    " Hz: kp=" +
    kp.to_string() +
    " ki=" +
    ki.to_string(),
  )
  println("dt      peak/A   overshoot/%   settle/s   final_error/A")
  let steps = [
    (50.0e-6 : Double),
    (100.0e-6 : Double),
    (200.0e-6 : Double),
    (500.0e-6 : Double),
    (1000.0e-6 : Double),
  ]
  for step in steps {
    let (peak, overshoot, settle, final_err) = scan(r, ld, lq, psi_f, pole_pairs, vdc, iq_ref, kp, ki, step)
    println(
      format_dt(step) +
      "   " +
      peak.to_string() +
      "   " +
      overshoot.to_string() +
      "   " +
      settle.to_string() +
      "   " +
      final_err.to_string(),
    )
  }
}

///|
/// 单次扫描：返回（峰值电流，超调百分比，最后一次越出 ±2% 带的时刻，末拍误差）。
///
/// 峰值取整段的最大 `|iq|`；3.5 ms 之后不再越带视为已调节，返回 0.0；
/// 仿真时长固定 50 ms，避免大 `dt` 时样本数太少看不出振荡。
fn scan(
  r : Double,
  ld : Double,
  lq : Double,
  psi_f : Double,
  pole_pairs : Int32,
  vdc : Double,
  iq_ref : Double,
  kp : Double,
  ki : Double,
  dt : Double,
) -> (Double, Double, Double, Double) {
  let motor = @motor.PmsmModel::new(r, ld, lq, psi_f, pole_pairs, 0.0)
  let ctrl = @controller.FocController::new(kp, ki, kp, ki, dt, vdc, -12.0, 12.0)
  let total = (0.05 / dt).to_int()
  let band = 0.02 * iq_ref
  let mut k = 0
  let mut peak = 0.0
  let mut last_out = 0
  while k < total {
    let (ia, ib, ic) = motor.phase_currents()
    let (_, _iq, vd, vq, _, _, _) = ctrl.step(ia, ib, ic, motor.theta_e(), 0.0, iq_ref)
    motor.step(vd, vq, dt)
    let value = motor.iq()
    if value.abs() > peak {
      peak = value.abs()
    }
    if (value - iq_ref).abs() > band && k.to_double() * dt >= 0.0035 {
      last_out = k + 1
    }
    k += 1
  }
  let settle = last_out.to_double() * dt
  let final_err = (motor.iq() - iq_ref).abs()
  let overshoot = if peak > iq_ref { (peak - iq_ref) / iq_ref * 100.0 } else { 0.0 }
  (peak, overshoot, settle, final_err)
}

///|
/// 步长按微秒打印，避免一串 0.00005 这类读数不好排。
fn format_dt(dt : Double) -> String {
  let us = dt * 1.0e6
  let text = if us < 100.0 {
    us.to_string()
  } else {
    (us / 1.0).to_int().to_string()
  }
  text + "us"
}
