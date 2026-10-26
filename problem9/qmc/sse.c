/*
 * sse.c -- Stochastic series expansion (SSE) quantum Monte Carlo with
 * deterministic (Swendsen-Wang type) operator-loop updates for the spin-1/2
 * Heisenberg antiferromagnet
 *
 *     H = sum_<ij> S_i . S_j        (J = 1, every nearest-neighbour bond once)
 *
 * on a periodic Lx x Ly x Lz simple-cubic lattice (all L even, or 1 to drop a
 * direction).  Bond operators H_b = 1/4 - S_i.S_j  (so H = Nb/4 - sum_b H_b).
 *
 * Estimators (per sweep, written as bin averages):
 *   E_n   = Nb/4 - n/beta                       (standard SSE energy)
 *   E_imp = -(3/4) <#bonds whose two sites lie on the same loop>_slices
 *           (loop-improved estimator of sum_b <S_i.S_j>, averaged over the
 *            n propagated states; equal in expectation to E_n)
 *   mz2   = (S^z_tot)^2 at slice 0
 *   ms2   = improved estimator of (sum_x (-1)^x S^z_x)^2 / N^2 at slice 0
 *
 * Usage: sse Lx Ly Lz beta n_therm n_bins bin_size seed outfile [checkpoint]
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

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
static int *bsite;          /* 2*Nb : sites of bond b                    */
static int *sadj, *sdeg;    /* bonds touching each site (<= 6)           */

static void make_lattice(void)
{
    int L[3] = {Lx, Ly, Lz};
    N = Lx * Ly * Lz;
    int ndir = (Lx > 1) + (Ly > 1) + (Lz > 1);
    Nb = ndir * N;
    bsite = malloc(sizeof(int) * 2 * Nb);
    sadj = malloc(sizeof(int) * 6 * N);
    sdeg = calloc(N, sizeof(int));
    int b = 0;
    for (int z = 0; z < Lz; z++)
        for (int y = 0; y < Ly; y++)
            for (int x = 0; x < Lx; x++) {
                int i = x + Lx * (y + Ly * z);
                for (int mu = 0; mu < 3; mu++) {
                    if (L[mu] == 1) continue;
                    int c[3] = {x, y, z};
                    c[mu] = (c[mu] + 1) % L[mu];
                    int j = c[0] + Lx * (c[1] + Ly * c[2]);
                    bsite[2 * b] = i; bsite[2 * b + 1] = j;
                    sadj[6 * i + sdeg[i]++] = b;
                    sadj[6 * j + sdeg[j]++] = b;
                    b++;
                }
            }
}

/* ---------------- SSE configuration ---------------- */
static int M, n;
static int *op;             /* M  : -1 identity, else 2*b + type (0 diag, 1 off-diag) */
static int *X, *lid;        /* 4M : vertex links, loop id of each leg                 */
static int *first, *last, *seg;
static int8_t *spin;
static uint8_t *flipf;      /* flip decision per loop (<= 2M loops)                   */
static int *lcnt;           /* per-loop site count at slice 0                         */
static double beta;

static void alloc_config(int newM)
{
    op = realloc(op, sizeof(int) * newM);
    for (int p = M; p < newM; p++) op[p] = -1;
    X = realloc(X, sizeof(int) * 4 * (size_t)newM);
    lid = realloc(lid, sizeof(int) * 4 * (size_t)newM);
    flipf = realloc(flipf, 2 * (size_t)newM);
    lcnt = realloc(lcnt, sizeof(int) * 2 * (size_t)newM);
    M = newM;
}

static void diag_update(void)
{
    const double aprob = 0.5 * beta * Nb;
    for (int p = 0; p < M; p++) {
        int o = op[p];
        if (o < 0) {
            int b = (int)randint((uint32_t)Nb);
            if (spin[bsite[2 * b]] != spin[bsite[2 * b + 1]] && urand() * (M - n) < aprob) {
                op[p] = 2 * b; n++;
            }
        } else if (!(o & 1)) {
            if (urand() * aprob < (M - n + 1)) { op[p] = -1; n--; }
        } else {
            int b = o >> 1;
            spin[bsite[2 * b]] = -spin[bsite[2 * b]];
            spin[bsite[2 * b + 1]] = -spin[bsite[2 * b + 1]];
        }
    }
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

/* build every loop, flip each with probability 1/2; returns number of loops */
static int loop_update(void)
{
    int nl = 0;
    for (int p = 0; p < M; p++)
        if (op[p] >= 0) { int v = 4 * p; lid[v] = lid[v + 1] = lid[v + 2] = lid[v + 3] = -1; }
    for (int p = 0; p < M; p++) {
        if (op[p] < 0) continue;
        for (int h = 0; h < 4; h += 2) {
            int v0 = 4 * p + h;
            if (lid[v0] >= 0) continue;
            uint8_t f = (uint8_t)(rnext() >> 63);
            int v = v0;
            do {
                int vp = v ^ 1;
                lid[v] = nl; lid[vp] = nl;
                if (f) op[v >> 2] ^= 1;
                v = X[vp];
            } while (v != v0);
            flipf[nl++] = f;
        }
    }
    for (int i = 0; i < N; i++) {
        if (first[i] >= 0) { if (flipf[lid[first[i]]]) spin[i] = -spin[i]; }
        else if (rnext() >> 63) spin[i] = -spin[i];
    }
    return nl;
}

static inline int bond_conn(int b) { return seg[bsite[2 * b]] == seg[bsite[2 * b + 1]]; }

/* connections of the bonds touching i1 or i2 (each bond once) */
static inline int local_conn(int i1, int i2)
{
    int c = 0;
    for (int k = 0; k < sdeg[i1]; k++) c += bond_conn(sadj[6 * i1 + k]);
    for (int k = 0; k < sdeg[i2]; k++) {
        int bb = sadj[6 * i2 + k];
        if (bsite[2 * bb] == i1 || bsite[2 * bb + 1] == i1) continue;
        c += bond_conn(bb);
    }
    return c;
}

/* loop-improved estimators; must be called after loop_update (uses lid) */
static void improved(int nl, double *conn_avg, double *ms2)
{
    for (int i = 0; i < N; i++) seg[i] = (first[i] >= 0) ? lid[first[i]] : -1 - i;
    /* staggered structure factor at slice 0 */
    double s2 = 0;
    for (int l = 0; l < nl; l++) lcnt[l] = 0;
    for (int i = 0; i < N; i++) { if (seg[i] >= 0) lcnt[seg[i]]++; else s2 += 0.25; }
    for (int l = 0; l < nl; l++) s2 += 0.25 * (double)lcnt[l] * lcnt[l];
    *ms2 = s2 / ((double)N * N);
    /* nearest-neighbour connectivity averaged over the n propagated states */
    long conn = 0;
    for (int b = 0; b < Nb; b++) conn += bond_conn(b);
    double sum = 0;
    for (int p = 0; p < M; p++) {
        int o = op[p];
        if (o < 0) continue;
        int b = o >> 1, i1 = bsite[2 * b], i2 = bsite[2 * b + 1];
        int old = local_conn(i1, i2);
        seg[i1] = lid[4 * p + 2]; seg[i2] = lid[4 * p + 3];
        conn += local_conn(i1, i2) - old;
        sum += (double)conn;
    }
    *conn_avg = (n > 0) ? sum / n : (double)conn;
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

int main(int argc, char **argv)
{
    if (argc < 10) {
        fprintf(stderr, "usage: %s Lx Ly Lz beta n_therm n_bins bin_size seed outfile [checkpoint]\n", argv[0]);
        return 1;
    }
    Lx = atoi(argv[1]); Ly = atoi(argv[2]); Lz = atoi(argv[3]); beta = atof(argv[4]);
    long ntherm = atol(argv[5]), nbins = atol(argv[6]), binsize = atol(argv[7]);
    uint64_t seed = strtoull(argv[8], 0, 10);
    const char *outfn = argv[9], *ckfn = argc > 10 ? argv[10] : NULL;
    make_lattice();
    first = malloc(sizeof(int) * N); last = malloc(sizeof(int) * N); seg = malloc(sizeof(int) * N);
    spin = malloc(N);

    int resumed = ckfn && load_ckpt(ckfn) == 0;
    if (!resumed) {
        seed_rng(seed);
        M = 0; n = 0;
        alloc_config(20 + (int)(beta * Nb / 4));
        for (int z = 0; z < Lz; z++)            /* Neel start */
            for (int y = 0; y < Ly; y++)
                for (int x = 0; x < Lx; x++) spin[x + Lx * (y + Ly * z)] = ((x + y + z) & 1) ? -1 : 1;
        for (long s = 0; s < ntherm; s++) {
            diag_update();
            if (n > M * 3 / 4) alloc_config(n + n / 3 + 20);
            link_vertices();
            loop_update();
        }
        if (ckfn) save_ckpt(ckfn);
    }
    fprintf(stderr, "L=%dx%dx%d beta=%g M=%d n=%d resumed=%d\n", Lx, Ly, Lz, beta, M, n, resumed);

    FILE *out = fopen(outfn, "a");
    for (long bin = 0; bin < nbins; bin++) {
        double sEn = 0, sEi = 0, smz = 0, sms = 0, sn = 0, sn2 = 0;
        for (long s = 0; s < binsize; s++) {
            diag_update();
            link_vertices();
            int nl = loop_update();
            double ca, ms2;
            improved(nl, &ca, &ms2);
            double mz = 0;
            for (int i = 0; i < N; i++) mz += spin[i];
            mz *= 0.5;
            sEn += 0.25 * Nb - n / beta;
            sEi += -0.75 * ca;
            smz += mz * mz;
            sms += ms2;
            sn += n; sn2 += (double)n * n;
        }
        fprintf(out, "%.10f %.10f %.8f %.10f %.4f %.6e\n", sEn / binsize, sEi / binsize, smz / binsize,
                sms / binsize, sn / binsize, sn2 / binsize);
        fflush(out);
        if (ckfn && (bin % 20 == 19 || bin == nbins - 1)) save_ckpt(ckfn);
    }
    fclose(out);
    return 0;
}
