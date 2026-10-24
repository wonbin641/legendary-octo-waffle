Read("qf.g");
# Step-1 descendant count via Burnside, without GroupHomomorphismByImages on the cover.
# The 2-cover H* is relatively free: for an automorphism a of H, the map
# gC[i] -> (any lift of a(gH[i])) extends to an endomorphism of H*.  We evaluate it
# on fixed words (in gC) for the multiplicator generators.

# induced generating sequence of G = <gens> with words, by deterministic sifting
SiftWithWords := function(G, gens)
  local pcgs, F, fg, ech, queue, Sift, x, i, j, a, b, new;
  pcgs := Pcgs(G);
  F := FreeGroup(Length(gens));
  fg := GeneratorsOfGroup(F);
  ech := [];                     # ech[depth] = [elm, word]
  Sift := function(g, w)
    local k;
    while g <> One(G) do
      k := DepthOfPcElement(pcgs, g);
      if not IsBound(ech[k]) then return [g, w]; fi;
      g := ech[k][1]^-1 * g;
      w := ech[k][2]^-1 * w;
    od;
    return fail;
  end;
  queue := List([1..Length(gens)], i -> [gens[i], fg[i]]);
  while queue <> [] do
    x := Remove(queue, 1);
    new := Sift(x[1], x[2]);
    if new <> fail then
      # normalise leading exponent (p = 2: always 1)
      ech[DepthOfPcElement(pcgs, new[1])] := new;
      Add(queue, [new[1]^2, new[2]^2]);
      for a in Compacted(ech) do
        Add(queue, [Comm(new[1], a[1]), Comm(new[2], a[2])]);
      od;
    fi;
  od;
  Assert(0, Length(Compacted(ech)) = Length(pcgs));
  return rec(ech := ech, F := F, fg := fg, pcgs := pcgs);
end;

# word w with w(gens) = g
WordOf := function(S, g)
  local w, k, G1;
  w := One(S.F);
  while not IsOne(g) do
    k := DepthOfPcElement(S.pcgs, g);
    g := S.ech[k][1]^-1 * g;
    w := w * S.ech[k][2];
  od;
  return w;
end;

# d-generator fp presentation of QFGroup(d, k, typ) on x_1..x_d (z = w(x))
QFGroupFp := function(d, k, typ)
  local F, x, w, rels, i, j, sq, comm;
  F := FreeGroup(d); x := GeneratorsOfGroup(F);
  sq := List([1..d], i -> 0); comm := [];
  for i in [1..k] do Add(comm, [2*i-1, 2*i]); od;
  if typ = "-" then sq[1] := 1; sq[2] := 1; fi;
  if typ = "r" then sq[2*k+1] := 1; fi;
  if k >= 1 then w := Comm(x[2], x[1]); else w := x[1]^2; fi;
  rels := [w^2];
  for i in [1..d] do Add(rels, x[i]^2 / w^sq[i]); Add(rels, Comm(w, x[i])); od;
  for i in [1..d] do for j in [i+1..d] do
    if [i, j] in comm then Add(rels, Comm(x[j], x[i]) / w);
    else Add(rels, Comm(x[j], x[i])); fi;
  od; od;
  return F / rels;
end;

Step1CountC := function(H, Hfp)
  local A, AG, elms, hom, P, cover, d, gH, gC, M, N, pcgsM, pcgsN, pcgsMN, pH, pc, nH,
        classes, total, C, perm, imgs, img, mat, matMN, fixM, fixMN, posg, S, wM,
        x, y, wx, wy, wxy, ev, k, i, j, Lift, c;
  d := RankPGroup(H);
  c := PClassPGroup(H);
  pH := Pcgs(H); nH := Length(pH);
  cover := PqPCover(Hfp : Prime := 2, ClassBound := c);
  pc := FamilyPcgs(cover);   # not Pcgs(cover): PqPCover sets no pcgs, and computing
                             # PCentralSeries first would install a different one
  # the first nH pc generators of the cover form the pc presentation of H; check that
  # pc[i] -> pH[i] respects all power and conjugate relations of H (modulo the tails)
  for i in [1..nH] do
    Assert(0, ExponentsOfPcElement(pc, pc[i]^2){[1..nH]} = ExponentsOfPcElement(pH, pH[i]^2));
    for j in [i+1..nH] do
      Assert(0, ExponentsOfPcElement(pc, pc[j]^pc[i]){[1..nH]} = ExponentsOfPcElement(pH, pH[j]^pH[i]));
    od;
  od;
  M := SubgroupNC(cover, pc{[nH+1..Length(pc)]});     # the 2-multiplicator (the tails)
  Assert(0, Size(M) * Size(H) = Size(cover));
  Assert(0, IsElementaryAbelian(M) and IsSubgroup(Centre(cover), M));
  N := PCentralSeries(cover, 2)[c + 1];                  # nucleus P_{c+1}(H*)
  Assert(0, IsSubgroup(M, N));
  if Size(N) = 1 then return [0, 0, Length(pc) - nH, 0]; fi;
  gH := pH{[1..d]};
  gC := pc{[1..d]};
  Lift := h -> Product([1..nH], i -> pc[i]^ExponentsOfPcElement(pH, h)[i]);
  pcgsM := Pcgs(M);
  pcgsN := InducedPcgs(pcgsM, N);
  pcgsMN := pcgsM mod pcgsN;
  S := SiftWithWords(cover, gC);
  wM := List(pcgsM, m -> WordOf(S, m));
  Assert(0, ForAll([1..Length(pcgsM)], i -> MappedWord(wM[i], S.fg, gC) = pcgsM[i]));
  A := AutomorphismGroupPGroup(H);
  AG := ConvertHybridAutGroup(A);
  elms := AsSSortedList(H);
  hom := ActionHomomorphism(AG, elms, OnPoints);
  P := Image(hom);
  Assert(0, Size(P) = A.size);
  posg := List(gH, g -> Position(elms, g));
  classes := ConjugacyClasses(P);
  total := 0;
  for C in classes do
    perm := Representative(C);
    imgs := List(posg, i -> Lift(elms[i^perm]));
    img := List(wM, w -> MappedWord(w, S.fg, imgs));
    Assert(0, ForAll(img, x -> x in M));
    for k in [1..2] do       # spot check of the homomorphism property
      x := Random(cover); y := Random(cover);
      ev := w -> MappedWord(w, S.fg, imgs);
      Assert(0, ev(WordOf(S, x)) * ev(WordOf(S, y)) = ev(WordOf(S, x * y)));
    od;
    mat := List(img, x -> ExponentsOfPcElement(pcgsM, x)) * Z(2);
    fixM := Length(pcgsM) - RankMat(mat - IdentityMat(Length(pcgsM), GF(2)));
    if Length(pcgsMN) = 0 then fixMN := 0;
    else
      matMN := List(pcgsMN, m -> ExponentsOfPcElement(pcgsMN,
                 MappedWord(WordOf(S, m), S.fg, imgs))) * Z(2);
      fixMN := Length(pcgsMN) - RankMat(matMN - IdentityMat(Length(pcgsMN), GF(2)));
    fi;
    total := total + Size(C) * (2^fixM - 2^fixMN);
  od;
  Assert(0, total mod Size(P) = 0);
  return [total / Size(P), Length(classes), Length(pcgsM), Length(pcgsN)];
end;
