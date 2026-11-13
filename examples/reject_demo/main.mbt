///|
/// 拒绝演示：不合法输入会得到什么。
///
/// 这个库的卖点之一是「不返回 NaN」——但承诺只有被演示过才算数。这里把每条
/// 拒绝路径跑一遍：非法周期、非法母线电压、NaN、过大的参考矢量、越界扇区。
///
/// 运行：`moon run examples/reject_demo --target native`
fn nan_value() -> Double {
  let big = 1.0e308 * 10.0
  big - big
}

///|
fn show_inputs(label : String, r : Result[Unit, String]) -> Unit {
  match r {
    Ok(_) => println("  " + label + " -> 通过")
    Err(e) => println("  " + label + " -> 拒绝：" + e)
  }
}

///|
fn show_duties(label : String, t : (Double, Double, Double)) -> Unit {
  let (a, b, c) = t
  println(
    "  " +
    label +
    " -> (" +
    a.to_string() +
    ", " +
    b.to_string() +
    ", " +
    c.to_string() +
    ")",
  )
}

///|
fn main {
  let ts = 0.0001
  let vdc = 24.0
  println("== 入口校验（check_inputs）==")
  show_inputs(
    "正常输入 (0.5, 0.3, 1e-4, 24)",
    @svpwm.check_inputs(0.5, 0.3, ts, vdc),
  )
  show_inputs("开关周期 ts = 0", @svpwm.check_inputs(0.5, 0.3, 0.0, vdc))
  show_inputs(
    "母线电压 vdc = -24",
    @svpwm.check_inputs(0.5, 0.3, ts, -24.0),
  )
  show_inputs(
    "参考矢量含 NaN",
    @svpwm.check_inputs(nan_value(), 0.3, ts, vdc),
  )
  show_inputs(
    "参考矢量 1e200（平方会溢出）",
    @svpwm.check_inputs(1.0e200, 0.0, ts, vdc),
  )
  show_inputs(
    "vdc = 5e-324（除法会溢出）",
    @svpwm.check_inputs(0.5, 0.3, ts, 5.0e-324),
  )

  println("")
  println("== 兜底：不该出现 NaN 的地方（duties 的承诺）==")
  show_duties("duties(vdc = -24)", @svpwm.duties(0.5, 0.3, ts, -24.0))
  show_duties("duties(1e200, 0)", @svpwm.duties(1.0e200, 0.0, ts, vdc))
  show_duties("duties(正常, m=0.8)", @svpwm.duties(0.5, 0.3, ts, vdc))
  let nan = nan_value()
  let (na, nb, nc) = @svpwm.duties(nan, 0.0, ts, vdc)
  println(
    "  duties(NaN, 0) -> 是否含 NaN：" +
    (na != na || nb != nb || nc != nc).to_string(),
  )

  println("")
  println("== 扇区与序列 ==")
  let (t1, t2) = @svpwm.action_times(0.5, 0.3, 0, ts, vdc)
  println(
    "  action_times(扇区=0) -> (" +
    t1.to_string() +
    ", " +
    t2.to_string() +
    ")",
  )
  println(
    "  switching_sequence(扇区=7) -> 段数 " +
    @svpwm.switching_sequence(7, 0.00005, 0.00005, ts).length().to_string(),
  )
  println(
    "  switching_sequence(NaN 时长) -> 段数 " +
    @svpwm.switching_sequence(1, nan, 0.00005, ts).length().to_string(),
  )
  println(
    "  switching_sequence(正常) -> 段数 " +
    @svpwm.switching_sequence(1, 0.00005, 0.00005, ts).length().to_string(),
  )

  println("")
  println("== 角度 ==")
  let two_pi = 6.283185307179586
  let r = @angle.normalize_angle(-1.0e-17)
  println(
    "  normalize_angle(-1e-17) -> " +
    r.to_string() +
    "（< 2π: " +
    (r < two_pi).to_string() +
    "）",
  )
  println(
    "  electrical_to_mechanical(1.0, 极对数=0) -> " +
    @angle.electrical_to_mechanical(1.0, 0).to_string(),
  )
}
