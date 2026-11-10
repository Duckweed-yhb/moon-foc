///|
/// 输入校验与退化输入测试。
///
/// 关注的是「数值内核不静默产出 NaN」：控制环里 NaN 会一路传到 PWM 比较
/// 寄存器，故障点离源头很远，比返回错误更难查。

///|
test "check_inputs accepts a normal operating point" {
  match @svpwm.check_inputs(1.0, 0.5, 0.0001, 24.0) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
}

///|
test "check_inputs rejects non-positive period and dc bus" {
  // 开关周期为 0 时 duties 的 2*T_on/Ts 会变成 inf。
  match @svpwm.check_inputs(1.0, 0.0, 0.0, 24.0) {
    Ok(_) => fail("ts=0 should be rejected")
    Err(e) => assert_true(e.contains("switch period"))
  }
  match @svpwm.check_inputs(1.0, 0.0, 0.0001, 0.0) {
    Ok(_) => fail("vdc=0 should be rejected")
    Err(e) => assert_true(e.contains("dc bus"))
  }
  match @svpwm.check_inputs(1.0, 0.0, -0.0001, 24.0) {
    Ok(_) => fail("negative ts should be rejected")
    Err(_) => ()
  }
}

///|
test "check_inputs rejects NaN and infinity" {
  // NaN 用 0/0 构造，不依赖常量字面量；layered 比较走 x != x。
  let nan = 0.0 / 0.0
  match @svpwm.check_inputs(nan, 0.0, 0.0001, 24.0) {
    Ok(_) => fail("NaN alpha should be rejected")
    Err(e) => assert_true(e.contains("reference vector"))
  }
  let inf = 1.0 / 0.0
  match @svpwm.check_inputs(1.0, inf, 0.0001, 24.0) {
    Ok(_) => fail("infinite beta should be rejected")
    Err(_) => ()
  }
}

///|
test "duties on degenerate input returns zeros, not NaN" {
  // 退化输入返回 0 占空比（安全侧），不是 NaN。
  let (da, db, dc) = @svpwm.duties(1.0, 0.5, 0.0, 24.0)
  assert_eq(da, 0.0)
  assert_eq(db, 0.0)
  assert_eq(dc, 0.0)
  let (ea, eb, ec) = @svpwm.duties(1.0, 0.5, 0.0001, 0.0)
  assert_eq(ea, 0.0)
  assert_eq(eb, 0.0)
  assert_eq(ec, 0.0)
}

///|
test "duties_checked passes normal case through to duties" {
  let direct = @svpwm.duties(1.0, 0.5, 0.0001, 24.0)
  match @svpwm.duties_checked(1.0, 0.5, 0.0001, 24.0) {
    Err(e) => fail(e)
    Ok(d) => {
      assert_eq(d.0, direct.0)
      assert_eq(d.1, direct.1)
      assert_eq(d.2, direct.2)
    }
  }
  match @svpwm.duties_checked(0.0 / 0.0, 0.5, 0.0001, 24.0) {
    Ok(_) => fail("NaN input should surface as Err")
    Err(_) => ()
  }
}
