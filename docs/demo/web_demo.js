function $oob() {
  throw new Error("Index out of bounds");
}
class $PanicError extends Error {}
function $panic(message) {
  throw new $PanicError(message);
}
function _M0TPB13StringBuilder(param0) {
  this.val = param0;
}
function _M0TPC16string10StringView(param0, param1, param2) {
  this.str = param0;
  this.start = param1;
  this.end = param2;
}
const _M0FPB19int__to__string__js = (x, radix) => {
  return x.toString(radix);
};
const _M0MPC16double6Double8mod__ffi = (a, b) => (a % b);
function _M0TP38Duckweed10moon_2dfoc2pi2Pi(param0, param1, param2, param3, param4, param5) {
  this.kp = param0;
  this.ki = param1;
  this.dt = param2;
  this.out_min = param3;
  this.out_max = param4;
  this.integ = param5;
}
function _M0TP38Duckweed10moon_2dfoc10controller9LoopGains(param0, param1) {
  this.kp = param0;
  this.ki = param1;
}
function _M0TP38Duckweed10moon_2dfoc10controller15SpeedController(param0, param1, param2, param3) {
  this.pi = param0;
  this.iq_min = param1;
  this.iq_max = param2;
  this.last = param3;
}
function _M0TPB8MutLocalGdE(param0) {
  this.val = param0;
}
function _M0TPB8MutLocalGiE(param0) {
  this.val = param0;
}
function _M0TP38Duckweed10moon_2dfoc10controller13FocController(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9) {
  this.d_pi = param0;
  this.q_pi = param1;
  this.ts = param2;
  this.vdc = param3;
  this.last_id = param4;
  this.last_iq = param5;
  this.last_alpha = param6;
  this.last_beta = param7;
  this.last_vd = param8;
  this.last_vq = param9;
}
function _M0TP38Duckweed10moon_2dfoc5motor9PmsmModel(param0, param1, param2, param3, param4, param5, param6, param7, param8) {
  this.r = param0;
  this.ld = param1;
  this.lq = param2;
  this.psi_f = param3;
  this.pole_pairs = param4;
  this.id = param5;
  this.iq = param6;
  this.theta_e = param7;
  this.omega_e = param8;
}
function _M0TP38Duckweed10moon_2dfoc5motor15MechanicalModel(param0, param1, param2, param3, param4) {
  this.j = param0;
  this.b = param1;
  this.pole_pairs = param2;
  this.omega_m = param3;
  this.theta_m = param4;
}
function _M0TPB8MutLocalGsE(param0) {
  this.val = param0;
}
function _M0TPB5ArrayGdE(param0, param1) {
  this.buf = param0;
  this.len = param1;
}
const _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger = { method_0: _M0IPB13StringBuilderPB6Logger13write__string, method_1: _M0IP016_24default__implPB6Logger16write__substringGRPB13StringBuilderE, method_2: _M0IPB13StringBuilderPB6Logger11write__view, method_3: _M0IPB13StringBuilderPB6Logger11write__char, method_4: _M0IP016_24default__implPB6Logger28write__string__interpolationGRPB13StringBuilderE, method_5: _M0IP016_24default__implPB6Logger5writeGRPB13StringBuilderE };
const _M0FP38Duckweed10moon_2dfoc5angle7two__pi = 6.2831853071795862;
function _M0MPC15array5Array6bufferGdE(self) {
  return self.buf;
}
function _M0MPB18UninitializedArray6lengthGdE(self) {
  return self.length;
}
function _M0MPC15array10FixedArray12unsafe__blitGRPB17UnsafeMaybeUninitGdEE(dst, dst_offset, src, src_offset, len) {
  if (dst === src && dst_offset < src_offset) {
    let _tmp = 0;
    while (true) {
      const i = _tmp;
      if (i < len) {
        const _tmp$2 = dst_offset + i | 0;
        const _tmp$3 = src_offset + i | 0;
        if (_tmp$2 >>> 0 < dst.length) {
          dst[_tmp$2] = _tmp$3 >>> 0 < src.length ? src[_tmp$3] : $oob();
        } else {
          $oob();
        }
        _tmp = i + 1 | 0;
        continue;
      } else {
        return;
      }
    }
  } else {
    let _tmp = len - 1 | 0;
    let _tmp$2 = len > 0;
    while (true) {
      const i = _tmp;
      const _more = _tmp$2;
      if (_more) {
        const _tmp$3 = dst_offset + i | 0;
        const _tmp$4 = src_offset + i | 0;
        if (_tmp$3 >>> 0 < dst.length) {
          dst[_tmp$3] = _tmp$4 >>> 0 < src.length ? src[_tmp$4] : $oob();
        } else {
          $oob();
        }
        _tmp = i - 1 | 0;
        _tmp$2 = i > 0;
        continue;
      } else {
        return;
      }
    }
  }
}
function _M0MPB18UninitializedArray12unsafe__blitGdE(dst, dst_offset, src, src_offset, len) {
  _M0MPC15array10FixedArray12unsafe__blitGRPB17UnsafeMaybeUninitGdEE(dst, dst_offset, src, src_offset, len);
}
function _M0MPB18UninitializedArray23unsafe__make__and__blitGdE(src, allocate_len, src_offset, dst_offset, blit_len) {
  const dst = new Array(allocate_len);
  _M0MPB18UninitializedArray12unsafe__blitGdE(dst, dst_offset, src, src_offset, blit_len);
  return dst;
}
function _M0FPB11range__fits(offset, len, length) {
  return offset >= 0 && offset <= (length - len | 0);
}
function _M0MPB13StringBuilder13write__objectGiE(self, obj) {
  _M0IP016_24default__implPB4Show6outputGiE(obj, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0MPB18UninitializedArray23make__and__blit_2einnerGdE(src, allocate_len, len, src_offset, dst_offset) {
  if (allocate_len >= 0 && (len >= 0 && (_M0FPB11range__fits(src_offset, len, _M0MPB18UninitializedArray6lengthGdE(src)) && _M0FPB11range__fits(dst_offset, len, allocate_len)))) {
    return _M0MPB18UninitializedArray23unsafe__make__and__blitGdE(src, allocate_len, src_offset, dst_offset, len);
  } else {
    const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(89);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "bounds check failed: allocate_len = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, allocate_len);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", src_offset = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, src_offset);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", dst_offset = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, dst_offset);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", len = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, len);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", src.length = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, _M0MPB18UninitializedArray6lengthGdE(src));
    return $panic(_M0MPB13StringBuilder10to__string(_string_builder));
  }
}
function _M0MPB13StringBuilder21StringBuilder_2einner(size_hint) {
  return size_hint >= 0 ? new _M0TPB13StringBuilder("") : $panic("size_hint must be non-negative");
}
function _M0MPB13StringBuilder10to__string(self) {
  return self.val;
}
function _M0IPB13StringBuilderPB6Logger11write__char(self, ch) {
  self.val = `${self.val}${String.fromCodePoint(ch)}`;
}
function _M0IPB13StringBuilderPB6Logger13write__string(self, str) {
  self.val = `${self.val}${str}`;
}
function _M0MPC16uint166UInt1622is__leading__surrogate(self) {
  return self >= 55296 && self <= 56319;
}
function _M0MPC16uint166UInt1623is__trailing__surrogate(self) {
  return self >= 56320 && self <= 57343;
}
function _M0IP016_24default__implPB6Logger28write__string__interpolationGRPB13StringBuilderE(self, show) {
  show.method_table.method_0(show.self, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0IP016_24default__implPB6Logger5writeGRPB13StringBuilderE(self, show) {
  show.method_table.method_0(show.self, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0MPC16string6String21clamped__view_2einner(self, start, end) {
  const len = self.length;
  const lo = start <= 0 ? 0 : start >= len ? len : _M0MPC16uint166UInt1623is__trailing__surrogate(self.charCodeAt(start)) && _M0MPC16uint166UInt1622is__leading__surrogate(self.charCodeAt(start - 1 | 0)) ? start + 1 | 0 : start;
  let hi;
  if (end === undefined) {
    hi = len;
  } else {
    const _Some = end;
    const _e = _Some;
    hi = _e <= 0 ? 0 : _e >= len ? len : _M0MPC16uint166UInt1623is__trailing__surrogate(self.charCodeAt(_e)) && _M0MPC16uint166UInt1622is__leading__surrogate(self.charCodeAt(_e - 1 | 0)) ? _e - 1 | 0 : _e;
  }
  return lo >= hi ? new _M0TPC16string10StringView(self, lo, lo) : new _M0TPC16string10StringView(self, lo, hi);
}
function _M0IP016_24default__implPB6Logger16write__substringGRPB13StringBuilderE(self, value, start, len) {
  _M0IPB13StringBuilderPB6Logger11write__view(self, _M0MPC16string6String21clamped__view_2einner(value, start, start + len | 0));
}
function _M0IP016_24default__implPB4Show6outputGiE(self, logger) {
  logger.method_table.method_0(logger.self, _M0IPC13int3IntPB4Show10to__string(self));
}
function _M0MPC13int3Int18to__string_2einner(self, radix) {
  return _M0FPB19int__to__string__js(self, radix);
}
function _M0MPC16string10StringView9to__owned(self) {
  return self.str.substring(self.start, self.end);
}
function _M0IPB13StringBuilderPB6Logger11write__view(self, str) {
  self.val = `${self.val}${_M0MPC16string10StringView9to__owned(str)}`;
}
function _M0IPC16string6StringPB4Show10to__string(self) {
  return self;
}
function _M0MPC15array5Array6lengthGdE(self) {
  return self.len;
}
function _M0FPB23array__growth__capacity(current, len, required) {
  if (required < len) {
    $panic("Array capacity overflow");
  }
  const start = current === 0 ? 8 : current;
  let _tmp = start;
  while (true) {
    const space = _tmp;
    if (space < required) {
      const next = Math.imul(space, 2) | 0;
      if (next <= space) {
        return required;
      }
      _tmp = next;
      continue;
    } else {
      return space;
    }
  }
}
function _M0MPC15array5Array8capacityGdE(self) {
  return _M0MPC15array5Array6bufferGdE(self).length;
}
function _M0MPC15array5Array14resize__bufferGdE(self, new_capacity) {
  const old_buf = self.buf;
  self.buf = [];
  const len = self.len;
  const copy_len = len < new_capacity ? len : new_capacity;
  const new_buf = _M0MPB18UninitializedArray23make__and__blit_2einnerGdE(old_buf, new_capacity, copy_len, 0, 0);
  self.buf = new_buf;
}
function _M0MPC15array5Array7reallocGdE(self, required) {
  const old_cap = _M0MPC15array5Array8capacityGdE(self);
  const new_cap = _M0FPB23array__growth__capacity(old_cap, self.len, required);
  _M0MPC15array5Array14resize__bufferGdE(self, new_cap);
}
function _M0MPC15array5Array4pushGdE(self, value) {
  if (self.len === _M0MPC15array5Array6bufferGdE(self).length) {
    _M0MPC15array5Array7reallocGdE(self, self.len + 1 | 0);
  }
  const length = self.len;
  self.buf[length] = value;
  self.len = length + 1 | 0;
}
function _M0IPC13int3IntPB4Show10to__string(self) {
  return _M0MPC13int3Int18to__string_2einner(self, 10);
}
function _M0MPC16double6Double7to__int(self) {
  return self !== self ? 0 : self >= 2147483647 ? 2147483647 : self <= -2147483648 ? -2147483648 : self | 0;
}
function _M0MPC16double6Double5floor(_tmp) {
  return Math.floor(_tmp);
}
function _M0MPC16double6Double5round(_tmp) {
  return Math.round(_tmp);
}
function _M0IPC16double6DoublePB3Mod3mod(self, other) {
  return _M0MPC16double6Double8mod__ffi(self, other);
}
function _M0MPC15array5Array2atGdE(self, index) {
  const len = self.len;
  return index >= 0 && index < len ? _M0MPC15array5Array6bufferGdE(self)[index] : $panic();
}
function _M0FPB7printlnGsE(input) {
  console.log(_M0IPC16string6StringPB4Show10to__string(input));
}
function _M0FPC14math3sin(_tmp) {
  return Math.sin(_tmp);
}
function _M0FPC14math3cos(_tmp) {
  return Math.cos(_tmp);
}
function _M0FPC14math5atan2(_tmp, _tmp$2) {
  return Math.atan2(_tmp, _tmp$2);
}
function _M0FP38Duckweed10moon_2dfoc5coord6clarke(ia, ib, ic) {
  const alpha = 0.66666666666666663 * (ia - ib / 2 - ic / 2);
  const beta = 1 / Math.sqrt(3) * (ib - ic);
  return { _0: alpha, _1: beta };
}
function _M0FP38Duckweed10moon_2dfoc5coord11inv__clarke(alpha, beta) {
  const ia = alpha;
  const ib = -alpha / 2 + beta * (Math.sqrt(3) / 2);
  const ic = -alpha / 2 - beta * (Math.sqrt(3) / 2);
  return { _0: ia, _1: ib, _2: ic };
}
function _M0FP38Duckweed10moon_2dfoc5coord4park(alpha, beta, theta) {
  const c = _M0FPC14math3cos(theta);
  const s = _M0FPC14math3sin(theta);
  const d = alpha * c + beta * s;
  const q = -alpha * s + beta * c;
  return { _0: d, _1: q };
}
function _M0FP38Duckweed10moon_2dfoc5coord9inv__park(d, q, theta) {
  const c = _M0FPC14math3cos(theta);
  const s = _M0FPC14math3sin(theta);
  const alpha = d * c - q * s;
  const beta = d * s + q * c;
  return { _0: alpha, _1: beta };
}
function _M0MP38Duckweed10moon_2dfoc2pi2Pi3new(kp, ki, dt, out_min, out_max) {
  const step_time = dt > 0 ? dt : 0;
  const lo = out_min <= out_max ? out_min : out_max;
  const hi = out_min <= out_max ? out_max : out_min;
  return new _M0TP38Duckweed10moon_2dfoc2pi2Pi(kp, ki, step_time, lo, hi, 0);
}
function _M0FP38Duckweed10moon_2dfoc2pi9pi__clamp(v, lo, hi) {
  return v > hi ? hi : v < lo ? lo : v;
}
function _M0FP38Duckweed10moon_2dfoc2pi10pi__finite(x) {
  return x === x && Math.abs(x) <= 1e+308;
}
function _M0MP38Duckweed10moon_2dfoc2pi2Pi4step(self, err) {
  if (!_M0FP38Duckweed10moon_2dfoc2pi10pi__finite(err)) {
    return _M0FP38Duckweed10moon_2dfoc2pi9pi__clamp(self.integ, self.out_min, self.out_max);
  }
  const candidate = self.integ + self.ki * err * self.dt;
  const raw = self.kp * err + candidate;
  const out = _M0FP38Duckweed10moon_2dfoc2pi9pi__clamp(raw, self.out_min, self.out_max);
  const pushing_high = raw > self.out_max && err > 0;
  const pushing_low = raw < self.out_min && err < 0;
  if (!(pushing_high || pushing_low)) {
    self.integ = candidate;
  }
  return out;
}
function _M0FP38Duckweed10moon_2dfoc5svpwm10sector__of(alpha, beta) {
  const theta = _M0FPC14math5atan2(beta, alpha);
  const theta_pos = theta < 0 ? theta + 6.2831853071795862 : theta;
  const sector = _M0MPC16double6Double7to__int(_M0MPC16double6Double5floor(theta_pos / 1.0471975511965976)) + 1 | 0;
  if (sector > 6) {
    return 6;
  }
  return sector;
}
function _M0FP38Duckweed10moon_2dfoc5svpwm6finite(x) {
  if (x !== x) {
    return false;
  }
  if (Math.abs(x) > 1e+308) {
    return false;
  }
  return true;
}
function _M0FP38Duckweed10moon_2dfoc5svpwm13action__times(alpha, beta, sector, ts, vdc) {
  if (sector < 1 || sector > 6) {
    return { _0: 0, _1: 0 };
  }
  if (vdc <= 0 || ts <= 0) {
    return { _0: 0, _1: 0 };
  }
  if (!_M0FP38Duckweed10moon_2dfoc5svpwm6finite(alpha) || !_M0FP38Duckweed10moon_2dfoc5svpwm6finite(beta)) {
    return { _0: 0, _1: 0 };
  }
  const vref = Math.sqrt(alpha * alpha + beta * beta);
  if (vref <= 1e-012) {
    return { _0: 0, _1: 0 };
  }
  const theta_raw = _M0FPC14math5atan2(beta, alpha);
  const theta_pos = theta_raw < 0 ? theta_raw + 6.2831853071795862 : theta_raw;
  const sector_d = sector + 0;
  const sector_start = (sector_d - 1) * 3.1415926535897931 / 3;
  const local_norm = theta_pos - sector_start;
  const k = Math.sqrt(3) * ts / vdc;
  const t1 = k * vref * _M0FPC14math3sin(1.0471975511965976 - local_norm);
  const t2 = k * vref * _M0FPC14math3sin(local_norm);
  const sum = t1 + t2;
  if (sum > ts && sum > 0) {
    const scale = ts / sum;
    return { _0: t1 * scale, _1: t2 * scale };
  }
  return { _0: t1, _1: t2 };
}
function _M0FP38Duckweed10moon_2dfoc5svpwm6duties(alpha, beta, ts, vdc) {
  if (ts <= 0 || vdc <= 0) {
    return { _0: 0, _1: 0, _2: 0 };
  }
  if (!_M0FP38Duckweed10moon_2dfoc5svpwm6finite(alpha) || !_M0FP38Duckweed10moon_2dfoc5svpwm6finite(beta)) {
    return { _0: 0, _1: 0, _2: 0 };
  }
  const sector = _M0FP38Duckweed10moon_2dfoc5svpwm10sector__of(alpha, beta);
  let t1;
  let t2;
  _L: {
    const _bind = _M0FP38Duckweed10moon_2dfoc5svpwm13action__times(alpha, beta, sector, ts, vdc);
    const _t1 = _bind._0;
    const _t2 = _bind._1;
    t1 = _t1;
    t2 = _t2;
    break _L;
  }
  const t0 = ts - t1 - t2;
  let ta;
  let tb;
  let tc;
  _L$2: {
    switch (sector) {
      case 1: {
        ta = t0 / 2 + t1 + t2;
        tb = t0 / 2 + t2;
        tc = t0 / 2;
        break _L$2;
      }
      case 2: {
        ta = t0 / 2 + t1;
        tb = t0 / 2 + t1 + t2;
        tc = t0 / 2;
        break _L$2;
      }
      case 3: {
        ta = t0 / 2;
        tb = t0 / 2 + t1 + t2;
        tc = t0 / 2 + t2;
        break _L$2;
      }
      case 4: {
        ta = t0 / 2;
        tb = t0 / 2 + t1;
        tc = t0 / 2 + t1 + t2;
        break _L$2;
      }
      case 5: {
        ta = t0 / 2 + t2;
        tb = t0 / 2;
        tc = t0 / 2 + t1 + t2;
        break _L$2;
      }
      default: {
        ta = t0 / 2 + t1 + t2;
        tb = t0 / 2;
        tc = t0 / 2 + t1;
        break _L$2;
      }
    }
  }
  const da = 2 * ta / ts - 1;
  const db = 2 * tb / ts - 1;
  const dc = 2 * tc / ts - 1;
  if (!_M0FP38Duckweed10moon_2dfoc5svpwm6finite(da) || (!_M0FP38Duckweed10moon_2dfoc5svpwm6finite(db) || !_M0FP38Duckweed10moon_2dfoc5svpwm6finite(dc))) {
    return { _0: 0, _1: 0, _2: 0 };
  }
  return { _0: da, _1: db, _2: dc };
}
function _M0FP38Duckweed10moon_2dfoc10controller14design__finite(x) {
  return x === x && Math.abs(x) <= 1e+308;
}
function _M0FP38Duckweed10moon_2dfoc10controller10design__pi() {
  return 3.1415926535897931;
}
function _M0FP38Duckweed10moon_2dfoc10controller19design__speed__loop(j, b, kt, bandwidth_hz) {
  const j_safe = _M0FP38Duckweed10moon_2dfoc10controller14design__finite(j) && j > 1e-012 ? j : 1e-012;
  _M0FP38Duckweed10moon_2dfoc10controller14design__finite(b) && b > 0 ? b : 0;
  if (!(_M0FP38Duckweed10moon_2dfoc10controller14design__finite(kt) && kt > 0)) {
    return new _M0TP38Duckweed10moon_2dfoc10controller9LoopGains(0, 0);
  }
  if (!(_M0FP38Duckweed10moon_2dfoc10controller14design__finite(bandwidth_hz) && bandwidth_hz > 0)) {
    return new _M0TP38Duckweed10moon_2dfoc10controller9LoopGains(0, 0);
  }
  const omega = 2 * _M0FP38Duckweed10moon_2dfoc10controller10design__pi() * bandwidth_hz;
  const kp = omega * j_safe / kt;
  return new _M0TP38Duckweed10moon_2dfoc10controller9LoopGains(kp, kp * omega / 5);
}
function _M0MP38Duckweed10moon_2dfoc10controller15SpeedController3new(kp, ki, dt, iq_min, iq_max) {
  const lo = iq_min < iq_max ? iq_min : iq_max;
  const hi = iq_min < iq_max ? iq_max : iq_min;
  return new _M0TP38Duckweed10moon_2dfoc10controller15SpeedController(_M0MP38Duckweed10moon_2dfoc2pi2Pi3new(kp, ki, dt, lo, hi), lo, hi, 0);
}
function _M0MP38Duckweed10moon_2dfoc10controller15SpeedController4step(self, omega_ref, omega_meas) {
  if (!(_M0FP38Duckweed10moon_2dfoc10controller14design__finite(omega_ref) && _M0FP38Duckweed10moon_2dfoc10controller14design__finite(omega_meas))) {
    return 0;
  }
  self.last = _M0MP38Duckweed10moon_2dfoc2pi2Pi4step(self.pi, omega_ref - omega_meas);
  return self.last;
}
function _M0FP38Duckweed10moon_2dfoc10controller6finite(x) {
  return x === x && Math.abs(x) <= 1e+308;
}
function _M0MP38Duckweed10moon_2dfoc10controller13FocController4step(self, ia, ib, ic, theta_e, id_ref, iq_ref) {
  if (!(_M0FP38Duckweed10moon_2dfoc10controller6finite(ia) && (_M0FP38Duckweed10moon_2dfoc10controller6finite(ib) && (_M0FP38Duckweed10moon_2dfoc10controller6finite(ic) && (_M0FP38Duckweed10moon_2dfoc10controller6finite(theta_e) && (_M0FP38Duckweed10moon_2dfoc10controller6finite(id_ref) && _M0FP38Duckweed10moon_2dfoc10controller6finite(iq_ref))))))) {
    return { _0: 0, _1: 0, _2: 0, _3: 0, _4: 0, _5: 0, _6: 0 };
  }
  let alpha;
  let beta;
  _L: {
    const _bind = _M0FP38Duckweed10moon_2dfoc5coord6clarke(ia, ib, ic);
    const _alpha = _bind._0;
    const _beta = _bind._1;
    alpha = _alpha;
    beta = _beta;
    break _L;
  }
  let id;
  let iq;
  _L$2: {
    const _bind = _M0FP38Duckweed10moon_2dfoc5coord4park(alpha, beta, theta_e);
    const _id = _bind._0;
    const _iq = _bind._1;
    id = _id;
    iq = _iq;
    break _L$2;
  }
  const vd = _M0MP38Duckweed10moon_2dfoc2pi2Pi4step(self.d_pi, id_ref - id);
  const vq = _M0MP38Duckweed10moon_2dfoc2pi2Pi4step(self.q_pi, iq_ref - iq);
  let valpha;
  let vbeta;
  _L$3: {
    const _bind = _M0FP38Duckweed10moon_2dfoc5coord9inv__park(vd, vq, theta_e);
    const _valpha = _bind._0;
    const _vbeta = _bind._1;
    valpha = _valpha;
    vbeta = _vbeta;
    break _L$3;
  }
  let db;
  let da;
  let dc;
  _L$4: {
    const _bind = _M0FP38Duckweed10moon_2dfoc5svpwm6duties(valpha, vbeta, self.ts, self.vdc);
    const _da = _bind._0;
    const _db = _bind._1;
    const _dc = _bind._2;
    db = _db;
    da = _da;
    dc = _dc;
    break _L$4;
  }
  self.last_id = id;
  self.last_iq = iq;
  self.last_alpha = alpha;
  self.last_beta = beta;
  self.last_vd = vd;
  self.last_vq = vq;
  return { _0: id, _1: iq, _2: vd, _3: vq, _4: da, _5: db, _6: dc };
}
function _M0FP38Duckweed10moon_2dfoc10controller10fw__finite(x) {
  return x === x && (x !== 1 / 0 && x !== -1 / 0);
}
function _M0FP38Duckweed10moon_2dfoc10controller14flux__headroom(omega_e, ld, lq, psi_f, iq, vmax) {
  if (!(_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(omega_e) && (_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(ld) && (_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(lq) && (_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(psi_f) && (_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(iq) && _M0FP38Duckweed10moon_2dfoc10controller10fw__finite(vmax))))))) {
    return 0;
  }
  if (ld <= 0 || (vmax <= 0 || omega_e === 0)) {
    return 0;
  }
  const speed = Math.abs(omega_e);
  const vq_term = speed * lq * iq;
  const square = vmax * vmax - vq_term * vq_term;
  if (square <= 0) {
    return -psi_f;
  }
  return Math.sqrt(square) / speed - psi_f;
}
function _M0FP38Duckweed10moon_2dfoc10controller20field__weakening__id(omega_e, ld, lq, psi_f, iq, vmax, id_min) {
  if (!(_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(id_min) && (_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(omega_e) && (_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(ld) && (_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(lq) && (_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(psi_f) && (_M0FP38Duckweed10moon_2dfoc10controller10fw__finite(iq) && _M0FP38Duckweed10moon_2dfoc10controller10fw__finite(vmax)))))))) {
    return 0;
  }
  if (ld <= 0 || (vmax <= 0 || omega_e === 0)) {
    return 0;
  }
  const floor = id_min < 0 ? id_min : 0;
  const speed = Math.abs(omega_e);
  const vq_term = speed * lq * iq;
  const square = vmax * vmax - vq_term * vq_term;
  if (square <= 0) {
    return floor;
  }
  const headroom = Math.sqrt(square) / speed - psi_f;
  if (headroom >= 0) {
    return 0;
  }
  const id = headroom / ld;
  return id < floor ? floor : id;
}
function _M0FP38Duckweed10moon_2dfoc10controller10ff__finite(v) {
  return v === v && Math.abs(v) <= 1e+308;
}
function _M0FP38Duckweed10moon_2dfoc10controller18back__emf__voltage(omega_e, psi_f) {
  if (!(_M0FP38Duckweed10moon_2dfoc10controller10ff__finite(omega_e) && _M0FP38Duckweed10moon_2dfoc10controller10ff__finite(psi_f))) {
    return 0;
  }
  const v = omega_e * psi_f;
  return _M0FP38Duckweed10moon_2dfoc10controller10ff__finite(v) ? v : 0;
}
function _M0FP38Duckweed10moon_2dfoc10controller18apply__feedforward(vd_pi, vq_pi, vd_ff, vq_ff, vdc) {
  if (!(_M0FP38Duckweed10moon_2dfoc10controller10ff__finite(vd_pi) && (_M0FP38Duckweed10moon_2dfoc10controller10ff__finite(vq_pi) && (_M0FP38Duckweed10moon_2dfoc10controller10ff__finite(vd_ff) && _M0FP38Duckweed10moon_2dfoc10controller10ff__finite(vq_ff))))) {
    return { _0: 0, _1: 0 };
  }
  const vd = vd_pi + vd_ff;
  const vq = vq_pi + vq_ff;
  if (!(_M0FP38Duckweed10moon_2dfoc10controller10ff__finite(vdc) && vdc > 0)) {
    return { _0: vd, _1: vq };
  }
  const limit = vdc / Math.sqrt(3);
  const mag = Math.sqrt(vd * vd + vq * vq);
  if (!_M0FP38Duckweed10moon_2dfoc10controller10ff__finite(mag) || mag <= limit) {
    return { _0: vd, _1: vq };
  }
  const scale = limit / mag;
  return { _0: vd * scale, _1: vq * scale };
}
function _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(self) {
  return self.kp;
}
function _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(self) {
  return self.ki;
}
function _M0FP38Duckweed10moon_2dfoc10controller21design__current__loop(r, l, bandwidth_hz) {
  const r_safe = _M0FP38Duckweed10moon_2dfoc10controller14design__finite(r) && r > 0 ? r : 0;
  const l_safe = _M0FP38Duckweed10moon_2dfoc10controller14design__finite(l) && l > 1e-009 ? l : 1e-009;
  if (!(_M0FP38Duckweed10moon_2dfoc10controller14design__finite(bandwidth_hz) && bandwidth_hz > 0)) {
    return new _M0TP38Duckweed10moon_2dfoc10controller9LoopGains(0, 0);
  }
  const omega = 2 * _M0FP38Duckweed10moon_2dfoc10controller10design__pi() * bandwidth_hz;
  return new _M0TP38Duckweed10moon_2dfoc10controller9LoopGains(omega * l_safe, omega * r_safe);
}
function _M0FP38Duckweed10moon_2dfoc10controller15loop__gain__mag(r, l, kp, ki, omega) {
  if (!(_M0FP38Duckweed10moon_2dfoc10controller14design__finite(omega) && omega > 0)) {
    return 0;
  }
  const l_safe = _M0FP38Duckweed10moon_2dfoc10controller14design__finite(l) && l > 1e-009 ? l : 1e-009;
  const r_safe = _M0FP38Duckweed10moon_2dfoc10controller14design__finite(r) && r >= 0 ? r : 0;
  const cr = kp;
  const ci = -(ki / omega);
  const d = r_safe * r_safe + omega * l_safe * (omega * l_safe);
  const pr = r_safe / d;
  const pi_ = -(omega * l_safe) / d;
  const rr = cr * pr - ci * pi_;
  const ri = cr * pi_ + ci * pr;
  return Math.sqrt(rr * rr + ri * ri);
}
function _M0FP38Duckweed10moon_2dfoc10controller17loop__gain__phase(r, l, kp, ki, omega) {
  if (!(_M0FP38Duckweed10moon_2dfoc10controller14design__finite(omega) && omega > 0)) {
    return 0;
  }
  const l_safe = _M0FP38Duckweed10moon_2dfoc10controller14design__finite(l) && l > 1e-009 ? l : 1e-009;
  const r_safe = _M0FP38Duckweed10moon_2dfoc10controller14design__finite(r) && r >= 0 ? r : 0;
  const cr = kp;
  const ci = -(ki / omega);
  const d = r_safe * r_safe + omega * l_safe * (omega * l_safe);
  const pr = r_safe / d;
  const pi_ = -(omega * l_safe) / d;
  const rr = cr * pr - ci * pi_;
  const ri = cr * pi_ + ci * pr;
  return _M0FPC14math5atan2(ri, rr);
}
function _M0FP38Duckweed10moon_2dfoc10controller13crossover__hz(r, l, kp, ki) {
  const lo = new _M0TPB8MutLocalGdE(0.001);
  const hi = new _M0TPB8MutLocalGdE(1000000000);
  const mag_lo = _M0FP38Duckweed10moon_2dfoc10controller15loop__gain__mag(r, l, kp, ki, 2 * _M0FP38Duckweed10moon_2dfoc10controller10design__pi() * lo.val);
  const mag_hi = _M0FP38Duckweed10moon_2dfoc10controller15loop__gain__mag(r, l, kp, ki, 2 * _M0FP38Duckweed10moon_2dfoc10controller10design__pi() * hi.val);
  if (!(mag_lo >= 1 && mag_hi < 1)) {
    return 0;
  }
  const i = new _M0TPB8MutLocalGiE(0);
  while (true) {
    if (i.val < 60) {
      const mid = Math.sqrt(lo.val * hi.val);
      const mag = _M0FP38Duckweed10moon_2dfoc10controller15loop__gain__mag(r, l, kp, ki, 2 * _M0FP38Duckweed10moon_2dfoc10controller10design__pi() * mid);
      if (mag >= 1) {
        lo.val = mid;
      } else {
        hi.val = mid;
      }
      i.val = i.val + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return lo.val;
}
function _M0FP38Duckweed10moon_2dfoc10controller18phase__margin__deg(r, l, kp, ki) {
  const fc = _M0FP38Duckweed10moon_2dfoc10controller13crossover__hz(r, l, kp, ki);
  if (fc <= 0) {
    return 0;
  }
  const arg = _M0FP38Duckweed10moon_2dfoc10controller17loop__gain__phase(r, l, kp, ki, 2 * _M0FP38Duckweed10moon_2dfoc10controller10design__pi() * fc);
  const pm = 180 + arg * 180 / _M0FP38Duckweed10moon_2dfoc10controller10design__pi();
  return _M0FP38Duckweed10moon_2dfoc10controller14design__finite(pm) ? pm : 0;
}
function _M0FP38Duckweed10moon_2dfoc10controller23delay__phase__loss__deg(crossover_hz, ts) {
  if (!(_M0FP38Duckweed10moon_2dfoc10controller14design__finite(crossover_hz) && crossover_hz > 0)) {
    return 0;
  }
  if (!(_M0FP38Duckweed10moon_2dfoc10controller14design__finite(ts) && ts > 0)) {
    return 0;
  }
  return 360 * crossover_hz * ts;
}
function _M0FP38Duckweed10moon_2dfoc10controller25margin__after__delay__deg(r, l, kp, ki, ts) {
  const pm = _M0FP38Duckweed10moon_2dfoc10controller18phase__margin__deg(r, l, kp, ki);
  const fc = _M0FP38Duckweed10moon_2dfoc10controller13crossover__hz(r, l, kp, ki);
  return pm - _M0FP38Duckweed10moon_2dfoc10controller23delay__phase__loss__deg(fc, ts);
}
function _M0MP38Duckweed10moon_2dfoc10controller13FocController3new(kp_d, ki_d, kp_q, ki_q, dt, vdc, v_min, v_max) {
  return new _M0TP38Duckweed10moon_2dfoc10controller13FocController(_M0MP38Duckweed10moon_2dfoc2pi2Pi3new(kp_d, ki_d, dt, v_min, v_max), _M0MP38Duckweed10moon_2dfoc2pi2Pi3new(kp_q, ki_q, dt, v_min, v_max), dt, vdc, 0, 0, 0, 0, 0, 0);
}
function _M0FP38Duckweed10moon_2dfoc5angle16normalize__angle(theta) {
  const r = new _M0TPB8MutLocalGdE(_M0IPC16double6DoublePB3Mod3mod(theta, _M0FP38Duckweed10moon_2dfoc5angle7two__pi));
  if (r.val < 0) {
    r.val = r.val + _M0FP38Duckweed10moon_2dfoc5angle7two__pi;
  }
  if (r.val >= _M0FP38Duckweed10moon_2dfoc5angle7two__pi) {
    r.val = 0;
  }
  return r.val;
}
function _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel3new(r, ld, lq, psi_f, pole_pairs, omega_m) {
  const pp = pole_pairs > 0 ? pole_pairs : 1;
  const ld_safe = ld > 1e-009 ? ld : 1e-009;
  const lq_safe = lq > 1e-009 ? lq : 1e-009;
  return new _M0TP38Duckweed10moon_2dfoc5motor9PmsmModel(r, ld_safe, lq_safe, psi_f, pp, 0, 0, 0, omega_m * (pp + 0));
}
function _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel10set__speed(self, omega_m) {
  self.omega_e = omega_m * (self.pole_pairs + 0);
}
function _M0FP38Duckweed10moon_2dfoc5motor6finite(x) {
  return x === x && Math.abs(x) <= 1e+308;
}
function _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel4step(self, vd, vq, dt) {
  if (!(_M0FP38Duckweed10moon_2dfoc5motor6finite(vd) && (_M0FP38Duckweed10moon_2dfoc5motor6finite(vq) && (_M0FP38Duckweed10moon_2dfoc5motor6finite(dt) && dt > 0)))) {
    return undefined;
  }
  const did = (vd - self.r * self.id) / self.ld;
  const diq = (vq - self.r * self.iq - self.omega_e * self.psi_f) / self.lq;
  self.id = self.id + did * dt;
  self.iq = self.iq + diq * dt;
  self.theta_e = _M0FP38Duckweed10moon_2dfoc5angle16normalize__angle(self.theta_e + self.omega_e * dt);
}
function _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel2id(self) {
  return self.id;
}
function _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel2iq(self) {
  return self.iq;
}
function _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel8theta__e(self) {
  return self.theta_e;
}
function _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel15phase__currents(self) {
  let alpha;
  let beta;
  _L: {
    const _bind = _M0FP38Duckweed10moon_2dfoc5coord9inv__park(self.id, self.iq, self.theta_e);
    const _alpha = _bind._0;
    const _beta = _bind._1;
    alpha = _alpha;
    beta = _beta;
    break _L;
  }
  return _M0FP38Duckweed10moon_2dfoc5coord11inv__clarke(alpha, beta);
}
function _M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel3new(j, b, pole_pairs, omega_m) {
  const j_safe = j > 1e-012 ? j : 1e-012;
  const b_safe = b >= 0 ? b : 0;
  const pp = pole_pairs > 0 ? pole_pairs : 1;
  return new _M0TP38Duckweed10moon_2dfoc5motor15MechanicalModel(j_safe, b_safe, pp, omega_m, 0);
}
function _M0FP38Duckweed10moon_2dfoc5motor12mech__finite(x) {
  return x === x && Math.abs(x) <= 1e+308;
}
function _M0FP38Duckweed10moon_2dfoc5motor23electromagnetic__torque(id, iq, ld, lq, psi_f, pole_pairs) {
  if (!(_M0FP38Duckweed10moon_2dfoc5motor12mech__finite(id) && (_M0FP38Duckweed10moon_2dfoc5motor12mech__finite(iq) && (_M0FP38Duckweed10moon_2dfoc5motor12mech__finite(ld) && (_M0FP38Duckweed10moon_2dfoc5motor12mech__finite(lq) && _M0FP38Duckweed10moon_2dfoc5motor12mech__finite(psi_f)))))) {
    return 0;
  }
  const pp = pole_pairs > 0 ? pole_pairs : 1;
  const te = 1.5 * (pp + 0) * (psi_f * iq + (ld - lq) * id * iq);
  return _M0FP38Duckweed10moon_2dfoc5motor12mech__finite(te) ? te : 0;
}
function _M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel4step(self, torque, load, dt) {
  if (!(_M0FP38Duckweed10moon_2dfoc5motor12mech__finite(torque) && (_M0FP38Duckweed10moon_2dfoc5motor12mech__finite(load) && (_M0FP38Duckweed10moon_2dfoc5motor12mech__finite(dt) && dt > 0)))) {
    return undefined;
  }
  const acc = (torque - load - self.b * self.omega_m) / self.j;
  const next = self.omega_m + acc * dt;
  self.omega_m = next < 0 ? 0 : next;
  self.theta_m = _M0FP38Duckweed10moon_2dfoc5angle16normalize__angle(self.theta_m + self.omega_m * dt);
}
function _M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel8omega__m(self) {
  return self.omega_m;
}
function _M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel8omega__e(self) {
  return self.omega_m * (self.pole_pairs + 0);
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo6r__mot() {
  return 0.5;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot() {
  return 0.0008;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo7lq__mot() {
  return 0.0012;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo11psi__f__mot() {
  return 0.05;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo11pole__pairs() {
  return 4;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo8vdc__bus() {
  return 48;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step() {
  return 0.0001;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(x) {
  const q = _M0MPC16double6Double5round(x * 10000);
  const v = q / 10000;
  return v === 0 ? "0" : String(v);
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo4jarr(xs) {
  const s = new _M0TPB8MutLocalGsE("[");
  const i = new _M0TPB8MutLocalGiE(0);
  while (true) {
    if (i.val < _M0MPC15array5Array6lengthGdE(xs)) {
      if (i.val > 0) {
        s.val = `${s.val},`;
      }
      s.val = `${s.val}${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(_M0MPC15array5Array2atGdE(xs, i.val))}`;
      i.val = i.val + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return `${s.val}]`;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo14panel__current(bw) {
  const gains = _M0FP38Duckweed10moon_2dfoc10controller21design__current__loop(_M0FP48Duckweed10moon_2dfoc8examples9web__demo6r__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), bw);
  const vmax = _M0FP48Duckweed10moon_2dfoc8examples9web__demo8vdc__bus() / Math.sqrt(3);
  const ctrl = _M0MP38Duckweed10moon_2dfoc10controller13FocController3new(_M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(gains), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(gains), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(gains), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(gains), _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo8vdc__bus(), -vmax, vmax);
  const elec = _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel3new(_M0FP48Duckweed10moon_2dfoc8examples9web__demo6r__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7lq__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo11psi__f__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo11pole__pairs(), 0);
  const steps = 1200;
  const every = 4;
  const t = new _M0TPB5ArrayGdE([], 0);
  const iq = new _M0TPB5ArrayGdE([], 0);
  const i = new _M0TPB8MutLocalGiE(0);
  while (true) {
    if (i.val < steps) {
      let ib;
      let ia;
      let ic;
      _L: {
        const _bind = _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel15phase__currents(elec);
        const _ia = _bind._0;
        const _ib = _bind._1;
        const _ic = _bind._2;
        ib = _ib;
        ia = _ia;
        ic = _ic;
        break _L;
      }
      let vq;
      let obs_iq;
      let vd;
      _L$2: {
        const _bind = _M0MP38Duckweed10moon_2dfoc10controller13FocController4step(ctrl, ia, ib, ic, _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel8theta__e(elec), 0, 5);
        const _obs_iq = _bind._1;
        const _vd = _bind._2;
        const _vq = _bind._3;
        vq = _vq;
        obs_iq = _obs_iq;
        vd = _vd;
        break _L$2;
      }
      _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel4step(elec, vd, vq, _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step());
      if (every === 0) {
        $panic();
      }
      if ((i.val % every | 0) === 0) {
        _M0MPC15array5Array4pushGdE(t, (i.val + 0) * _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step());
        _M0MPC15array5Array4pushGdE(iq, obs_iq);
      }
      i.val = i.val + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return `DATA {\"panel\":\"current\",\"bw\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(bw)},\"ref\":5,\"t\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jarr(t)},\"iq\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jarr(iq)}}`;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo12panel__speed() {
  const j = 0.002;
  const b = 0.0005;
  const kt = 1.5 * (_M0FP48Duckweed10moon_2dfoc8examples9web__demo11pole__pairs() + 0) * _M0FP48Duckweed10moon_2dfoc8examples9web__demo11psi__f__mot();
  const speed_hz = 40;
  const current_hz = 400;
  const iq_limit = 8;
  const omega_ref = 100;
  const load_at = 10000;
  const load = 1;
  const steps = 20000;
  const every = 25;
  const speed_gains = _M0FP38Duckweed10moon_2dfoc10controller19design__speed__loop(j, b, kt, speed_hz);
  const current_gains = _M0FP38Duckweed10moon_2dfoc10controller21design__current__loop(_M0FP48Duckweed10moon_2dfoc8examples9web__demo6r__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), current_hz);
  const vlimit = _M0FP48Duckweed10moon_2dfoc8examples9web__demo8vdc__bus() / Math.sqrt(3);
  const elec = _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel3new(_M0FP48Duckweed10moon_2dfoc8examples9web__demo6r__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7lq__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo11psi__f__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo11pole__pairs(), 0);
  const mech = _M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel3new(j, b, _M0FP48Duckweed10moon_2dfoc8examples9web__demo11pole__pairs(), 0);
  const speed = _M0MP38Duckweed10moon_2dfoc10controller15SpeedController3new(_M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(speed_gains), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(speed_gains), _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step(), -iq_limit, iq_limit);
  const pi_d = _M0MP38Duckweed10moon_2dfoc2pi2Pi3new(_M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(current_gains), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(current_gains), _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step(), -vlimit, vlimit);
  const pi_q = _M0MP38Duckweed10moon_2dfoc2pi2Pi3new(_M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(current_gains), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(current_gains), _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step(), -vlimit, vlimit);
  const t = new _M0TPB5ArrayGdE([], 0);
  const omega = new _M0TPB5ArrayGdE([], 0);
  const iq_ref = new _M0TPB5ArrayGdE([], 0);
  const i = new _M0TPB8MutLocalGiE(0);
  while (true) {
    if (i.val < steps) {
      const w = _M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel8omega__m(mech);
      const iq_cmd = _M0MP38Duckweed10moon_2dfoc10controller15SpeedController4step(speed, omega_ref, w);
      const vd_pi = _M0MP38Duckweed10moon_2dfoc2pi2Pi4step(pi_d, 0 - _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel2id(elec));
      const vq_pi = _M0MP38Duckweed10moon_2dfoc2pi2Pi4step(pi_q, iq_cmd - _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel2iq(elec));
      const emf = _M0FP38Duckweed10moon_2dfoc10controller18back__emf__voltage(_M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel8omega__e(mech), _M0FP48Duckweed10moon_2dfoc8examples9web__demo11psi__f__mot());
      let vd;
      let vq;
      _L: {
        const _bind = _M0FP38Duckweed10moon_2dfoc10controller18apply__feedforward(vd_pi, vq_pi, 0, emf, _M0FP48Duckweed10moon_2dfoc8examples9web__demo8vdc__bus());
        const _vd = _bind._0;
        const _vq = _bind._1;
        vd = _vd;
        vq = _vq;
        break _L;
      }
      _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel10set__speed(elec, _M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel8omega__m(mech));
      _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel4step(elec, vd, vq, _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step());
      const te = _M0FP38Duckweed10moon_2dfoc5motor23electromagnetic__torque(_M0MP38Duckweed10moon_2dfoc5motor9PmsmModel2id(elec), _M0MP38Duckweed10moon_2dfoc5motor9PmsmModel2iq(elec), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7lq__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo11psi__f__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo11pole__pairs());
      const load_now = i.val >= load_at ? load : 0;
      _M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel4step(mech, te, load_now, _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step());
      if (every === 0) {
        $panic();
      }
      if ((i.val % every | 0) === 0) {
        _M0MPC15array5Array4pushGdE(t, (i.val + 0) * _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step());
        _M0MPC15array5Array4pushGdE(omega, _M0MP38Duckweed10moon_2dfoc5motor15MechanicalModel8omega__m(mech));
        _M0MPC15array5Array4pushGdE(iq_ref, iq_cmd);
      }
      i.val = i.val + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return `DATA {\"panel\":\"speed\",\"omega_ref\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(omega_ref)},\"load_t\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum((load_at + 0) * _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step())},\"load\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(load)},\"t\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jarr(t)},\"omega\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jarr(omega)},\"iq\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jarr(iq_ref)}}`;
}
function _M0FP48Duckweed10moon_2dfoc8examples9web__demo12panel__field(iq, id_min) {
  const vmax = _M0FP48Duckweed10moon_2dfoc8examples9web__demo8vdc__bus() / Math.sqrt(3);
  const w = new _M0TPB5ArrayGdE([], 0);
  const id = new _M0TPB5ArrayGdE([], 0);
  const head = new _M0TPB5ArrayGdE([], 0);
  const omega_e = new _M0TPB8MutLocalGdE(300);
  while (true) {
    if (omega_e.val <= 900) {
      _M0MPC15array5Array4pushGdE(w, omega_e.val);
      _M0MPC15array5Array4pushGdE(head, _M0FP38Duckweed10moon_2dfoc10controller14flux__headroom(omega_e.val, _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7lq__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo11psi__f__mot(), iq, vmax));
      _M0MPC15array5Array4pushGdE(id, _M0FP38Duckweed10moon_2dfoc10controller20field__weakening__id(omega_e.val, _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7lq__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo11psi__f__mot(), iq, vmax, id_min));
      omega_e.val = omega_e.val + 20;
      continue;
    } else {
      break;
    }
  }
  return `DATA {\"panel\":\"field\",\"iq\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(iq)},\"id_min\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(id_min)},\"omega_e\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jarr(w)},\"headroom\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jarr(head)},\"id\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jarr(id)}}`;
}
(() => {
  const gains = _M0FP38Duckweed10moon_2dfoc10controller21design__current__loop(_M0FP48Duckweed10moon_2dfoc8examples9web__demo6r__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), 400);
  const fc = _M0FP38Duckweed10moon_2dfoc10controller13crossover__hz(_M0FP48Duckweed10moon_2dfoc8examples9web__demo6r__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(gains), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(gains));
  const pm = _M0FP38Duckweed10moon_2dfoc10controller18phase__margin__deg(_M0FP48Duckweed10moon_2dfoc8examples9web__demo6r__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(gains), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(gains));
  const pm_delay = _M0FP38Duckweed10moon_2dfoc10controller25margin__after__delay__deg(_M0FP48Duckweed10moon_2dfoc8examples9web__demo6r__mot(), _M0FP48Duckweed10moon_2dfoc8examples9web__demo7ld__mot(), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(gains), _M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(gains), _M0FP48Duckweed10moon_2dfoc8examples9web__demo8dt__step());
  const kt = 1.5 * (_M0FP48Duckweed10moon_2dfoc8examples9web__demo11pole__pairs() + 0) * _M0FP48Duckweed10moon_2dfoc8examples9web__demo11psi__f__mot();
  const speed_gains = _M0FP38Duckweed10moon_2dfoc10controller19design__speed__loop(0.002, 0.0005, kt, 40);
  _M0FPB7printlnGsE(`META {\"kp\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(_M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(gains))},\"ki\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(_M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(gains))},\"crossover\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(fc)},\"pm\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(pm)},\"pm_delay\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(pm_delay)},\"speed_kp\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(_M0MP38Duckweed10moon_2dfoc10controller9LoopGains2kp(speed_gains))},\"speed_ki\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(_M0MP38Duckweed10moon_2dfoc10controller9LoopGains2ki(speed_gains))},\"vlimit\":${_M0FP48Duckweed10moon_2dfoc8examples9web__demo4jnum(_M0FP48Duckweed10moon_2dfoc8examples9web__demo8vdc__bus() / Math.sqrt(3))}}`);
  _M0FPB7printlnGsE(_M0FP48Duckweed10moon_2dfoc8examples9web__demo14panel__current(200));
  _M0FPB7printlnGsE(_M0FP48Duckweed10moon_2dfoc8examples9web__demo14panel__current(400));
  _M0FPB7printlnGsE(_M0FP48Duckweed10moon_2dfoc8examples9web__demo14panel__current(800));
  _M0FPB7printlnGsE(_M0FP48Duckweed10moon_2dfoc8examples9web__demo12panel__speed());
  _M0FPB7printlnGsE(_M0FP48Duckweed10moon_2dfoc8examples9web__demo12panel__field(2, -30));
  _M0FPB7printlnGsE(_M0FP48Duckweed10moon_2dfoc8examples9web__demo12panel__field(5, -30));
  _M0FPB7printlnGsE(_M0FP48Duckweed10moon_2dfoc8examples9web__demo12panel__field(8, -30));
  _M0FPB7printlnGsE(_M0FP48Duckweed10moon_2dfoc8examples9web__demo12panel__field(5, -8));
})();
//# sourceMappingURL=web_demo.js.map
