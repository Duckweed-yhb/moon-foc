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

  // d/q 经 inv_park 还原同一 alpha/beta，演示 Park 逆变换
  let (alpha2, beta2) = @coord.inv_park(d, q, theta)
  println("inv_park: alpha=" + alpha2.to_string() + " beta=" + beta2.to_string())

  // 最小示例直接用 Clarke 得到的 alpha/beta 喂 SVPWM；
  // 实际电流环输出 d/q 时，先经 inv_park 还原 alpha/beta 再调制。
  let sector = @svpwm.sector_of(alpha, beta)
  println("sector=" + sector.to_string())

  let (da, db, dc) = @svpwm.duties(alpha, beta, ts, vdc)
  println(
    "duties: da=" + da.to_string() + " db=" + db.to_string() + " dc=" +
      dc.to_string(),
  )
}
