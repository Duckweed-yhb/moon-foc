/// 角度处理：机械角度 ↔ 电角度，以及归一化。
///
/// 电角度 = 机械角度（rad）× 极对数。
/// 归一化约定：输出落在 [0, 2π)。

let two_pi = 6.283185307179586

/// 把任意弧度归一化到 [0, 2π)。
pub fn normalize_angle(theta : Double) -> Double {
  let mut r = theta % two_pi
  if r < 0.0 {
    r += two_pi
  }
  r
}

/// 机械角度（rad）→ 电角度（rad），已归一化到 [0, 2π)。
pub fn mechanical_to_electrical(mech_angle : Double, pole_pairs : Int) -> Double {
  normalize_angle(mech_angle * pole_pairs.to_double())
}
