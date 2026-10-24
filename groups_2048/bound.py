"""Assemble the rigorous lower bound for the number f(2048) of groups of order 2^11.

All terms are pairwise disjoint:
  e11        groups with P_3(G) = 1                         (Burnside count, e_n.py)
  D - Dgood  decomposable groups with P_3(G) != 1           (Euler transform, euler.py)
  b11[d]     indecomposable groups of rank d with P_3 != 1  (d = 1, 2, 3, 9; this script)
Every group of order 2^11 and rank <= 3 has P_3(G) != 1 (P_3 = 1 forces 11 <= d + d(d+1)/2),
so all indecomposable groups of rank <= 3 are new.  For rank 9 the groups with P_3 != 1 are
counted by step1.g; the decomposable ones among them are exactly K x C_2 with K of order 2^10,
rank 8 and P_3(K) != 1.
"""
import sys
from indecomposable_by_rank import invert

# ---- inputs -----------------------------------------------------------------------------
e11 = 1774274116992171            # groups of order 2^11 with P_3 = 1 (incl. C_2^11)
D, Dgood = 49497988786, 48812312655  # decomposable groups / decomposable with P_3 = 1

# number of groups of order 2^n with rank d (d = 1, 2, 3), n <= 11
# n <= 9: SmallGroups library; n = 10, 11: ANUPQ tree walk (pq_runs/)
N2 = {2: 1, 3: 3, 4: 8, 5: 19, 6: 53, 7: 162, 8: 540, 9: 2043, 10: 9121, 11: 47486}
N3 = {3: 1, 4: 4, 5: 24, 6: 137, 7: 833, 8: 6190, 9: 58859}
# command line:  --n3 N3(10) N3(11)   (pq tree walk)   --c C(10) C(11)   (gap/step1.g)
# where C(n) = number of groups of order 2^n, rank n-2, with P_3 != 1
args = sys.argv[1:]
c = {}
if "--n3" in args:
    i = args.index("--n3"); N3[10], N3[11] = int(args[i + 1]), int(args[i + 2])
if "--c" in args:
    i = args.index("--c"); c[10], c[11] = int(args[i + 1]), int(args[i + 2])

# ---- rank-graded Krull-Remak-Schmidt inversion for ranks <= 3 ----------------------------
N, R = 11, (3 if 11 in N3 else 2)
a = [[0] * (R + 1) for _ in range(N + 1)]
for n in range(1, N + 1):
    a[n][1] = 1
    a[n][2] = N2.get(n, 0)
    if R == 3:
        a[n][3] = N3[n] if n in N3 else 0
b = invert(a, N, R)
print("indecomposable, rank 1..3, order 2^11:", b[11][1:])
assert b[11][1] == 1 and b[11][2] == N2[11] - 5

bound = e11 + (D - Dgood) + b[11][1] + b[11][2]
if 11 in N3:
    bound += b[11][3]
    print("indecomposable rank 3:", b[11][3], "(decomposable rank 3:", N3[11] - b[11][3], ")")
if c:
    print("indecomposable rank 9 with P_3 != 1:", c[11] - c[10])
    bound += c[11] - c[10]
print("lower bound f(2048) >=", bound)
