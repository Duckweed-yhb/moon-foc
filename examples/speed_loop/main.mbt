///|
/// examples/speed_loop — 速度外环 + 电流内环 + 机械模型的级联仿真。
///
/// 三级串起来：速度 PI 出 iq 给定 → 电流 PI 出 d/q 电压（带反电动势前馈与
/// 矢量限幅）→ 电机电气模型 → 电磁转矩 → 机械方程积分出转速，反馈回速度环。
///
/// 两段工况：
///   ① 0.0 s 转速给定 0 → 100 rad/s 阶跃，看 10% 时刻与进 ±2% 带的时间；
///   ② 1.0 s 加 1 N·m 负载转矩，看转速跌落与拉回 ±1% 带的时间；
///   ③ 末段 0.2 s 的转速波动范围。
///
/// 电气模型是表面贴装近似、没有 d/q 交叉项，所以电压前馈只补它确实拥有的
/// 反电动势项；硬塞 vd_ff 等于给模型注入一个不存在的扰动，读数会假。
///
/// 运行：`moon run examples/speed_loop --target native`
fn main {
  let r = 0.5
  let ld = 0.0008
  let lq = 0.0012
  let psi_f = 0.05
  let pole_pairs = 4
  let j = 0.002
  let b = 0.0005
  let vdc = 48.0
  let dt = 1.0e-4
  let steps = 20000
  let current_hz = 400.0
  let speed_hz = 40.0
  let iq_limit = 8.0
  let omega_ref = 100.0
  let load_at = 10000
  let load = 1.0
  let tail_from = steps - 2000

  println(
    "=== 速度环级联仿真（J = 2e-3 kg·m², B = 5e-4, Kt = 0.3 N·m/A）===",
  )
  println(
    "电流环 " +
    current_hz.to_string() +
    " Hz / 速度环 " +
    speed_hz.to_string() +
    " Hz，比值 0.1，判据 speed_bandwidth_ok → " +
    @controller.speed_bandwidth_ok(speed_hz, current_hz, 0.2).to_string(),
  )

  let kt = 1.5 * pole_pairs.to_double() * psi_f
  let speed_gains = @controller.design_speed_loop(j, b, kt, speed_hz)
  println(
    "速度环增益：Kp = " +
    round4(speed_gains.kp()) +
    " A/(rad/s)，Ki = " +
    round4(speed_gains.ki()) +
    " A/rad",
  )

  let elec = @motor.PmsmModel::new(r, ld, lq, psi_f, pole_pairs, 0.0)
  let mech = @motor.MechanicalModel::new(j, b, pole_pairs, 0.0)
  let speed = @controller.SpeedController::new(
    speed_gains.kp(),
    speed_gains.ki(),
    dt,
    -iq_limit,
    iq_limit,
  )
  let current_gains = @controller.design_current_loop(r, ld, current_hz)
  let vlimit = vdc / 3.0.sqrt()
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

  let mut t_rise = -1.0
  let mut t_settle = -1.0
  let mut peak = 0.0
  let mut iq_peak = 0.0
  let mut dip = 0.0
  let mut dip_at = 0
  let mut band_since = -1
  let mut t_recover = -1.0
  let mut tail_min = 1.0e9
  let mut tail_max = -1.0e9
  let mut tail_sum = 0.0
  let mut tail_n = 0

  for i in 0..<steps {
    let omega = mech.omega_m()
    let iq_ref = speed.step(omega_ref, omega)
    let vd_pi = pi_d.step(0.0 - elec.id())
    let vq_pi = pi_q.step(iq_ref - elec.iq())
    let emf = @controller.back_emf_voltage(mech.omega_e(), psi_f)
    let (vd, vq) = @controller.apply_feedforward(vd_pi, vq_pi, 0.0, emf, vdc)
    elec.set_speed(mech.omega_m())
    elec.step(vd, vq, dt)
    let te = @motor.electromagnetic_torque(
      elec.id(),
      elec.iq(),
      ld,
      lq,
      psi_f,
      pole_pairs,
    )
    let load_now = if i >= load_at { load } else { 0.0 }
    mech.step(te, load_now, dt)

    let t = i.to_double() * dt
    if omega > peak {
      peak = omega
    }
    if iq_ref.abs() > iq_peak {
      iq_peak = iq_ref.abs()
    }
    if t_rise < 0.0 && omega >= 10.0 {
      t_rise = t
    }
    if t_settle < 0.0 && i > 0 && (omega - omega_ref).abs() <= 2.0 {
      t_settle = t
    }
    if i >= load_at {
      let sag = omega_ref - omega
      if sag > dip {
        dip = sag
        dip_at = i
      }
      // 跌落到底之后才算恢复；回带后还要连续 1 ms 不越界，
      // 避免把下落途中的一次穿越算成「已回带」。
      if i > dip_at {
        if (omega - omega_ref).abs() <= 1.0 {
          if band_since < 0 {
            band_since = i
          } else if t_recover < 0.0 && i - band_since >= 10 {
            t_recover = t - load_at.to_double() * dt
          }
        } else {
          band_since = -1
        }
      }
    }
    if i >= tail_from {
      if omega < tail_min {
        tail_min = omega
      }
      if omega > tail_max {
        tail_max = omega
      }
      tail_sum = tail_sum + omega
      tail_n = tail_n + 1
    }
  }

  println(
    "① 0 → 100 rad/s：10% 时刻 " +
    round4(t_rise) +
    " s，进 ±2% 带 " +
    round4(t_settle) +
    " s，峰值 " +
    round4(peak) +
    " rad/s，iq 峰值 " +
    round4(iq_peak) +
    " A（已顶到 " +
    iq_limit.to_string() +
    " A 限幅）",
  )
  println(
    "② 1.0 s 加 " +
    load.to_string() +
    " N·m：最大跌落 " +
    round4(dip) +
    " rad/s，回到 ±1% 带用时 " +
    round4(t_recover) +
    " s",
  )
  println(
    "③ 末段 0.2 s：转速 " +
    round4(tail_min) +
    " ~ " +
    round4(tail_max) +
    " rad/s，均值 " +
    round4(tail_sum / tail_n.to_double()) +
    " rad/s，末拍 iq " +
    round4(elec.iq()) +
    " A",
  )
  println(
    "注：" +
    load.to_string() +
    " N·m 负载对应 iq 约 " +
    round4(load / kt) +
    " A，另加阻尼项 B·ω/Kt = " +
    round4(b * omega_ref / kt) +
    " A。",
  )
}

///|
fn round4(x : Double) -> String {
  let q = (x * 10000.0).round()
  (q / 10000.0).to_string()
}
