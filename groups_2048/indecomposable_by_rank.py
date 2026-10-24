"""Rank-graded Krull-Remak-Schmidt inversion.

sum_{n,d} a[n][d] x^n y^d = prod_{n,d} (1 - x^n y^d)^(-b[n][d]),
where a[n][d] = number of groups of order 2^n and rank d, and b[n][d] = number
of directly indecomposable ones.  Given a (for the (n,d) needed), recover b.
"""
from math import comb


def multiset_coeffs(b, N, R):
    """c[n][d] = number of multisets of indecomposables with total (n,d),
    computed from b restricted to the pairs present."""
    c = [[0] * (R + 1) for _ in range(N + 1)]
    c[0][0] = 1
    for n0 in range(1, N + 1):
        for d0 in range(1, R + 1):
            k = b[n0][d0]
            if not k:
                continue
            new = [row[:] for row in c]
            for n in range(N + 1):
                for d in range(R + 1):
                    if not c[n][d]:
                        continue
                    j = 1
                    while n + j * n0 <= N and d + j * d0 <= R:
                        new[n + j * n0][d + j * d0] += c[n][d] * comb(k + j - 1, j)
                        j += 1
            c = new
    return c


def invert(a, N, R):
    b = [[0] * (R + 1) for _ in range(N + 1)]
    for n in range(1, N + 1):
        for d in range(1, min(n, R) + 1):
            c = multiset_coeffs(b, N, R)  # b[n][d] still 0 here
            b[n][d] = a[n][d] - c[n][d]
    return b


if __name__ == "__main__":
    # SmallGroups library counts by rank (orders 2^1..2^7) - validation input
    small = {1: [1], 2: [1, 1], 3: [1, 3, 1], 4: [1, 8, 4, 1], 5: [1, 19, 24, 6, 1],
             6: [1, 53, 137, 68, 7, 1], 7: [1, 162, 833, 1153, 169, 9, 1]}
    N, R = 7, 7
    a = [[0] * (R + 1) for _ in range(N + 1)]
    for n, row in small.items():
        for d, v in enumerate(row, 1):
            a[n][d] = v
    b = invert(a, N, R)
    direct = {5: [1, 17, 14, 2, 0], 6: [1, 50, 109, 40, 1, 0],
              7: [1, 159, 754, 987, 97, 2, 0]}  # DirectFactorsOfGroup on SmallGroups
    for n, row in direct.items():
        assert b[n][1:n + 1] == row, (n, b[n][1:n + 1], row)
    print("validation against DirectFactorsOfGroup (orders 2^5..2^7): OK")
