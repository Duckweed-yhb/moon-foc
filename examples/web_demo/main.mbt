///|
/// examples/web_demo — 浏览器演示的数据侧。
///
/// 三个面板：电流环阶跃（200 / 400 / 800 Hz 三种整定）、速度环带载、
/// 弱磁给定随转速变化。每条曲线都由 controller/ 与 motor/ 的库函数逐拍算
/// 出来，页面只负责画线，不在 JS 里再写一遍模型——图上的数与 README 引用的
/// 读数同源，改库就得重新出图。
///
/// 输出协议：`META {...}` 一行放整定读数，`DATA {...}` 每行一个面板，
/// 页面按 panel 字段分图。

///|
/// 电机与母线参数（与 speed_loop 示例保持一致）。
fn r_mot() -> Double {
  0.5
}

///|
fn ld_mot() -> Double {
  0.0008
}

///|
fn lq_mot() -> Double {
  0.0012
}

///|
fn psi_f_mot() -> Double {
  0.05
}

///|
fn pole_pairs() -> Int32 {
  4
}

///|
fn vdc_bus() -> Double {
  48.0
}

///|
fn dt_step() -> Double {
  1.0e-4
}

///|
/// 固定四位小数，避免 JSON 里出现超长尾数；-0.0 归零。
fn jnum(x : Double) -> String {
  let q = (x * 10000.0).round()
  let v = q / 10000.0
  if v == 0.0 {
    "0"
  } else {
    v.to_string()
  }
}

///|
/// 数字数组 → JSON 数组。
fn jarr(xs : Array[Double]) -> String {
  let mut s = "["
  let mut i = 0
  while i < xs.length() {
    if i > 0 {
      s = s + ","
    }
    s = s + jnum(xs[i])
    i = i + 1
  }
  s + "]"
}

///|
/// 电流环阶跃：iq 给定 0 → 5 A，电机静止，看不同整定带宽下的上升沿。
fn panel_current(bw : Double) -> String {
  let gains = @controller.design_current_loop(r_mot(), ld_mot(), bw)
  let vmax = vdc_bus() / 3.0.sqrt()
  let ctrl = @controller.FocController::new(
    gains.kp(),
    gains.ki(),
    gains.kp(),
    gains.ki(),
    dt_step(),
    vdc_bus(),
    -vmax,
    vmax,
  )
  let elec = @motor.PmsmModel::new(
    r_mot(),
    ld_mot(),
    lq_mot(),
    psi_f_mot(),
    pole_pairs(),
    0.0,
  )
  let steps = 1200
  let every = 4
  let t : Array[Double] = []
  let iq : Array[Double] = []
  let mut i = 0
  while i < steps {
    let (ia, ib, ic) = elec.phase_currents()
    let (_, obs_iq, vd, vq, _, _, _) = ctrl.step(
      ia,
      ib,
      ic,
      elec.theta_e(),
      0.0,
      5.0,
    )
    elec.step(vd, vq, dt_step())
    if i % every == 0 {
      t.push(i.to_double() * dt_step())
      iq.push(obs_iq)
    }
    i = i + 1
  }
  "DATA {\"panel\":\"current\",\"bw\":" +
  jnum(bw) +
  ",\"ref\":5,\"t\":" +
  jarr(t) +
  ",\"iq\":" +
  jarr(iq) +
  "}"
}

///|
/// 速度环：0 → 100 rad/s 阶跃，1.0 s 时加 1 N·m 负载。
///
/// 与 examples/speed_loop 同一套参数与结构：速度 PI 出 iq 给定，电流 PI
/// 出 d/q 电压（只补反电动势前馈，电气模型没有 d/q 交叉项），电机电气模型
/// 步进后算电磁转矩，再推进机械方程。
fn panel_speed() -> String {
  let j = 0.002
  let b = 0.0005
  let kt = 1.5 * pole_pairs().to_double() * psi_f_mot()
  let speed_hz = 40.0
  let current_hz = 400.0
  let iq_limit = 8.0
  let omega_ref = 100.0
  let load_at = 10000
  let load = 1.0
  let steps = 20000
  let every = 25

  let speed_gains = @controller.design_speed_loop(j, b, kt, speed_hz)
  let current_gains = @controller.design_current_loop(
    r_mot(),
    ld_mot(),
    current_hz,
  )
  let vlimit = vdc_bus() / 3.0.sqrt()
  let elec = @motor.PmsmModel::new(
    r_mot(),
    ld_mot(),
    lq_mot(),
    psi_f_mot(),
    pole_pairs(),
    0.0,
  )
  let mech = @motor.MechanicalModel::new(j, b, pole_pairs(), 0.0)
  let speed = @controller.SpeedController::new(
    speed_gains.kp(),
    speed_gains.ki(),
    dt_step(),
    -iq_limit,
    iq_limit,
  )
  let pi_d = @pi.Pi::new(
    current_gains.kp(),
    current_gains.ki(),
    dt_step(),
    -vlimit,
    vlimit,
  )
  let pi_q = @pi.Pi::new(
    current_gains.kp(),
    current_gains.ki(),
    dt_step(),
    -vlimit,
    vlimit,
  )

  let t : Array[Double] = []
  let omega : Array[Double] = []
  let iq_ref : Array[Double] = []
  let mut i = 0
  while i < steps {
    let w = mech.omega_m()
    let iq_cmd = speed.step(omega_ref, w)
    let vd_pi = pi_d.step(0.0 - elec.id())
    let vq_pi = pi_q.step(iq_cmd - elec.iq())
    let emf = @controller.back_emf_voltage(mech.omega_e(), psi_f_mot())
    let (vd, vq) = @controller.apply_feedforward(
      vd_pi,
      vq_pi,
      0.0,
      emf,
      vdc_bus(),
    )
    elec.set_speed(mech.omega_m())
    elec.step(vd, vq, dt_step())
    let te = @motor.electromagnetic_torque(
      elec.id(),
      elec.iq(),
      ld_mot(),
      lq_mot(),
      psi_f_mot(),
      pole_pairs(),
    )
    let load_now = if i >= load_at { load } else { 0.0 }
    mech.step(te, load_now, dt_step())
    if i % every == 0 {
      t.push(i.to_double() * dt_step())
      omega.push(mech.omega_m())
      iq_ref.push(iq_cmd)
    }
    i = i + 1
  }
  "DATA {\"panel\":\"speed\",\"omega_ref\":" +
  jnum(omega_ref) +
  ",\"load_t\":" +
  jnum(load_at.to_double() * dt_step()) +
  ",\"load\":" +
  jnum(load) +
  ",\"t\":" +
  jarr(t) +
  ",\"omega\":" +
  jarr(omega) +
  ",\"iq\":" +
  jarr(iq_ref) +
  "}"
}

///|
/// 弱磁给定：电角速度 300 → 900 rad/s，iq 分别取 2 / 5 / 8 A。
///
/// 拐点就是余量 `flux_headroom` 由正转负的地方，之后 id 按 headroom/Ld 往
/// 负走，直到 `id_min` 收住。
fn panel_field(iq : Double, id_min : Double) -> String {
  let vmax = vdc_bus() / 3.0.sqrt()
  let w : Array[Double] = []
  let id : Array[Double] = []
  let head : Array[Double] = []
  let mut omega_e = 300.0
  while omega_e <= 900.0 {
    w.push(omega_e)
    head.push(
      @controller.flux_headroom(
        omega_e,
        ld_mot(),
        lq_mot(),
        psi_f_mot(),
        iq,
        vmax,
      ),
    )
    id.push(
      @controller.field_weakening_id(
        omega_e,
        ld_mot(),
        lq_mot(),
        psi_f_mot(),
        iq,
        vmax,
        id_min,
      ),
    )
    omega_e = omega_e + 20.0
  }
  "DATA {\"panel\":\"field\",\"iq\":" +
  jnum(iq) +
  ",\"id_min\":" +
  jnum(id_min) +
  ",\"omega_e\":" +
  jarr(w) +
  ",\"headroom\":" +
  jarr(head) +
  ",\"id\":" +
  jarr(id) +
  "}"
}

///|
fn main {
  let gains = @controller.design_current_loop(r_mot(), ld_mot(), 400.0)
  let fc = @controller.crossover_hz(r_mot(), ld_mot(), gains.kp(), gains.ki())
  let pm = @controller.phase_margin_deg(
    r_mot(),
    ld_mot(),
    gains.kp(),
    gains.ki(),
  )
  let pm_delay = @controller.margin_after_delay_deg(
    r_mot(),
    ld_mot(),
    gains.kp(),
    gains.ki(),
    dt_step(),
  )
  let kt = 1.5 * pole_pairs().to_double() * psi_f_mot()
  let speed_gains = @controller.design_speed_loop(0.002, 0.0005, kt, 40.0)
  println(
    "META {\"kp\":" +
    jnum(gains.kp()) +
    ",\"ki\":" +
    jnum(gains.ki()) +
    ",\"crossover\":" +
    jnum(fc) +
    ",\"pm\":" +
    jnum(pm) +
    ",\"pm_delay\":" +
    jnum(pm_delay) +
    ",\"speed_kp\":" +
    jnum(speed_gains.kp()) +
    ",\"speed_ki\":" +
    jnum(speed_gains.ki()) +
    ",\"vlimit\":" +
    jnum(vdc_bus() / 3.0.sqrt()) +
    "}",
  )
  println(panel_current(200.0))
  println(panel_current(400.0))
  println(panel_current(800.0))
  println(panel_speed())
  println(panel_field(2.0, -30.0))
  println(panel_field(5.0, -30.0))
  println(panel_field(8.0, -30.0))
  println(panel_field(5.0, -8.0))
}
