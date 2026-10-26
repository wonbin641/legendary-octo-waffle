"""Fill problem9_final.md with the final numbers and render HTML/PDF.

usage: python3 build.py [--katex-base URL] [--pdf]
  needs: ../qmc/results.json (python3 analyze2.py results.json), ../qmc/validation/*.dat,
         pandoc; for --pdf also node + playwright (render_pdf.js) and the Noto KR fonts.
"""
import glob
import json
import math
import os
import re
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
QMC = os.path.join(HERE, "..", "qmc")
N = 8000


def pm(v, e, sig=2):
    """value +- error with the error rounded to `sig` significant digits"""
    d = max(0, sig - 1 - int(math.floor(math.log10(e))))
    return "%.*f \\pm %.*f" % (d, v, d, e)


def paren(v, e, sig=2):
    d = max(0, sig - 1 - int(math.floor(math.log10(e))))
    return "%.*f(%d)" % (d, v, round(e * 10 ** d))


def ed_table():
    sys.path.insert(0, os.path.join(QMC, "validation"))
    ref = {}
    for line in open(os.path.join(QMC, "validation", "ed_reference.txt")):
        if line.startswith("#"):
            continue
        lat, b, E, sz2, ms2 = line.split()
        ref[(lat, float(b))] = (float(E), float(sz2), float(ms2))
    files = [("2x2x2", 1, "v_222_b1.dat"), ("2x2x2", 4, "v_222_b4.dat"), ("4x2x1", 1, "v_421_b1.dat"),
             ("4x2x1", 4, "v_421_b4.dat"), ("4x4x1", 2, "v_441_b2.dat"), ("4x4x1", 8, "v_441_b8.dat")]
    rows = ["| 격자 | $\\beta$ | ED $\\langle H\\rangle$ | $E_n$ | $E_{\\rm mix}$ | $E_{\\rm RB2}$ | ED $\\langle (S^z)^2\\rangle$ | SSE | ED $m_s^2$ | SSE |",
            "|------|---|-----|-----|-----|-----|-----|-----|-----|-----|"]
    chi2 = 0.0
    for lat, b, fn in files:
        L = list(map(int, lat.split("x")))
        n_sites = L[0] * L[1] * L[2]
        nb = sum(l > 1 for l in L) * n_sites
        d = np.loadtxt(os.path.join(QMC, "validation", fn))
        n, noff, D, mz2, ms2, ca, ns, nd = d.T
        est = [0.25 * nb - n / b, 0.25 * D - noff / b, -0.25 * ca - (ns + 0.5 * nd) / b]
        f = lambda x: paren(x.mean(), x.std(ddof=1) / np.sqrt(len(x)), 1)
        E, s, m = ref[(lat, float(b))]
        x = est[2]
        chi2 += ((x.mean() - E) / (x.std(ddof=1) / np.sqrt(len(x)))) ** 2
        lat_s = lat.replace("x", "×") + (" (2D)" if L[2] == 1 else "")
        rows.append("| %s | %g | %.4f | %s | %s | %s | %.4f | %s | %.4f | %s |" %
                    (lat_s, b, E, f(est[0]), f(est[1]), f(est[2]), s, f(mz2), m, f(ms2)))
    return "\n".join(rows).replace("| -", "| −"), chi2


def timing(beta):
    """seconds per sweep of one sse3 chain (data-file mtime minus log mtime)"""
    out = []
    for log in glob.glob(os.path.join(QMC, "runs", "b%d_s*_rb.log" % beta)):
        dat = log[:-4] + ".dat"
        nb = sum(1 for _ in open(dat))
        bs = 100 if beta == 32 else 50
        out.append((os.path.getmtime(dat) - os.path.getmtime(log)) / (nb * bs))
    return float(np.mean(out))


def main():
    katex = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/"
    if "--katex-base" in sys.argv:
        katex = sys.argv[sys.argv.index("--katex-base") + 1]
    R = json.load(open(os.path.join(QMC, "results.json")))
    E0, dE0 = R["E0"], R["E0_err"]
    pb = {r["beta"]: r for r in R["per_beta"]}
    r32, r64 = pb[32], pb[64]

    # staggered structure factor (one component) at beta=32 from all beta=32 files
    ms = np.concatenate([np.loadtxt(f, ndmin=2)[5:, 4] for f in glob.glob(os.path.join(QMC, "runs", "b32_s*.dat"))])
    ms2_full = 3 * ms.mean()

    # production table
    def sweeps(r):
        tot = 0
        for f in r["files"]:
            bs = 100 if r["beta"] == 32 else 50
            tot += f["bins"] * bs
        return tot
    prod = ["| $\\beta$ | 체인 | 측정 스윕 | $E(\\beta)$ ($E_n$만) | $E(\\beta)$ (최선 추정량) | $\\langle (S^z_{\\rm tot})^2\\rangle$ | $I$ | $E_{\\rm rot}$ | $E_0=E(\\beta)-E_{\\rm rot}$ |",
            "|---|---|---|---|---|---|---|---|---|"]
    for r in (r32, r64):
        en = [(f["others"]["E_n"][0], f["others"]["E_n"][1]) for f in r["files"]]
        w = np.array([1 / e ** 2 for _, e in en]); v = np.array([x for x, _ in en])
        En, dEn = (w * v).sum() / w.sum(), 1 / np.sqrt(w.sum())
        nchains = len({f["file"].split("_s")[1][0] for f in r["files"]})
        prod.append("| %d | %d | %s | %s | %s | %s | %s | %.5f | %s |" % (
            r["beta"], nchains, "{:,}".format(sweeps(r)), paren(En, dEn), paren(r["E_beta"], r["err"]),
            paren(r["mz2"], r["mz2_err"]), "%.0f" % r["I"], r["E_rot"], paren(r["E0"], r["E0_err"])))
    prod.append("| 결합 | | | | | | | | **%s** |" % paren(E0, dE0))
    prod = [r.replace("| -", "| −").replace("(-", "(−") for r in prod]

    # comparison table
    e_lit, de_lit = -0.902325, 0.000011
    fs_lswt = -0.1456
    lit_qmc = N * e_lit + fs_lswt
    lit_peps, dlit_peps = N * -0.9024 + fs_lswt, N * 0.0001
    doc32, ddoc32 = -7218.530 - r32["E_rot"], 0.333
    cmp_rows = ["| 방법 | 전체 에너지 (L = 20) | 본 결과와의 차이 | 비고 |", "|-------------|-----------|-----|-----------|",
                "| 본 문서 SSE ($\\beta=32,64$, $E_{\\rm RB2}$·$E_{\\rm mix}$) | $%s$ | — | 통계 1σ |" % pm(E0, dE0),
                "| 기존 문서 SSE ($\\beta=32$, 회전자 보정) | $%s$ | %s σ | 원 값 $-7218.530(333)$ |" % (pm(doc32, ddoc32), "%.1f" % ((doc32 - E0) / math.hypot(ddoc32, dE0))),
                "| 문헌 QMC, 무한계 $-0.902325(11)$/site + 스핀파 유한크기 보정 | $%s$ | %s σ | Vlaar–Corboz 2021 (ALPS, L ≤ 12 외삽) |" % (pm(lit_qmc, N * de_lit), "%.1f" % ((lit_qmc - E0) / math.hypot(N * de_lit, dE0))),
                "| 문헌 iPEPS, 무한계 $-0.9024(1)$/site + 같은 보정 | $%s$ | %s σ | Vlaar–Corboz 2021 ($D\\le4$, $\\xi_D$ 외삽) |" % (pm(lit_peps, dlit_peps), ("%.1f" % ((lit_peps - E0) / math.hypot(dlit_peps, dE0))).replace("-", "−")),
                "| 변분 PEPS (엄밀 상한) | $\\le -7078.76$ ($D=2$, 본 문서), $< -7176.85$ ($D\\le8$, 기존) | QMC보다 위 | 정합 |",
                "| 엄밀 하한 | $\\ge -8000$ (본 문서), $> -7584.24$ (기존) | QMC보다 아래 | 정합 |"]
    a_obs = (E0 / N - e_lit) * 20 ** 4
    da_obs = math.hypot(dE0 / N, de_lit) * 20 ** 4

    # cost of 15 digits
    best_var = []
    for f in r32["files"]:
        if f["estimator"] == "E_RB2":
            best_var.append(f["err"] ** 2 * f["bins"] * 100)   # variance per sweep incl. autocorrelation
    var_sweep = float(np.mean(best_var))
    tsweep = timing(32)
    eff = var_sweep * tsweep
    years = eff / (5e-16) ** 2 / 3.156e7

    # variance ratio E_RB2 / E_n on the sse3 files at beta=32
    ratios = [(f["others"]["E_RB2"][1] / f["others"]["E_n"][1]) ** 2 for f in r32["files"] if "E_RB2" in f["others"]]
    var_ratio = "1/%.1f" % (1 / np.mean(ratios))
    ed, chi2 = ed_table()
    subs = {
        "E0_PM": pm(E0, dE0), "E0S_PM": pm(E0 / N, dE0 / N), "IMPROVE": "%.0f" % (0.333 / dE0),
        "MS2FULL": "%.3f" % ms2_full, "GAP_ROTOR": "%.4f" % (1 / r32["I"]),
        "I32": "%.0f" % r32["I"], "I64": "%.0f" % r64["I"],
        "DIFF_PM": pm(r32["E0"] - r64["E0"], math.hypot(r32["E0_err"], r64["E0_err"])),
        "ED_TABLE": ed, "ED_CHI2": "%.1f" % chi2, "PROD_TABLE": "\n".join(prod), "COMPARE_TABLE": "\n".join(cmp_rows),
        "A_OBS": pm(a_obs, da_obs, 1), "VAR_RATIO": var_ratio, "EFF": "%.0f" % eff, "YEARS": "10^{%d}" % int(math.floor(math.log10(years))),
    }
    src = open(os.path.join(HERE, "problem9_final.md")).read()
    for k, v in subs.items():
        src = src.replace("{{%s}}" % k, v)
    left = re.findall(r"\{\{[A-Z0-9_]+\}\}", src)
    if left:
        raise SystemExit("unfilled placeholders: %s" % left)
    filled = os.path.join(HERE, "problem9_final.filled.md")
    open(filled, "w").write(src)
    html = os.path.join(HERE, "problem9_final.html")
    subprocess.run(["pandoc", filled, "-s", "--katex=" + katex, "--css", "style.css", "-o", html], check=True, cwd=HERE)
    print("wrote", html)
    print(json.dumps({k: v for k, v in subs.items() if "TABLE" not in k}, ensure_ascii=False, indent=1))
    if "--pdf" in sys.argv:
        subprocess.run(["node", "render_pdf.js", html, os.path.join(HERE, "problem9_final.pdf")], check=True, cwd=HERE)


if __name__ == "__main__":
    main()
