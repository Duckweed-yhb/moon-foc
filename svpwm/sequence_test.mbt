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
    assert_eq(seq.length(), 7)
    let mut total = 0.0
    for item in seq {
      let (_, dur) = item
      assert_true(dur >= -1.0e-18)
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
