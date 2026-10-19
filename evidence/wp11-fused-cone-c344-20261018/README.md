# WP11 fused combinational cone screen

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.

The prototype targeted `rtl_pipe`'s private, zero-delay
`.part -> .concat -> XOR -> .arith/sum` cone. Four candidate builds from the
same pinned base compiled successfully but emitted zero fused operators. No
instruction or output screen ran, and no speedup is claimed. Stop WP11 for
this candidate and move to another profiled package.

The generated netlist represents the zero pad through a `BUFT` and has local
`_ivl_` aliases for intermediate expressions. Attempt 1 recognized neither;
attempt 2 added those shapes; attempt 3 showed that the zero-pad helper
rejected the BUFT path; attempt 4 corrected the BUFT pin count but still
emitted zero operators. The remaining blocker is not diagnosed well enough to
justify more matcher work in this round.

The reference and candidate builds used separate source/install directories,
4 CPUs, and 8 GiB. Inputs, patches, logs, generated VVP files, and build
results are preserved under `attempts/`.

## Attempts

- [Attempt 1](attempts/r1/README.md), job 2827: initial matcher; zero matches.
- [Attempt 2](attempts/r2/README.md), job 2828: recognized BUFT and local
  aliases; zero matches.
- [Attempt 3](attempts/r3/README.md), job 2829: temporary diagnostic;
  zero-pad check returned false.
- [Attempt 4](attempts/r4/README.md), job 2830: corrected pin count; zero
  matches. Dependent screen job 2832 was canceled before running.
