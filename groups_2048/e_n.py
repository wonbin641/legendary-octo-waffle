# Independent Burnside count of groups of order 2^n with P_3(G)=1.
# e_n = sum_d (1/|GL_d|) sum_g #{(n-d)-dim S^2(g)-invariant subspaces of S^2(F_2^d)}
# Module structure of S^2(g) is computed numerically (ranks of f(T)^k), not by theory.
from fractions import Fraction
from functools import lru_cache
import itertools, sys

def pmul(a,b):
    r=0
    while b:
        if b&1: r^=a
        a<<=1; b>>=1
    return r
def pmod(a,m):
    dm=m.bit_length()
    while a.bit_length()>=dm: a^=m<<(a.bit_length()-dm)
    return a
def irreducibles(deg):
    out=[]
    for p in range(1<<deg,1<<(deg+1)):
        if all(pmod(p,q) for k in range(1,deg//2+1) for q in irreducibles_c(k)): out.append(p)
    return out
@lru_cache(None)
def irreducibles_c(k): return tuple(irreducibles(k))
def parts(n,mx=None):
    if mx is None: mx=n
    if n==0: yield (); return
    for k in range(min(n,mx),0,-1):
        for r in parts(n-k,k): yield (k,)+r
def conj(l):
    return tuple(sum(1 for x in l if x>i) for i in range(l[0] if l else 0))
def cent(l,q):
    lc=conj(l); s=sum(x*x for x in lc); res=Fraction(q)**s
    from collections import Counter
    for mlt in Counter(l).values():
        for j in range(1,mlt+1): res*=1-Fraction(1,q**j)
    return res
def classes(d):
    # rational canonical forms: multiset of (irreducible f != x, partition)
    polys=[(f,k) for k in range(1,d+1) for f in irreducibles_c(k) if f!=2]
    def rec(i,rem):
        if rem==0: yield []; return
        if i==len(polys): return
        f,k=polys[i]
        yield from rec(i+1,rem)
        for s in range(1,rem//k+1):
            for l in parts(s):
                for rest in rec(i+1,rem-k*s): yield [(f,k,l)]+rest
    yield from rec(0,d)
def companion(p):
    k=p.bit_length()-1; M=[[0]*k for _ in range(k)]
    for i in range(1,k): M[i][i-1]=1
    for i in range(k): M[i][k-1]=(p>>i)&1
    return M
def blockdiag(bs):
    n=sum(len(b) for b in bs); M=[[0]*n for _ in range(n)]; o=0
    for b in bs:
        for i in range(len(b)):
            for j in range(len(b)): M[o+i][o+j]=b[i][j]
        o+=len(b)
    return M
def rep(cls):
    bs=[]
    for f,k,l in cls:
        for e in l:
            p=1
            for _ in range(e): p=pmul(p,f)
            bs.append(companion(p))
    return blockdiag(bs)
def sym2(g):
    d=len(g); idx={}
    pairs=[(i,j) for i in range(d) for j in range(i,d)]
    for t,p in enumerate(pairs): idx[p]=t
    m=len(pairs); T=[[0]*m for _ in range(m)]
    for c,(i,j) in enumerate(pairs):
        a=[g[l][i] for l in range(d)]; b=[g[l][j] for l in range(d)]
        for l in range(d):
            if a[l]&b[l]: T[idx[(l,l)]][c]^=1
            for l2 in range(l+1,d):
                if (a[l]&b[l2])^(a[l2]&b[l]): T[idx[(l,l2)]][c]^=1
    return T
# matrices as lists of int rows (bitmasks over columns)
def tobits(M): return [sum(v<<j for j,v in enumerate(r)) for r in M]
def mm(A,B,n):
    # rows bitmask: (AB)_i = xor of B_j for j in A_i
    out=[]
    for r in A:
        s=0; j=0
        while r:
            if r&1: s^=B[j]
            r>>=1; j+=1
        out.append(s)
    return out
def rank(M):
    rows=[r for r in M if r]; rk=0
    while rows:
        p=rows.pop(); 
        if not p: continue
        rk+=1; hb=p.bit_length()-1
        rows=[r^p if (r>>hb)&1 else r for r in rows]
        rows=[r for r in rows if r]
    return rk
def polyeval(f,T,n):
    I=[1<<i for i in range(n)]; R=[0]*n; P=I
    k=0
    while f>>k:
        if (f>>k)&1: R=[a^b for a,b in zip(R,P)]
        P=mm(P,T,n); k+=1
    return R
def charpoly_factors(T,n,R):
    # find irreducible f with nontrivial kernel, and partitions
    res=[]; tot=0
    for k in range(1,min(n,R)+1):
        if tot==n: break
        for f in irreducibles_c(k):
            F=polyeval(f,T,n); P=[1<<i for i in range(n)]; dims=[0]
            while True:
                P=mm(P,F,n); dims.append(n-rank(P))
                if dims[-1]==dims[-2]: break
            if dims[-1]==0: continue
            # dims[e] = k * sum_i min(lambda_i, e) ; conjugate partition parts = (dims[e]-dims[e-1])/k
            lc=[(dims[e]-dims[e-1])//k for e in range(1,len(dims)-1)]
            res.append((k,tuple(lc))); tot+=dims[-1]
    assert R<n or tot==n
    return res
def gauss(n,k,q):
    if k<0 or k>n: return 0
    r=Fraction(1)
    for i in range(k): r*=Fraction(q**(n-i)-1,q**(i+1)-1)
    return int(r)
def birk(lc,mc,q):
    L=len(lc); lc=list(lc)+[0]; mc=list(mc)+[0]*(L+1-len(mc)); r=1
    for i in range(L):
        r*=q**(mc[i+1]*(lc[i]-mc[i]))*gauss(lc[i]-mc[i+1],mc[i]-mc[i+1],q)
    return r
def subpart_counts(lc,q):
    # poly: size |mu| -> number of submodules
    lam=[sum(1 for x in lc if x>i) for i in range(lc[0])] if lc else []
    out={}
    def rec(i,prev,cur):
        if i==len(lam):
            mu=[x for x in cur if x]; mc=conj(tuple(mu)) if mu else ()
            s=sum(mu); out[s]=out.get(s,0)+birk(lc,mc,q); return
        for v in range(min(lam[i],prev),-1,-1): rec(i+1,v,cur+[v])
    rec(0,10**9,[])
    return out
def inv_subspace_poly(T,n,R):
    poly={0:1}
    for k,lc in charpoly_factors(T,n,R):
        c=subpart_counts(lc,2**k); new={}
        for a,x in poly.items():
            for b,y in c.items(): new[a+k*b]=new.get(a+k*b,0)+x*y
        poly=new
    return poly
def GLorder(d):
    r=1
    for i in range(d): r*=2**d-2**i
    return r
N=int(sys.argv[1])
tot={n:Fraction(0) for n in range(N+1)}; tot[0]=Fraction(1)
byd={}
for d in range(1,N+1):
    mass=Fraction(0); m=d*(d+1)//2
    for cls in classes(d):
        c=1
        for f,k,l in cls: c*=cent(l,2**k)
        mass+=1/c
        T=tobits(sym2(rep(cls))); P=inv_subspace_poly(T,m,N-d)
        for r,cnt in P.items():
            if d+r<=N:
                tot[d+r]+=Fraction(cnt)/c
                byd[(d+r,d)]=byd.get((d+r,d),0)+Fraction(cnt)/c
    assert mass==1,(d,mass)
    print("d",d,"done",file=sys.stderr)
for n in range(N+1):
    assert tot[n].denominator==1; print(n,tot[n])
for (n,d),v in sorted(byd.items()):
    assert v.denominator==1; print('n=%d d=%d'%(n,d),v)
