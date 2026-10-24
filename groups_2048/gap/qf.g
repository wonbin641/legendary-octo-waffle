LoadPackage("anupq");; LoadPackage("autpgrp");;
# Group H(q): V = F_2^d, Phi = <z> = C2, x_i^2 = z^{q_i}, [x_j,x_i] = z^{b_ij}.
# Quadratic form types on F_2^d: hyperbolic/elliptic part of rank 2k plus radical,
# q|rad = 0 or q|rad != 0.
QFGroup := function(d, k, typ)
  # typ: "+" , "-" (q|rad = 0), or "r" (q|rad nonzero)
  local F, x, rels, i, j, sq, comm;
  F := FreeGroup(d + 1); x := GeneratorsOfGroup(F);
  sq := List([1..d], i -> 0); comm := [];
  for i in [1..k] do Add(comm, [2*i-1, 2*i]); od;      # b(x_{2i-1}, x_{2i}) = 1
  if typ = "-" then sq[1] := 1; sq[2] := 1; fi;          # elliptic plane: x1^2=x2^2=z
  if typ = "r" then sq[2*k+1] := 1; fi;                  # radical vector with q = 1
  rels := [x[d+1]^2];
  for i in [1..d] do Add(rels, x[i]^2 / x[d+1]^sq[i]); od;
  for i in [1..d] do for j in [i+1..d] do
    if [i, j] in comm then Add(rels, Comm(x[j], x[i]) / x[d+1]);
    else Add(rels, Comm(x[j], x[i])); fi;
  od; od;
  for i in [1..d] do Add(rels, Comm(x[d+1], x[i])); od;
  return PcGroupFpGroup(F / rels);
end;
QFTypes := function(d)
  local L, k;
  L := [];
  for k in [1..QuoInt(d, 2)] do Add(L, [k, "+"]); Add(L, [k, "-"]); od;
  for k in [0..QuoInt(d - 1, 2)] do Add(L, [k, "r"]); od;
  return L;
end;
