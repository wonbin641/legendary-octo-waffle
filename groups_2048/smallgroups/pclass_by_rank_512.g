# Within each rank block of SmallGroups(512,*), groups appear sorted by p-class (check by
# sampling), so count p-class <= 2 per rank by bisection.
n := NumberSmallGroups(512);
starts := [ 1, 2, 2045, 60904, 420515, 7532393, 10493062, 10494201, 10494213, 10494214 ];
pc := i -> PClassPGroup(SmallGroup(512, i));
for d in [1..9] do
  lo := starts[d]; hi := starts[d+1];   # block [lo, hi)
  # check monotone p-class in block by random sampling
  ok := true;
  for k in [1..Minimum(2000, hi-lo-1)] do
    i := Random([lo..hi-2]);
    if pc(i) > pc(i+1) then ok := false; fi;
  od;
  # first index in block with p-class >= 3
  a := lo; b := hi;
  while a < b do
    m := QuoInt(a + b, 2);
    if pc(m) >= 3 then b := m; else a := m + 1; fi;
  od;
  Print("rank ", d, ": p-class<=2 count ", a - lo, ", p-class>=3 count ", hi - a, ", monotone sample ", ok, "\n");
od;
QUIT;
