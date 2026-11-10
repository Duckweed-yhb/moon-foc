///|
/// 角度处理：机械角度 ↔ 电角度，以及归一化。
///
/// 电角度 = 机械角度（rad）× 极对数。
/// 归一化约定：输出落在 [0, 2π)。
let two_pi = 6.283185307179586

///|
/// 把任意弧度归一化到 [0, 2π)。
pub fn normalize_angle(theta : Double) -> Double {
  let mut r = theta % two_pi
  if r < 0.0 {
    r += two_pi
  }
  r
}

///|
/// 机械角度（rad）→ 电角度（rad），已归一化到 [0, 2π)。
pub fn mechanical_to_electrical(
  mech_angle : Double,
  pole_pairs : Int32,
) -> Double {
  normalize_angle(mech_angle * pole_pairs.to_double())
}

///|
/// 电角度（rad）→ 机械角度（rad）。
///
/// 注意这是**周期意义下**的逆：`mechanical_to_electrical` 把结果归一化到
/// [0, 2π)，所以反解只能回到一个周期内，输出落在 [0, 2π/pole_pairs)，
/// 满足 `mechanical_to_electrical(electrical_to_mechanical(x, p), p) == x`。
///
/// 编码器零位标定、极对数换算都用到这个方向；`pole_pairs <= 0` 时机械角
/// 没有意义，返回 0（与 `mechanical_to_electrical` 对 pole_pairs=0 恒返 0 对称）。
pub fn electrical_to_mechanical(
  elec_angle : Double,
  pole_pairs : Int32,
) -> Double {
  if pole_pairs <= 0 {
    return 0.0
  }
  normalize_angle(elec_angle) / pole_pairs.to_double()
}
