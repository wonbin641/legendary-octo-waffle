# Per-parent comparison of the Burnside count with ANUPQ's own descendant construction.
Read("step1.g");
for d in [3..7] do
  for t in QFTypes(d) do
    H := QFGroup(d, t[1], t[2]);
    r := Step1CountC(H, QFGroupFp(d, t[1], t[2]));
    Print("d=", d, " ", t, " burnside ", r[1], "  pq ", Length(PqDescendants(H : StepSize := 1)), "\n");
  od;
od;
QUIT;
