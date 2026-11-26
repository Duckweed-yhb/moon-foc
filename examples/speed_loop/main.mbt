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
  ignore(run_case(40.0))
  ignore(run_case(20.0))
}

///|
priv struct SpeedResponse {
  final_iq : Double
  tail_min : Double
  tail_max : Double
  dip : Double
  recovery : Double
  first_entry : Double
  iq_ref_peak : Double
  iq_peak : Double
}

///|
fn run_case(speed_hz : Double) -> SpeedResponse {
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
    " Hz，比值 " +
    round4(speed_hz / current_hz) +
    "，判据 speed_bandwidth_ok → " +
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

  let drive = @simulation.SpeedDrive::new(
    {
      resistance: r,
      ld,
      lq,
      magnet_flux: psi_f,
      pole_pairs,
      inertia: j,
      damping: b,
    },
    { vdc, dt, current_hz, speed_hz, iq_limit, },
  ).unwrap()
  println(
    "SpeedDrive 带宽比=" +
    round4(drive.bandwidth_ratio()) +
    "，5:1 分离检查=" +
    drive.bandwidth_ok(0.2).to_string(),
  )
  let mut final_iq = 0.0

  let mut t_rise = -1.0
  let mut t_settle = -1.0
  let mut peak = 0.0
  let mut iq_ref_peak = 0.0
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
    let omega = drive.omega_m()
    let load_now = if i >= load_at { load } else { 0.0 }
    let sample = drive.step(omega_ref, load_now).unwrap()
    let iq_ref = sample.iq_ref
    final_iq = sample.iq
    let t = i.to_double() * dt
    if omega > peak {
      peak = omega
    }
    if iq_ref.abs() > iq_ref_peak {
      iq_ref_peak = iq_ref.abs()
    }
    if sample.iq.abs() > iq_peak {
      iq_peak = sample.iq.abs()
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
        band_since = -1
        t_recover = -1.0
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

  let response : SpeedResponse = {
    final_iq,
    tail_min,
    tail_max,
    dip,
    recovery: t_recover,
    first_entry: t_settle,
    iq_ref_peak,
    iq_peak,
  }
  println(
    "① 0 → 100 rad/s：10% 时刻 " +
    round4(t_rise) +
    " s，进 ±2% 带 " +
    round4(response.first_entry) +
    " s，峰值 " +
    round4(peak) +
    " rad/s，模型 iq 峰值 " +
    round4(response.iq_peak) +
    " A，iq 给定峰值 " +
    round4(response.iq_ref_peak) +
    " A（给定限幅 " +
    iq_limit.to_string() +
    " A）",
  )
  println(
    "② 1.0 s 加 " +
    load.to_string() +
    " N·m：最大跌落 " +
    round4(response.dip) +
    " rad/s，回到 ±1% 带用时 " +
    round4(response.recovery) +
    " s",
  )
  println(
    "③ 末段 0.2 s：转速 " +
    round4(response.tail_min) +
    " ~ " +
    round4(response.tail_max) +
    " rad/s，均值 " +
    round4(tail_sum / tail_n.to_double()) +
    " rad/s，末拍 iq " +
    round4(response.final_iq) +
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
  response
}

///|
fn round4(x : Double) -> String {
  let q = (x * 10000.0).round()
  (q / 10000.0).to_string()
}
