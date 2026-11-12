/// SVPWM 扇区判断与作用时间计算。
///
/// 标准七段式 SVPWM。输入 alpha/beta 参考矢量（幅值不变约定），
/// 输出扇区号 (1-6)、相邻基本矢量作用时间 T1/T2、零矢量时间 T0。
/// Ts 为开关周期（秒），Vdc 为母线电压（伏特）。
///
/// 过调制：当 T1+T2 > Ts 时按比例缩放，使 T1+T2=Ts。

///|
/// 根据 alpha/beta 判断扇区（1-6）。
///
/// 直接用 atan2 算电角度 theta_e ∈ [0, 2pi)，再按 pi/3 分扇区。
/// 扇区 1 = [0, pi/3)，扇区 2 = [pi/3, 2pi/3)，...，扇区 6 = [5pi/3, 2pi)。
pub fn sector_of(alpha : Double, beta : Double) -> Int32 {
  let theta = @math.atan2(beta, alpha)
  let theta_pos = if theta < 0.0 {
    theta + 3.141592653589793 * 2.0
  } else {
    theta
  }
  let sector = (theta_pos / (3.141592653589793 / 3.0)).floor().to_int() + 1
  if sector > 6 {
    return 6
  }
  sector
}

///|
/// 计算相邻矢量作用时间 T1/T2（与 Ts 同单位）。
///
/// 返回 (T1, T2)。线性区按 sin 分解；当 T1+T2 > Ts 时按比例缩放使 T1+T2=Ts。
pub fn action_times(
  alpha : Double,
  beta : Double,
  sector : Int32,
  ts : Double,
  vdc : Double,
) -> (Double, Double) {
  // 扇区只接受 1..6。传 0 或 7 时旧实现照样往下算：sector_start 变成 −π/3 或 2π，
  // 局部角落到 [0, π/3) 之外，T1/T2 会出现负值——控制环拿到负作用时间不会报错，
  // 只会静默输出错的占空比。这里直接返回零作用时间（等价于零矢量），
  // 需要区分「零矢量」与「参数非法」时用 sector_of 自行校验。
  if sector < 1 || sector > 6 {
    return (0.0, 0.0)
  }
  if vdc <= 0.0 || ts <= 0.0 {
    return (0.0, 0.0)
  }
  // 非有限输入：下面全是浮点运算，NaN 会一路穿到 T1/T2 并变成占空比。
  // 控制环拿到 NaN 占空比不会报错，只会在比较寄存器那头出怪事。
  if !finite(alpha) || !finite(beta) {
    return (0.0, 0.0)
  }
  let vref = (alpha * alpha + beta * beta).sqrt()
  if vref <= 0.000000000001 {
    return (0.0, 0.0)
  }
  // theta_e 先归一到 [0, 2pi)，再减扇区起点，得到扇区内局部角 [0, pi/3)；
  // 直接用带符号 atan2 会让下半平面扇区（5/6）折出负的作用时间。
  let theta_raw = @math.atan2(beta, alpha)
  let theta_pos = if theta_raw < 0.0 {
    theta_raw + 3.141592653589793 * 2.0
  } else {
    theta_raw
  }
  let sector_d = sector.to_double()
  let sector_start = (sector_d - 1.0) * 3.141592653589793 / 3.0
  let local_norm = theta_pos - sector_start
  // T1/T2 公式（幅值不变约定，系数 sqrt(3)）
  let k = 3.0.sqrt() * ts / vdc
  let t1 = k * vref * @math.sin(3.141592653589793 / 3.0 - local_norm)
  let t2 = k * vref * @math.sin(local_norm)
  // 过调制：按比例缩
  let sum = t1 + t2
  if sum > ts && sum > 0.0 {
    let scale = ts / sum
    return (t1 * scale, t2 * scale)
  }
  (t1, t2)
}

///|
/// 扇区 + T1/T2 → 三相占空比 (da, db, dc) ∈ [-1, 1]。
///
/// 七段式对称发波：零矢量在两端和中点平分 T0。
pub fn duties(
  alpha : Double,
  beta : Double,
  ts : Double,
  vdc : Double,
) -> (Double, Double, Double) {
  // 退化输入不返回 NaN：ts<=0 会让最后的除法变成 inf/NaN，控制环拿到 NaN
  // 之后故障点离源头很远。要区分「算出来就是 0」和「输入不合法」，用
  // duties_checked。
  if ts <= 0.0 || vdc <= 0.0 {
    return (0.0, 0.0, 0.0)
  }
  // 与 action_times 同一口径：非有限输入返回零矢量，不产出 NaN 占空比。
  if !finite(alpha) || !finite(beta) {
    return (0.0, 0.0, 0.0)
  }
  let sector = sector_of(alpha, beta)
  let (t1, t2) = action_times(alpha, beta, sector, ts, vdc)
  let t0 = ts - t1 - t2
  // 各相在一个开关周期内的高电平时间（秒），按扇区映射
  let (ta, tb, tc) = match sector {
    1 => (t0 / 2.0 + t1 + t2, t0 / 2.0 + t2, t0 / 2.0)
    2 => (t0 / 2.0 + t1, t0 / 2.0 + t1 + t2, t0 / 2.0)
    3 => (t0 / 2.0, t0 / 2.0 + t1 + t2, t0 / 2.0 + t2)
    4 => (t0 / 2.0, t0 / 2.0 + t1, t0 / 2.0 + t1 + t2)
    5 => (t0 / 2.0 + t2, t0 / 2.0, t0 / 2.0 + t1 + t2)
    _ => (t0 / 2.0 + t1 + t2, t0 / 2.0, t0 / 2.0 + t1) // sector 6
  }
  // 占空比 = 2*T_on/Ts - 1，范围 [-1, 1]
  let da = 2.0 * ta / ts - 1.0
  let db = 2.0 * tb / ts - 1.0
  let dc = 2.0 * tc / ts - 1.0
  // 最终守卫：入口的 finite 只看得见原始输入，中间量却可能先溢出
  // （alpha² 在 |alpha| > 1.34e154 时已经是 Inf，再乘 0 就变 NaN；
  // vdc 极小时 k = √3·ts/vdc 也会溢出）。README 承诺「不返回 NaN」，这里兜底。
  if !finite(da) || !finite(db) || !finite(dc) {
    return (0.0, 0.0, 0.0)
  }
  (da, db, dc)
}

///|
/// 单值是否为可用于计算的有限数（NaN 与 ±Inf 都返回 false）。
///
/// 不用标准库的 is_nan / is_inf：IEEE 754 的 `x != x` 与量级判断在任何
/// 后端都是同一语义，跨 wasm-gc / js / native 不会因运行时差异而不同。
fn finite(x : Double) -> Bool {
  if x != x {
    return false // NaN
  }
  if x.abs() > 1.0e308 {
    return false // ±Inf
  }
  true
}

///|
/// 校验一组计算输入：alpha / beta / ts / vdc 必须全部有限，且 ts>0、vdc>0。
///
/// 控制环里出现 NaN 最怕的是「静默往下传」：占空比变成 NaN 之后，PWM 比较
/// 寄存器写入什么取决于下游实现，故障点离源头很远。这里在入口挡住。
pub fn check_inputs(
  alpha : Double,
  beta : Double,
  ts : Double,
  vdc : Double,
) -> Result[Unit, String] {
  if !finite(alpha) || !finite(beta) {
    return Err("reference vector is not finite")
  }
  if !finite(ts) || ts <= 0.0 {
    return Err("switch period must be finite and > 0")
  }
  if !finite(vdc) || vdc <= 0.0 {
    return Err("dc bus voltage must be finite and > 0")
  }
  Ok(())
}

///|
/// 带校验的占空比计算：输入不合法时返回结构化错误，而不是 NaN。
///
/// `duties` 保持原签名（[0,1] 之外由下游兜底）；需要区分「算出来是 0」和
/// 「输入不合法」的调用方用这个。
pub fn duties_checked(
  alpha : Double,
  beta : Double,
  ts : Double,
  vdc : Double,
) -> Result[(Double, Double, Double), String] {
  match check_inputs(alpha, beta, ts, vdc) {
    Err(e) => Err(e)
    Ok(_) => Ok(duties(alpha, beta, ts, vdc))
  }
}

///|
/// 调制比 m = |Vref| / (Vdc/√3)：线性区边界处 m = 1，m > 1 即进入过调制区。
///
/// 与 `action_times` 里的钳位配套使用：钳位只保证 T1+T2=Ts，不告诉调用方
/// 「已经削顶了」。需要报警或降额时用这个判断，别去反推 T1/T2。
pub fn modulation_index(alpha : Double, beta : Double, vdc : Double) -> Double {
  // 非有限输入或非正母线电压：返回 0 而不是 NaN。NaN 一路传到比较里
  // 只会得到 false（"没进过调制"），比显式的 0 更难查。
  // 需要区分「调制比为 0」与「输入非法」时先用 check_inputs。
  if !finite(alpha) || !finite(beta) || !finite(vdc) || vdc <= 0.0 {
    return 0.0
  }
  let vref = (alpha * alpha + beta * beta).sqrt()
  vref / (vdc / 3.0.sqrt())
}

///|
/// 参考矢量是否已进入过调制区（m > 1）。
///
/// 只看幅值，与扇区无关：六边形内切圆半径就是 Vdc/√3，超过即削顶。
pub fn is_overmodulated(alpha : Double, beta : Double, vdc : Double) -> Bool {
  modulation_index(alpha, beta, vdc) > 1.0
}

///|
/// 占空比 → 相电压（伏特，相对直流母线中点）。占空比以 0 为中心，
/// 因此 `v = duty · Vdc / 2`。
///
/// 供观测器、反电势估算这类下游环节使用：它们要的是电压，不是占空比。
pub fn phase_voltages(
  da : Double,
  db : Double,
  dc : Double,
  vdc : Double,
) -> (Double, Double, Double) {
  // 母线电压非正时相电压没有物理意义（负电压会被下游当成真的），
  // 与 duties 的退化输入约定保持一致：一律返回 0。
  if !finite(vdc) || vdc <= 0.0 {
    return (0.0, 0.0, 0.0)
  }
  let half = vdc / 2.0
  (da * half, db * half, dc * half)
}

///|
/// 占空比 → 线电压 (vab, vbc, vca)，单位伏特。
///
/// 三相对称时三者之和恒为 0（等于零序分量的一次差分），这条恒等式是
/// 相电压到线电压换算的正确性判据，测试里用它做断言。
pub fn line_voltages(
  da : Double,
  db : Double,
  dc : Double,
  vdc : Double,
) -> (Double, Double, Double) {
  let (va, vb, vc) = phase_voltages(da, db, dc, vdc)
  (va - vb, vb - vc, vc - va)
}

///|
/// 载波法 SVPWM：三相参考电压 → 占空比（零序注入取 (vmax+vmin)/2）。
///
/// 与 `duties(alpha, beta, ts, vdc)` 是同一件事的两条路径：七段式 SVPWM 的
/// 波形等于「正弦调制 + 中点平移」。一致性由测试锁住，任一路径改动后
/// 另一条会立刻暴露差异——这比拿一张手算表核对更可靠。
///
/// 前提：`va/vb/vc` 必须是有限值。NaN 输入会原样穿过钳位（NaN 的比较恒为
/// false），需要入口校验时先用 `check_inputs`。
pub fn duties_from_voltages(
  va : Double,
  vb : Double,
  vc : Double,
  vdc : Double,
) -> (Double, Double, Double) {
  if vdc <= 0.0 {
    return (0.0, 0.0, 0.0)
  }
  let mut vmax = va
  let mut vmin = va
  if vb > vmax {
    vmax = vb
  }
  if vc > vmax {
    vmax = vc
  }
  if vb < vmin {
    vmin = vb
  }
  if vc < vmin {
    vmin = vc
  }
  // 零序注入：把三相参考的中点移到母线电压中点。
  let offset = -(vmax + vmin) / 2.0
  let half = vdc / 2.0
  // 载波法在 m > 1 时占空比会越过 ±1，这里饱和而不是外推：
  // 下游拿到越界占空比只会写进比较寄存器，故障点离这里太远。
  let da = clamp_duty((va + offset) / half)
  let db = clamp_duty((vb + offset) / half)
  let dc = clamp_duty((vc + offset) / half)
  // vdc 极小（如 5e-324）时 half 下溢、除法溢出成 Inf，NaN 也会穿过钳位
  // （`NaN > 1` 恒 false）。最终守卫保证不返回 NaN，与 duties 同口径。
  if !finite(da) || !finite(db) || !finite(dc) {
    return (0.0, 0.0, 0.0)
  }
  (da, db, dc)
}

///|
/// 死区补偿：按电流方向修正占空比。
///
/// 互补 PWM 的死区会让实际输出电压向电流方向「少」，按占空比域补偿量为
/// `sign(i_p) · 2·td/ts`（推导见实现处；本包的 d ↔ d·Vdc/2 相电压）。
/// 返回补偿后的占空比，并钳位到 [-1, 1]。
///
/// 约定：`td` 与 `ts` 同单位（秒），`td/ts` 应远小于 1；`ts <= 0` 时原样返回。
/// `ia/ib/ic` 用 A（符号即可），零电流不补偿。
pub fn dead_time_compensation(
  da : Double,
  db : Double,
  dc : Double,
  ia : Double,
  ib : Double,
  ic : Double,
  td : Double,
  ts : Double,
) -> (Double, Double, Double) {
  // 无死区 / 非法周期：原样返回，但仍然钳位——调用方不该因为「这次没补偿」
  // 就拿到越界占空比。NaN 一并挡掉：`NaN <= 0` 恒 false，会穿过去变成 NaN 输出。
  if ts != ts || td != td || ts <= 0.0 || td <= 0.0 {
    return (clamp_duty(da), clamp_duty(db), clamp_duty(dc))
  }
  // 量纲：本包的占空比域是 d ↔ d·Vdc/2 的相电压（见 phase_voltages）。
  // 死区让每相每周期的伏秒损失 Td·Vdc，平均电压误差 = (Td/Ts)·Vdc，
  // 换回占空比域要乘 2/Vdc，即 Δd = 2·Td/Ts。以前写成 Td/Ts，只补了一半
  // ——而且测试把这个 0.005 一起写进了期望值，等于把错误锁住。
  let delta = 2.0 * td / ts
  (
    clamp_duty(da + sign_of(ia) * delta),
    clamp_duty(db + sign_of(ib) * delta),
    clamp_duty(dc + sign_of(ic) * delta),
  )
}

///|
/// 电流符号：正 1 / 负 −1 / 零 0。
fn sign_of(i : Double) -> Double {
  if i > 0.0 {
    1.0
  } else if i < 0.0 {
    -1.0
  } else {
    0.0
  }
}

///|
/// 占空比钳位到 [-1, 1]。
fn clamp_duty(d : Double) -> Double {
  if d > 1.0 {
    1.0
  } else if d < -1.0 {
    -1.0
  } else {
    d
  }
}

///|
/// 七段式开关序列：一个开关周期内按时间排好的 (开关状态, 持续时间)。
///
/// 开关状态是 3 位编码（bit2=a 相上桥、bit1=b、bit0=c，1 = 上桥导通）：
/// 000 零矢量、111 七矢量、100/110/010/011/001/101 是六个基本矢量。
///
/// 序列（对称七段式）：0 → Vk → Vk+1 → 7 → Vk+1 → Vk → 0，
/// 时间依次为 t0/4、t1/2、t2/2、t0/2、t2/2、t1/2、t0/4，其中 t0 = ts−t1−t2。
///
/// 这是 `duties` 的另一半：占空比告诉 MCU「每相导通用多少时间」，这个函数
/// 告诉它「按什么顺序切」。两者必须自洽——测试里用「各相高电平时间之和
/// 等于占空比」把两条路径钉在一起。
///
/// 扇区非法或 t1+t2 > ts 时返回空数组（调用方应先用 `action_times`）。
///
/// 每项是 tuple（MoonBit 的 tuple 不能直接当返回类型别名），返回
/// `Array[(Int32, Double)]`：(state, duration)，duration 与 `ts` 同单位。
pub fn switching_sequence(
  sector : Int32,
  t1 : Double,
  t2 : Double,
  ts : Double,
) -> Array[(Int32, Double)] {
  let out : Array[(Int32, Double)] = []
  if sector < 1 || sector > 6 || ts <= 0.0 {
    return out
  }
  // 扇区边界上 sin 的浮点残差会让 t1/t2 出现 −1e−17 量级的负数；
  // 夹到 0 再判总时长，别把正常输入当非法。
  //
  // 容差必须是相对的：比例钳位后 t1+t2 = ts·(1±1e-16)，绝对容差 1e-18 在
  // ts 较大（0.01 s 以上）时会把合法的过调制输入判成非法、返回空数组。
  // NaN 也要挡：`NaN < 0` 与 `NaN > x` 都是 false，会一路穿过判据被当成
  // 「零时长段」丢掉，最后返回一个段数合理、总时长等于 Ts 的假序列。
  if t1 != t1 || t2 != t2 {
    return out
  }
  let t1c = if t1 < 0.0 { 0.0 } else { t1 }
  let t2c = if t2 < 0.0 { 0.0 } else { t2 }
  if t1c + t2c > ts * (1.0 + 1.0e-12) {
    return out
  }
  // 六个基本矢量的三相开关状态（a b c）。
  let states = [0x04, 0x06, 0x02, 0x03, 0x01, 0x05]
  let k = sector - 1
  let vk = states[k]
  let vk1 = states[(k + 1) % 6]
  let t0 = ts - t1c - t2c
  let quarter = t0 / 4.0
  let raw : Array[(Int32, Double)] = [
    (0x00, quarter),
    (vk, t1c / 2.0),
    (vk1, t2c / 2.0),
    (0x07, t0 / 2.0),
    (vk1, t2c / 2.0),
    (vk, t1c / 2.0),
    (0x00, quarter),
  ]
  // 丢掉零时长段：过调制边界（t0=0）或扇区边界（t1/t2=0）时，
  // 七段式会退化。留着零长度段等于让 MCU 去写一个零脉冲——
  // 多数定时器能忍，但没必要，而且让「序列长度」失去意义。
  for item in raw {
    let (state, dur) = item
    if dur > 0.0 {
      out.push((state, dur))
    }
  }
  out
}

///|
/// 从 alpha/beta 直接得到七段式开关序列：内部依次算扇区、作用时间、序列。
///
/// 手工三步（`sector_of` → `action_times` → `switching_sequence`）最容易错在
/// 把扇区传错，或者忘了先做输入校验。这个入口把它们串起来，输入不合法
/// （非有限值、ts/vdc 非正）时返回空数组而不是一个看似正常的序列。
///
/// 行为与手工三步完全一致：内部就是那三个函数。
pub fn switching_sequence_of(
  alpha : Double,
  beta : Double,
  ts : Double,
  vdc : Double,
) -> Array[(Int32, Double)] {
  match check_inputs(alpha, beta, ts, vdc) {
    Err(_) => return []
    Ok(_) => ()
  }
  let sector = sector_of(alpha, beta)
  let (t1, t2) = action_times(alpha, beta, sector, ts, vdc)
  switching_sequence(sector, t1, t2, ts)
}

///|
/// 开关序列里某一相的高电平总时间（秒）。把 `switching_sequence` 与
/// `duties` 对起来用：`on_time(c, ts, seq) == (duty_c + 1) / 2 * ts`。
pub fn on_time_of_phase(seq : Array[(Int32, Double)], phase : Int32) -> Double {
  let shift = match phase {
    0 => 2
    1 => 1
    _ => 0
  }
  let mut sum = 0.0
  for item in seq {
    let (state, dur) = item
    let bit = (state >> shift) & 0x01
    if bit == 0x01 {
      sum = sum + dur
    }
  }
  sum
}
