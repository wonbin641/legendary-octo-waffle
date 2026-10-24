"""Parallel p-group generation tree walk: one standalone pq job per capable
class-2 group (subtree), each in its own directory, then sum the counts."""
import os, re, subprocess, sys, collections
from concurrent.futures import ThreadPoolExecutor

PQ = "/opt/anupq_patched/bin/x86_64-pc-linux-gnu-default64-kv9/pq"
ENV = dict(os.environ, ANUPQ_GAP_EXEC="/opt/gapbuild/gap-4.14.0/gap")
d, N, workers, base = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
os.makedirs(base, exist_ok=True)

def mkin(class_bound):
    gens = "{" + ", ".join("x%d" % i for i in range(1, d + 1)) + "}"
    T = [[1 if (i == j or (i, j) == (0, 1)) else 0 for j in range(d)] for i in range(d)]
    C = [[1 if j == (i - 1) % d else 0 for j in range(d)] for i in range(d)]
    L = ["1", "c2d%d" % d, "2", "1", "1", gens, "{}", "0", "7", "9", "1", "2"]
    for Mx in (T, C):
        L += [" ".join(map(str, r)) for r in Mx]
    L += ["0", "5", str(class_bound), "1", "1", str(N), "0", "1", "1", "0", "0"]
    return "\n".join(L) + "\n"

def counts(path):
    c = collections.Counter()
    for l in open(path):
        m = re.match(r"# of immediate descendants of order 2\^(\d+) is (\d+)", l)
        if m:
            c[int(m.group(1))] += int(m.group(2))
    return c

def run(dirname, inp):
    os.makedirs(dirname, exist_ok=True)
    out = os.path.join(dirname, "out")
    if os.path.exists(out) and "Total user time" in open(out).read():
        return out                      # already done (restartable)
    with open(out, "w") as f:
        subprocess.run([PQ], input=inp.encode(), stdout=f, stderr=subprocess.STDOUT,
                       cwd=dirname, env=ENV, check=False)
    return out

# root: class-2 descendants of C_2^d only
root = os.path.join(base, "root")
rout = run(root, mkin(2))
ncap = int(re.search(r"(\d+) capable groups saved on file c2d%d_class2" % d, open(rout).read()).group(1))
classfile = os.path.join(root, "c2d%d_class2" % d)
print("root counts", sorted(counts(rout).items()), "capable class-2 groups:", ncap, flush=True)

def job(i):
    inp = "9\n3\n%s\n%d\n5\n30\n1\n1\n%d\n0\n1\n1\n0\n0\n" % (classfile, i, N)
    out = run(os.path.join(base, "g%03d" % i), inp)
    ok = "Total user time" in open(out).read()
    return i, counts(out), ok

total = counts(rout)
with ThreadPoolExecutor(workers) as ex:
    for i, c, ok in ex.map(job, range(ncap, 0, -1)):   # heavy (late) groups first
        total += c
        print("subtree", i, "done" if ok else "INCOMPLETE", sum(c.values()), flush=True)
print("TOTAL", sorted(total.items()), flush=True)
