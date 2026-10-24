from math import comb
a=[1,1,2,5,14,51,267,2328,56092,10494213,49487367289]   # OEIS A000679, n=0..10
e=[1,1,2,4,8,23,90,780,30079,8785773,48803495723]
def inv_euler(a):
    b=[0]*len(a)
    for n in range(1,len(a)):
        # coefficient of x^n in prod_{k<n}(1-x^k)^{-b_k}
        p=[1]+[0]*n
        for k in range(1,n):
            q=[0]*(n+1)
            for i in range(n+1):
                if p[i]:
                    for j in range(0,(n-i)//k+1): q[i+j*k]+=p[i]*comb(b[k]+j-1,j)
            p=q
        b[n]=a[n]-p[n]
    return b
def coef(b,n):
    p=[1]+[0]*n
    for k in range(1,n):
        q=[0]*(n+1)
        for i in range(n+1):
            if p[i]:
                for j in range(0,(n-i)//k+1): q[i+j*k]+=p[i]*comb(b[k]+j-1,j)
        p=q
    return p[n]
b=inv_euler(a); h=inv_euler(e)
print(b); print(h)
D=coef(b,11); Dg=coef(h,11); print(D,Dg,D-Dg)
print(1774274116992171+D-Dg+5)
