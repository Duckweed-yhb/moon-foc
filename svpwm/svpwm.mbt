/// SVPWM 扇区判断。
///
/// 输入 alpha/beta 参考矢量（幅值不变约定），输出扇区号 1-6。
/// 用经典的 N 位标志法：
///   Vref1 = beta
///   Vref2 = (sqrt(3)/2)*alpha - beta/2
///   Vref3 = -(sqrt(3)/2)*alpha - beta/2
///   N = (Vref1>0) + 2*(Vref2>0) + 4*(Vref3>0)
/// N 到扇区的映射：3→1, 1→2, 5→3, 4→4, 6→5, 2→6
pub fn sector_of(alpha : Double, beta : Double) -> Int {
  let sqrt3_half = 3.0.sqrt() / 2.0
  let v1 = beta
  let v2 = sqrt3_half * alpha - beta / 2.0
  let v3 = -sqrt3_half * alpha - beta / 2.0
  let bit1 = if v1 > 0.0 { 1 } else { 0 }
  let bit2 = if v2 > 0.0 { 2 } else { 0 }
  let bit3 = if v3 > 0.0 { 4 } else { 0 }
  let n = bit1 + bit2 + bit3
  match n {
    3 => 1
    1 => 2
    5 => 3
    4 => 4
    6 => 5
    2 => 6
    _ => 1 // Vref=0 时返回默认扇区，调用方应先判零
  }
}
