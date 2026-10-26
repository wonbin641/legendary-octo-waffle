"""Rigorous (exact integer) certificate for the 33-spin Anderson-type lower bound.

For positive integer bond weights w (one per bond class, see cluster33_bound.py),
C = 4 H_c in the Marshall-rotated S^z=17/2 basis is an integer matrix with
off-diagonal entries <= 0.  For any positive vector v,
    C - diag((Cv)_i / v_i) = sum_{i<j} (-C_ij) v_i v_j (e_i/v_i - e_j/v_j)(e_i/v_i - e_j/v_j)^T  >= 0,
so lambda_min(C) >= min_i (Cv)_i/v_i  (Collatz-Wielandt).  v is constant on orbits of the
order-432 symmetry group, so (Cv)_i is constant on orbits and only the 447635 orbit
representatives are checked.  v comes from eigsh refined by power iteration with the
nonnegative matrix sI - H (no cancellations, so even tiny components are accurate),
then scaled to Python integers; (Cv) and the minimum ratio are computed exactly.
Result: E0 >= N * min_i (Cv)_i/v_i / (4 W),  W = sum_k n_k w_k / 3.

usage: python3 cluster33_certificate.py w_a w_b w_c1 w_c2 w_d w_e
"""
import sys
from fractions import Fraction

import numpy as np

import cluster33_bound as cb


def main():
    w = [int(a) for a in sys.argv[1:7]]
    assert len(w) == 6 and min(w) > 0
    mats, conf, inv, sizes, rconf = cb.build(return_all=True)
    Hm = sum(wk * m for wk, m in zip(w, mats))            # orthonormal orbit basis, float
    e, psi = cb.energy(mats, np.array(w, float))
    print("float cluster ground energy with these weights: %.12f" % e)
    psi = np.abs(psi)
    s = Hm.diagonal().max() + 1.0
    for it in range(4000):                                # power iteration with s - H >= 0
        p = s * psi - Hm @ psi
        r = p / psi
        psi = p / np.linalg.norm(p)
        if it % 500 == 0 or it == 3999:
            print("  power it %4d: ratio spread %.3e  (s - ratio range [%.9f, %.9f])"
                  % (it, r.max() - r.min(), s - r.max(), s - r.min()))
    u = psi / np.sqrt(sizes)                              # amplitude of every configuration in its orbit
    print("dynamic range of the Perron vector: %.3e" % (u.min() / u.max()))
    scale = 10.0 ** 15 / u.min()
    v = [int(round(x * scale)) for x in u]                # exact positive integers
    vo = np.array(v, dtype=object)
    no = len(rconf)
    Cv = np.zeros(no, dtype=object)
    for bi, (i, j) in enumerate(cb.bonds):
        wb = w[cb.bcls[bi]]
        si = (rconf >> np.uint64(i)) & np.uint64(1)
        sj = (rconf >> np.uint64(j)) & np.uint64(1)
        anti = si != sj
        Cv += np.where(anti, -wb, wb).astype(object) * vo  # diagonal: 4 * (+-1/4) * w
        src = np.where(anti)[0]
        flipped = rconf[src] ^ (np.uint64(1 << i) | np.uint64(1 << j))
        dst = inv[np.searchsorted(conf, flipped)]
        contrib = np.zeros(no, dtype=object)
        np.add.at(contrib, src, (-2 * wb) * vo[dst])      # off-diagonal: 4 * (-1/2) * w
        Cv += contrib
    ratio = np.array([float(Fraction(int(a), int(b))) for a, b in zip(Cv, v)])
    m = ratio.min()
    cand = np.where(ratio <= m + 1e-9 * abs(m))[0]
    dmin = min(Fraction(int(Cv[k]), int(v[k])) for k in cand)
    W = Fraction(sum(int(n) * wk for n, wk in zip(cb.ncls, w)), 3)
    bound = 8000 * dmin / (4 * W)
    print("weights:", w, " W =", W, " candidates checked exactly:", len(cand))
    print("certified: lambda_min(4 H_c) >= %.12f  (float 4E_c = %.12f)" % (float(dmin), 4 * e))
    print("certified lower bound E0 >= %s" % bound)
    print("                         = %.10f  (per site %.12f)" % (float(bound), float(bound) / 8000))
    print("status document bound: -7584.244762 ; ours is %s" %
          ("at least as strong" if bound >= Fraction("-7584.244762") else "weaker"))


if __name__ == "__main__":
    main()
