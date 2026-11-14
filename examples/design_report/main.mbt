/// examples/design_report — 从电机参数整定电流环，再把整定结果接回闭环。
///
/// 前半段是设计：给定 R / L 与目标带宽，算出 d/q 轴 PI 增益，并给出交叉频率、
/// 理想相位裕度、一拍延时的相位损失与计入延时后的实际裕度。
/// 后半段是验证：把同一组增益交给 FocController，在简化 PMSM 模型上走时域，
/// 看 q 轴电流是否真的按设计收敛到给定值。
///
/// 只依赖 controller 与 motor 两个包，纯计算、四后端一致。

///|
fn main {
  let r = 0.5
  let l = 0.002
  let ts = 50.0e-6
  let vdc = 48.0
  let bandwidth = 800.0
  println("== 电流环整定 ==")
  println("电机 R = " + r.to_string() + " ohm, L = " + l.to_string() + " H")
  println(
    "开关周期 Ts = " +
    ts.to_string() +
    " s, Vdc = " +
    vdc.to_string() +
    " V",
  )
  println("目标带宽 = " + bandwidth.to_string() + " Hz")
  let gains = @controller.design_current_loop(r, l, bandwidth)
  println("Kp = " + gains.kp().to_string())
  println("Ki = " + gains.ki().to_string())
  println("Ki/Kp = " + (gains.ki() / gains.kp()).to_string() + " (= R/L)")
  let fc = @controller.crossover_hz(r, l, gains.kp(), gains.ki())
  let pm = @controller.phase_margin_deg(r, l, gains.kp(), gains.ki())
  let loss = @controller.delay_phase_loss_deg(fc, ts)
  let after = @controller.margin_after_delay_deg(
    r,
    l,
    gains.kp(),
    gains.ki(),
    ts,
  )
  println("交叉频率 = " + fc.to_string() + " Hz")
  println("理想相位裕度 = " + pm.to_string() + " deg")
  println("一拍延时损失 = " + loss.to_string() + " deg")
  println("计入延时后裕度 = " + after.to_string() + " deg")
  println(
    "45 deg 门槛下可用: " +
    @controller.design_is_usable(r, l, gains.kp(), gains.ki(), ts, 45.0).to_string(),
  )
  println("")
  println("== 把整定结果接回闭环 ==")
  let iq_ref = 2.0
  let model = @motor.PmsmModel::new(r, l, l, 0.02, 4, 0.0)
  let v_max = vdc * 0.9
  let ctl = @controller.FocController::new(
    gains.kp(),
    gains.ki(),
    gains.kp(),
    gains.ki(),
    ts,
    vdc,
    -v_max,
    v_max,
  )
  let steps = 4000
  let mut i = 0
  while i < steps {
    let (ia, ib, ic) = model.phase_currents()
    let (_, _, vd, vq, _, _, _) = ctl.step(
      ia,
      ib,
      ic,
      model.theta_e(),
      0.0,
      iq_ref,
    )
    model.step(vd, vq, ts)
    if i == 399 || i == 799 || i == 3999 {
      println(
        "t = " +
        ((i + 1).to_double() * ts).to_string() +
        " s: id = " +
        model.id().to_string() +
        ", iq = " +
        model.iq().to_string(),
      )
    }
    i += 1
  }
  println("稳态误差 = " + (model.iq() - iq_ref).abs().to_string())

  // 采样侧：同一拍的三相占空比下，检查哪两相的下管导通时间够 ADC 建立。
  let min_window = 1.5e-6
  let duties = (0.52, 0.31, 0.88)
  let (da, db, dc) = duties
  println(
    "采样窗口余量 (µs)：a = " +
    @controller.sample_window_margin(da, ts, min_window).to_string() +
    "，b = " +
    @controller.sample_window_margin(db, ts, min_window).to_string() +
    "，c = " +
    @controller.sample_window_margin(dc, ts, min_window).to_string(),
  )
  let pairs = @controller.pick_sample_pair(duties, ts, min_window)
  if pairs.length() == 0 {
    println("三相都不满足采样窗口，本次采样丢弃")
  } else {
    let (pa, pb) = pairs[0]
    println(
      "优先采样相：" +
      pa.to_string() +
      " 与 " +
      pb.to_string() +
      "，候选对 " +
      pairs.length().to_string() +
      " 组",
    )
  }
  let ia = 1.984
  let ib = -0.972
  println(
    "两相重构 ic = " +
    @controller.reconstruct_third(ia, ib).to_string() +
    "，残差 = " +
    @controller.zero_sequence_residual(
      ia,
      ib,
      @controller.reconstruct_third(ia, ib),
    ).to_string(),
  )
  // 过调制边界：内切圆（线性区边界）与外接圆之间还有一条六边形边，
  // 削顶多少由方向决定，同一个幅值在轴线方向被削、在顶点方向不被削。
  println("")
  println("=== 过调制边界（Vdc = " + vdc.to_string() + " V）===")
  let inradius = vdc / 3.0.sqrt()
  println("线性区边界（内切圆）|V| = " + inradius.to_string())
  println("顶点方向（外接圆）|V| = " + (2.0 * vdc / 3.0).to_string())
  let axis_alpha = @math.cos(3.141592653589793 / 6.0)
  let axis_beta = @math.sin(3.141592653589793 / 6.0)
  println(
    "30° 方向边界 |V| = " +
    @svpwm.hexagon_radius(axis_alpha, axis_beta, vdc).to_string(),
  )
  println(
    "0° 方向 30 V 的削顶比例 = " +
    @svpwm.clipping_ratio(30.0, 0.0, vdc).to_string(),
  )
  let clipped = @svpwm.project_to_hexagon(
    30.0 * axis_alpha,
    30.0 * axis_beta,
    vdc,
  )
  println(
    "30° 方向 30 V 投影后 = (" +
    clipped.0.to_string() +
    ", " +
    clipped.1.to_string() +
    ")，幅值 " +
    (clipped.0 * clipped.0 + clipped.1 * clipped.1).sqrt().to_string() +
    "，削顶比例 " +
    @svpwm.clipping_ratio(30.0 * axis_alpha, 30.0 * axis_beta, vdc).to_string(),
  )
}
