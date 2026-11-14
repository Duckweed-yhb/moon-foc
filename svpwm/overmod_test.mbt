///|
/// 过调制几何边界：六边形半径、投影与削顶比例。
///
/// 这几条的用途不是再验一遍钳位本身（`overmodulation_test.mbt` 已经钉住
/// 「保持相位、幅值落在内外圆之间」），而是把「被削掉多少」变成可算的数，
/// 并证明几何式与 `action_times` 的比例钳位落在同一个幅值上。

///|
test "hexagon radius equals the inscribed radius on the sector axis" {
  let vdc = 48.0
  let inradius = vdc / 3.0.sqrt()
  // θ = 30° 落在扇区 1 的轴线上
  let alpha = @math.cos(3.141592653589793 / 6.0)
  let beta = @math.sin(3.141592653589793 / 6.0)
  let r = @svpwm.hexagon_radius(alpha, beta, vdc)
  assert_true((r - inradius).abs() < 1.0e-9)
}

///|
test "hexagon radius reaches two thirds of the bus at the vertex" {
  let vdc = 48.0
  let r = @svpwm.hexagon_radius(1.0, 0.0, vdc)
  assert_true((r - 2.0 * vdc / 3.0).abs() < 1.0e-9)
}

///|
test "hexagon radius matches the magnitude action_times actually outputs" {
  let vdc = 24.0
  let ts = 0.0001
  let inradius = vdc / 3.0.sqrt()
  let mut factor = 1.2
  while factor < 2.1 {
    let mag = factor * inradius
    let mut i = 0
    while i < 12 {
      // 每个扇区中点与靠边各取一次，覆盖 cos(π/6 − φ) 的两端
      let theta = i.to_double() * 3.141592653589793 / 12.0 + 0.02
      let alpha = mag * @math.cos(theta)
      let beta = mag * @math.sin(theta)
      let sector = @svpwm.sector_of(alpha, beta)
      let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
      let effective = @svpwm.hexagon_radius(alpha, beta, vdc)
      // 钳位后作用时间占满整个周期，反推幅值：|V| = (t1+t2)/ts 对应的边界值
      assert_true((t1 + t2 - ts).abs() < 1.0e-6)
      let projected = @svpwm.project_to_hexagon(alpha, beta, vdc)
      let pmag = (projected.0 * projected.0 + projected.1 * projected.1).sqrt()
      assert_true((pmag - effective).abs() < 1.0e-9)
      // 解析式与「钳位后占空比对应的实际幅值」一致：把投影后的矢量再算一次
      // action_times，时间必须刚好填满周期（边界上不留零矢量）。
      let psector = @svpwm.sector_of(projected.0, projected.1)
      let (p1, p2) = @svpwm.action_times(
        projected.0,
        projected.1,
        psector,
        ts,
        vdc,
      )
      assert_true((p1 + p2 - ts).abs() < 1.0e-6)
      i += 1
    }
    factor += 0.3
  }
}

///|
test "project to hexagon keeps the direction and lands on the boundary" {
  let vdc = 48.0
  let theta = 3.141592653589793 / 6.0 + 0.2
  let mag = 40.0
  let alpha = mag * @math.cos(theta)
  let beta = mag * @math.sin(theta)
  let (pa, pb) = @svpwm.project_to_hexagon(alpha, beta, vdc)
  let pmag = (pa * pa + pb * pb).sqrt()
  let ptheta = @math.atan2(pb, pa)
  assert_true((ptheta - theta).abs() < 1.0e-9)
  assert_true((pmag - @svpwm.hexagon_radius(alpha, beta, vdc)).abs() < 1.0e-9)
  assert_true(pmag < mag)
}

///|
test "project to hexagon leaves a linear-region vector untouched" {
  let vdc = 48.0
  let inradius = vdc / 3.0.sqrt()
  let alpha = 0.4 * inradius
  let beta = -0.3 * inradius
  let (pa, pb) = @svpwm.project_to_hexagon(alpha, beta, vdc)
  assert_true(pa == alpha)
  assert_true(pb == beta)
}

///|
test "clipping ratio is zero inside the linear region and positive beyond" {
  let vdc = 48.0
  let inradius = vdc / 3.0.sqrt()
  let inside = inradius * 0.9
  assert_eq(@svpwm.clipping_ratio(inside, 0.0, vdc), 0.0)
  // 顶点方向（θ=0）：边界是 2·Vdc/3 = 32 V，30 V 还在界内，34 V 才被削
  assert_eq(@svpwm.clipping_ratio(30.0, 0.0, vdc), 0.0)
  let ratio = @svpwm.clipping_ratio(34.0, 0.0, vdc)
  assert_true(ratio > 0.0)
  assert_true((ratio - (1.0 - 32.0 / 34.0)).abs() < 1.0e-12)
  // 扇区轴线方向（θ=30°）：边界是内切圆 27.71 V，30 V 已经超了
  let ax = 30.0 * @math.cos(3.141592653589793 / 6.0)
  let ay = 30.0 * @math.sin(3.141592653589793 / 6.0)
  assert_true(@svpwm.clipping_ratio(ax, ay, vdc) > 0.0)
}

///|
test "over modulation geometry rejects degenerate input without NaN" {
  let nan = 0.0 / 0.0
  let inf = 1.0 / 0.0
  assert_eq(@svpwm.hexagon_radius(nan, 1.0, 48.0), 0.0)
  assert_eq(@svpwm.hexagon_radius(1.0, inf, 48.0), 0.0)
  assert_eq(@svpwm.hexagon_radius(1.0, 1.0, 0.0), 0.0)
  assert_eq(@svpwm.hexagon_radius(0.0, 0.0, 48.0), 48.0 / 3.0.sqrt())
  let (pa, pb) = @svpwm.project_to_hexagon(nan, 1.0, 48.0)
  assert_eq(pa, 0.0)
  assert_eq(pb, 0.0)
  assert_eq(@svpwm.clipping_ratio(1.0, 1.0, -48.0), 0.0)
}
