"""Quick (floating point) Anderson-type cluster lower bounds for the cubic S=1/2 AFM.
E0/N >= (#orientations * E_C) / m   where every lattice bond is covered m times by the
translated/rotated copies of the open cluster C (all bond weights 1)."""
import numpy as np, itertools
from scipy.sparse import coo_matrix
from scipy.sparse.linalg import eigsh

def cluster_energy(sites, nup=None):
    idx = {s: k for k, s in enumerate(sites)}
    bonds = []
    for s in sites:
        for mu in range(3):
            t = list(s); t[mu] += 1; t = tuple(t)
            if t in idx: bonds.append((idx[s], idx[t]))
    n = len(sites)
    if nup is None:
        A = sum(1 for s in sites if sum(s) % 2 == 0); nup = (n + abs(2*A - n)) // 2 if False else None
    best = None
    # lowest energy is in |Sz| <= |S_A - S_B| sectors (Lieb-Mattis); use the sector Sz = (|A|-|B|)/2
    A = sum(1 for s in sites if sum(s) % 2 == 0); B = n - A
    ndown = min(A, B)
    states = [sum(1 << k for k in c) for c in itertools.combinations(range(n), n - ndown)]
    index = {s: k for k, s in enumerate(states)}
    rows, cols, vals = [], [], []
    for k, s in enumerate(states):
        d = 0.0
        for i, j in bonds:
            if ((s >> i) ^ (s >> j)) & 1:
                d -= 0.25
                rows.append(index[s ^ (1 << i) ^ (1 << j)]); cols.append(k); vals.append(0.5)
            else:
                d += 0.25
        rows.append(k); cols.append(k); vals.append(d)
    H = coo_matrix((vals, (rows, cols)), shape=(len(states),) * 2).tocsr()
    e = eigsh(H, k=1, which='SA')[0][0] if len(states) > 50 else np.linalg.eigvalsh(H.toarray())[0]
    return e, len(bonds), len(states)

def block(a, b, c):
    return [(x, y, z) for x in range(a) for y in range(b) for z in range(c)]

for name, sites in [("cube 2x2x2", block(2, 2, 2)), ("block 2x2x3", block(2, 2, 3)), ("block 2x2x4", block(2, 2, 4)),
                    ("block 2x3x3", block(2, 3, 3))]:
    e, nb, dim = cluster_energy(sites)
    # per-site bound: each bond direction covered uniformly after averaging over the 3 axis permutations
    # bound per site = E_C * 3 / (bonds of C)   (sum over translations & orientations covers each bond nb/3*...)
    per_site = 3 * e / nb
    print("%-12s sites=%2d bonds=%2d dim=%7d  E_C=%.6f  bound/site=%.6f  total>=%.2f" % (name, len(sites), nb, dim, e, per_site, per_site * 8000))
