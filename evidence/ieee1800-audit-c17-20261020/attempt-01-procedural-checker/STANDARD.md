# Standard basis — IEEE 1800 checker instantiation

IEEE 1800-2017 §17.3 (p. 487) and IEEE 1800-2023 §17.3 (p. 506) state that a checker may be instantiated wherever a concurrent assertion may appear, except in fork-join blocks and in a procedure of another checker. Both editions call an instance inside procedural code a “procedural checker instance.” The probe places its instance in a module `initial` procedure, outside both listed exclusions.

The test expects the procedural checker instance to elaborate and run its clocked assertion. The paired static-instance control is `ivtest/ivltests/sv_checker_basic.v`.
