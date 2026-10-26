"""Elementary, self-contained rigorous bounds on E0 for H = sum_<ij> S_i.S_j on (Z/20Z)^3.

Lower:  H = (1/2) sum_x S_x . (sum_{y~x} S_y) and each star term >= -2  ==>  E0 >= -N = -8000.
Upper:  |psi_t> = prod_<ab> exp(-i th X_a Y_b) |Neel>,  t = tan(th) rational:
        <S_i.S_j> = (1/4)(-2 s c^5 - c^10),  s = 2t/(1+t^2), c = (1-t^2)/(1+t^2)
        (closed form verified by brute force in one_layer_check.py); exact rational arithmetic.
Also the Neel product state: E0 <= -Nb/4 = -6000.
"""
from fractions import Fraction as F

N, Nb = 8000, 24000

def star_min():
    # S_x . T with T = total spin of the 6 neighbours (T = 0..3):  min = -(T+1)/2 over T>=1/2 -> T=3
    return min(Fraction_val for Fraction_val in [F(-(T + 1), 2) for T in range(1, 4)])

def one_layer(t):
    s = 2 * t / (1 + t * t)
    c = (1 - t * t) / (1 + t * t)
    return Nb * F(1, 4) * (-2 * s * c ** 5 - c ** 10)

lower = F(N, 2) * star_min()
best = min((one_layer(F(k, 10000)), F(k, 10000)) for k in range(860, 900))
print("E0 >= %s  (= %.6f)" % (lower, float(lower)))
print("E0 <= -6000 (Neel product state)")
print("E0 <= %s ... = %.9f   (one-layer state, tan(theta) = %s)" % (str(best[0])[:40], float(best[0]), best[1]))
print("rigorous elementary interval width = %.6f" % float(best[0] - lower))
