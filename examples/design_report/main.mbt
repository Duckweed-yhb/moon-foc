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
}
