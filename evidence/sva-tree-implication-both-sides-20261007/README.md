# Sequence trees on both implication operands

The parser previously accepted a sequence-combinator tree on one side of an
implication when the other side was a flat sequence, but rejected trees on
both sides. The implementation now transfers both tree carriers to the
existing SVA NFA implication lowering.

The regression covers parenthesized `or` trees on both sides for both
overlapped and nonoverlapped implication. Each property sees one successful
branch and one failing consequent branch.

## Qualification

- `make -j1 install` — passed on the merged local branch.
- `PATH="../local-install/bin:$PATH" ./vvp_reg.pl --strict regress-sva-tree-implication-both-sides-legacy.list` — 1/1 passed.
- `PATH="../local-install/bin:$PATH" python3 vvp_reg.py --strict regress-sva-tree-implication-both-sides-vvp.list` — 2/2 passed under strict 2017 and 2023.

This qualifies the tested `or`-tree subset. Runtime qualification for
both-sided `and`/`intersect` trees and broader sequence combinations remains
open; this does not close the general nested-property consequent gap in G12
or clause 16.
