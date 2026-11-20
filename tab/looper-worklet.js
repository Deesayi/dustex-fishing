// DUSTEX Tab audio worklets: the looper (records the guitar and plays the layers, locked to the clock) and the input capture for chords + notes mode
class DxLoop extends AudioWorkletProcessor {
  constructor() { super(); this.len = 0; this.O = 0; this.layers = []; this.cur = null; this.dirty = false; this.pass = null;
    this.playing = false; this.win = null; this.lat = 0; this.pool = []; this.pk = 0; this.n = 0; this.port.onmessage = e => this.cmd(e.data); }
  take() { const b = this.pool.pop(); if (b && b.length === this.len) { b.fill(0); return b; } return new Float32Array(this.len); }
  info(ev) { this.port.postMessage({ ev, n: this.layers.length }); }
  commit() { if (this.cur && this.dirty) { this.layers.push(this.cur); this.info('layers'); } this.cur = null; this.dirty = false; this.pass = null; }
  cmd(m) {
    if (m.cmd === 'buf') { this.pool.push(m.b); return; }
    if (m.cmd === 'rec') { this.len = m.len; this.O = m.O; this.layers = []; this.cur = null; this.pass = null; this.dirty = false; this.lat = m.lat; this.win = { a: m.O, b: m.O + m.len, first: true }; this.playing = true; }
    else if (m.cmd === 'play') { this.O = m.O; this.playing = true; }
    else if (m.cmd === 'stop') { this.commit(); this.win = null; this.playing = false; }
    else if (m.cmd === 'dub') { this.lat = m.lat; this.win = { a: m.a, b: Infinity }; if (m.O !== undefined) { this.O = m.O; this.playing = true; } this.pass = null; }
    else if (m.cmd === 'dubOff') { if (this.win) this.win.b = Math.max(this.win.a, m.at); }
    else if (m.cmd === 'undo') { if (this.win && this.win.first) return this.cmd({ cmd: 'clear' }); if (this.win) { this.win = null; this.cur = null; this.dirty = false; this.pass = null; this.info('dubdone'); } else this.layers.pop(); this.info('layers'); }
    else if (m.cmd === 'dump') { const mix = new Float32Array(this.len); for (const L of this.layers) for (let i = 0; i < this.len; i++) mix[i] += L[i]; this.port.postMessage({ ev: 'dump', d: mix }, [mix.buffer]); }
    else if (m.cmd === 'clear') { this.layers = []; this.cur = null; this.dirty = false; this.pass = null; this.win = null; this.playing = false; this.len = 0; this.info('layers'); }
  }
  process(inputs, outputs) {
    const inp = inputs[0] && inputs[0][0], out = outputs[0][0], L = this.layers, len = this.len;
    for (let i = 0; i < out.length; i++) {
      const fr = currentFrame + i; let y = 0;
      if (this.playing && len && fr >= this.O) { const p = (fr - this.O) % len; for (let k = 0; k < L.length; k++) y += L[k][p]; if (this.cur) y += this.cur[p]; }
      out[i] = y;
      if (inp) { const x = inp[i], ax = x < 0 ? -x : x; if (ax > this.pk) this.pk = ax;
        if (this.win && len) { const tf = fr - this.lat;
          if (tf >= this.win.a) {
            if (tf >= this.win.b) { const first = this.win.first; this.commit(); this.win = null; this.info(first ? 'recdone' : 'dubdone'); }
            else { const q = tf - this.O, ps = Math.floor(q / len), p = q - ps * len;
              if (this.pass !== ps) { this.commit(); this.cur = this.take(); this.pass = ps; this.info('need'); }
              this.cur[p] += x; this.dirty = true; } } } }
    }
    if (++this.n >= 12) { this.n = 0; this.port.postMessage({ ev: 'lvl', v: this.pk }); this.pk = 0; }
    return true;
  }
}
registerProcessor('dxloop', DxLoop);
class DxCap extends AudioWorkletProcessor {                     // hands the raw input to the page in 4096-sample blocks (chords + notes mode)
  constructor() { super(); this.b = new Float32Array(4096); this.n = 0; }
  process(inputs) { const x = inputs[0] && inputs[0][0]; if (x) { this.b.set(x, this.n); this.n += x.length; if (this.n >= 4096) { this.port.postMessage(this.b.slice(0, this.n)); this.n = 0; } } return true; }
}
registerProcessor('dxcap', DxCap);
