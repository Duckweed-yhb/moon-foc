///|
/// examples/weak_flux_loop — 弱磁与速度环联动的高转速仿真。
///
/// 转速给定爬到基速以上，d 轴给定交给 `field_weakening_id` 按电压极限算，
/// q 轴仍由速度 PI 出；电气模型的 q 轴磁链取 ψf + Ld·id，负 id 才真的能把
/// 反电势压下去。同一组参数跑两遍对比：
///
///   ① 关弱磁：id 恒 0，转速爬到电压极限就停住；
///   ② 开弱磁：id 随转速变负，转速上限抬高，代价是同样的转矩要更多 iq。
///
/// 边界：稳态近似算的弱磁给定，没算电阻压降与电流环相位滞后；模型仍无
/// vd 侧交叉项，所以弱磁深度会比实测偏乐观。
///
/// 运行：`moon run examples/weak_flux_loop --target native`
fn main {
  let target = 170.0
  let steps = 20000
  let off = run_case(false, target, steps)
  let on = run_case(true, target, steps)
  println(
    "=== 弱磁与速度环联动（Vdc 48 V，线性调制区 27.71 V，给定 0 → 170 rad/s）===",
  )
  println(
    "① 关弱磁（id 恒 0）：转速上限 " +
    round2(off.ceiling) +
    " rad/s，末段 id " +
    round4(off.tail_id) +
    " A，iq " +
    round4(off.tail_iq) +
    " A，电压峰值 " +
    round2(off.volt_max) +
    " V，触限 " +
    off.limit_steps.to_string() +
    " 拍",
  )
  println(
    "② 开弱磁：转速上限 " +
    round2(on.ceiling) +
    " rad/s，末段 id " +
    round4(on.tail_id) +
    " A，iq " +
    round4(on.tail_iq) +
    " A，电压峰值 " +
    round2(on.volt_max) +
    " V，触限 " +
    on.limit_steps.to_string() +
    " 拍",
  )
  println(
    "③ 转速上限抬高 " +
    round2(on.ceiling - off.ceiling) +
    " rad/s（" +
    round2((on.ceiling / off.ceiling - 1.0) * 100.0) +
    "%），弱磁最深处 id = " +
    round4(on.id_min) +
    " A",
  )
  println(
    "④ 末段跟踪：开弱磁 " +
    round2(on.tail_speed) +
    " / " +
    round2(on.tail_ref) +
    " rad/s（给定），关弱磁 " +
    round2(off.tail_speed) +
    " / " +
    round2(off.tail_ref) +
    " rad/s",
  )
}

///|
/// 一组工况的读数。
struct Outcome {
  /// 后半程达到的最高转速（rad/s）。
  ceiling : Double
  /// 末段平均转速与平均给定。
  tail_speed : Double
  tail_ref : Double
  /// 末拍 d/q 电流。
  tail_id : Double
  tail_iq : Double
  /// 全程最负的 id 与最大电压幅值。
  id_min : Double
  volt_max : Double
  /// 电压幅值顶到限幅 98% 以上的拍数。
  limit_steps : Int32
}

///|
/// 跑一条转速斜坡。`use_fw` 决定 d 轴给定走弱磁还是恒 0。
fn run_case(use_fw : Bool, target : Double, steps : Int32) -> Outcome {
  let r = 0.5
  let ld = 0.0008
  let lq = 0.0012
  let psi_f = 0.05
  let pole_pairs = 4
  let j = 0.002
  let b = 0.0005
  let vdc = 48.0
  let dt = 1.0e-4
  let current_hz = 400.0
  let speed_hz = 40.0
  let iq_limit = 8.0
  let id_limit = 8.0
  let ramp_rate = 150.0
  let vlimit = vdc / 3.0.sqrt()
  let kt = 1.5 * pole_pairs.to_double() * psi_f

  let elec = @motor.PmsmModel::new(r, ld, lq, psi_f, pole_pairs, 0.0)
  let mech = @motor.MechanicalModel::new(j, b, pole_pairs, 0.0)
  let speed_gains = @controller.design_speed_loop(j, b, kt, speed_hz)
  let speed = @controller.SpeedController::new(
    speed_gains.kp(),
    speed_gains.ki(),
    dt,
    -iq_limit,
    iq_limit,
  )
  let current_gains = @controller.design_current_loop(r, ld, current_hz)
  let pi_d = @pi.Pi::new(
    current_gains.kp(),
    current_gains.ki(),
    dt,
    -vlimit,
    vlimit,
  )
  let pi_q = @pi.Pi::new(
    current_gains.kp(),
    current_gains.ki(),
    dt,
    -vlimit,
    vlimit,
  )

  let mut ceiling = -1.0e9
  let mut id_min = 0.0
  let mut volt_max = 0.0
  let mut limit_steps = 0
  let mut tail_speed = 0.0
  let mut tail_ref = 0.0
  let mut tail_n = 0
  let tail_from = steps - 1500
  let half = steps / 2

  for i in 0..<steps {
    let t = i.to_double() * dt
    let ramp = t * ramp_rate
    let omega_ref = if ramp < target { ramp } else { target }
    let omega = mech.omega_m()
    let iq_ref = speed.step(omega_ref, omega)
    let omega_e = mech.omega_e()
    let id_ref = if use_fw {
      @controller.field_weakening_id(
        omega_e,
        ld,
        lq,
        psi_f,
        iq_ref,
        vlimit,
        -id_limit,
      )
    } else {
      0.0
    }
    let vd_pi = pi_d.step(id_ref - elec.id())
    let vq_pi = pi_q.step(iq_ref - elec.iq())
    // 模型里的 q 轴磁链是 ψf + Ld·id，前馈按同一个磁链算，别多补一项
    let emf = @controller.back_emf_voltage(omega_e, psi_f + ld * elec.id())
    let (vd, vq) = @controller.apply_feedforward(vd_pi, vq_pi, 0.0, emf, vdc)
    elec.set_speed(omega)
    elec.step(vd, vq, dt)
    let te = @motor.electromagnetic_torque(
      elec.id(),
      elec.iq(),
      ld,
      lq,
      psi_f,
      pole_pairs,
    )
    mech.step(te, 0.0, dt)

    let volt = (vd * vd + vq * vq).sqrt()
    if volt > volt_max {
      volt_max = volt
    }
    if volt >= 0.98 * vlimit {
      limit_steps = limit_steps + 1
    }
    if elec.id() < id_min {
      id_min = elec.id()
    }
    if i >= half && omega > ceiling {
      ceiling = omega
    }
    if i >= tail_from {
      tail_speed = tail_speed + omega
      tail_ref = tail_ref + omega_ref
      tail_n = tail_n + 1
    }
  }

  {
    ceiling,
    tail_speed: tail_speed / tail_n.to_double(),
    tail_ref: tail_ref / tail_n.to_double(),
    tail_id: elec.id(),
    tail_iq: elec.iq(),
    id_min,
    volt_max,
    limit_steps,
  }
}

///|
fn round2(x : Double) -> String {
  let q = (x * 100.0).round()
  (q / 100.0).to_string()
}

///|
fn round4(x : Double) -> String {
  let q = (x * 10000.0).round()
  (q / 10000.0).to_string()
}
