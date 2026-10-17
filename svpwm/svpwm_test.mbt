/// svpwm 单测：扇区判断、作用时间对称性、过调制钳位、零矢量输入。

fn approx_equal(x : Double, y : Double, eps : Double) -> Bool {
  (x - y).abs() < eps
}

let eps = 0.0000001

test "sector: alpha-axis positive (theta=0) → sector 1" {
  assert_eq(@svpwm.sector_of(1.0, 0.0), 1)
}

test "sector: beta-axis positive (theta=pi/2) → sector 2" {
  assert_eq(@svpwm.sector_of(0.0, 1.0), 2)
}

test "sector: theta=pi → sector 4" {
  assert_eq(@svpwm.sector_of(-1.0, 0.0), 4)
}

test "action_times: zero input → (0,0)" {
  let (t1, t2) = @svpwm.action_times(0.0, 0.0, 1, 1.0, 24.0)
  assert_true(approx_equal(t1, 0.0, eps))
  assert_true(approx_equal(t2, 0.0, eps))
}

test "action_times: linear region T1+T2 ≤ Ts" {
  // Vdc=24, Ts=1e-4, Vref 取线性区最大 = Vdc/sqrt(3) ≈ 13.86
  let vdc = 24.0
  let ts = 0.0001
  let vref = vdc / 3.0.sqrt() * 0.5 // 半载，留余量
  let alpha = vref // theta=0, sector 1
  let (t1, t2) = @svpwm.action_times(alpha, 0.0, 1, ts, vdc)
  assert_true(t1 + t2 <= ts + eps)
  assert_true(t1 > 0.0)
  // 扇区 1，theta=0：t2 应该 ≈ 0
  assert_true(approx_equal(t2, 0.0, 0.000001))
}

test "action_times: overmodulation clamps T1+T2 = Ts" {
  // 输入 Vref 超线性区
  let vdc = 24.0
  let ts = 0.0001
  let vref = vdc // 远超 Vdc/sqrt(3) ≈ 13.86
  let alpha = vref * 0.7
  let beta = vref * 0.7
  let sector = @svpwm.sector_of(alpha, beta)
  let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
  assert_true(approx_equal(t1 + t2, ts, eps))
}

test "duties: zero input → all 0" {
  let (da, db, dc) = @svpwm.duties(0.0, 0.0, 0.0001, 24.0)
  assert_true(approx_equal(da, 0.0, eps))
  assert_true(approx_equal(db, 0.0, eps))
  assert_true(approx_equal(dc, 0.0, eps))
}

test "duties: all within [-1, 1] range" {
  let (da, db, dc) = @svpwm.duties(5.0, 2.0, 0.0001, 24.0)
  assert_true(da >= -1.0 && da <= 1.0)
  assert_true(db >= -1.0 && db <= 1.0)
  assert_true(dc >= -1.0 && dc <= 1.0)
}
