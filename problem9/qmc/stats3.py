import sys, numpy as np
fn = sys.argv[1]; L = list(map(int, sys.argv[2:5])); beta = float(sys.argv[5]); skip = int(sys.argv[6]) if len(sys.argv) > 6 else 0
N = L[0]*L[1]*L[2]; Nb = ((L[0]>1)+(L[1]>1)+(L[2]>1))*N
d = np.loadtxt(fn, ndmin=2)[skip:]
n, noff, D, mz2, ms2, ca, ns, nd = d.T
est = {"E_n": 0.25*Nb - n/beta, "E_mix": 0.25*D - noff/beta, "E_RB2": -0.25*ca - (ns + 0.5*nd)/beta, "E_imp(3zz)": -0.75*ca}
for k, v in est.items():
    print("  %-11s %.6f +- %.6f  (bin std %.4f)" % (k, v.mean(), v.std(ddof=1)/np.sqrt(len(v)), v.std(ddof=1)))
