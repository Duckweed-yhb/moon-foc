///|
test "coupled speed drive balances torque and dq voltage under signed loads" {
  let p = motor_params()
  for n in 0..<40 {
    let speed = (1000 + n * 200).to_double() / 100.0
    let load = (n * 36 - 700).to_double() / 1000.0
    let drive = @simulation.SpeedDrive::new(p, {
      ..drive_tuning(),
      speed_hz: 20.0 + (n % 21).to_double(),
    }).unwrap()
    drive.set_cross_coupling(true)
    for k in 0..<18000 {
      let s = drive.step(speed, if k < 5000 { 0.0 } else { load }).unwrap()
      if k == 17999 {
        assert_true((s.omega_m - speed).abs() < 1.0e-5)
        assert_true(s.id.abs() < 1.0e-6)
        assert_true(
          (s.vd + speed * p.pole_pairs.to_double() * p.lq * s.iq).abs() < 1.0e-5,
        )
        assert_true((s.torque - load - p.damping * speed).abs() < 1.0e-6)
      }
    }
  }
}
