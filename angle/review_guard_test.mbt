///|
/// 评审回归：归一化必须真的落在 [0, 2π)。
///
/// `-1e-17 + 2π` 在 double 里正好等于 2π（相对误差 1.8e-16 把 1e-17 吃掉了），
/// 旧实现直接返回 2π。而「两个接近的量相减」「编码器零位残差」给出的正是这种
/// 极小负角；调用方按 floor(θ/(π/3)) 查六扇区表就会得到索引 6。
test "normalize_angle stays below two pi for tiny negative angles" {
  let two_pi = 6.283185307179586
  for x in [-1.0e-17, -1.0e-300, -4.44e-16, -1.0e-9, -0.5] {
    let r = @angle.normalize_angle(x)
    assert_true(r >= 0.0)
    assert_true(r < two_pi)
  }
}

///|
/// 正角度、超一圈、恰好 2π 的既有语义不变。
test "normalize_angle keeps the usual cases" {
  assert_eq(@angle.normalize_angle(0.0), 0.0)
  assert_true((@angle.normalize_angle(0.5) - 0.5).abs() < 1.0e-15)
  assert_true(
    (@angle.normalize_angle(7.0) - (7.0 - 6.283185307179586)).abs() < 1.0e-12,
  )
  assert_eq(@angle.normalize_angle(6.283185307179586), 0.0)
}
