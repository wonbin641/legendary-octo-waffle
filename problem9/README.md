# 문제 9 — 20×20×20 스핀-1/2 하이젠베르크 반강자성체: 검토와 최종 해답

최종 보고서는 [`report/problem9_final.pdf`](report/problem9_final.pdf)이고, 같은 내용의 HTML과 Markdown이 함께 있다.

## 결론

* **바닥상태.** 유일하며($g_0=1$) 총스핀 0, $\mathbf k=0$, 공간군 자명 표현에 속한다. 엄밀히 증명된다(기존 증명 검토).
* **Néel 상관 (L = 20 자체, 새 정리).** $\langle(\sum_x(-1)^x\mathbf S_x)^2\rangle/N^2 \ge 0.0827$이고, 바닥상태 위 0.00536 이내에 $S=1$, $\mathbf k=(\pi,\pi,\pi)$ 상태가 있다. 유한갭 위상질서는 배제된다.
* **에너지 엄밀 구간 (본 작업에서 다시 증명).** $-7584.2447614214 \le E_0 \le -7078.7617937$. 하한은 기존 문서의 33스핀 클러스터 하한을 독립적으로 재최적화하고 정확한 정수 인증서로 증명한 것이다.
* **에너지 QMC 값.** $E_0 = -7218.873 \pm 0.029$, 사이트당 $-0.9023592(36)$ (통계 1σ, `qmc/results.json`).
* **소수점 15자리.** 알려진 어떤 방법으로도 도달할 수 없다 (보고서 §6).

## 구성

| 경로 | 내용 |
|---|---|
| `report/` | 보고서 원본(`problem9_final.md`), 숫자를 채운 판, HTML, PDF, 빌드 스크립트 |
| `qmc/sse3.c` | 생산용 SSE QMC (다중 커서 루프 갱신, Rao–Blackwell 추정량) |
| `qmc/sse2.c`, `qmc/sse.c` | 이전 판 |
| `qmc/runs/` | L = 20 생산 계산의 묶음 자료 |
| `qmc/analyze2.py` | 오차 분석과 회전자 보정 → `qmc/results.json` |
| `qmc/ed_check.py`, `qmc/validation/` | 정확 대각화와의 비교 |
| `kls_finite_L.py` | 정리 1의 구간 산술 증명 계산 |
| `bounds/` | 별 하한, 1층 회로 상한과 그 검증 |
| `review/` | 기존 문서 수치 검증, 33스핀 궤도 수, 33스핀 하한 재최적화·정수 인증, 스핀파 유한크기 보정 |

## 재현

```
cd qmc && gcc -O3 -march=native -o sse3 sse3.c -lm
SSE_MFAC=2 ./sse3 20 20 20 32 3000 100000 100 1 runs/b32_s1_rb.dat runs/b32_s1.ckpt   # 원하는 만큼 실행
python3 analyze2.py results.json
cd .. && python3 kls_finite_L.py 20
cd report && python3 build.py --pdf      # pandoc, node+playwright, Noto KR 글꼴 필요
```
