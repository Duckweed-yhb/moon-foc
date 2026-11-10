///|
/// 载波法 SVPWM 与空间矢量法的等价性，以及死区补偿的符号约定。
///
/// 七段式 SVPWM 的调制波形 = 正弦调制 + 零序注入 (vmax+vmin)/2，两条路径
/// 必须给出同一组占空比。这不是「再算一遍」，而是两套独立推导互证：
/// 任一路径改了扇区映射或钳位，这里立刻出现偏差。

///|
/// 幅值不变约定下的反 Clarke（与 coord/inv_clarke 同式）。
///
/// svpwm 包不依赖 coord（纯数值核心不该有包间耦合），所以测试里内联。
fn inv_clarke_inline(alpha : Double, beta : Double) -> (Double, Double, Double) {
  (
    alpha,
    -alpha / 2.0 + beta * (3.0.sqrt() / 2.0),
    -alpha / 2.0 - beta * (3.0.sqrt() / 2.0),
  )
}

///|
test "carrier SVPWM matches space vector SVPWM" {
  let vdc = 24.0
  let ts = 0.0001
  let mag = 0.9 * vdc / 3.0.sqrt() // 线性区内
  let mut i = 0
  while i < 72 {
    let theta = i.to_double() * 2.0 * 3.141592653589793 / 72.0
    let alpha = mag * @math.cos(theta)
    let beta = mag * @math.sin(theta)
    let (da, db, dc) = @svpwm.duties(alpha, beta, ts, vdc)
    let (va, vb, vc) = inv_clarke_inline(alpha, beta)
    let (ca, cb, cc) = @svpwm.duties_from_voltages(va, vb, vc, vdc)
    // 实测最大偏差 1e-15，容差留两个数量级余量。
    assert_true((da - ca).abs() < 1.0e-12)
    assert_true((db - cb).abs() < 1.0e-12)
    assert_true((dc - cc).abs() < 1.0e-12)
    i += 1
  }
}

///|
test "carrier SVPWM saturates instead of extrapolating in over modulation" {
  // 载波法的线性上限是 m = 2/√3 ≈ 1.1547，超过后占空比会越界。这里取 m=1.5，
  // 要求饱和在 ±1：宁可削顶，也不要把 1.3 这种占空比交给比较寄存器。
  let vdc = 24.0
  let mag = 1.5 * vdc / 3.0.sqrt()
  let (va, vb, vc) = inv_clarke_inline(mag, 0.0)
  let (ca, cb, cc) = @svpwm.duties_from_voltages(va, vb, vc, vdc)
  for d in [ca, cb, cc] {
    assert_true(d <= 1.0 + 1.0e-12)
    assert_true(d >= -1.0 - 1.0e-12)
  }
  // 至少有一相被削到边界，证明确实进了过调制区。
  assert_true(ca > 0.999999999 || cb > 0.999999999 || cc > 0.999999999)
}

///|
test "zero sequence injection centers the reference in the linear region" {
  // 线性区内：零序注入把中点移到母线中点，三个占空比最大与最小之和为 0。
  let vdc = 24.0
  let mag = 0.8 * vdc / 3.0.sqrt()
  let (va, vb, vc) = inv_clarke_inline(mag * 0.6, mag * 0.8)
  let (ca, cb, cc) = @svpwm.duties_from_voltages(va, vb, vc, vdc)
  let mut cmin = ca
  if cb < cmin {
    cmin = cb
  }
  if cc < cmin {
    cmin = cc
  }
  let mut cmax = ca
  if cb > cmax {
    cmax = cb
  }
  if cc > cmax {
    cmax = cc
  }
  assert_true((cmax + cmin).abs() < 1.0e-12)
}

///|
test "dead time compensation follows current sign" {
  let td = 0.0000005 // 500 ns
  let ts = 0.0001 // 10 kHz → td/ts = 0.5%
  let (da, db, dc) = @svpwm.dead_time_compensation(
    0.0, 0.0, 0.0, 1.0, -1.0, 0.0, td, ts,
  )
  assert_true((da - 0.005).abs() < 1.0e-12) // 正电流 → 占空比加
  assert_true((db + 0.005).abs() < 1.0e-12) // 负电流 → 占空比减
  assert_eq(dc, 0.0) // 零电流不补偿
}

///|
test "dead time compensation is skipped without dead time or period" {
  let (a1, b1, c1) = @svpwm.dead_time_compensation(
    0.1, 0.2, 0.3, 1.0, 1.0, 1.0, 0.0, 0.0001,
  )
  assert_eq(a1, 0.1)
  assert_eq(b1, 0.2)
  assert_eq(c1, 0.3)
  let (a2, b2, c2) = @svpwm.dead_time_compensation(
    0.1, 0.2, 0.3, 1.0, 1.0, 1.0, 0.0000005, 0.0,
  )
  assert_eq(a2, 0.1)
  assert_eq(b2, 0.2)
  assert_eq(c2, 0.3)
}

///|
test "dead time compensation clamps to the duty range" {
  // 占空比已经在 1 附近，再补偿也不能越过 ±1。
  let (da, db, dc) = @svpwm.dead_time_compensation(
    0.999, 0.5, -0.999, 1.0, 1.0, -1.0, 0.0005, 0.0001,
  )
  assert_true(da <= 1.0)
  assert_true(db <= 1.0)
  assert_true(dc >= -1.0)
}

///|
test "equal compensation on all phases does not change line voltages" {
  // 三相电流同号时补偿量相同，是共模偏移：线电压不变，这正是补偿该有的性质。
  let vdc = 24.0
  let td = 0.0000005
  let ts = 0.0001
  let (da, db, dc) = @svpwm.duties(1.0, 0.5, ts, vdc)
  let (ca, cb, cc) = @svpwm.dead_time_compensation(
    da, db, dc, 1.0, 1.0, 1.0, td, ts,
  )
  let (vab1, vbc1, vca1) = @svpwm.line_voltages(da, db, dc, vdc)
  let (vab2, vbc2, vca2) = @svpwm.line_voltages(ca, cb, cc, vdc)
  assert_true((vab1 - vab2).abs() < 1.0e-12)
  assert_true((vbc1 - vbc2).abs() < 1.0e-12)
  assert_true((vca1 - vca2).abs() < 1.0e-12)
}
