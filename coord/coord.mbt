/// Coordinate transforms for three-phase FOC.
///
/// Conventions (amplitude-invariant):
///   - Clarke:   alpha = (2/3)*(ia - ib/2 - ic/2)
///                beta  = (1/sqrt(3))*(ib - ic)
///   - invClarke: ia = alpha
///                ib = -alpha/2 + beta*sqrt(3)/2
///                ic = -alpha/2 - beta*sqrt(3)/2
///   - Park:      d =  alpha*cos(theta) + beta*sin(theta)
///                q = -alpha*sin(theta) + beta*cos(theta)
///   - invPark:   alpha = d*cos(theta) - q*sin(theta)
///                beta  = d*sin(theta) + q*cos(theta)
///
/// Angles are in radians. cos/sin are periodic; callers can feed any theta.

/// Three-phase to alpha-beta (Clarke, amplitude-invariant).
pub fn clarke(ia : Double, ib : Double, ic : Double) -> (Double, Double) {
  let alpha = (2.0 / 3.0) * (ia - ib / 2.0 - ic / 2.0)
  let beta = (1.0 / 3.0.sqrt()) * (ib - ic)
  (alpha, beta)
}

/// Alpha-beta back to three-phase (inverse Clarke).
/// With the amplitude-invariant convention, ia+ib+ic == 0 automatically.
pub fn inv_clarke(alpha : Double, beta : Double) -> (Double, Double, Double) {
  let ia = alpha
  let ib = -alpha / 2.0 + beta * (3.0.sqrt() / 2.0)
  let ic = -alpha / 2.0 - beta * (3.0.sqrt() / 2.0)
  (ia, ib, ic)
}

/// Alpha-beta to d-q (Park transform). theta is the electrical angle in radians.
pub fn park(alpha : Double, beta : Double, theta : Double) -> (Double, Double) {
  let c = @math.cos(theta)
  let s = @math.sin(theta)
  let d = alpha * c + beta * s
  let q = -alpha * s + beta * c
  (d, q)
}

/// d-q back to alpha-beta (inverse Park).
pub fn inv_park(d : Double, q : Double, theta : Double) -> (Double, Double) {
  let c = @math.cos(theta)
  let s = @math.sin(theta)
  let alpha = d * c - q * s
  let beta = d * s + q * c
  (alpha, beta)
}
