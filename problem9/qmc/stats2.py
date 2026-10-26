"""Analyse sse2 bin files: four energy estimators, optimal unbiased combination."""
import sys
import numpy as np

def load(fn, Lx, Ly, Lz, beta, skip=0):
    d = np.loadtxt(fn, ndmin=2)[skip:]
    N = Lx*Ly*Lz; Nb = ((Lx>1)+(Ly>1)+(Lz>1))*N
    n, noff, D, mz2, ms2 = d.T
    E = np.vstack([0.25*Nb - n/beta, 0.75*D, -1.5*noff/beta]).T
    return E, mz2, ms2

def combo(E):
    C = np.cov(E.T)
    one = np.ones(E.shape[1])
    w = np.linalg.solve(C, one); w /= w.sum()
    return w, E @ w

def rebin(x, k):
    m = len(x)//k
    return x[:m*k].reshape(m, k, *x.shape[1:]).mean(axis=1)

if __name__ == "__main__":
    fn = sys.argv[1]; Lx, Ly, Lz = map(int, sys.argv[2:5]); beta = float(sys.argv[5])
    skip = int(sys.argv[6]) if len(sys.argv) > 6 else 0
    E, mz2, ms2 = load(fn, Lx, Ly, Lz, beta, skip)
    names = ["E_n", "3E_zz", "1.5E_off"]
    nb = len(E)
    print("%s: %d bins" % (fn, nb))
    for k, nm in enumerate(names):
        print("  %-11s %.6f +- %.6f   (bin std %.4f)" % (nm, E[:, k].mean(), E[:, k].std(ddof=1)/np.sqrt(nb), E[:, k].std(ddof=1)))
    w, Ec = combo(E)
    print("  optimal w =", np.round(w, 4), " E = %.6f +- %.6f" % (Ec.mean(), Ec.std(ddof=1)/np.sqrt(nb)))
    print("  mz2 = %.6f +- %.6f   ms2 = %.7f +- %.7f" % (mz2.mean(), mz2.std(ddof=1)/np.sqrt(nb), ms2.mean(), ms2.std(ddof=1)/np.sqrt(nb)))
