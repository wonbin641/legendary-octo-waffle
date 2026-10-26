"""SSE (sse3) estimators vs exact diagonalisation on small periodic lattices."""
import numpy as np
ref = {}
for line in open("ed_reference.txt"):
    if line.startswith("#"): continue
    lat, b, E, sz2, ms2 = line.split()
    ref[(lat, float(b))] = (float(E), float(sz2), float(ms2))
files = {("2x2x2", 1): "v_222_b1.dat", ("2x2x2", 4): "v_222_b4.dat", ("4x2x1", 1): "v_421_b1.dat",
         ("4x2x1", 4): "v_421_b4.dat", ("4x4x1", 2): "v_441_b2.dat", ("4x4x1", 8): "v_441_b8.dat"}
print("| lattice | beta | ED <H> | E_n | E_mix | E_RB2 | ED <(S^z)^2> | SSE | ED m_s^2 | SSE |")
print("|---|---|---|---|---|---|---|---|---|---|")
for (lat, b), fn in files.items():
    L = list(map(int, lat.split("x"))); N = L[0]*L[1]*L[2]; Nb = sum(l > 1 for l in L) * N
    d = np.loadtxt(fn)
    n, noff, D, mz2, ms2, ca, ns, nd = d.T
    est = [0.25*Nb - n/b, 0.25*D - noff/b, -0.25*ca - (ns + 0.5*nd)/b]
    f = lambda x: "%.4f(%d)" % (x.mean(), round(1e4 * x.std(ddof=1)/np.sqrt(len(x))))
    E, s, m = ref[(lat, float(b))]
    print("| %s | %g | %.4f | %s | %s | %s | %.4f | %s | %.4f | %s |" % (lat, b, E, f(est[0]), f(est[1]), f(est[2]), s, f(mz2), m, f(ms2)))
    z = [(x.mean() - E)/(x.std(ddof=1)/np.sqrt(len(x))) for x in est]
    print("<!-- z-scores E_n, E_mix, E_RB2: %s -->" % np.round(z, 2))
