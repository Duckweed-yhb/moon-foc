///|
/// 波形报告：把一个开关周期的七段式序列画成 ASCII 时序图。
///
/// 这个示例存在的理由很直接——库的价值在「三相桥臂什么时候开、开多久」，
/// 而这个东西用数字表看不出来。一屏 ASCII 图能让任何人在 10 秒内看懂
/// 三件事：扇区对不对、七段式是否对称、三相是不是互补。
///
/// 运行：`moon run examples/waveform --target native`
/// 可选参数式接口：`build_report(alpha, beta, ts, vdc)`，便于嵌到别的工具里。
fn state_bit(state : Int32, phase : Int32) -> Bool {
  // 状态字节按 a b c 从高到低：0x04 = a 通，0x02 = b 通，0x01 = c 通。
  let mask = match phase {
    0 => 0x04
    1 => 0x02
    _ => 0x01
  }
  (state & mask) != 0
}

///|
/// 画一相的高电平时间线：`#` 为导通，`.` 为关断，宽度按时长比例分配。
fn timeline_of(
  seq : Array[(Int32, Double)],
  ts : Double,
  phase : Int32,
  columns : Int32,
) -> String {
  let mut out = ""
  for seg in seq {
    let (state, dur) = seg
    let scaled = dur / ts * columns.to_double() + 0.5
    let mut w = scaled.to_int()
    if w < 0 {
      w = 0
    }
    let ch = if state_bit(state, phase) { "#" } else { "." }
    let mut i = 0
    while i < w {
      out = out + ch
      i = i + 1
    }
  }
  out
}

///|
/// 生成一段可读报告：扇区、占空比、七段式序列与时序图。
pub fn build_report(
  alpha : Double,
  beta : Double,
  ts : Double,
  vdc : Double,
  label : String,
) -> Unit {
  let seq = @svpwm.switching_sequence_of(alpha, beta, ts, vdc)
  let (da, db, dc) = @svpwm.duties(alpha, beta, ts, vdc)
  println("")
  println("=== " + label + " ===")
  println(
    "|Vref| = " +
    (alpha * alpha + beta * beta).sqrt().to_string() +
    " V,  m = " +
    @svpwm.modulation_index(alpha, beta, vdc).to_string() +
    ",  sector = " +
    @svpwm.sector_of(alpha, beta).to_string(),
  )
  println(
    "duties  a=" +
    da.to_string() +
    "  b=" +
    db.to_string() +
    "  c=" +
    dc.to_string(),
  )
  if seq.length() == 0 {
    println("(非法输入：序列为空)")
    return
  }
  let mut seq_line = ""
  for seg in seq {
    let (state, dur) = seg
    seq_line = seq_line + "[" + state.to_string() + " " + dur.to_string() + "]"
  }
  println("seq     " + seq_line)
  let cols = 60
  println("a  |" + timeline_of(seq, ts, 0, cols) + "|")
  println("b  |" + timeline_of(seq, ts, 1, cols) + "|")
  println("c  |" + timeline_of(seq, ts, 2, cols) + "|")
}

///|
fn main {
  let ts = 0.0001 // 10 kHz
  let vdc = 24.0 // 24 V 母线
  // 线性区：m = 0.8
  build_report(
    0.8 * vdc / 3.0.sqrt() * 0.8660254037844387,
    0.8 * vdc / 3.0.sqrt() * 0.5,
    ts,
    vdc,
    "线性区 m=0.8, theta=30deg",
  )
  // 过调制：m = 1.5（比例钳位，方向不变、幅值贴六边形）
  build_report(
    1.5 * vdc / 3.0.sqrt() * 0.8660254037844387,
    1.5 * vdc / 3.0.sqrt() * 0.5,
    ts,
    vdc,
    "过调制 m=1.5, theta=30deg",
  )
  // 零矢量：应当整周期不翻转
  build_report(0.0, 0.0, ts, vdc, "零矢量")
}
