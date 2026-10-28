# Issue #825 T0/T1

T0 used the Slurm compiler built from this branch with `./configure --enable-libveriuser --prefix="$PWD/local-install"`, `make -j3`, and `make install`, followed by `PATH="$PWD/local-install/bin:$PATH" ./ci/run-smoke.sh`.

T0 passed the smoke set (56/56), VPI regression set (155/155), all `ci/run-repros.sh` checks, the negative suite, and all VVP runtime probes.

T1 selection followed the touched parser/elaboration seams: `parse.y` now keeps specify terminals as a typed interface/member pair, while `elaborate.cc` resolves bound interface members and modport directions after hierarchy binding. The canonical graph query surfaced `PSpecPath`, existing `specify5.v`, and interface-forwarding/binding nodes. The selected existing regressions cover specify paths and timing, interface port arrays, forwarding chains, selected/modport actuals, generic/wildcard ports, and VIF indexing.

T1 passed 39/39 legacy tests and 57/57 JSON tests. Each JSON test ran individually with a 120-second process-group timeout. The issue-specific tests additionally passed paired -g2017/-g2023 positive cases and five paired negative cases: wrong source direction, wrong destination direction, hidden modport member, non-interface dotted path, and unknown interface member.
