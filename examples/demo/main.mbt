/// demo: 一组对称三相电流 + 电角度，走完 Clarke → Park → SVPWM 全链路。
/// 输入：ia=1.0, ib=-0.5, ic=-0.5, theta=0.7 rad, Vdc=24V, Ts=100us。

fn main() -> Unit {
  let ia = 1.0
  let ib = -0.5
  let ic = -0.5
  let theta = 0.7
  let vdc = 24.0
  let ts = 0.0001

  let (alpha, beta) = @coord.clarke(ia, ib, ic)
  println("alpha=" + alpha.to_string() + " beta=" + beta.to_string())

  let (d, q) = @coord.park(alpha, beta, theta)
  println("d=" + d.to_string() + " q=" + q.to_string())

  // 用 alpha/beta 直接喂 SVPWM（典型 FOC 链路是 d/q → inv_park → alpha/beta → SVPWM）
  let sector = @svpwm.sector_of(alpha, beta)
  println("sector=" + sector.to_string())

  let (da, db, dc) = @svpwm.duties(alpha, beta, ts, vdc)
  println(
    "duties: da=" + da.to_string() + " db=" + db.to_string() + " dc=" +
      dc.to_string(),
  )
}
