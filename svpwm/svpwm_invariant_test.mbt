///|
/// 全圆扫描与恒等式测试：不依赖任何外部参考数据，靠数学不变量抓错。
///
/// 手算夹具（`coord_test` / `svpwm_test` 里的 20 组）验证的是「特定点是
/// 对的」；这里验证的是「整个圆上都自洽」——扇区边界、过调制区、零矢量
/// 这些位置的错位，单点夹具很容易漏掉。

///|
/// 两值是否在容差内相等。
fn close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
test "duties stay inside [-1, 1] across the full circle" {
  // 幅值不变约定下，线性区最大相电压约 Vdc/√3，对应占空比 ±1；
  // 全圆扫描时任何一点越界都说明扇区映射或钳位写错了。
  let vdc = 24.0
  let ts = 0.0001
  let mut i = 0
  while i < 360 {
    let theta = i.to_double() * 3.141592653589793 / 180.0
    let mag = 0.9 * vdc / 3.0.sqrt() // 线性区内
    let (da, db, dc) = @svpwm.duties(
      mag * @math.cos(theta),
      mag * @math.sin(theta),
      ts,
      vdc,
    )
    assert_true(da >= -1.000000001 && da <= 1.000000001)
    assert_true(db >= -1.000000001 && db <= 1.000000001)
    assert_true(dc >= -1.000000001 && dc <= 1.000000001)
    i += 1
  }
}

///|
test "over-modulation clamps action times to the switching period" {
  // 参考矢量推到 2 倍线性区上限：T1+T2 必须被钳到 Ts，而不是超出去。
  let vdc = 24.0
  let ts = 0.0001
  let mag = 2.0 * vdc / 3.0.sqrt()
  let mut i = 0
  while i < 72 {
    let theta = i.to_double() * 2.0 * 3.141592653589793 / 72.0
    let alpha = mag * @math.cos(theta)
    let beta = mag * @math.sin(theta)
    let sector = @svpwm.sector_of(alpha, beta)
    let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
    assert_true(t1 >= -1.0e-18)
    assert_true(t2 >= -1.0e-18)
    assert_true(t1 + t2 <= ts + 1.0e-18)
    assert_true(@svpwm.is_overmodulated(alpha, beta, vdc))
    i += 1
  }
}

///|
test "duties are continuous across sector boundaries" {
  // 扇区切换点上越过 0.01° 的边界，三相占空比不应跳变：
  // 跳变说明某个扇区的矢量映射顺序写错了。
  let vdc = 24.0
  let ts = 0.0001
  let mag = 0.8 * vdc / 3.0.sqrt()
  let mut sector_start = 0.0
  while sector_start < 6.283185307179586 {
    let a = sector_start - 0.00017453292519943296 // -0.01°
    let b = sector_start + 0.00017453292519943296 // +0.01°
    let (a1, b1, c1) = @svpwm.duties(
      mag * @math.cos(a),
      mag * @math.sin(a),
      ts,
      vdc,
    )
    let (a2, b2, c2) = @svpwm.duties(
      mag * @math.cos(b),
      mag * @math.sin(b),
      ts,
      vdc,
    )
    assert_true(close(a1, a2, 0.002))
    assert_true(close(b1, b2, 0.002))
    assert_true(close(c1, c2, 0.002))
    sector_start += 3.141592653589793 / 3.0
  }
}

///|
test "modulation index is 1 at the linear limit" {
  let vdc = 24.0
  let vlimit = vdc / 3.0.sqrt()
  assert_true(close(@svpwm.modulation_index(vlimit, 0.0, vdc), 1.0, 1.0e-12))
  assert_false(@svpwm.is_overmodulated(vlimit * 0.999, 0.0, vdc))
  assert_true(@svpwm.is_overmodulated(vlimit * 1.001, 0.0, vdc))
  // 直流母线为 0 时调制比没有意义，约定返回 0 而不是 inf。
  assert_eq(@svpwm.modulation_index(1.0, 0.0, 0.0), 0.0)
}

///|
test "line voltages sum to zero and match phase differences" {
  let vdc = 24.0
  let (da, db, dc) = @svpwm.duties(1.0, 0.5, 0.0001, vdc)
  let (vab, vbc, vca) = @svpwm.line_voltages(da, db, dc, vdc)
  // 线电压之和恒为 0（三相同一条回路）。
  assert_true(close(vab + vbc + vca, 0.0, 1.0e-12))
  // 与相电压差一致：vab = (da - db)·Vdc/2。
  assert_true(close(vab, (da - db) * vdc / 2.0, 1.0e-12))
  assert_true(close(vbc, (db - dc) * vdc / 2.0, 1.0e-12))
  assert_true(close(vca, (dc - da) * vdc / 2.0, 1.0e-12))
  // 全零占空比 → 全零电压。
  let (z1, z2, z3) = @svpwm.phase_voltages(0.0, 0.0, 0.0, vdc)
  assert_eq(z1, 0.0)
  assert_eq(z2, 0.0)
  assert_eq(z3, 0.0)
}

///|
test "action_times rejects out of range sector instead of returning negative times" {
  // 传 0 或 7 时旧实现会让局部角落到 [0, π/3) 之外，T1/T2 变负。
  for bad in [0, 7, -1] {
    let (t1, t2) = @svpwm.action_times(5.0, 2.0, bad, 0.0001, 24.0)
    assert_eq(t1, 0.0)
    assert_eq(t2, 0.0)
  }
  // 合法扇区照常工作。
  let (t1, t2) = @svpwm.action_times(5.0, 2.0, 1, 0.0001, 24.0)
  assert_true(t1 >= 0.0)
  assert_true(t2 >= 0.0)
}

///|
test "dead time compensation clamps even when it is skipped" {
  // 没有死区 / 非法周期时不补偿，但越界占空比仍要被钳住。
  let (a, b, c) = @svpwm.dead_time_compensation(
    1.3, -1.3, 0.5, 1.0, -1.0, 0.0, 0.0, 0.0001,
  )
  assert_eq(a, 1.0)
  assert_eq(b, -1.0)
  assert_eq(c, 0.5)
}

///|
test "voltage reconstruction and modulation index reject non-finite input" {
  // 母线电压非正 / NaN：相电压返回 0，不返回负电压或 NaN。
  let (va1, vb1, vc1) = @svpwm.phase_voltages(0.5, 0.5, 0.5, -24.0)
  assert_eq(va1, 0.0)
  assert_eq(vb1, 0.0)
  assert_eq(vc1, 0.0)
  let nan = 0.0 / 0.0
  let (va2, _, _) = @svpwm.phase_voltages(0.5, 0.5, 0.5, nan)
  assert_eq(va2, 0.0)
  // 调制比遇到 NaN 返回 0（"没进过调制"），而不是 NaN。
  assert_eq(@svpwm.modulation_index(nan, 0.0, 24.0), 0.0)
  assert_eq(@svpwm.modulation_index(1.0, nan, 24.0), 0.0)
  assert_false(@svpwm.is_overmodulated(nan, 0.0, 24.0))
}
