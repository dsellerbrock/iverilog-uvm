# Open/closed issue dedupe for §24.7 `$exit` outside a program

Searches used `gh issue list --state all` (open and closed): `"$exit"`, `"$exit" ignored`, `"$exit" outside program`, and `§24.7`. Full JSON results and SHA-256 hashes are in this directory.

The only directly matching issue is open #786. Its body explicitly records the module-called `$exit` form from `r20_02_exit.sv` and the observed output (`EX0` only), alongside the related program-call issue. This candidate is already covered; do not file a duplicate. Add the paired-edition rerun as a comment/evidence to #786 after the run completes.
