///|
/// svpwm 单测：扇区判断、作用时间对称性、过调制钳位、零矢量输入。
fn approx_equal(x : Double, y : Double, eps : Double) -> Bool {
  (x - y).abs() < eps
}

///|
let eps = 0.0000001

///|
test "sector: alpha-axis positive (theta=0) → sector 1" {
  assert_eq(@svpwm.sector_of(1.0, 0.0), 1)
}

///|
test "sector: beta-axis positive (theta=pi/2) → sector 2" {
  assert_eq(@svpwm.sector_of(0.0, 1.0), 2)
}

///|
test "sector: theta=pi → sector 4" {
  assert_eq(@svpwm.sector_of(-1.0, 0.0), 4)
}

///|
test "action_times: zero input → (0,0)" {
  let (t1, t2) = @svpwm.action_times(0.0, 0.0, 1, 1.0, 24.0)
  assert_true(approx_equal(t1, 0.0, eps))
  assert_true(approx_equal(t2, 0.0, eps))
}

///|
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

///|
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

///|
test "duties: zero input → all 0" {
  let (da, db, dc) = @svpwm.duties(0.0, 0.0, 0.0001, 24.0)
  assert_true(approx_equal(da, 0.0, eps))
  assert_true(approx_equal(db, 0.0, eps))
  assert_true(approx_equal(dc, 0.0, eps))
}

///|
test "duties: all within [-1, 1] range" {
  let (da, db, dc) = @svpwm.duties(5.0, 2.0, 0.0001, 24.0)
  assert_true(da >= -1.0 && da <= 1.0)
  assert_true(db >= -1.0 && db <= 1.0)
  assert_true(dc >= -1.0 && dc <= 1.0)
}

// 补扇区 3/5/6 的精确判定点，覆盖第二象限、负 beta 轴与右下区域。

///|
test "sector: theta=3pi/4 (second quadrant) → sector 3" {
  assert_eq(@svpwm.sector_of(-0.7, 0.7), 3)
}

///|
test "sector: theta=3pi/2 (negative beta axis) → sector 5" {
  assert_eq(@svpwm.sector_of(0.0, -1.0), 5)
}

///|
test "sector: theta=11pi/6 (lower right) → sector 6" {
  assert_eq(@svpwm.sector_of(0.8660254037844386, -0.5), 6)
}

// 线性区内逐扇区检查：相邻矢量作用时间非负且求和不超 Ts，
// 七段式发波下最高/中/低相的占空比次序固定，扇区映射错位会被次序断言拦下。

///|
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

///|
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

///|
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

// F2 手算绝对值基准：Vref=6 V、θ=π/6（扇区 1 中点），Vdc=24 V、Ts=1e-4 s。
// 线性区上限 Vdc/√3≈13.86 V，6 V 远在内部；θ=π/6 时 sin(π/6)=0.5，T1=T2。
// 期望值由教材公式独立手算：T1=T2=(√3·Ts/Vdc)·Vref·sin(π/6)，
// 占空比按七段式扇区 1 映射 T_on 后做 2·T_on/Ts-1，不取自本库运行输出。

///|
let oracle_vdc = 24.0

///|
let oracle_ts = 0.0001

///|
let oracle_alpha = 5.196152422706632 // 6·cos(π/6)

///|
let oracle_beta = 3.0 // 6·sin(π/6)

///|
test "action_times: hand-computed absolute baseline at theta=pi/6, Vref=6" {
  assert_eq(@svpwm.sector_of(oracle_alpha, oracle_beta), 1)
  let (t1, t2) = @svpwm.action_times(
    oracle_alpha, oracle_beta, 1, oracle_ts, oracle_vdc,
  )
  // 手算值：√3·1e-4/24·6·0.5 = 2.1650635094611e-5 s
  assert_true(approx_equal(t1, 0.000021650635094611, 0.000000000001))
  assert_true(approx_equal(t2, 0.000021650635094611, 0.000000000001))
}

///|
test "duties: hand-computed absolute baseline at theta=pi/6, Vref=6" {
  let (da, db, dc) = @svpwm.duties(
    oracle_alpha, oracle_beta, oracle_ts, oracle_vdc,
  )
  // 扇区 1：db 居中为 0；da=√3·Vref/Vdc=√3/4，dc=-da
  assert_true(approx_equal(da, 0.4330127018922193, 0.000000001))
  assert_true(approx_equal(db, 0.0, 0.000000001))
  assert_true(approx_equal(dc, -0.4330127018922193, 0.000000001))
}

// 与 coord 同一组 20 个基准点：duties 期望值同样由 Python 独立算出。
// 幅值 20 A 的几组进入过调制区，用来锁定 T1+T2=Ts 的按比例缩放行为。

///|
test "fixtures: 20 independent svpwm cases" {
  let inputs : Array[(Double, Double)] = [
    (1.0, 0.0),
    (4.755282581475766, 1.5450849718747375),
    (8.090169943749473, 5.877852522924733),
    (11.755705045849462, 16.180339887498953),
    (0.3090169943749474, 0.9510565162951538),
    (5.921189464667501e-16, 5.000000000000002),
    (-3.090169943749473, 9.510565162951538),
    (-11.755705045849455, 16.18033988749896),
    (-0.8090169943749471, 0.5877852522924737),
    (-4.7552825814757655, 1.5450849718747393),
    (-9.999999999999996, 3.589530347915986e-15),
    (-19.021130325903073, -6.180339887498939),
    (-0.8090169943749472, -0.587785252292473),
    (-2.938926261462366, -4.045084971874738),
    (-3.0901699437494754, -9.510565162951538),
    (-4.736951571734001e-15, -20.000000000000007),
    (0.30901699437494706, -0.9510565162951541),
    (2.9389262614623637, -4.04508497187474),
    (8.09016994374947, -5.877852522924736),
    (19.021130325903066, -6.180339887498959),
  ]
  let expected : Array[(Double, Double, Double)] = [
    (0.0625, -0.0625, -0.0625),
    (0.35295861286928076, -0.12994480676109965, -0.35295861286928076),
    (0.7177343550073119, 0.13066057908456719, -0.7177343550073116),
    (1.0, 0.77115870394148, -1.0),
    (0.03862712429686832, 0.0686365919621943, -0.0686365919621944),
    (-1.1102230246251565e-16, 0.36084391824351614, -0.36084391824351625),
    (-0.3862712429686844, 0.6863659196219432, -0.6863659196219433),
    (-1.0, 1.0, -0.7711587039414802),
    (-0.07177343550073112, 0.07177343550073112, -0.013066057908456719),
    (-0.35295861286928065, 0.35295861286928076, 0.12994480676109932),
    (-0.6249999999999996, 0.6250000000000002, 0.6249999999999996),
    (-1.0, 0.36815876429462646, 1.0),
    (-0.07177343550073112, -0.013066057908456719, 0.07177343550073112),
    (-0.32964732242932226, -0.2542104019223753, 0.32964732242932193),
    (-0.3862712429686841, -0.6863659196219436, 0.6863659196219438),
    (4.440892098500626e-16, -1.0, 1.0),
    (0.03862712429686832, -0.0686365919621944, 0.0686365919621943),
    (0.32964732242932193, -0.32964732242932204, 0.25421040192237565),
    (0.7177343550073116, -0.7177343550073115, 0.1306605790845683),
    (1.0, -1.0, -0.3681587642946237),
  ]
  for i in 0..<20 {
    let (alpha, beta) = inputs[i]
    let (eda, edb, edc) = expected[i]
    let (da, db, dc) = @svpwm.duties(alpha, beta, 0.0001, 24.0)
    assert_true(approx_equal(da, eda, eps))
    assert_true(approx_equal(db, edb, eps))
    assert_true(approx_equal(dc, edc, eps))
  }
}
