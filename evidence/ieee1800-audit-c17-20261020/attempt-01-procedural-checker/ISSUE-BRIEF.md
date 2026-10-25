# Lead handoff candidate — IEEE 1800 §17.3 procedural checker instance

The probe places a checker instantiation in a module `initial` procedure. IEEE 1800-2017 §17.3 (p. 487) and IEEE 1800-2023 §17.3 (p. 506) define checker instances inside procedural code and prohibit only instances in fork-join blocks or in a procedure of another checker. The tested instance is outside both exclusions.

Icarus `cc25756d1` rejects the instance at line 10 with `syntax error` / `Malformed statement` in both `-g2017` and `-g2023`. The existing static-checker control passes in both editions. Slang 11.0.448 also rejects the source, so treat it only as a cross-implementation observation, not an oracle.

Open and closed issue searches for `procedural checker`, `checker instantiation`, and `checker in procedure` returned no hits. Please classify Supported/Partial/Missing and file only if the standard and scope warrant it. This brief is not an issue filing.
