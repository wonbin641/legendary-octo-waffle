"""Exact diagonalisation reference for small periodic lattices (validates sse.c).

Builds the same bond list as sse.c (duplicate bonds for L=2 included), and
prints thermal <H>, <(S^z_tot)^2>, <(sum_x (-1)^x S^z_x)^2>/N^2 at given betas,
plus the ground-state energy.

usage: python3 ed_check.py Lx Ly Lz beta1 [beta2 ...]
"""
import sys
from itertools import combinations

import numpy as np


def bonds(L):
    Lx, Ly, Lz = L
    out = []
    for z in range(Lz):
        for y in range(Ly):
            for x in range(Lx):
                i = x + Lx * (y + Ly * z)
                for mu in range(3):
                    if L[mu] == 1:
                        continue
                    c = [x, y, z]
                    c[mu] = (c[mu] + 1) % L[mu]
                    out.append((i, c[0] + Lx * (c[1] + Ly * c[2])))
    return out


def main():
    L = tuple(int(a) for a in sys.argv[1:4])
    betas = [float(a) for a in sys.argv[4:]]
    N = L[0] * L[1] * L[2]
    B = bonds(L)
    par = np.array([(i % L[0] + (i // L[0]) % L[1] + i // (L[0] * L[1])) % 2 for i in range(N)])
    levels = []  # (energy, sz2, ms2)
    for nup in range(N + 1):
        states = [sum(1 << k for k in c) for c in combinations(range(N), nup)]
        index = {s: k for k, s in enumerate(states)}
        dim = len(states)
        H = np.zeros((dim, dim))
        for k, s in enumerate(states):
            for (i, j) in B:
                si, sj = (s >> i) & 1, (s >> j) & 1
                if si == sj:
                    H[k, k] += 0.25
                else:
                    H[k, k] -= 0.25
                    H[index[s ^ (1 << i) ^ (1 << j)], k] += 0.5
        w, v = np.linalg.eigh(H)
        bits = np.array([[(s >> i) & 1 for i in range(N)] for s in states])
        ms = ((bits - 0.5) * np.where(par == 0, 1, -1)).sum(axis=1)
        ms2 = (v ** 2 * (ms ** 2)[:, None]).sum(axis=0) / N ** 2
        sz2 = (nup - N / 2) ** 2
        levels += [(w[a], sz2, ms2[a]) for a in range(dim)]
    E = np.array([l[0] for l in levels])
    SZ = np.array([l[1] for l in levels])
    MS = np.array([l[2] for l in levels])
    print("N=%d bonds=%d E0=%.12f" % (N, len(B), E.min()))
    for beta in betas:
        wts = np.exp(-beta * (E - E.min()))
        Z = wts.sum()
        print("beta=%g  <H>=%.10f  <Sz^2>=%.10f  <ms2>=%.10f" %
              (beta, (wts * E).sum() / Z, (wts * SZ).sum() / Z, (wts * MS).sum() / Z))


if __name__ == "__main__":
    main()
