import sys
d, N = int(sys.argv[1]), int(sys.argv[2])
gens = "{" + ", ".join("x%d" % i for i in range(1, d + 1)) + "}"
T = [[1 if (i == j or (i, j) == (0, 1)) else 0 for j in range(d)] for i in range(d)]
C = [[1 if j == (i - 1) % d else 0 for j in range(d)] for i in range(d)]
lines = ["1", "c2d%d" % d, "2", "1", "1", gens, "{}", "0", "7", "9", "1", "2"]
for M in (T, C):
    lines += [" ".join(map(str, row)) for row in M]
lines += ["0", "5", "30", "1", "1", str(N), "0", "1", "1", "0", "0"]
print("\n".join(lines))
