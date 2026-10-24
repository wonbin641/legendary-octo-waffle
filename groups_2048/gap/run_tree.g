# Cross-check driver: GAP-side tree walk (PqDescendants + AutPGrp automorphisms).
# Usage (from this directory):  gap -q -b run_tree.g
Read("tree.g");
Print("rank 2: ", CountTree(2, 11), "\n");   # ~15 min
Print("rank 3: ", CountTree(3, 10), "\n");   # several hours
QUIT;
