"""Final analysis of the 20^3 SSE production runs.

Files in runs/:
  b{beta}_s{k}.dat      (sse2)  columns: n, n_off, D, mz2, ms2
  b{beta}_s{k}_rb.dat   (sse3)  columns: n, n_off, D, mz2, ms2, conn, n_same_off, n_diff
Every line is an average over one bin of sweeps.

Unbiased energy estimators (H = sum_b S_i.S_j, Nb = 24000):
  E_n   = Nb/4 - n/beta                                  standard SSE
  E_mix = D/4 - n_off/beta                               (diagonal + off-diagonal SSE estimators)
  E_RB2 = -conn/4 - (n_same_off + n_diff/2)/beta         = E[E_mix | loop structure]
Per file the lowest-variance estimator is used (E_mix for sse2 files, E_RB2 for sse3
files); errors from pairwise rebinning; files combined with inverse-variance weights.
T -> 0: E0 = E(beta) - E_rot(beta), with the quantum-rotor (Anderson tower) energy
E_rot of levels S(S+1)/(2I), I fixed by <(S^z_tot)^2> = <S(S+1)>/3.
"""
import glob
import json
import sys

import numpy as np

N, Nb = 8000, 24000


def rebin_errors(x):
    errs, y = [], np.asarray(x, float)
    while len(y) >= 16:
        errs.append(y.std(ddof=1) / np.sqrt(len(y)))
        m = len(y) // 2
        y = 0.5 * (y[:2 * m:2] + y[1:2 * m:2])
    return errs


def plateau(errs):
    return max(errs[-3:]) if len(errs) >= 3 else errs[-1]


def rotor_energy(beta, I, Smax=5000):
    S = np.arange(Smax, dtype=float)
    e = S * (S + 1) / (2 * I)
    w = (2 * S + 1) * np.exp(-beta * e)
    return float((w * e).sum() / w.sum())


def rotor_sz2(beta, I, Smax=5000):
    S = np.arange(Smax, dtype=float)
    w = (2 * S + 1) * np.exp(-beta * S * (S + 1) / (2 * I))
    return float((w * S * (S + 1)).sum() / w.sum() / 3)


def rotor_inertia(beta, mz2):
    """I such that the rotor gives <(S^z_tot)^2> = mz2 (bisection)"""
    lo, hi = 1.0, 1e6
    for _ in range(200):
        mid = np.sqrt(lo * hi)
        if rotor_sz2(beta, mid) < mz2: lo = mid
        else: hi = mid
    return np.sqrt(lo * hi)


def estimators(d, beta):
    out = {"E_n": 0.25 * Nb - d[:, 0] / beta, "E_mix": 0.25 * d[:, 2] - d[:, 1] / beta}
    if d.shape[1] >= 8:
        out["E_RB2"] = -0.25 * d[:, 5] - (d[:, 6] + 0.5 * d[:, 7]) / beta
    return out


def analyse_beta(beta, skip_old=5, skip_new=1, verbose=True):
    vals, errs, mz = [], [], []
    rows = []
    for fn in sorted(glob.glob("runs/b%d_s*.dat" % beta)):
        d = np.loadtxt(fn, ndmin=2)
        d = d[(skip_new if fn.endswith("_rb.dat") else skip_old):]
        if len(d) < 16:
            continue
        est = estimators(d, beta)
        best = "E_RB2" if "E_RB2" in est else "E_mix"
        x = est[best]
        e = plateau(rebin_errors(x))
        vals.append(x.mean()); errs.append(e); mz.append(d[:, 3])
        rows.append({"file": fn, "bins": len(d), "estimator": best, "E": x.mean(), "err": e,
                     "others": {k: [float(v.mean()), plateau(rebin_errors(v))] for k, v in est.items()}})
        if verbose:
            o = "  ".join("%s=%.3f(%.3f)" % (k, v[0], v[1]) for k, v in rows[-1]["others"].items())
            print("  %-24s bins=%5d  %s" % (fn, len(d), o))
    vals, errs = np.array(vals), np.array(errs)
    w = 1 / errs ** 2
    E = float((w * vals).sum() / w.sum()); dE = float(1 / np.sqrt(w.sum()))
    chi2 = float(((vals - E) ** 2 * w).sum() / max(len(vals) - 1, 1))
    allmz = np.concatenate(mz)
    mz2, dmz2 = float(allmz.mean()), plateau(rebin_errors(allmz))
    I = rotor_inertia(beta, mz2)
    Erot = rotor_energy(beta, I)
    dErot = abs(rotor_energy(beta, rotor_inertia(beta, mz2 + dmz2)) - Erot)
    res = {"beta": beta, "E_beta": E, "err": dE, "chi2_dof": chi2, "mz2": mz2, "mz2_err": dmz2, "I": I,
           "E_rot": Erot, "E_rot_err": dErot, "E0": E - Erot, "E0_err": float(np.hypot(dE, dErot)), "files": rows}
    if verbose:
        print("  beta=%g: E(beta) = %.4f +- %.4f  (chi2/dof = %.2f over %d files)" % (beta, E, dE, chi2, len(vals)))
        print("           <mz^2> = %.4f +- %.4f -> I = %.1f, E_rot = %.5f +- %.5f (1/beta = %.5f)"
              % (mz2, dmz2, I, Erot, dErot, 1 / beta))
        print("           E0 = %.4f +- %.4f   (per site %.7f +- %.7f)" % (res["E0"], res["E0_err"], res["E0"] / N, res["E0_err"] / N))
    return res


if __name__ == "__main__":
    results = []
    for beta in (32, 64):
        if glob.glob("runs/b%d_s*.dat" % beta):
            print("beta = %d" % beta)
            results.append(analyse_beta(beta))
    v = np.array([r["E0"] for r in results]); e = np.array([r["E0_err"] for r in results])
    w = 1 / e ** 2
    E0 = float((w * v).sum() / w.sum()); dE0_stat = float(1 / np.sqrt(w.sum()))
    # PDG-style scale factor when the temperatures disagree by more than their errors
    chi2 = float(((v - E0) ** 2 * w).sum()); dof = max(len(v) - 1, 1)
    scale = max(1.0, np.sqrt(chi2 / dof))
    dE0 = dE0_stat * scale
    print("combined E0 = %.4f +- %.4f   (per site %.7f +- %.7f); chi2/dof = %.2f, error scale %.2f"
          % (E0, dE0, E0 / N, dE0 / N, chi2 / dof, scale))
    if len(results) == 2:
        diff = results[0]["E0"] - results[1]["E0"]
        print("beta=32 vs beta=64 after rotor correction: diff = %.4f +- %.4f" % (diff, np.hypot(*e)))
    if len(sys.argv) > 1:
        json.dump({"per_beta": results, "E0": E0, "E0_err": dE0, "E0_err_stat": dE0_stat,
                   "chi2_dof_beta": chi2 / dof, "error_scale": scale}, open(sys.argv[1], "w"), indent=1)
