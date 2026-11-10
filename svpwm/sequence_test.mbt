///|
/// 七段式开关序列测试。
///
/// 判据是「与占空比自洽」：序列里每一相的高电平总时间必须等于
/// `(duty+1)/2·ts`。这条把 `switching_sequence` 与 `duties` 两条独立路径
/// 钉在一起——任一边的扇区映射写错，这里都会立刻失配。

///|
fn seq_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-15
}

///|
test "sequence durations sum to the switching period" {
  let ts = 0.0001
  let vdc = 24.0
  let mag = 0.9 * vdc / 3.0.sqrt()
  let mut i = 0
  while i < 72 {
    let theta = i.to_double() * 2.0 * 3.141592653589793 / 72.0
    let alpha = mag * @math.cos(theta)
    let beta = mag * @math.sin(theta)
    let sector = @svpwm.sector_of(alpha, beta)
    let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
    let seq = @svpwm.switching_sequence(sector, t1, t2, ts)
    // 零时长段会被丢掉：扇区边界上 t1 或 t2 为 0 时少于七段，但至少三段。
    assert_true(seq.length() >= 3 && seq.length() <= 7)
    let mut total = 0.0
    for item in seq {
      let (_, dur) = item
      assert_true(dur > 0.0)
      total = total + dur
    }
    assert_true(seq_near(total, ts))
    i += 1
  }
}

///|
test "phase on times match the duty ratios" {
  let ts = 0.0001
  let vdc = 24.0
  let mag = 0.9 * vdc / 3.0.sqrt()
  let mut i = 0
  while i < 36 {
    let theta = i.to_double() * 2.0 * 3.141592653589793 / 36.0
    let alpha = mag * @math.cos(theta)
    let beta = mag * @math.sin(theta)
    let (da, db, dc) = @svpwm.duties(alpha, beta, ts, vdc)
    let sector = @svpwm.sector_of(alpha, beta)
    let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
    let seq = @svpwm.switching_sequence(sector, t1, t2, ts)
    // 占空比以 0 为中心 → 高电平时间 = (duty+1)/2 · ts
    assert_true(
      seq_near(@svpwm.on_time_of_phase(seq, 0), (da + 1.0) / 2.0 * ts),
    )
    assert_true(
      seq_near(@svpwm.on_time_of_phase(seq, 1), (db + 1.0) / 2.0 * ts),
    )
    assert_true(
      seq_near(@svpwm.on_time_of_phase(seq, 2), (dc + 1.0) / 2.0 * ts),
    )
    i += 1
  }
}

///|
test "sequence is symmetric and starts and ends at the zero vector" {
  let seq = @svpwm.switching_sequence(1, 3.0e-5, 2.0e-5, 1.0e-4)
  assert_eq(seq.length(), 7)
  let (s0, d0) = seq[0]
  let (s6, d6) = seq[6]
  assert_eq(s0, 0x00)
  assert_eq(s6, 0x00)
  assert_true(seq_near(d0, d6))
  // 第二段与第六段是同一个基本矢量，时间相等
  let (s1, d1) = seq[1]
  let (s5, d5) = seq[5]
  assert_eq(s1, s5)
  assert_true(seq_near(d1, d5))
  // 中间是七矢量
  let (s3, _) = seq[3]
  assert_eq(s3, 0x07)
}

///|
test "invalid sector or overlong times yield an empty sequence" {
  assert_eq(@svpwm.switching_sequence(0, 1.0e-5, 1.0e-5, 1.0e-4).length(), 0)
  assert_eq(@svpwm.switching_sequence(7, 1.0e-5, 1.0e-5, 1.0e-4).length(), 0)
  // t1+t2 超过 ts：先 action_times 钳位，这里直接拒绝
  assert_eq(@svpwm.switching_sequence(1, 8.0e-5, 8.0e-5, 1.0e-4).length(), 0)
}

///|
/// 过调制边界（t0 = 0）：零矢量没有时间，序列应退化成 3 段而不是 7 段。
test "zero vector segments disappear at the over modulation boundary" {
  let ts = 0.0001
  let seq = @svpwm.switching_sequence(1, 6.0e-5, 4.0e-5, ts) // t1+t2 == ts
  // 两个零矢量段被丢掉，剩 V1、V2、V2、V1 四段（中间两个 V2 各自是 t2/2）
  assert_eq(seq.length(), 4)
  let (s0, d0) = seq[0]
  let (s1, d1) = seq[1]
  let (s2, d2) = seq[2]
  let (s3, d3) = seq[3]
  assert_eq(s0, 0x04) // V1
  assert_eq(s1, 0x06) // V2
  assert_eq(s2, 0x06) // V2
  assert_eq(s3, 0x04) // 回到 V1
  assert_true(seq_near(d0, 3.0e-5))
  assert_true(seq_near(d1, 2.0e-5))
  assert_true(seq_near(d2, 2.0e-5))
  assert_true(seq_near(d3, 3.0e-5))
  assert_true(seq_near(d0 + d1 + d2 + d3, ts))
  // 每段都非零：下游不该拿到零长度脉冲
  for item in seq {
    let (_, dur) = item
    assert_true(dur > 0.0)
  }
}

///|
/// 扇区边界上一个矢量为零时间：对应段被丢掉，剩 5 段。
test "a zero length active vector is dropped too" {
  let ts = 0.0001
  let seq = @svpwm.switching_sequence(2, 0.0, 5.0e-5, ts)
  assert_eq(seq.length(), 5)
  for item in seq {
    let (_, dur) = item
    assert_true(dur > 0.0)
  }
  let mut total = 0.0
  for item in seq {
    let (_, dur) = item
    total = total + dur
  }
  assert_true(seq_near(total, ts))
}

///|
/// 组合入口与手工三步必须逐位一致。
test "switching_sequence_of matches the manual composition" {
  let vdc = 24.0
  let ts = 0.0001
  let mag = 0.95 * vdc / 3.0.sqrt() // 线性区
  let mut i = 0
  while i < 24 {
    let theta = (i.to_double() + 0.5) * 2.0 * 3.141592653589793 / 24.0
    let alpha = mag * @math.cos(theta)
    let beta = mag * @math.sin(theta)
    // 手工三步
    let sector = @svpwm.sector_of(alpha, beta)
    let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
    let manual = @svpwm.switching_sequence(sector, t1, t2, ts)
    // 组合入口
    let combined = @svpwm.switching_sequence_of(alpha, beta, ts, vdc)
    assert_eq(manual.length(), combined.length())
    let mut k = 0
    while k < manual.length() {
      let (ms, md) = manual[k]
      let (cs, cd) = combined[k]
      assert_eq(ms, cs)
      assert_true(seq_near(md, cd))
      k += 1
    }
    i += 1
  }
}

///|
/// 非法输入返回空数组：不会给出一个「看起来正常」的序列。
test "switching_sequence_of rejects invalid inputs" {
  let nan = 0.0 / 0.0
  assert_eq(@svpwm.switching_sequence_of(nan, 0.0, 0.0001, 24.0).length(), 0)
  assert_eq(@svpwm.switching_sequence_of(1.0, 0.0, 0.0, 24.0).length(), 0)
  assert_eq(@svpwm.switching_sequence_of(1.0, 0.0, 0.0001, 0.0).length(), 0)
  // 合法输入给出 7 段（线性区内零矢量时间不为零）
  assert_eq(@svpwm.switching_sequence_of(1.0, 0.5, 0.0001, 24.0).length(), 7)
}

///|
/// 过调制输入：组合入口同样钳位，序列总时长等于 Ts。
test "switching_sequence_of clamps in over modulation" {
  let vdc = 24.0
  let ts = 0.0001
  let mag = 2.0 * vdc / 3.0.sqrt()
  let seq = @svpwm.switching_sequence_of(mag, 0.0, ts, vdc)
  assert_true(seq.length() > 0)
  let mut total = 0.0
  for item in seq {
    let (_, dur) = item
    assert_true(dur > 0.0)
    total = total + dur
  }
  assert_true(seq_near(total, ts))
}
