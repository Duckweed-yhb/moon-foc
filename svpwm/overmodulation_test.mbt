///|
/// 过调制钳位的性质测试。
///
/// `action_times` 在 T1+T2 > Ts 时按比例缩放，这个做法有一个不太显眼的性质：
/// **缩放保持 t1:t2 比例**，所以合成矢量的方向不变，只是幅值被压到六边形边上。
/// 这条性质是「过调制时电压相位不失真」的依据；如果以后换成最小相位误差
/// （MPE）或顶点保持策略，方向会被有意改变，必须同时改掉这里的断言和 README。
///
/// 另外钉住幅值范围：钳位后的合成矢量必须落在内切圆（Vdc/√3）与外接圆
/// （2·Vdc/3）之间——低于内切圆说明压过头，高于外接圆说明压根没钳住。

///|
/// 扇区的基本矢量（幅值不变约定）：Vk 在 (sector-1)·60°，Vk+1 在 sector·60°，
/// 幅值都是 2·Vdc/3。
fn sector_vector(
  sector : Int32,
  which : Int32,
  vdc : Double,
) -> (Double, Double) {
  let idx = sector - 1 + which
  let angle = idx.to_double() * 3.141592653589793 / 3.0
  let mag = 2.0 * vdc / 3.0
  (mag * @math.cos(angle), mag * @math.sin(angle))
}

///|
/// 角度差归一到 (−π, π]。
fn angle_diff(a : Double, b : Double) -> Double {
  let mut d = a - b
  while d > 3.141592653589793 {
    d = d - 2.0 * 3.141592653589793
  }
  while d <= -3.141592653589793 {
    d = d + 2.0 * 3.141592653589793
  }
  d
}

///|
test "over modulation clamping preserves the reference phase" {
  let vdc = 24.0
  let ts = 0.0001
  let inradius = vdc / 3.0.sqrt()
  let mut mag_factor = 1.1
  while mag_factor < 2.1 {
    let mag = mag_factor * inradius
    let mut i = 0
    while i < 36 {
      // 避开扇区边界：边界上 t1 或 t2 为 0，比例没有意义
      let theta = (i.to_double() + 0.5) * 2.0 * 3.141592653589793 / 36.0
      let alpha = mag * @math.cos(theta)
      let beta = mag * @math.sin(theta)
      let sector = @svpwm.sector_of(alpha, beta)
      let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
      // 由作用时间反推合成矢量（标幺化到 Ts）
      let (vkx, vky) = sector_vector(sector, 0, vdc)
      let (vk1x, vk1y) = sector_vector(sector, 1, vdc)
      let eff_x = t1 / ts * vkx + t2 / ts * vk1x
      let eff_y = t1 / ts * vky + t2 / ts * vk1y
      let eff_angle = @math.atan2(eff_y, eff_x)
      assert_true(angle_diff(eff_angle, theta).abs() < 1.0e-9)
      // 幅值落在内切圆与外接圆之间
      let eff_mag = (eff_x * eff_x + eff_y * eff_y).sqrt()
      assert_true(eff_mag >= inradius - 1.0e-9)
      assert_true(eff_mag <= 2.0 * vdc / 3.0 + 1.0e-9)
      i += 1
    }
    mag_factor += 0.3
  }
}

///|
test "linear region reproduces the reference magnitude exactly" {
  let vdc = 24.0
  let ts = 0.0001
  let inradius = vdc / 3.0.sqrt()
  let mag = 0.8 * inradius
  let mut i = 0
  while i < 12 {
    let theta = (i.to_double() + 0.5) * 2.0 * 3.141592653589793 / 12.0
    let alpha = mag * @math.cos(theta)
    let beta = mag * @math.sin(theta)
    let sector = @svpwm.sector_of(alpha, beta)
    let (t1, t2) = @svpwm.action_times(alpha, beta, sector, ts, vdc)
    let (vkx, vky) = sector_vector(sector, 0, vdc)
    let (vk1x, vk1y) = sector_vector(sector, 1, vdc)
    let eff_x = t1 / ts * vkx + t2 / ts * vk1x
    let eff_y = t1 / ts * vky + t2 / ts * vk1y
    let eff_mag = (eff_x * eff_x + eff_y * eff_y).sqrt()
    // 线性区没有钳位：合成矢量幅值应等于参考幅值
    assert_true((eff_mag - mag).abs() < 1.0e-9)
    i += 1
  }
}
