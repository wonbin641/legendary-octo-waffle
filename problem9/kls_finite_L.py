"""Rigorous Neel-order and low-lying-triplet bounds for the L=20 periodic cubic S=1/2 AFM.

Ingredients (all for the finite torus (Z/LZ)^3, L even, unique S=0 ground state):
  * infrared bound (Dyson-Lieb-Simon):  chi_p <= 1/(2 E_{p+Q}),  E_p = sum_mu (1 - cos p_mu)
  * double commutator:                   c_p = <[S^1_{-p},[H,S^1_p]]> = (4/9) eps E_p,  eps = -E0/N
  * Cauchy-Schwarz (T=0 Falk-Bruch):     g_p <= sqrt(c_p chi_p)/2 <= sqrt(eps E_p / (18 E_{p+Q}))
  * sum rules:  (1/N) sum_p g_p = 1/4,   (1/N) sum_p g_p E_p = 3/4 + eps/3,   g_0 = 0 (singlet)
For any cut c in [0,6) (weights E_p - c; terms with E_p < c are dropped since g_p >= 0):

  m2 := <(sum_x (-1)^x S^1_x)^2>/N^2 >= [3/4 + eps/3 - c/4 - sqrt(eps/18) S(c)] / (6 - c),
  S(c) = (1/N) sum_{p != 0,Q ; E_p > c} (E_p - c) sqrt(E_p/(6 - E_p)),

and the S=1, k=Q state S^1_Q|GS> gives  E_1(S=1,k=Q) - E0 <= c_Q/(2 g_Q) = (4/3) eps / (N m2).
All sums are evaluated with outward-rounded interval arithmetic (mpmath.iv); eps is
swept over [eps_lo, eps_hi] in sub-intervals, so the printed numbers are rigorous.

usage: python3 kls_finite_L.py [L]
"""
import sys
from collections import Counter

from mpmath import iv, mpf

iv.prec = 100


def momentum_classes(L):
    half = [min(n, L - n) for n in range(L)]
    cnt = Counter(tuple(sorted((half[a], half[b], half[c])))
                  for a in range(L) for b in range(L) for c in range(L))
    return [(key, mult, sum(1 - iv.cos(2 * iv.pi * k / L) for k in key)) for key, mult in cnt.items()]


def S_of_cut(classes, L, c):
    N = L ** 3
    q = (L // 2,) * 3
    S = iv.mpf(0)
    for key, mult, E in classes:
        if key == (0, 0, 0) or key == q or E.b <= c:
            continue
        if E.a <= c:
            return None                      # cut inside an E_p interval: skip this c
        S += mult * (E - c) * iv.sqrt(E / (6 - E))
    return S / N


def bounds(S, c, N, eps_lo, eps_hi, K=400):
    m2_lo, gap_hi = None, None
    for k in range(K):
        e = iv.mpf([eps_lo + (eps_hi - eps_lo) * k / K, eps_lo + (eps_hi - eps_lo) * (k + 1) / K])
        m2 = (iv.mpf(3) / 4 + e / 3 - iv.mpf(c) / 4 - iv.sqrt(e / 18) * S) / (6 - iv.mpf(c))
        if m2.a <= 0:
            return None, None
        gap = (iv.mpf(4) / 3) * e / (N * m2)
        m2_lo = m2.a if m2_lo is None else min(m2_lo, m2.a)
        gap_hi = gap.b if gap_hi is None else max(gap_hi, gap.b)
    return m2_lo, gap_hi


def main():
    L = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    N = L ** 3
    classes = momentum_classes(L)
    cuts = [mpf(k) / 100 for k in range(0, 300)]
    Svals = [(c, S_of_cut(classes, L, c)) for c in cuts]
    cases = [("elementary: E0 in [-8000, -7078.7617937]", mpf("7078.761793") / N, mpf(1)),
             ("status-doc certificates: E0 in [-7584.244762, -7176.848195]", mpf("7176.848194") / N, mpf("7584.244762") / N)]
    for name, lo, hi in cases:
        best_m2, best_gap = None, None
        for c, S in Svals:
            if S is None:
                continue
            m2, gap = bounds(S, c, N, lo, hi, K=60)
            if m2 is None:
                continue
            if best_m2 is None or m2 > best_m2[0]:
                best_m2 = (m2, c)
            if best_gap is None or gap < best_gap[0]:
                best_gap = (gap, c)
        # re-evaluate the two optimal cuts with a fine eps grid
        cm, cg = best_m2[1], best_gap[1]
        m2, _ = bounds(dict(Svals)[cm], cm, N, lo, hi)
        _, gap = bounds(dict(Svals)[cg], cg, N, lo, hi)
        print("L=%d, %s" % (L, name))
        print("   eps = -E0/N in [%.7f, %.7f]" % (float(lo), float(hi)))
        print("   cut c=%.2f:  m2 (one component)            >= %.6f" % (float(cm), float(m2) - 5e-7))
        print("               <(sum (-1)^x S_x)^2>/N^2      >= %.6f" % (3 * float(m2) - 5e-7))
        print("   cut c=%.2f:  E1(S=1,k=Q) - E0            <= %.6f" % (float(cg), float(gap) + 5e-7))


if __name__ == "__main__":
    main()
