///|
/// FOC 电流环时域仿真：简化 PMSM 模型 + controller 闭环。
///
/// 参数（离线演示用，不是选型推荐）：R=0.5 Ω，Ld=Lq=1 mH，ψf=0.05 Wb，
/// 4 极对，静止；Vdc=24 V，Ts=100 µs；iq 给定 2.0 A，id 给定 0 A。
/// 运行：`moon run examples/foc_sim --target native`
fn main {
  let r = 0.5
  let ld = 0.001
  let lq = 0.001
  let psi_f = 0.05
  let pole_pairs = 4
  let dt = 1.0e-4
  let vdc = 24.0

  let motor = @motor.PmsmModel::new(r, ld, lq, psi_f, pole_pairs, 0.0)
  let ctrl = @controller.FocController::new(
    2.0, 1000.0, 2.0, 1000.0, dt, vdc, -12.0, 12.0,
  )
  let id_ref = 0.0
  let iq_ref = 2.0

  let total = 2000 // 0.2 s
  let mut k = 0
  while k < total {
    let (ia, ib, ic) = motor.phase_currents()
    let (id, iq, vd, vq, da, db, dc) = ctrl.step(
      ia,
      ib,
      ic,
      motor.theta_e(),
      id_ref,
      iq_ref,
    )
    motor.step(vd, vq, dt)
    // 每 200 拍（20 ms）打一行轨迹
    if k % 200 == 0 {
      println(
        "t=" +
        (k.to_double() * dt).to_string() +
        "s  id=" +
        id.to_string() +
        " A  iq=" +
        iq.to_string() +
        " A  vd=" +
        vd.to_string() +
        " V  vq=" +
        vq.to_string() +
        " V  duties=(" +
        da.to_string() +
        ", " +
        db.to_string() +
        ", " +
        dc.to_string() +
        ")",
      )
    }
    k += 1
  }
  println(
    "final: id=" +
    motor.id().to_string() +
    " A  iq=" +
    motor.iq().to_string() +
    " A  (given id=" +
    id_ref.to_string() +
    ", iq=" +
    iq_ref.to_string() +
    ")",
  )
}
