Clause: 2017 §19.5 Syntax 19-2 p. 558 and §19.5.1 / 2023 §19.5 Syntax 19-2 p. 582 and §19.5.1 p. 585.

Requirement: Syntax 19-2 allows “bins_keyword bin_identifier [ [ [ covergroup_expression ] ] ] = default”. The §19.5.1 example uses `bins others[] = default;` and assigns each unmatched value its own bin.

Probe: `tests/1800_audit/c19/p19_05_bins_cov.sv`. Evidence: `evidence/ieee1800-audit-c19a-20261017/results.txt`.

Observed: `bins others[] = default;` fails compilation in both editions with a syntax error and “unsupported bins declaration was ignored”. The scalar form `bins others = default;` compiles and runs.

Expected: the array-default declaration compiles and creates one bin per unmatched value; default bins remain excluded from coverage computation as specified in §19.5.
