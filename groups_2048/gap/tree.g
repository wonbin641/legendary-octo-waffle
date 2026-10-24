# Count all d-generator 2-groups of order 2^k, k <= N, by walking the
# p-group generation tree from the elementary abelian group of rank d.
LoadPackage("anupq");;
CountTree := function(d, N)
  local F, root, counts, stack, H, des, D, n, nodes;
  F := FreeGroup(d);
  root := PcGroupFpGroup(F / Concatenation(List(GeneratorsOfGroup(F), x -> x^2),
            List(Combinations(GeneratorsOfGroup(F), 2), c -> Comm(c[1], c[2]))));
  counts := List([1..N], i -> 0);
  counts[d] := 1;
  stack := [root]; nodes := 0;
  while stack <> [] do
    H := Remove(stack);
    if Size(H) >= 2^N then continue; fi;
    des := PqDescendants(H : OrderBound := N);
    nodes := nodes + 1;
    for D in des do
      n := Length(Factors(Size(D)));
      counts[n] := counts[n] + 1;
      if IsCapable(D) and n < N then Add(stack, D); fi;
    od;
  od;
  return counts;
end;
