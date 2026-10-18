# IEEE 1800 clause 19 probe batch C

The probes ran on DAN-DESKTOP with the protected Icarus 13.0 devel toolchain built from source revision `9b5fad2af`. Exact binary SHA-256 values and unedited outputs are in each attempt's `results.txt`; Slurm stdout and per-case compile/run logs are preserved locally. Attempts 01 and 02 used jobs 2263 and 2266, respectively, each with 1 CPU and 1 GiB. Remote run directories were removed after copying the evidence.

## Results

- **§19.3 clocking-event sampling — implemented.** In both `-g2017` and `-g2023`, two separate posedges produce 50% coverage, and two samples in one time slot with `at_least=2` produce 25%. The separate block-event form remains a gap under #625.
- **§19.8 two-argument getters — partial, #622.** The group getter compiles but reports `cov=0 tot=0` after sampling. The named-coverpoint overload is not resolved. Type-level checking is blocked by the missing methods already recorded under #627.
- **§19.5 implicit coverpoint names — partial, #630.** `coverpoint v` without a label does not expose `g.v` in either edition; the explicit `v: coverpoint v` control reports 25% in both.
- **§19.4.1 embedded covergroup inheritance — missing in 2023, tracked by #457.** The minimal class-contained `covergroup extends g1` probe fails syntax in `-g2023`. Its `-g2017` rejection is expected. An undefined base also produces only a generic syntax error.

Attempt 01's undefined-base marker was a false positive: it matched the word `undefined` in the source filename. Attempt 02 contains the corrected diagnostic filter and reduced bisection. The original positive inheritance probe is retained in attempt 01; attempt 02 reduces it to the `extends` syntax.

## Issue references

- #622 comment: two-argument getter findings and the c19c evidence path.
- #630: unlabeled single-variable coverpoint is not named after its variable.
- #457 comment: c19c evidence confirms the existing embedded-inheritance scope; no duplicate issue was opened.
