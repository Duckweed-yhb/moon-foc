///|
test "flux headroom is positive below the base speed" {
  // ωe=400、Vmax=48/√3=27.7128：27.7128/400 = 0.06928 > ψf=0.05，还有余量
  let h = @controller.flux_headroom(
    400.0, 0.0008, 0.0012, 0.05, 0.0, 27.712812921102035,
  )
  assert_true((h - 0.019282).abs() <= 1.0e-6)
  assert_true(
    @controller.field_weakening_id(
      400.0, 0.0008, 0.0012, 0.05, 0.0, 27.712812921102035, -8.0,
    ) ==
    0.0,
  )
}

///|
test "flux headroom turns negative above the base speed" {
  let vmax = 27.712812921102035
  let h = @controller.flux_headroom(600.0, 0.0008, 0.0012, 0.05, 0.0, vmax)
  assert_true((h + 0.0038119785).abs() <= 1.0e-9)
  let id = @controller.field_weakening_id(
    600.0, 0.0008, 0.0012, 0.05, 0.0, vmax, -8.0,
  )
  assert_true((id + 4.7649730812).abs() <= 1.0e-6)
}

///|
test "q-axis current eats into the voltage budget" {
  let vmax = 27.712812921102035
  // iq=5 A 时 (ωe·Lq·iq)=3.6 V 先占掉一部分，弱磁更深
  let h = @controller.flux_headroom(600.0, 0.0008, 0.0012, 0.05, 5.0, vmax)
  assert_true((h + 0.0042033).abs() <= 1.0e-7)
  let id = @controller.field_weakening_id(
    600.0, 0.0008, 0.0012, 0.05, 5.0, vmax, -8.0,
  )
  assert_true((id + 5.254185).abs() <= 1.0e-5)
}

///|
test "weakening id respects the current floor" {
  let vmax = 27.712812921102035
  // 需要 -4.76 A，给到 -3 A 就停在 -3 A
  assert_true(
    @controller.field_weakening_id(600.0, 0.0008, 0.0012, 0.05, 0.0, vmax, -3.0) ==
    -3.0,
  )
  // 正的 id_min 按 0 处理，不至于把 id 抬成正的
  assert_true(
    @controller.field_weakening_id(600.0, 0.0008, 0.0012, 0.05, 0.0, vmax, 2.0) ==
    0.0,
  )
}

///|
test "no voltage budget left degenerates to the floor" {
  // vmax=1、iq=5 A 时 ωe·Lq·iq=6 V 已经超了母线，方程无解
  assert_true(
    @controller.flux_headroom(1000.0, 0.0008, 0.0012, 0.05, 5.0, 1.0) == -0.05,
  )
  assert_true(
    @controller.field_weakening_id(1000.0, 0.0008, 0.0012, 0.05, 5.0, 1.0, -6.0) ==
    -6.0,
  )
}

///|
test "invalid inputs return zero" {
  let vmax = 27.712812921102035
  assert_true(
    @controller.flux_headroom(0.0, 0.0008, 0.0012, 0.05, 0.0, vmax) == 0.0,
  )
  assert_true(
    @controller.flux_headroom(600.0, 0.0, 0.0012, 0.05, 0.0, vmax) == 0.0,
  )
  assert_true(
    @controller.flux_headroom(600.0, 0.0008, 0.0012, 0.05, 0.0, 0.0) == 0.0,
  )
  assert_true(
    @controller.flux_headroom(0.0 / 0.0, 0.0008, 0.0012, 0.05, 0.0, vmax) == 0.0,
  )
  assert_true(
    @controller.field_weakening_id(
      600.0,
      0.0008,
      0.0012,
      0.05,
      1.0 / 0.0,
      vmax,
      -8.0,
    ) ==
    0.0,
  )
}
