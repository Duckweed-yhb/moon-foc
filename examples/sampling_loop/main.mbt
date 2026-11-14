/// examples/sampling_loop — 两相采样接进闭环，与三相真值对照。
///
/// 同一台电机、同一组整定增益、同一条 iq 给定，跑两遍：A 用三相真值电流，
/// B 只采两相、按上一拍占空比挑一对可用的采样相、第三相由 `ic = -ia - ib`
/// 重构。两条轨迹在同一时间基上逐步对比，最后给出 q 轴电流的最大偏差、采样
/// 相切换次数，以及有没有哪一拍三相都不满足窗口。
///
/// 这里故意不做「电流环 + 采样时刻」的模拟：采样相的选择用的是上一拍算出的
/// 占空比，和真实控制器「先出波、下一拍再采」的时序一致；但 ADC 建立过程、
/// 开关噪声都不在模型内，读数只说明重构没有把电流环带偏。

///|
/// 按相号取出一对采样值。相序固定为 a=0、b=1、c=2。
fn measured_for_pair(
  pair : (Int32, Int32),
  ia : Double,
  ib : Double,
  ic : Double,
) -> (Double, Double) {
  let (p, q) = pair
  let v1 = if p == 0 { ia } else if p == 1 { ib } else { ic }
  let v2 = if q == 0 { ia } else if q == 1 { ib } else { ic }
  (v1, v2)
}

///|
fn main {
  let r = 0.5
  let l = 0.002
  let ts = 50.0e-6
  let vdc = 48.0
  let bandwidth = 800.0
  let iq_ref = 2.0
  let min_window = 1.5e-6
  let steps = 4000

  let gains = @controller.design_current_loop(r, l, bandwidth)
  let v_max = vdc * 0.9

  // A：三相真值进控制器。
  let model_a = @motor.PmsmModel::new(r, l, l, 0.02, 4, 0.0)
  let ctl_a = @controller.FocController::new(
    gains.kp(),
    gains.ki(),
    gains.kp(),
    gains.ki(),
    ts,
    vdc,
    -v_max,
    v_max,
  )

  // B：只采两相，第三相重构，采样相按上一拍占空比挑。
  let model_b = @motor.PmsmModel::new(r, l, l, 0.02, 4, 0.0)
  let ctl_b = @controller.FocController::new(
    gains.kp(),
    gains.ki(),
    gains.kp(),
    gains.ki(),
    ts,
    vdc,
    -v_max,
    v_max,
  )
  let mut pair : (Int32, Int32) = (0, 1)
  let mut switches = 0
  let mut drops = 0

  println("== 两相采样闭环 ==")
  println(
    "R = " +
    r.to_string() +
    " ohm, L = " +
    l.to_string() +
    " H, Ts = " +
    ts.to_string() +
    " s",
  )
  println("Kp = " + gains.kp().to_string() + ", Ki = " + gains.ki().to_string())
  println(
    "iq 给定 = " +
    iq_ref.to_string() +
    " A，最小采样窗口 = " +
    min_window.to_string() +
    " s",
  )
  println("")

  let mut max_diff = 0.0
  let mut i = 0
  while i < steps {
    // A：三相真值。
    let (ia, ib, ic) = model_a.phase_currents()
    let (_, _, vd_a, vq_a, _, _, _) = ctl_a.step(
      ia,
      ib,
      ic,
      model_a.theta_e(),
      0.0,
      iq_ref,
    )
    model_a.step(vd_a, vq_a, ts)

    // B：两相实测 + 第三相重构，采样相沿用上一拍挑出来的那一对。
    let (ja, jb, jc) = model_b.phase_currents()
    let (m1, m2) = measured_for_pair(pair, ja, jb, jc)
    let (_, _, vd_b, vq_b, da, db, dc) = ctl_b.step_from_pair(
      pair,
      m1,
      m2,
      model_b.theta_e(),
      0.0,
      iq_ref,
    )
    model_b.step(vd_b, vq_b, ts)

    // 下一拍该采哪两相，由这一拍的占空比决定。
    let next = @controller.pick_sample_pair((da, db, dc), ts, min_window)
    if next.length() == 0 {
      drops += 1
    } else {
      let candidate = next[0]
      if candidate != pair {
        switches += 1
        pair = candidate
      }
    }

    let diff = (model_a.iq() - model_b.iq()).abs()
    if diff > max_diff {
      max_diff = diff
    }
    if i == 399 || i == 1999 || i == 3999 {
      println(
        "t = " +
        ((i + 1).to_double() * ts).to_string() +
        " s: iq(三相) = " +
        model_a.iq().to_string() +
        "，iq(两相) = " +
        model_b.iq().to_string() +
        "，采样相 = (" +
        pair.0.to_string() +
        ", " +
        pair.1.to_string() +
        ")",
      )
    }
    i += 1
  }

  println("")
  println(
    "全段 |iq(三相) − iq(两相)| 最大值 = " + max_diff.to_string(),
  )
  println("稳态误差(两相) = " + (model_b.iq() - iq_ref).abs().to_string())
  println("采样相切换次数 = " + switches.to_string())
  println("三相都不满足窗口的拍数 = " + drops.to_string())
  println(
    "最终采样相 = (" + pair.0.to_string() + ", " + pair.1.to_string() + ")",
  )

  // C：a 相传感器带 0.02 A 偏置。
  //
  // 两路传感器下这件事查不出来：第三相是重构出来的，三相和恒为零，
  // `zero_sequence_residual` 对自己的重构结果只会读出 0。能看见偏置的只有
  // 闭环结果 - q 轴稳态电流被拉偏。若硬件另有一路真值（三传感器），残差
  // 才会等于偏置，这里把两种情况都打出来。
  let bias = 0.02
  let model_c = @motor.PmsmModel::new(r, l, l, 0.02, 4, 0.0)
  let ctl_c = @controller.FocController::new(
    gains.kp(),
    gains.ki(),
    gains.kp(),
    gains.ki(),
    ts,
    vdc,
    -v_max,
    v_max,
  )
  let mut j = 0
  let mut residual_two = 0.0
  let mut residual_three = 0.0
  while j < steps {
    let (ca, cb, cc) = model_c.phase_currents()
    let (measured_a, measured_b) = (ca + bias, cb)
    let (_, _, vd_c, vq_c, _, _, _) = ctl_c.step_from_pair(
      (0, 1),
      measured_a,
      measured_b,
      model_c.theta_e(),
      0.0,
      iq_ref,
    )
    model_c.step(vd_c, vq_c, ts)
    residual_two = @controller.zero_sequence_residual(
      measured_a,
      measured_b,
      @controller.reconstruct_third(measured_a, measured_b),
    )
    // 假设还有一路未经偏置的 c 相：残差等于偏置本身。
    residual_three = @controller.zero_sequence_residual(
      measured_a, measured_b, cc,
    )
    j += 1
  }
  println("")
  println(
    "偏置 0.02 A（a 相），只采两相：残差 = " +
    residual_two.to_string(),
  )
  println(
    "偏置 0.02 A（a 相），另有一路真值 c 相：残差 = " +
    residual_three.to_string(),
  )
  println("偏置下 iq = " + model_c.iq().to_string())
  println(
    "偏置下 |iq − 给定| = " + (model_c.iq() - iq_ref).abs().to_string(),
  )
}
