"""Independent (floating-point) reconstruction of the status document's 33-spin
Anderson-type lower bound.

Cluster: centres {+-e1,+-e2,+-e3,+-(1,1,1)} and their 25 neighbours, 48 bonds.
Bond classes under the cluster symmetry group (order 432):
  a: axis centre -> origin (6)            b: axis centre -> 2 e_k (6)
  c1: axis centre -> (+-)(e_a+e_b) leaf adjacent to a diagonal centre (12)
  c2: axis centre -> mixed-sign leaf (12)
  d: diagonal centre -> shared leaf (6)  e: diagonal centre -> private leaf (6)
Each class has the same number of bonds in each direction, so translating the
weighted cluster over the torus gives W*H with W = sum_k n_k w_k / 3, hence
E0/N >= E_c(w)/W.  E_c(w) is computed in the S^z=17/2 sector (8 down spins),
restricted to the fully symmetric (Perron) sector of dimension 447635.

This module provides the shared construction (orbits, class matrices, energy).
Its main() is a slow derivative-free search; the optimisation actually used is
cluster33_opt.py (exact Hellmann-Feynman gradients) and the rigorous bound comes
from cluster33_certificate.py.
"""
import sys
import time
from itertools import combinations

import numpy as np
from scipy.optimize import minimize
from scipy.sparse import coo_matrix, csr_matrix
from scipy.sparse.linalg import eigsh

centers = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1), (1, 1, 1), (-1, -1, -1)]
units = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
add = lambda a, b: tuple(x + y for x, y in zip(a, b))
leaves = sorted({add(c, u) for c in centers for u in units})
sites = centers + leaves
idx = {s: k for k, s in enumerate(sites)}
bonds = [(idx[c], idx[add(c, u)]) for c in centers for u in units]
nsite = len(sites)


def bond_class(ci, li):
    c, l = sites[ci], sites[li]
    if c in [(1, 1, 1), (-1, -1, -1)]:
        return "d" if 0 in l else "e"
    if l == (0, 0, 0):
        return "a"
    if l == tuple(2 * x for x in c):
        return "b"
    s = sum(c)                       # +1 or -1
    other = [x for x, y in zip(l, c) if y == 0 and x != 0][0]
    return "c1" if other == s else "c2"


classes = ["a", "b", "c1", "c2", "d", "e"]
bcls = np.array([classes.index(bond_class(i, j)) for i, j in bonds])
ncls = np.bincount(bcls, minlength=6)


def lattice_perms():
    from itertools import permutations, product
    out = []
    bset = {frozenset((sites[i], sites[j])) for i, j in bonds}
    for perm in permutations(range(3)):
        for sg in product((1, -1), repeat=3):
            f = lambda s: tuple(sg[k] * s[perm[k]] for k in range(3))
            if {f(s) for s in sites} == set(sites) and {frozenset((f(sites[i]), f(sites[j]))) for i, j in bonds} == bset:
                out.append(np.array([idx[f(s)] for s in sites]))
    return out


def leaf_perms():
    nb = {k: set() for k in range(nsite)}
    for i, j in bonds:
        nb[i].add(j); nb[j].add(i)
    groups = {}
    for k in range(len(centers), nsite):
        groups.setdefault(frozenset(nb[k]), []).append(k)
    out = []
    for g in groups.values():
        if len(g) > 1:
            for a, b in zip(g, g[1:]):
                p = np.arange(nsite); p[a], p[b] = b, a; out.append(p)
    return out


def permute_bits(x, p):
    y = np.zeros_like(x)
    for i in range(nsite):
        y |= ((x >> np.uint64(i)) & np.uint64(1)) << np.uint64(p[i])
    return y


def build(return_all=False):
    t0 = time.time()
    ndown = 8
    conf = np.fromiter((sum(1 << i for i in c) for c in combinations(range(nsite), ndown)), dtype=np.uint64)
    conf.sort()
    n = len(conf)
    print("configurations:", n, "(%.0fs)" % (time.time() - t0)); sys.stdout.flush()
    gens = lattice_perms()[1:] + leaf_perms()
    lab = np.arange(n, dtype=np.int64)
    images = [np.searchsorted(conf, permute_bits(conf, p)) for p in gens]
    while True:
        old = lab.copy()
        for im in images:
            m = np.minimum(lab, lab[im])
            lab = m
            np.minimum.at(lab, im, m)
        if np.array_equal(old, lab):
            break
    reps, inv, sizes = np.unique(lab, return_inverse=True, return_counts=True)
    print("orbits:", len(reps), "(%.0fs)" % (time.time() - t0)); sys.stdout.flush()
    # matrices per bond class in the orthonormal orbit basis (Marshall-rotated: off-diagonal -w/2)
    rconf = conf[reps]
    no = len(reps)
    mats = []
    for k in range(6):
        rows, cols, vals = [], [], []
        diag = np.zeros(no)
        for bi in np.where(bcls == k)[0]:
            i, j = bonds[bi]
            si = (rconf >> np.uint64(i)) & np.uint64(1)
            sj = (rconf >> np.uint64(j)) & np.uint64(1)
            anti = si != sj
            diag += np.where(anti, -0.25, 0.25)
            src = np.where(anti)[0]
            flipped = rconf[src] ^ (np.uint64(1 << i) | np.uint64(1 << j))
            dst = inv[np.searchsorted(conf, flipped)]
            rows.append(dst); cols.append(src)
            vals.append(-0.5 * np.sqrt(sizes[src] / sizes[dst]))
        rows = np.concatenate(rows + [np.arange(no)]); cols = np.concatenate(cols + [np.arange(no)])
        vals = np.concatenate(vals + [diag])
        mats.append(csr_matrix(coo_matrix((vals, (rows, cols)), shape=(no, no))))
    print("matrices built (%.0fs)" % (time.time() - t0)); sys.stdout.flush()
    if return_all:
        return mats, conf, inv, sizes, rconf
    return mats


def energy(mats, w, v0=None):
    H = sum(wk * m for wk, m in zip(w, mats))
    e, v = eigsh(H, k=1, which="SA", v0=v0, tol=1e-12)
    return e[0], v[:, 0]


def main():
    print("bond class sizes (a,b,c1,c2,d,e):", ncls.tolist())
    mats = build()
    # symmetric check of the orbit-basis construction: the matrix must be symmetric
    Hs = sum(mats)
    print("symmetry check |H - H^T|_max =", abs(Hs - Hs.T).max())
    state = {"v": None}

    def bound(x):
        w = np.exp(np.concatenate([[0.0], x]))          # w_a = 1 fixes the scale
        e, v = energy(mats, w, state["v"])
        state["v"] = np.abs(v)
        W = (ncls * w).sum() / 3
        return e / W

    x0 = np.zeros(5)
    print("uniform weights: bound per site = %.7f" % bound(x0)); sys.stdout.flush()
    res = minimize(lambda x: -bound(x), x0, method="Nelder-Mead",
                   options={"xatol": 1e-5, "fatol": 1e-9, "maxiter": 600, "disp": True})
    w = np.exp(np.concatenate([[0.0], res.x]))
    b = bound(res.x)
    print("optimal weights (a,b,c1,c2,d,e) =", np.round(w / w.min(), 6))
    print("optimal bound per site = %.8f   total = %.6f" % (b, 8000 * b))
    print("status document: -7584.244762 (per site %.8f)" % (-7584.244762 / 8000))


if __name__ == "__main__":
    main()
