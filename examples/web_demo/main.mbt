///|
/// examples/web_demo — 浏览器演示的数据侧。
///
/// 页面上的滑块不做实时求解（MoonBit 的 js 产物没有向外导出函数），
/// 所以这里预先算好参数网格，页面按滑块位置取对应那一档：
/// 电流环带宽 100..1000 Hz 每 50 Hz 一档、速度环负载 0.5..2.5 N·m 每
/// 0.5 一档、弱磁 q 轴电流 2..8 A 每 1 A 一档。网格里的每条曲线都是由
/// controller/ 与 motor/ 的库函数逐拍算出来的，页面只画线，不在 JS 里
/// 再写一遍模型——图上的数与 README 引用的读数同源，改库就得重新出图。
///
/// 输出协议：`META {...}` 一行放固定读数，`DATA {...}` 每行一个面板，
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
/// 已拼好的数组字面量串起来，`[a,b],[c,d]` → `[[a,b],[c,d]]`。
fn jrows(rows : Array[String]) -> String {
  let mut s = "["
  let mut i = 0
  while i < rows.length() {
    if i > 0 {
      s = s + ","
    }
    s = s + rows[i]
    i = i + 1
  }
  s + "]"
}

///|
/// 电流环阶跃：iq 给定 0 → 5 A，电机静止，带宽从 100 扫到 1000 Hz。
/// 每档记录前 0.024 s（约 60 点），并给出该档的交叉频率与计延时的相角裕度。
fn panel_current_grid() -> String {
  let bws : Array[Double] = []
  let kps : Array[Double] = []
  let kis : Array[Double] = []
  let pms : Array[Double] = []
  let pms_delay : Array[Double] = []
  let curves : Array[String] = []
  let t : Array[Double] = []
  let vmax = vdc_bus() / 3.0.sqrt()
  let mut bw = 100.0
  let mut first = true
  while bw <= 1000.0 {
    let gains = @controller.design_current_loop(r_mot(), ld_mot(), bw)
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
    let iq : Array[Double] = []
    let mut i = 0
    while i < 240 {
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
      if i % 4 == 0 {
        iq.push(obs_iq)
        if first {
          t.push(i.to_double() * dt_step())
        }
      }
      i = i + 1
    }
    first = false
    bws.push(bw)
    kps.push(gains.kp())
    kis.push(gains.ki())
    pms.push(
      @controller.phase_margin_deg(r_mot(), ld_mot(), gains.kp(), gains.ki()),
    )
    pms_delay.push(
      @controller.margin_after_delay_deg(
        r_mot(),
        ld_mot(),
        gains.kp(),
        gains.ki(),
        dt_step(),
      ),
    )
    curves.push(jarr(iq))
    bw = bw + 50.0
  }
  "DATA {\"panel\":\"cur\",\"bw\":" +
  jarr(bws) +
  ",\"kp\":" +
  jarr(kps) +
  ",\"ki\":" +
  jarr(kis) +
  ",\"pm\":" +
  jarr(pms) +
  ",\"pm_delay\":" +
  jarr(pms_delay) +
  ",\"t\":" +
  jarr(t) +
  ",\"iq\":" +
  jrows(curves) +
  "}"
}

///|
/// 速度环：0 → 100 rad/s 阶跃，1.0 s 时加负载，负载取 0.5..2.5 N·m。
///
/// 与 examples/speed_loop 同一套参数与结构：速度 PI 出 iq 给定，电流 PI
/// 出 d/q 电压（只补反电动势前馈，电气模型没有 d/q 交叉项），电机电气模型
/// 步进后算电磁转矩，再推进机械方程。每档顺带给出起步峰值与负载投入后的
/// 最大跌落。
fn panel_speed_grid() -> String {
  let j = 0.002
  let b = 0.0005
  let kt = 1.5 * pole_pairs().to_double() * psi_f_mot()
  let speed_hz = 40.0
  let current_hz = 400.0
  let iq_limit = 8.0
  let omega_ref = 100.0
  let load_at = 10000
  let steps = 20000
  let every = 50

  let loads : Array[Double] = []
  let peaks : Array[Double] = []
  let drops : Array[Double] = []
  let curves_w : Array[String] = []
  let curves_iq : Array[String] = []
  let t : Array[Double] = []
  let mut first = true
  let mut load = 0.5
  while load <= 2.5 {
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
    let om : Array[Double] = []
    let iq_s : Array[Double] = []
    let mut peak = 0.0
    let mut drop = 0.0
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
        let wv = mech.omega_m()
        om.push(wv)
        iq_s.push(iq_cmd)
        if first {
          t.push(i.to_double() * dt_step())
        }
        if wv > peak {
          peak = wv
        }
        if i >= load_at && omega_ref - wv > drop {
          drop = omega_ref - wv
        }
      }
      i = i + 1
    }
    first = false
    loads.push(load)
    peaks.push(peak)
    drops.push(drop)
    curves_w.push(jarr(om))
    curves_iq.push(jarr(iq_s))
    load = load + 0.5
  }
  "DATA {\"panel\":\"speed\",\"loads\":" +
  jarr(loads) +
  ",\"peaks\":" +
  jarr(peaks) +
  ",\"drops\":" +
  jarr(drops) +
  ",\"load_t\":" +
  jnum(load_at.to_double() * dt_step()) +
  ",\"t\":" +
  jarr(t) +
  ",\"omega\":" +
  jrows(curves_w) +
  ",\"iq\":" +
  jrows(curves_iq) +
  "}"
}

///|
/// 弱磁给定：电角速度 300 → 900 rad/s，iq 从 2 扫到 8 A。
///
/// 拐点就是余量 `flux_headroom` 由正转负的地方，之后 id 按 headroom/Ld 往
/// 负走。另给一条 iq = 5 A、id 下限收到 −8 A 的曲线做对照。
fn panel_field_grid() -> String {
  let vmax = vdc_bus() / 3.0.sqrt()
  let w : Array[Double] = []
  let iqs : Array[Double] = []
  let curves_id : Array[String] = []
  let curves_head : Array[String] = []
  let mut omega_e = 300.0
  while omega_e <= 900.0 {
    w.push(omega_e)
    omega_e = omega_e + 20.0
  }
  let mut iq = 2.0
  while iq <= 8.0 {
    let id : Array[Double] = []
    let head : Array[Double] = []
    for we in w {
      head.push(
        @controller.flux_headroom(we, ld_mot(), lq_mot(), psi_f_mot(), iq, vmax),
      )
      id.push(
        @controller.field_weakening_id(
          we,
          ld_mot(),
          lq_mot(),
          psi_f_mot(),
          iq,
          vmax,
          -30.0,
        ),
      )
    }
    iqs.push(iq)
    curves_id.push(jarr(id))
    curves_head.push(jarr(head))
    iq = iq + 1.0
  }
  let id_limited : Array[Double] = []
  for we in w {
    id_limited.push(
      @controller.field_weakening_id(
        we,
        ld_mot(),
        lq_mot(),
        psi_f_mot(),
        5.0,
        vmax,
        -8.0,
      ),
    )
  }
  "DATA {\"panel\":\"field\",\"iqs\":" +
  jarr(iqs) +
  ",\"omega_e\":" +
  jarr(w) +
  ",\"id\":" +
  jrows(curves_id) +
  ",\"headroom\":" +
  jrows(curves_head) +
  ",\"id_limited\":" +
  jarr(id_limited) +
  "}"
}

///|
fn main {
  let gains = @controller.design_current_loop(r_mot(), ld_mot(), 400.0)
  let kt = 1.5 * pole_pairs().to_double() * psi_f_mot()
  let speed_gains = @controller.design_speed_loop(0.002, 0.0005, kt, 40.0)
  println(
    "META {\"crossover\":" +
    jnum(@controller.crossover_hz(r_mot(), ld_mot(), gains.kp(), gains.ki())) +
    ",\"speed_kp\":" +
    jnum(speed_gains.kp()) +
    ",\"speed_ki\":" +
    jnum(speed_gains.ki()) +
    ",\"vlimit\":" +
    jnum(vdc_bus() / 3.0.sqrt()) +
    ",\"grid_bw\":19,\"grid_load\":5,\"grid_iq\":7}",
  )
  println(panel_current_grid())
  println(panel_speed_grid())
  println(panel_field_grid())
}
