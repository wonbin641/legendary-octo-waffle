/*
 * sse2.c -- production SSE QMC (Sandvik) with deterministic operator-loop
 * updates for the spin-1/2 Heisenberg antiferromagnet
 *
 *     H = sum_<ij> S_i . S_j        (J = 1, every nearest-neighbour bond once)
 *
 * on a periodic Lx x Ly x Lz simple-cubic lattice (all L even, or 1 to drop a
 * direction).  Bond operators H_b = 1/4 - S_i.S_j, so H = Nb/4 - sum_b H_b.
 *
 * Per sweep it records (bin averages are written to the output file):
 *   n      number of non-identity operators          E_n   = Nb/4 - n/beta
 *   noff   number of off-diagonal operators          E_off = -noff/beta
 *   D      sum_b s_i s_j (s = +-1) averaged over the n propagated states
 *                                                     E_zz  = D/4
 *   mz2    (S^z_tot)^2,  ms2 = (sum_x (-1)^x S^z_x)^2 / N^2   at slice 0
 * SU(2) symmetry gives <E_off> = 2<E_zz>, so E_n, 3E_zz, (3/2)E_off and
 * E_zz + E_off are four unbiased estimators of <H>.
 *
 * Usage: sse2 Lx Ly Lz beta n_therm n_bins bin_size seed outfile [checkpoint]
 * With a checkpoint file the run resumes from it (no re-thermalisation) and
 * appends to outfile.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <sys/mman.h>

/* ---------------- random numbers: xoshiro256** ---------------- */
static uint64_t rs[4];
static inline uint64_t rotl(uint64_t x, int k) { return (x << k) | (x >> (64 - k)); }
static inline uint64_t rnext(void)
{
    const uint64_t r = rotl(rs[1] * 5, 7) * 9, t = rs[1] << 17;
    rs[2] ^= rs[0]; rs[3] ^= rs[1]; rs[1] ^= rs[2]; rs[0] ^= rs[3];
    rs[2] ^= t; rs[3] = rotl(rs[3], 45);
    return r;
}
static inline double urand(void) { return (double)(rnext() >> 11) * 0x1.0p-53; }
static inline uint32_t randint(uint32_t m) { return (uint32_t)(((rnext() >> 32) * (uint64_t)m) >> 32); }
static void seed_rng(uint64_t seed)
{
    for (int i = 0; i < 4; i++) {
        uint64_t z = (seed += 0x9e3779b97f4a7c15ULL);
        z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
        z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
        rs[i] = z ^ (z >> 31);
    }
}

/* ---------------- lattice ---------------- */
static int Lx, Ly, Lz, N, Nb;
static int *bsite;          /* 2*Nb : sites of bond b                      */
static int *nbr, *ndeg;     /* neighbours of each site (with multiplicity) */
static int8_t *stag;        /* (-1)^(x+y+z)                                */

static void make_lattice(void)
{
    int L[3] = {Lx, Ly, Lz};
    N = Lx * Ly * Lz;
    Nb = ((Lx > 1) + (Ly > 1) + (Lz > 1)) * N;
    bsite = malloc(sizeof(int) * 2 * Nb);
    nbr = malloc(sizeof(int) * 6 * N);
    ndeg = calloc(N, sizeof(int));
    stag = malloc(N);
    int b = 0;
    for (int z = 0; z < Lz; z++)
        for (int y = 0; y < Ly; y++)
            for (int x = 0; x < Lx; x++) {
                int i = x + Lx * (y + Ly * z);
                stag[i] = ((x + y + z) & 1) ? -1 : 1;
                for (int mu = 0; mu < 3; mu++) {
                    if (L[mu] == 1) continue;
                    int c[3] = {x, y, z};
                    c[mu] = (c[mu] + 1) % L[mu];
                    int j = c[0] + Lx * (c[1] + Ly * c[2]);
                    bsite[2 * b] = i; bsite[2 * b + 1] = j;
                    nbr[6 * i + ndeg[i]++] = j;
                    nbr[6 * j + ndeg[j]++] = i;
                    b++;
                }
            }
}

/* ---------------- SSE configuration ---------------- */
static int M, n;
static int *op;             /* M  : -1 identity, else 2*b + type (0 diag, 1 off-diag) */
static int *X;              /* 4M : vertex links                                      */
static int *first, *last;
static int8_t *spin;
static double beta;

static void *huge_realloc(void *ptr, size_t oldsz, size_t sz)
{
    /* 2 MB aligned buffers with transparent huge pages: the loop update is
     * dominated by pointer chasing through X, so TLB misses matter */
    const size_t A = 2u << 20;
    size_t asz = (sz + A - 1) / A * A;
    void *q = aligned_alloc(A, asz);
    if (!q) { fprintf(stderr, "out of memory\n"); exit(1); }
    madvise(q, asz, MADV_HUGEPAGE);
    if (ptr) { memcpy(q, ptr, oldsz < sz ? oldsz : sz); free(ptr); }
    return q;
}

static void alloc_config(int newM)
{
    op = huge_realloc(op, sizeof(int) * (size_t)M, sizeof(int) * (size_t)newM);
    for (int p = M; p < newM; p++) op[p] = -1;
    X = huge_realloc(X, 0, sizeof(int) * 4 * (size_t)newM);
    M = newM;
}

/* sum over the neighbours k of i (k != j) of s_i s_k */
static inline int edge_sum(int i, int j)
{
    int c = 0;
    for (int k = 0; k < ndeg[i]; k++) { int m = nbr[6 * i + k]; if (m != j) c += spin[m]; }
    return c * spin[i];
}

/* diagonal update; returns sum over the n propagated states of D = sum_b s_i s_j
 * and the number of off-diagonal operators via *noff */
static double diag_update(int *noff)
{
    const double aprob = 0.5 * beta * Nb;
    long D = 0;
    for (int b = 0; b < Nb; b++) D += spin[bsite[2 * b]] * spin[bsite[2 * b + 1]];
    double Dsum = 0;
    int no = 0;
    for (int p = 0; p < M; p++) {
        int o = op[p];
        if (o < 0) {
            int b = (int)randint((uint32_t)Nb);
            if (spin[bsite[2 * b]] != spin[bsite[2 * b + 1]] && urand() * (M - n) < aprob) {
                op[p] = 2 * b; n++;
                Dsum += D;
            }
        } else if (!(o & 1)) {
            if (urand() * aprob < (M - n + 1)) { op[p] = -1; n--; }
            else Dsum += D;
        } else {
            int b = o >> 1, i = bsite[2 * b], j = bsite[2 * b + 1];
            D -= 2 * (edge_sum(i, j) + edge_sum(j, i));
            spin[i] = -spin[i];
            spin[j] = -spin[j];
            Dsum += D; no++;
        }
    }
    *noff = no;
    return Dsum;
}

static void link_vertices(void)
{
    for (int i = 0; i < N; i++) first[i] = last[i] = -1;
    for (int p = 0; p < M; p++) {
        int o = op[p];
        if (o < 0) continue;
        int b = o >> 1, v0 = 4 * p, i1 = bsite[2 * b], i2 = bsite[2 * b + 1];
        int v1 = last[i1], v2 = last[i2];
        if (v1 >= 0) { X[v1] = v0; X[v0] = v1; } else first[i1] = v0;
        if (v2 >= 0) { X[v2] = v0 + 1; X[v0 + 1] = v2; } else first[i2] = v0 + 1;
        last[i1] = v0 + 2; last[i2] = v0 + 3;
    }
    for (int i = 0; i < N; i++)
        if (first[i] >= 0) { X[first[i]] = last[i]; X[last[i]] = first[i]; }
}

/*
 * Same update, but NCUR loops are traced concurrently (interleaved pointer
 * chasing hides memory latency).  Each cursor labels a contiguous arc of a loop
 * (X[v] = -(label+1)); arcs of one loop are merged by union-find:
 *  - a cursor stops when its next leg is already labelled and merges with it;
 *  - a new cursor started at leg s merges with the arc owning X[s] if that leg
 *    is labelled (two arcs that started next to each other and moved apart).
 * Every boundary between two arcs of a loop is covered by one of these rules,
 * so union-find roots are exactly the loops; each root is flipped with
 * probability 1/2 in a final sequential pass.
 */
#ifndef NCUR
#define NCUR 16
#endif
static int *uf;
static uint8_t *ufl;
static int ufcap;

static inline int uf_find(int a)
{
    while (uf[a] != a) { uf[a] = uf[uf[a]]; a = uf[a]; }
    return a;
}
static inline void uf_union(int a, int b)
{
    a = uf_find(a); b = uf_find(b);
    if (a < b) uf[b] = a; else if (b < a) uf[a] = b;
}

static void loop_update_mc(void)
{
    if (ufcap < 2 * M + NCUR) {
        ufcap = 2 * M + NCUR;
        uf = realloc(uf, sizeof(int) * ufcap);
        ufl = realloc(ufl, ufcap);
    }
    int nlab = 0, cur[NCUR], lab[NCUR], act[NCUR], nact = 0;
    long scan = 0, nlegs = 4L * M;
    for (int k = 0; k < NCUR; k++) act[k] = 0;
    for (;;) {
        for (int k = 0; k < NCUR; k++) {
            if (!act[k]) {
                /* find the next unlabelled even leg of a real vertex */
                while (scan < nlegs && (op[scan >> 2] < 0 || X[scan] < 0)) scan += 2;
                if (scan >= nlegs) continue;
                int s = (int)scan, l = nlab++;
                uf[l] = l; lab[k] = l; act[k] = 1; nact++;
                int u = X[s], nxt = X[s ^ 1];
                X[s] = X[s ^ 1] = -(l + 1);
                if (X[u] < 0) uf_union(l, -X[u] - 1);
                cur[k] = nxt;
                if (X[nxt] < 0) { uf_union(l, -X[nxt] - 1); act[k] = 0; nact--; }
                continue;
            }
            int v = cur[k], l = lab[k];
            /* another cursor may have reached v since our last step */
            if (X[v] < 0) { uf_union(l, -X[v] - 1); act[k] = 0; nact--; continue; }
            int nxt = X[v ^ 1];
            X[v] = X[v ^ 1] = -(l + 1);
            cur[k] = nxt;
            if (X[nxt] < 0) { uf_union(l, -X[nxt] - 1); act[k] = 0; nact--; }
        }
        if (nact == 0 && scan >= nlegs) break;
    }
    for (int l = 0; l < nlab; l++)
        if (uf[l] == l) ufl[l] = (uint8_t)(rnext() >> 63);
    for (int p = 0; p < M; p++) {
        if (op[p] < 0) continue;
        int r1 = uf_find(-X[4 * p] - 1), r2 = uf_find(-X[4 * p + 2] - 1);
        if (ufl[r1] ^ ufl[r2]) op[p] ^= 1;
    }
    for (int i = 0; i < N; i++) {
        if (first[i] >= 0) { if (ufl[uf_find(-X[first[i]] - 1)]) spin[i] = -spin[i]; }
        else if (rnext() >> 63) spin[i] = -spin[i];
    }
}

/* construct all loops, flip each with probability 1/2 (X entries become -1 / -2) */
static void loop_update(void)
{
    for (int p = 0; p < M; p++) {
        if (op[p] < 0) continue;
        for (int h = 0; h < 4; h += 2) {
            int v0 = 4 * p + h;
            if (X[v0] < 0) continue;
            int v = v0;
            if (rnext() >> 63) {
                do {
                    op[v >> 2] ^= 1;
                    X[v] = -2;
                    int vp = v ^ 1;
                    v = X[vp];
                    X[vp] = -2;
                } while (v != v0);
            } else {
                do {
                    X[v] = -1;
                    int vp = v ^ 1;
                    v = X[vp];
                    X[vp] = -1;
                } while (v != v0);
            }
        }
    }
    for (int i = 0; i < N; i++) {
        if (first[i] >= 0) { if (X[first[i]] == -2) spin[i] = -spin[i]; }
        else if (rnext() >> 63) spin[i] = -spin[i];
    }
}

/* ---------------- checkpointing ---------------- */
static int save_ckpt(const char *fn)
{
    char tmp[1024]; snprintf(tmp, sizeof tmp, "%s.tmp", fn);
    FILE *f = fopen(tmp, "wb"); if (!f) return -1;
    int hdr[5] = {Lx, Ly, Lz, M, n};
    fwrite(hdr, sizeof(int), 5, f); fwrite(&beta, sizeof(double), 1, f);
    fwrite(rs, sizeof(uint64_t), 4, f);
    fwrite(op, sizeof(int), M, f); fwrite(spin, 1, N, f);
    fclose(f); return rename(tmp, fn);
}
static int load_ckpt(const char *fn)
{
    FILE *f = fopen(fn, "rb"); if (!f) return -1;
    int hdr[5]; double b;
    if (fread(hdr, sizeof(int), 5, f) != 5 || fread(&b, sizeof(double), 1, f) != 1) { fclose(f); return -1; }
    if (hdr[0] != Lx || hdr[1] != Ly || hdr[2] != Lz || b != beta) { fclose(f); fprintf(stderr, "checkpoint mismatch\n"); exit(1); }
    alloc_config(hdr[3]); n = hdr[4];
    if (fread(rs, sizeof(uint64_t), 4, f) != 4 || fread(op, sizeof(int), M, f) != (size_t)M ||
        fread(spin, 1, N, f) != (size_t)N) { fclose(f); fprintf(stderr, "bad checkpoint\n"); exit(1); }
    fclose(f); return 0;
}

static double now(void)
{
    struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + 1e-9 * t.tv_nsec;
}

int main(int argc, char **argv)
{
    if (argc < 10) {
        fprintf(stderr, "usage: %s Lx Ly Lz beta n_therm n_bins bin_size seed outfile [checkpoint]\n"
                        "env: SSE_MFAC (M/n target, default 1.33), SSE_NDIAG (diagonal updates per loop update, default 1),\n"
                        "     SSE_SERIAL_LOOPS (set: trace loops one at a time)\n",
                argv[0]);
        return 1;
    }
    Lx = atoi(argv[1]); Ly = atoi(argv[2]); Lz = atoi(argv[3]); beta = atof(argv[4]);
    long ntherm = atol(argv[5]), nbins = atol(argv[6]), binsize = atol(argv[7]);
    uint64_t seed = strtoull(argv[8], 0, 10);
    const char *outfn = argv[9], *ckfn = argc > 10 ? argv[10] : NULL;
    double mfac = getenv("SSE_MFAC") ? atof(getenv("SSE_MFAC")) : 4.0 / 3.0;
    int ndiag = getenv("SSE_NDIAG") ? atoi(getenv("SSE_NDIAG")) : 1;
    int multicursor = getenv("SSE_SERIAL_LOOPS") ? 0 : 1;
    make_lattice();
    first = malloc(sizeof(int) * N); last = malloc(sizeof(int) * N);
    spin = malloc(N);

    int resumed = ckfn && load_ckpt(ckfn) == 0;
    if (!resumed) {
        seed_rng(seed);
        M = 0; n = 0;
        alloc_config(20 + (int)(beta * Nb / 4));
        for (int i = 0; i < N; i++) spin[i] = stag[i];          /* Neel start */
        int noff;
        for (long s = 0; s < ntherm; s++) {
            for (int k = 0; k < ndiag; k++) diag_update(&noff);
            if (n > M / mfac) alloc_config((int)(mfac * n) + 20);
            link_vertices();
            if (multicursor) loop_update_mc(); else loop_update();
        }
        if (ckfn) save_ckpt(ckfn);
    }
    fprintf(stderr, "L=%dx%dx%d beta=%g M=%d n=%d resumed=%d mfac=%g ndiag=%d\n", Lx, Ly, Lz, beta, M, n,
            resumed, mfac, ndiag);

    double tdiag = 0, tlink = 0, tloop = 0;
    FILE *out = fopen(outfn, "a");
    for (long bin = 0; bin < nbins; bin++) {
        double sn = 0, snoff = 0, sD = 0, smz = 0, sms = 0;
        for (long s = 0; s < binsize; s++) {
            int noff = 0;
            double t0 = now(), dn = 0, dD = 0;
            for (int k = 0; k < ndiag; k++) {
                double Dsum = diag_update(&noff);
                dn += n; dD += (n > 0) ? Dsum / n : 0;
            }
            double t1 = now();
            link_vertices();
            double t2 = now();
            if (multicursor) loop_update_mc(); else loop_update();
            double t3 = now();
            tdiag += t1 - t0; tlink += t2 - t1; tloop += t3 - t2;
            long mz = 0, ms = 0;
            for (int i = 0; i < N; i++) { mz += spin[i]; ms += stag[i] * spin[i]; }
            sn += dn / ndiag; snoff += noff;
            sD += dD / ndiag;
            smz += 0.25 * (double)mz * mz;
            sms += 0.25 * (double)ms * ms / ((double)N * N);
        }
        fprintf(out, "%.6f %.6f %.8f %.8f %.10f\n", sn / binsize, snoff / binsize, sD / binsize,
                smz / binsize, sms / binsize);
        fflush(out);
        if (ckfn && (bin % 20 == 19 || bin == nbins - 1)) save_ckpt(ckfn);
    }
    fclose(out);
    long nsw = nbins * binsize;
    fprintf(stderr, "time per sweep: diag %.4f s  link %.4f s  loop %.4f s  (M=%d n=%d)\n",
            tdiag / nsw, tlink / nsw, tloop / nsw, M, n);
    return 0;
}
