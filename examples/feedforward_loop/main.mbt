///|
/// examples/feedforward_loop — 解耦前馈在电流环里补掉了什么。
///
/// 同一套电机参数与 PI 增益，只切换「加不加前馈」：
///   A：PI 输出直接给电压（不加前馈）；
///   B：PI 输出 + `decoupling_terms()`，再走 `apply_feedforward()` 限幅。
///
/// PI 带积分，稳态误差两种情况都会收敛到零，所以这里看瞬态：
/// 从 iq = 0 起步追 5 A，记录①进入 ±2% 带所需时间，②过程中的最大偏差。
/// 反电动势是 PI 眼里的扰动，前馈把它按模型直接扣掉，起步阶段就不必先
/// 「积」出这一项电压。
///
/// 运行：`moon run examples/feedforward_loop --target native`
fn main {
  let vdc = 48.0
  let r = 0.5
  let ld = 0.0008
  let lq = 0.0012
  let psi_f = 0.05
  let pole_pairs = 4
  let dt = 1.0e-5
  let steps = 2000
  let iq_ref = 5.0
  let bandwidth_hz = 400.0

  println(
    "=== 解耦前馈对比（R = 0.5 Ω, Ld = 0.8 mH, Lq = 1.2 mH, ψf = 0.05 Wb）===",
  )
  println(
    "iq 0 → 5 A 的起步过程，Vdc = 48 V，Ts = 10 µs，PI 按 400 Hz 整定",
  )
  for omega_m in [50.0, 100.0, 120.0] {
    let plain = run(
      r, ld, lq, psi_f, pole_pairs, omega_m, dt, steps, iq_ref, vdc, bandwidth_hz,
      false,
    )
    let with_ff = run(
      r, ld, lq, psi_f, pole_pairs, omega_m, dt, steps, iq_ref, vdc, bandwidth_hz,
      true,
    )
    let omega_e = omega_m * pole_pairs.to_double()
    let emf = @controller.back_emf_voltage(omega_e, psi_f)
    println(
      "ωm = " +
      omega_m.to_string() +
      " rad/s（ωe = " +
      omega_e.to_string() +
      "，反电动势 " +
      round4(emf) +
      " V）",
    )
    println(
      "  不加前馈：进入 ±2% 用时 " +
      round4(plain.0) +
      " ms，最大偏差 " +
      round4(plain.1) +
      " A，末拍 iq " +
      round4(plain.2),
    )
    println(
      "  加前馈：  进入 ±2% 用时 " +
      round4(with_ff.0) +
      " ms，最大偏差 " +
      round4(with_ff.1) +
      " A，末拍 iq " +
      round4(with_ff.2),
    )
  }
  println(
    "注：模型无负载，iq 到位后电压只需抵住反电动势与电阻压降；两者末拍都收敛，差别在起步这一段。",
  )
}

///|
/// 跑一段起步过程，返回 (进入 ±2% 带用时 ms, 最大偏差 A, 末拍 iq)。
/// 若始终没进带，用时记满量程 `steps·dt·1000`。
fn run(
  r : Double,
  ld : Double,
  lq : Double,
  psi_f : Double,
  pole_pairs : Int32,
  omega_m : Double,
  dt : Double,
  steps : Int32,
  iq_ref : Double,
  vdc : Double,
  bandwidth_hz : Double,
  use_ff : Bool,
) -> (Double, Double, Double) {
  let motor = @motor.PmsmModel::new(r, ld, lq, psi_f, pole_pairs, omega_m)
  let gains = @controller.design_current_loop(r, ld, bandwidth_hz)
  let limit = vdc / 3.0.sqrt()
  let pi_d = @pi.Pi::new(gains.kp(), gains.ki(), dt, -limit, limit)
  let pi_q = @pi.Pi::new(gains.kp(), gains.ki(), dt, -limit, limit)
  let band = 0.02 * iq_ref
  let mut worst = 0.0
  let mut settled_at = steps
  for i in 0..<steps {
    let id = motor.id()
    let iq = motor.iq()
    let vd_pi = pi_d.step(0.0 - id)
    let vq_pi = pi_q.step(iq_ref - iq)
    let (vd, vq) = if use_ff {
      let (vd_ff, vq_ff) = @controller.decoupling_terms(
        motor.omega_e(),
        ld,
        lq,
        psi_f,
        id,
        iq,
      )
      @controller.apply_feedforward(vd_pi, vq_pi, vd_ff, vq_ff, vdc)
    } else {
      (vd_pi, vq_pi)
    }
    motor.step(vd, vq, dt)
    let err = (iq_ref - motor.iq()).abs()
    if err > worst {
      worst = err
    }
    if settled_at == steps && err <= band {
      settled_at = i
    }
  }
  let ms = settled_at.to_double() * dt * 1000.0
  (ms, worst, motor.iq())
}

///|
fn round4(x : Double) -> String {
  let q = (x * 10000.0).round()
  (q / 10000.0).to_string()
}
