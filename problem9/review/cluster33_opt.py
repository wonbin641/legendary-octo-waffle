"""Optimise the 33-spin cluster lower bound with exact gradients, then certify it.

f(w) = E_c(w) / W(w),   W = sum_k n_k w_k / 3,   E0/N >= f(w)  (see cluster33_bound.py)
Hellmann-Feynman: dE_c/dw_k = <psi|H_k|psi>, so df/dw_k = (<H_k> - f n_k/3) / W.
The optimum is rounded to integer weights and certified exactly with
cluster33_certificate.py's positive-vector argument (rerun separately for the record).
"""
import sys
import time

import numpy as np
from scipy.optimize import minimize

import cluster33_bound as cb


def main():
    t0 = time.time()
    mats = cb.build()
    state = {"v": None, "n": 0}

    def fg(x):
        w = np.exp(np.concatenate([[0.0], x]))
        e, v = cb.energy(mats, w, state["v"])
        state["v"] = np.abs(v)
        W = (cb.ncls * w).sum() / 3
        f = e / W
        hk = np.array([v @ (m @ v) for m in mats])
        grad_w = (hk - f * cb.ncls / 3) / W
        grad_x = (grad_w * w)[1:]                  # chain rule for w = exp(x), w_a fixed
        state["n"] += 1
        print("  eval %3d  f = %.10f  w = %s  (%.0fs)" % (state["n"], f, np.round(w, 5), time.time() - t0))
        sys.stdout.flush()
        return -f, -grad_x

    res = minimize(fg, np.zeros(5), jac=True, method="L-BFGS-B", options={"gtol": 1e-10, "ftol": 1e-14, "maxiter": 200})
    w = np.exp(np.concatenate([[0.0], res.x]))
    print("optimum (real weights, w_a = 1):", np.round(w, 8))
    print("optimal bound per site = %.10f  total = %.6f" % (-res.fun, -8000 * res.fun))
    wi = np.rint(1000 * w / w.min()).astype(int)
    print("integer weights for the certificate:", " ".join(map(str, wi)))


if __name__ == "__main__":
    main()
