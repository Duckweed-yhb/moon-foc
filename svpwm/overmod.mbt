// svpwm/overmod.mbt — 过调制的几何边界。
//
// `action_times` 在 T1+T2 > Ts 时按比例缩，比例缩等价于「保持参考矢量方向、
// 把幅值压到六边形边界」：最小相位误差的削顶。要让调用方知道「这一拍到底被
// 削掉多少」，需要的是六边形边界本身，所以这里把边界写成可算的函数。
//
// 六边形顶点在内切圆之外：以 Vdc/√3 为基准（线性区边界 m = 1），扇区轴线处
// 边界等于内切圆半径，扇区边界（顶点方向）处等于 2·Vdc/3，对应 m = 2/√3
// ≈ 1.1547。扇区内任意角度上边界为
//
//   r(φ) = (Vdc/√3) / cos(π/6 − φ)，  φ ∈ [0, π/3]
//
// 只此一层几何，不做模式 II 的相位压缩与保持段——那需要跨基波周期维护角度
// 状态，不在纯函数能表达的范围内，故本包只说明未实现。

///|
/// 未归一化角度 → [0, 2π) 的正角。
fn positive_angle(theta : Double) -> Double {
  let two_pi = 3.141592653589793 * 2.0
  let t = theta
  // 先做一次粗归约，避免大角度时反复加减丢精度：整数圈先整体扣掉。
  let turns = (t / two_pi).floor()
  let reduced = t - turns * two_pi
  if reduced < 0.0 {
    reduced + two_pi
  } else {
    reduced
  }
}

///|
/// 参考矢量方向上六边形边界的幅值（伏特）。
///
/// 返回的是「这一拍能输出的最大矢量长度」：线性区内它大于等于 `|Vref|`，
/// 进过调制区后小于 `|Vref|`，差多少就是被削掉的幅值。
/// 非法输入（非有限、`vdc <= 0`）返回 0，不返回 NaN。
pub fn hexagon_radius(alpha : Double, beta : Double, vdc : Double) -> Double {
  if !finite(alpha) || !finite(beta) || !finite(vdc) || vdc <= 0.0 {
    return 0.0
  }
  // 零矢量方向无定义，边界按内切圆给（扇区轴线处本来就等于内切圆）。
  let vref = (alpha * alpha + beta * beta).sqrt()
  if vref <= 0.000000000001 {
    return vdc / 3.0.sqrt()
  }
  let theta = positive_angle(@math.atan2(beta, alpha))
  let sector_start = (theta / (3.141592653589793 / 3.0)).floor() *
    (3.141592653589793 / 3.0)
  // 扇区内局部角 [0, π/3)，cos(π/6 − φ) 在该区间最小 0.866，不会碰到 0。
  let local_angle = theta - sector_start
  let denom = @math.cos(3.141592653589793 / 6.0 - local_angle)
  if denom <= 0.0 {
    // 理论上到不了这里（|local − π/6| ≤ π/6），留一个不返回 Inf 的出口。
    return vdc / 3.0.sqrt()
  }
  vdc / 3.0.sqrt() / denom
}

///|
/// 把参考矢量压到六边形边界上：方向不变，幅值取 `hexagon_radius`。
///
/// 线性区内原样返回；过调制区返回的是「同一方向上能真的输出」的那个矢量。
/// 与 `action_times` 的比例钳位等价——后者缩的是时间，前者缩的是矢量，两者
/// 落在同一个幅值上。
pub fn project_to_hexagon(
  alpha : Double,
  beta : Double,
  vdc : Double,
) -> (Double, Double) {
  if !finite(alpha) || !finite(beta) || !finite(vdc) || vdc <= 0.0 {
    return (0.0, 0.0)
  }
  let vref = (alpha * alpha + beta * beta).sqrt()
  if vref <= 0.000000000001 {
    return (0.0, 0.0)
  }
  let limit = hexagon_radius(alpha, beta, vdc)
  if limit <= 0.0 || vref <= limit {
    return (alpha, beta)
  }
  let scale = limit / vref
  (alpha * scale, beta * scale)
}

///|
/// 被削掉的幅值比例：`1 − boundary/|Vref|`，线性区内为 0。
///
/// 控制环可以用它在过调制时降额或报警；也可以拿它和 `modulation_index`
/// 对上——m ≤ 1 时这里必然为 0，m > 1 时不一定为 0（矢量可能仍落在顶点附近
/// 的六边形内），这两个量不是一回事。
pub fn clipping_ratio(alpha : Double, beta : Double, vdc : Double) -> Double {
  if !finite(alpha) || !finite(beta) || !finite(vdc) || vdc <= 0.0 {
    return 0.0
  }
  let vref = (alpha * alpha + beta * beta).sqrt()
  if vref <= 0.000000000001 {
    return 0.0
  }
  let limit = hexagon_radius(alpha, beta, vdc)
  if limit >= vref || limit <= 0.0 {
    return 0.0
  }
  1.0 - limit / vref
}
