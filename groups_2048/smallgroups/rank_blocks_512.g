# check monotonicity of rank in SmallGroups(256,*) and find rank boundaries for 512 by bisection
prev := 0; mono := true;
for i in [1..NumberSmallGroups(256)] do
  r := RankPGroup(SmallGroup(256, i));
  if r < prev then mono := false; fi; prev := r;
od;
Print("256 rank monotone: ", mono, "\n");
n := NumberSmallGroups(512);
rk := i -> RankPGroup(SmallGroup(512, i));
# first index with rank >= d
first := function(d)
  local lo, hi, mid;
  lo := 1; hi := n + 1;
  while lo < hi do
    mid := QuoInt(lo + hi, 2);
    if rk(mid) >= d then hi := mid; else lo := mid + 1; fi;
  od;
  return lo;
end;
f := List([1..10], d -> first(d));
Print("512 first index of rank d (d=1..10): ", f, "\n");
Print("512 counts by rank: ", List([1..9], d -> f[d+1] - f[d]), "\n");
# dense random check of monotonicity
ok := true;
for k in [1..3000] do
  i := Random([1..n-1]);
  if rk(i) > rk(i+1) then ok := false; fi;
od;
Print("random adjacent check: ", ok, "\n");
QUIT;
