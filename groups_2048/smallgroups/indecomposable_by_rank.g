# Indecomposable groups of order 2^n by rank, directly from SmallGroups.
for n in [3..7] do
  a := List([1..n], i -> 0); b := List([1..n], i -> 0);
  for i in [1..NumberSmallGroups(2^n)] do
    G := SmallGroup(2^n, i); r := RankPGroup(G);
    a[r] := a[r] + 1;
    if Length(DirectFactorsOfGroup(G)) = 1 then b[r] := b[r] + 1; fi;
  od;
  Print("2^", n, " all by rank: ", a, "  indecomposable by rank: ", b, "\n");
od;
QUIT;
