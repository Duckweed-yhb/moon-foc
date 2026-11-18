///|
fn motor_params() -> @simulation.MotorParams {
  {
    resistance: 0.5,
    ld: 0.0008,
    lq: 0.0012,
    magnet_flux: 0.05,
    pole_pairs: 4,
    inertia: 0.002,
    damping: 0.0005,
  }
}

///|
fn drive_tuning() -> @simulation.DriveTuning {
  { vdc: 48.0, dt: 1.0e-4, current_hz: 400.0, speed_hz: 40.0, iq_limit: 8.0, }
}

///|
test "step reports applied voltage and integrated mechanical state" {
  let p = motor_params()
  let t = drive_tuning()
  let drive = @simulation.SpeedDrive::new(p, t).unwrap()
  let sample = drive.step(100.0, 0.0).unwrap()
  assert_eq(sample.iq_ref, t.iq_limit)
  assert_eq(sample.id, 0.0)
  assert_true((sample.iq - sample.vq * t.dt / p.lq).abs() < 1.0e-12)
  let torque = 1.5 * p.pole_pairs.to_double() * p.magnet_flux * sample.iq
  assert_true((torque - sample.torque).abs() < 1.0e-12)
  assert_true((sample.omega_m - torque * t.dt / p.inertia).abs() < 1.0e-12)
  assert_eq(sample.omega_m, drive.omega_m())
}

///|
test "rejected commands leave the next valid sample reproducible" {
  let drive = @simulation.SpeedDrive::new(motor_params(), drive_tuning()).unwrap()
  let reference = @simulation.SpeedDrive::new(motor_params(), drive_tuning()).unwrap()
  for i in 0..<50 {
    if i == 25 {
      assert_true(drive.step(0.0 / 0.0, 0.0) is Err(_))
      assert_true(drive.step(50.0, 1.0 / 0.0) is Err(_))
    }
    let s = drive.step(50.0, 0.3).unwrap()
    let expected = reference.step(50.0, 0.3).unwrap()
    assert_eq(s.omega_m, expected.omega_m)
    assert_eq(s.iq, expected.iq)
    assert_eq(s.vq, expected.vq)
  }
}

///|
test "drive validates setup before simulation" {
  let p = motor_params()
  let t = drive_tuning()
  assert_true(@simulation.SpeedDrive::new({ ..p, pole_pairs: 0, }, t) is Err(_))
  assert_true(@simulation.SpeedDrive::new({ ..p, ld: 0.0, }, t) is Err(_))
  assert_true(
    @simulation.SpeedDrive::new({ ..p, inertia: 0.0 / 0.0, }, t) is Err(_),
  )
  assert_true(@simulation.SpeedDrive::new(p, { ..t, dt: 0.0, }) is Err(_))
  assert_true(
    @simulation.SpeedDrive::new(p, { ..t, vdc: 1.0 / 0.0, }) is Err(_),
  )
  assert_true(
    @simulation.SpeedDrive::new(p, { ..t, speed_hz: 1.0e250, }) is Err(_),
  )
}
