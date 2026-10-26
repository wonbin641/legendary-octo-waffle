"""Brute-force check of the closed-form energy of |psi> = exp(-i th sum_<ab> X_a Y_b)|Neel>
(a in A, b in B) on small periodic bipartite lattices, against
  <S_i.S_j> = (1/4) * ( -2 sin(2th) cos(2th)^(z-1) - cos(2th)^(2(z-1)) ).
"""
import numpy as np
from itertools import product

def lattice(L):
    sites = list(product(*[range(l) for l in L]))
    idx = {s: k for k, s in enumerate(sites)}
    bonds = []
    for s in sites:
        for mu in range(len(L)):
            t = list(s); t[mu] = (t[mu] + 1) % L[mu]
            bonds.append((idx[s], idx[tuple(t)]))
    par = [sum(s) % 2 for s in sites]
    return len(sites), bonds, par

X = np.array([[0, 1], [1, 0]], complex); Y = np.array([[0, -1j], [1j, 0]]); Z = np.diag([1., -1.]).astype(complex)

def apply1(psi, Op, k, N):
    psi = psi.reshape((2,) * N)
    psi = np.tensordot(Op, psi, axes=([1], [k]))
    return np.moveaxis(psi, 0, k).reshape(-1)

def check(L, th):
    N, bonds, par = lattice(L)
    z = 2 * len(L)
    # Neel: A (par 0) up = index 0, B down = index 1 ; basis |0>=up
    psi = np.zeros(2 ** N, complex)
    psi[int("".join("0" if par[k] == 0 else "1" for k in range(N)), 2)] = 1
    # all P_ab = X_a Y_b commute, P^2 = 1  ->  exp(-i th P) = cos th - i sin th P
    for (i, j) in bonds:
        a, b = (i, j) if par[i] == 0 else (j, i)
        Ppsi = apply1(apply1(psi, X, a, N), Y, b, N)
        psi = np.cos(th) * psi - 1j * np.sin(th) * Ppsi
    E = 0
    for (i, j) in bonds:
        for O in (X, Y, Z):
            E += 0.25 * np.vdot(psi, apply1(apply1(psi, O, i, N), O, j, N)).real
    s, c = np.sin(2 * th), np.cos(2 * th)
    formula = len(bonds) * 0.25 * (-2 * s * c ** (z - 1) - c ** (2 * (z - 1)))
    return E, formula

for L in [(4, 4), (4, 4, 2)[:2], (6, 2)]:
    pass
for L, th in [((4, 4), 0.1), ((4, 4), 0.23), ((6, 4), 0.17)]:
    E, f = check(L, th)
    print(L, th, "brute=%.12f formula=%.12f diff=%.2e" % (E, f, E - f))
