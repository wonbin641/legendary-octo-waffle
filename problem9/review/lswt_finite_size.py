"""Linear spin-wave estimate of the finite-size shift of E0 on the L^3 torus (S=1/2, J=1):
E0(L) = -N d S(S+1) + (1/2) sum_k w_k,  w_k = 2 d S sqrt(1 - gamma_k^2),  gamma_k = (1/d) sum cos k_mu.
Delta(L) = (1/2) sum_k w_k - N * (1/2) <w>_BZ ;  the BZ average is extrapolated from large L."""
import numpy as np
d, S = 3, 0.5
def half_sum(L):
    k = 2*np.pi*np.arange(L)/L
    c = np.cos(k)
    g = (c[:,None,None] + c[None,:,None] + c[None,None,:])/3
    w = 2*d*S*np.sqrt(np.clip(1 - g**2, 0, None))
    return 0.5*w.sum(), L**3
vals = {L: half_sum(L) for L in (20, 40, 80, 160, 240)}
# per-site average converges like 1/L^4: fit avg(L) = a0 + a1/L^4 on the large sizes
Ls = np.array([80, 160, 240]); av = np.array([vals[L][0]/vals[L][1] for L in Ls])
A = np.vstack([np.ones(3), Ls**-4.0]).T
a0, a1 = np.linalg.lstsq(A, av, rcond=None)[0]
s20, N20 = vals[20]
print("LSWT e_inf = %.7f" % (-d*S*(S+1) + a0))
print("LSWT Delta(L=20) = E0(20) - N e_inf = %.4f   -> a = Delta*L/... per site coefficient a = %.3f (e(L)=e_inf + a/L^4)"
      % (s20 - N20*a0, (s20/N20 - a0)*20**4))
