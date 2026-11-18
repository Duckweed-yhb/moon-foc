///|
/// SI motor parameters for the simplified PMSM and single-inertia load.
pub(all) struct MotorParams {
  resistance : Double
  ld : Double
  lq : Double
  magnet_flux : Double
  pole_pairs : Int32
  inertia : Double
  damping : Double
}

///|
/// Electrical supply, sample period (seconds), loop bandwidths (Hz)
/// and absolute q-axis current reference limit (A).
pub(all) struct DriveTuning {
  vdc : Double
  dt : Double
  current_hz : Double
  speed_hz : Double
  iq_limit : Double
}

///|
/// One tick of the cascaded speed/current controller and the simulated plant.
/// omega_m, id and iq are sampled after integration; iq_ref, vd and vq are
/// the commands applied during this tick. All values use SI units.
pub struct DriveSample {
  omega_m : Double
  id : Double
  iq : Double
  iq_ref : Double
  vd : Double
  vq : Double
  torque : Double
}

///|
pub struct SpeedDrive {
  priv params : MotorParams
  priv tuning : DriveTuning
  priv electrical : @motor.PmsmModel
  priv mechanical : @motor.MechanicalModel
  priv speed : @controller.SpeedController
  priv d_pi : @pi.Pi
  priv q_pi : @pi.Pi
}

///|
fn positive(x : Double) -> Bool {
  x > 0.0 && !x.is_inf()
}

///|
/// Start from rest with empty integrators. The electrical model simulates back
/// EMF with q-axis flux psi_f + Ld * id, and omits the d-axis cross term.
/// The mechanical model clamps speed at zero.
pub fn SpeedDrive::new(
  params : MotorParams,
  tuning : DriveTuning,
) -> Result[SpeedDrive, String] {
  if !(params.resistance >= 0.0 &&
    !params.resistance.is_inf() &&
    params.damping >= 0.0 &&
    !params.damping.is_inf()) {
    return Err("resistance and damping must be finite and non-negative")
  }
  if !(positive(params.ld) &&
    positive(params.lq) &&
    positive(params.inertia) &&
    positive(params.magnet_flux) &&
    params.pole_pairs > 0) {
    return Err(
      "inductances, inertia, magnet flux and pole pairs must be positive and finite",
    )
  }
  if !(positive(tuning.vdc) &&
    positive(tuning.dt) &&
    positive(tuning.current_hz) &&
    positive(tuning.speed_hz) &&
    positive(tuning.iq_limit)) {
    return Err(
      "supply voltage, sample period, bandwidths and current limit must be positive and finite",
    )
  }
  // The underlying plant clamps smaller inductances and inertia. Designing
  // gains from the unclamped values would tune the controller for another motor.
  if params.ld < 1.0e-9 || params.lq < 1.0e-9 || params.inertia < 1.0e-12 {
    return Err("plant requires Ld and Lq >= 1e-9 H and inertia >= 1e-12 kg m^2")
  }
  let kt = 1.5 * params.pole_pairs.to_double() * params.magnet_flux
  let sg = @controller.design_speed_loop(
    params.inertia,
    params.damping,
    kt,
    tuning.speed_hz,
  )
  let dg = @controller.design_current_loop(
    params.resistance,
    params.ld,
    tuning.current_hz,
  )
  let qg = @controller.design_current_loop(
    params.resistance,
    params.lq,
    tuning.current_hz,
  )
  if !(positive(sg.kp()) &&
    positive(sg.ki()) &&
    positive(dg.kp()) &&
    positive(qg.kp()) &&
    !dg.ki().is_inf() &&
    !qg.ki().is_inf()) {
    return Err("controller gains exceed the supported range")
  }
  let limit = tuning.vdc / 3.0.sqrt()
  Ok({
    params,
    tuning,
    electrical: @motor.PmsmModel::new(
      params.resistance,
      params.ld,
      params.lq,
      params.magnet_flux,
      params.pole_pairs,
      0.0,
    ),
    mechanical: @motor.MechanicalModel::new(
      params.inertia,
      params.damping,
      params.pole_pairs,
      0.0,
    ),
    speed: @controller.SpeedController::new(
      sg.kp(),
      sg.ki(),
      tuning.dt,
      -tuning.iq_limit,
      tuning.iq_limit,
    ),
    d_pi: @pi.Pi::new(dg.kp(), dg.ki(), tuning.dt, -limit, limit),
    q_pi: @pi.Pi::new(qg.kp(), qg.ki(), tuning.dt, -limit, limit),
  })
}

///|
pub fn SpeedDrive::omega_m(self : SpeedDrive) -> Double {
  self.mechanical.omega_m()
}

///|
/// Apply one sample of speed reference (rad/s) and opposing load torque (N m).
/// Reject non-finite commands before updating either controller or plant.
pub fn SpeedDrive::step(
  self : SpeedDrive,
  omega_ref : Double,
  load_torque : Double,
) -> Result[DriveSample, String] {
  if omega_ref.is_nan() ||
    omega_ref.is_inf() ||
    load_torque.is_nan() ||
    load_torque.is_inf() {
    return Err("speed reference and load torque must be finite")
  }
  if omega_ref < 0.0 {
    return Err("reverse speed reference is outside the single-direction model")
  }
  let p = self.params
  let t = self.tuning
  let e = self.electrical
  let m = self.mechanical
  let iq_ref = self.speed.step(omega_ref, m.omega_m())
  let vd_pi = self.d_pi.step(-e.id())
  let vq_pi = self.q_pi.step(iq_ref - e.iq())
  let emf = @controller.back_emf_voltage(m.omega_e(), p.magnet_flux)
  let (vd, vq) = @controller.apply_feedforward(vd_pi, vq_pi, 0.0, emf, t.vdc)
  e.set_speed(m.omega_m())
  e.step(vd, vq, t.dt)
  let torque = @motor.electromagnetic_torque(
    e.id(),
    e.iq(),
    p.ld,
    p.lq,
    p.magnet_flux,
    p.pole_pairs,
  )
  m.step(torque, load_torque, t.dt)
  Ok({ omega_m: m.omega_m(), id: e.id(), iq: e.iq(), iq_ref, vd, vq, torque, })
}
