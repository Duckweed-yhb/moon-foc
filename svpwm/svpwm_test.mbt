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

// 补扇区 3/5/6 的精确判定点，覆盖第二象限、负 beta 轴与右下区域。
test "sector: theta=3pi/4 (second quadrant) → sector 3" {
  assert_eq(@svpwm.sector_of(-0.7, 0.7), 3)
}

test "sector: theta=3pi/2 (negative beta axis) → sector 5" {
  assert_eq(@svpwm.sector_of(0.0, -1.0), 5)
}

test "sector: theta=11pi/6 (lower right) → sector 6" {
  assert_eq(@svpwm.sector_of(0.8660254037844386, -0.5), 6)
}

// 线性区内逐扇区检查：相邻矢量作用时间非负且求和不超 Ts，
// 七段式发波下最高/中/低相的占空比次序固定，扇区映射错位会被次序断言拦下。
test "sector 3: linear timing non-negative, duty order db >= dc >= da" {
  let vdc = 24.0
  let ts = 0.0001
  let (alpha, beta) = (-0.7, 0.7)
  let sector = @svpwm.sector_of(alpha, beta)
  let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
  assert_true(t1 >= -eps && t2 >= -eps)
  assert_true(t1 + t2 >= -eps)
  assert_true(t1 + t2 <= ts + eps)
  let (da, db, dc) = @svpwm.duties(alpha, beta, ts, vdc)
  assert_true(db >= dc && dc >= da)
}

test "sector 5: linear timing non-negative, duty order dc >= da >= db" {
  let vdc = 24.0
  let ts = 0.0001
  let (alpha, beta) = (0.0, -1.0)
  let sector = @svpwm.sector_of(alpha, beta)
  let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
  assert_true(t1 >= -eps && t2 >= -eps)
  assert_true(t1 + t2 >= -eps)
  assert_true(t1 + t2 <= ts + eps)
  let (da, db, dc) = @svpwm.duties(alpha, beta, ts, vdc)
  assert_true(dc >= da && da >= db)
}

test "sector 6: linear timing non-negative, duty order da >= dc >= db" {
  let vdc = 24.0
  let ts = 0.0001
  let (alpha, beta) = (0.8660254037844386, -0.5)
  let sector = @svpwm.sector_of(alpha, beta)
  let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
  assert_true(t1 >= -eps && t2 >= -eps)
  assert_true(t1 + t2 >= -eps)
  assert_true(t1 + t2 <= ts + eps)
  let (da, db, dc) = @svpwm.duties(alpha, beta, ts, vdc)
  assert_true(da >= dc && dc >= db)
}
