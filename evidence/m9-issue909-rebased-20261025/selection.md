# M9-909 T1 selection on current main

The change adds rejection of illegal output clockvar variable drivers in `elab_sig.cc` and `elaborate.cc`; T1 selects the existing clocking-output declaration, continuous-driver, and clockvar control/rejection tests in both legacy and JSON runners. The focused set contains 10 legacy rows and 28 JSON rows. The paired issue reproducer is also compiled under `-g2017` and `-g2023` and must fail with the output-clockvar diagnostic. Fast Linux separately covers the T0 smoke set.
