"""Integrated autocorrelation time of E_n from per-sweep sse2 output."""
import sys
import numpy as np

def tau_int(x, wmax=200):
    x = x - x.mean(); n = len(x); v = x.var()
    f = np.fft.rfft(np.concatenate([x, np.zeros(n)]))
    acf = np.fft.irfft(f * np.conj(f))[:n] / (v * np.arange(n, 0, -1))
    tau = 0.5
    for w in range(1, wmax):
        tau += acf[w]
        if w >= 6 * tau: break
    return tau, acf[:6]

beta = float(sys.argv[1])
for spec in sys.argv[2:]:
    fn, cost = spec.split(':'); cost = float(cost)
    d = np.loadtxt(fn)[200:]
    E = 6000 - d[:, 0] / beta
    tau, acf = tau_int(E)
    var = E.var()
    eff = var * 2 * tau * cost  # variance x seconds per sweep: smaller is better
    print("%s: <E>=%.3f  std/sweep=%.2f  tau_int=%.2f  acf=%s  var*2tau*cost=%.1f" %
          (fn, E.mean(), np.sqrt(var), tau, np.round(acf, 3), eff))
