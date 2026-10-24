# Groups of order 2^(d+2), rank d, with P_3(G) <> 1 (= step-1 immediate descendants of
# the groups H of order 2^(d+1) with |Phi(H)| = 2, i.e. nonzero quadratic forms on F_2^d).
# Usage (from this directory): gap -q -b rank_n_minus_2.g
# For d = 8, 9 run each parent in a fresh GAP process (see ../README.md).
Read("step1.g");
for d in [3..9] do
  tot := 0;
  for t in QFTypes(d) do
    r := Step1CountC(QFGroup(d, t[1], t[2]), QFGroupFp(d, t[1], t[2]));
    Print("d=", d, " ", t, " -> ", r, "\n");
    tot := tot + r[1];
  od;
  Print("rank ", d, ", order 2^", d + 2, ": ", tot, " groups with P_3 <> 1\n");
od;
QUIT;
