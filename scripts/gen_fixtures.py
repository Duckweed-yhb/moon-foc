#!/usr/bin/env python3
"""生成 moon-foc 的 20 组独立基准（fixtures）。

期望值全部由本脚本按教材公式独立计算，不读取、不导入 MoonBit 库的任何输出。
每个 fixture 覆盖：Clarke(ia,ib,ic) -> (alpha,beta)，Park -> (d,q)，SVPWM -> (da,db,dc)。

输出为两段可直接粘进 coord_test.mbt / svpwm_test.mbt 的 MoonBit 代码。
注意：本机沙箱不允许脚本写 03-竞赛 下的文件，所以这里只打印、不落盘。
"""

import math
import sys

TS = 1e-4
VDC = 24.0


def sector_of(alpha, beta):
    theta = math.atan2(beta, alpha)
    if theta < 0:
        theta += 2 * math.pi
    s = int(math.floor(theta / (math.pi / 3))) + 1
    return min(s, 6)


def action_times(alpha, beta, sector, ts, vdc):
    vref = math.hypot(alpha, beta)
    if vdc <= 0 or ts <= 0 or vref <= 1e-12:
        return 0.0, 0.0
    theta = math.atan2(beta, alpha)
    if theta < 0:
        theta += 2 * math.pi
    local = theta - (sector - 1) * math.pi / 3
    k = math.sqrt(3.0) * ts / vdc
    t1 = k * vref * math.sin(math.pi / 3 - local)
    t2 = k * vref * math.sin(local)
    total = t1 + t2
    if total > ts and total > 0:
        scale = ts / total
        return t1 * scale, t2 * scale
    return t1, t2


def duties(alpha, beta, ts, vdc):
    sector = sector_of(alpha, beta)
    t1, t2 = action_times(alpha, beta, sector, ts, vdc)
    t0 = ts - t1 - t2
    if sector == 1:
        ta, tb, tc = t0 / 2 + t1 + t2, t0 / 2 + t2, t0 / 2
    elif sector == 2:
        ta, tb, tc = t0 / 2 + t1, t0 / 2 + t1 + t2, t0 / 2
    elif sector == 3:
        ta, tb, tc = t0 / 2, t0 / 2 + t1 + t2, t0 / 2 + t2
    elif sector == 4:
        ta, tb, tc = t0 / 2, t0 / 2 + t1, t0 / 2 + t1 + t2
    elif sector == 5:
        ta, tb, tc = t0 / 2 + t2, t0 / 2, t0 / 2 + t1 + t2
    else:
        ta, tb, tc = t0 / 2 + t1 + t2, t0 / 2, t0 / 2 + t1
    return 2 * ta / ts - 1, 2 * tb / ts - 1, 2 * tc / ts - 1


def cases():
    out = []
    for k in range(20):
        phi = 2 * math.pi * k / 20
        theta = math.pi * k / 20
        amp = [1.0, 5.0, 10.0, 20.0][k % 4]
        ia = amp * math.cos(phi)
        ib = amp * math.cos(phi - 2 * math.pi / 3)
        ic = amp * math.cos(phi + 2 * math.pi / 3)
        alpha = (2.0 / 3.0) * (ia - ib / 2 - ic / 2)
        beta = (1.0 / math.sqrt(3.0)) * (ib - ic)
        d = alpha * math.cos(theta) + beta * math.sin(theta)
        q = -alpha * math.sin(theta) + beta * math.cos(theta)
        da, db, dc = duties(alpha, beta, TS, VDC)
        out.append(dict(ia=ia, ib=ib, ic=ic, alpha=alpha, beta=beta,
                        theta=theta, d=d, q=q, da=da, db=db, dc=dc))
    return out


def num(x):
    return repr(float(x))


def coord_block(cs):
    ins = ", ".join("(%s, %s, %s, %s)" % (
        num(c["ia"]), num(c["ib"]), num(c["ic"]), num(c["theta"])) for c in cs)
    exp = ", ".join("(%s, %s, %s, %s)" % (
        num(c["alpha"]), num(c["beta"]), num(c["d"]), num(c["q"])) for c in cs)
    return (
        '// 20 组独立基准：由 scripts/gen_fixtures.py 按教材公式计算（Python 独立实现，\n'
        '// 不读取本库输出）。电流幅值 1/5/10/20 A 轮换，覆盖线性区与过调制输入。\n'
        'test "fixtures: 20 independent coord cases" {\n'
        "  let inputs : Array[(Double, Double, Double, Double)] = [%s]\n"
        "  let expected : Array[(Double, Double, Double, Double)] = [%s]\n"
        "  for i in 0..<20 {\n"
        "    let (ia, ib, ic, theta) = inputs[i]\n"
        "    let (ea, eb, ed, eq) = expected[i]\n"
        "    let (alpha, beta) = @coord.clarke(ia, ib, ic)\n"
        "    assert_true(approx_equal(alpha, ea, eps))\n"
        "    assert_true(approx_equal(beta, eb, eps))\n"
        "    let (d, q) = @coord.park(alpha, beta, theta)\n"
        "    assert_true(approx_equal(d, ed, eps))\n"
        "    assert_true(approx_equal(q, eq, eps))\n"
        "  }\n"
        "}" % (ins, exp)
    )


def svpwm_block(cs):
    ins = ", ".join("(%s, %s)" % (num(c["alpha"]), num(c["beta"])) for c in cs)
    exp = ", ".join("(%s, %s, %s)" % (
        num(c["da"]), num(c["db"]), num(c["dc"])) for c in cs)
    return (
        '// 与 coord 同一组 20 个基准点：duties 的期望值同样由 Python 独立算出，\n'
        '// 其中幅值 20 A 的两组进入过调制区，用于锁定 T1+T2=Ts 的缩放行为。\n'
        'test "fixtures: 20 independent svpwm cases" {\n'
        "  let inputs : Array[(Double, Double)] = [%s]\n"
        "  let expected : Array[(Double, Double, Double)] = [%s]\n"
        "  for i in 0..<20 {\n"
        "    let (alpha, beta) = inputs[i]\n"
        "    let (eda, edb, edc) = expected[i]\n"
        "    let (da, db, dc) = @svpwm.duties(alpha, beta, %s, %s)\n"
        "    assert_true(approx_equal(da, eda, eps))\n"
        "    assert_true(approx_equal(db, edb, eps))\n"
        "    assert_true(approx_equal(dc, edc, eps))\n"
        "  }\n"
        "}" % (ins, exp, num(TS), num(VDC))
    )


def main():
    cs = cases()
    print(coord_block(cs))
    print("@@@SPLIT@@@")
    print(svpwm_block(cs))
    vmax = max(math.hypot(c["alpha"], c["beta"]) for c in cs)
    print("@@@META@@@ max|Vref|=%.4f linear_limit=%.4f" % (vmax, VDC / math.sqrt(3)))


if __name__ == "__main__":
    sys.exit(main())
