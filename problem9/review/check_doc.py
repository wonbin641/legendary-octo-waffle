from fractions import Fraction as F
from math import comb, log10, lgamma, log
# 1. lower bound fraction
lb = F(-17245854161006113762086375, 2273905273828601429918)
print("lower bound =", float(lb), " > -7584.244762 ?", lb > F("-7584.244762"))
print("per site", float(lb)/8000, "per bond", float(lb)/24000)
ub = F("-7176.84819477")
print("width ~", float(ub-lb))
# 2. C(8000,4000)
c = comb(8000,4000)
print("C(8000,4000) ~ %.4e" % float(F(c, 10**2406)), "x 1e2406")
# singlet dimension and symmetric-sector estimate
sing = comb(8000,4000) - comb(8000,4001)
print("log10 singlets =", log10(sing))
G = 8000*48
print("log10 singlets/|G| =", log10(sing) - log10(G))
# 3. sample count for 5e-16 at beta=16 using Var(n)/beta^2 >= <n>/beta^2 = (6000 - E)/beta
for E in (-7176.84819477, -7218.5, -7584.244762):
    var = (6000 - E)/16
    print("E=",E," per-sample var >=",var," samples needed >= %.3e" % (var/(5e-16)**2))
# 4. 1-layer circuit closed form check
import math
best=None
for k in range(1,200000):
    x = k*1e-6*2  # x = 2 theta
    s, cc = math.sin(x), math.cos(x)
    f = 0.25*(-2*s*cc**5 - cc**10)
    if best is None or f < best[0]: best=(f,x)
print("1-layer best per-bond", best, "total", best[0]*24000)
