"""Check the status document's 33-spin cluster: sites, bonds, sector size and the number
of symmetry-reduced representatives (447635), via Burnside's lemma for candidate groups."""
from itertools import permutations, product
from math import comb

centers = [(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1),(1,1,1),(-1,-1,-1)]
units = [(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]
add = lambda a, b: tuple(x + y for x, y in zip(a, b))
leaves = sorted({add(c, u) for c in centers for u in units})
sites = centers + leaves
bonds = [(c, add(c, u)) for c in centers for u in units]
print("sites:", len(sites), " centers:", len(centers), " leaves:", len(leaves), " bonds:", len(bonds))
print("S^z = 17/2 sector (8 down spins): C(33,8) =", comb(33, 8))
idx = {s: k for k, s in enumerate(sites)}

# lattice symmetries of the cluster: signed axis permutations preserving the site set
lat = []
for perm in permutations(range(3)):
    for sg in product((1, -1), repeat=3):
        f = lambda s, perm=perm, sg=sg: tuple(sg[k] * s[perm[k]] for k in range(3))
        if {f(s) for s in sites} == set(sites) and {frozenset((f(a), f(b))) for a, b in bonds} == {frozenset(b) for b in bonds}:
            lat.append(tuple(idx[f(s)] for s in sites))
print("lattice symmetry group of the cluster: order", len(lat))

# private leaves (adjacent to exactly one centre); groups of interchangeable ones
nb = {s: set() for s in sites}
for a, b in bonds:
    nb[a].add(b); nb[b].add(a)
classes = {}
for l in leaves:
    classes.setdefault(frozenset(nb[l]), []).append(l)
swap_classes = [v for v in classes.values() if len(v) > 1]
print("interchangeable leaf classes:", swap_classes)

def compose(p, q):  # p after q
    return tuple(p[q[i]] for i in range(len(q)))

def generate(gens):
    e = tuple(range(len(sites)))
    G = {e}; frontier = [e]
    while frontier:
        new = []
        for g in frontier:
            for h in gens:
                x = compose(h, g)
                if x not in G:
                    G.add(x); new.append(x)
        frontier = new
    return G

leaf_gens = []
for cl in swap_classes:
    a, b = idx[cl[0]], idx[cl[1]]
    c = idx[cl[2]] if len(cl) > 2 else None
    t = list(range(len(sites))); t[a], t[b] = b, a; leaf_gens.append(tuple(t))
    if c is not None:
        t = list(range(len(sites))); t[a], t[b], t[c] = b, c, a; leaf_gens.append(tuple(t))

def orbits(G, k=8):
    total = 0
    for g in G:
        seen, cyc = set(), []
        for i in range(len(g)):
            if i in seen: continue
            n, j = 0, i
            while j not in seen:
                seen.add(j); j = g[j]; n += 1
            cyc.append(n)
        poly = [1] + [0] * k                       # coefficient of x^k in prod (1 + x^len)
        for n in cyc:
            for d in range(k, n - 1, -1):
                poly[d] += poly[d - n]
        total += poly[k]
    assert total % len(G) == 0
    return total // len(G)

G1 = generate(lat)
G2 = generate(lat + leaf_gens)
print("orbits under lattice group (order %d): %d" % (len(G1), orbits(G1)))
print("orbits under lattice group + leaf permutations (order %d): %d" % (len(G2), orbits(G2)))
