# WP4 pinned-base correctness gates

Measurement base: `374b037e7c8fba7097e0b86b05be7956ca6b5487`.

Slurm job 1733 ran the full correctness stages against the candidate install
used by the focused and broad screens. Its exit code was 0; every stage returned
0:

- `make check`
- FPGA target install required by the JSON rejection cases
- `.github/ivtest_gate.sh`: legacy ivtest, VPI, negative, runtime invariants,
  and the full JSON suite
- An additional standalone full JSON replay
- Real-DPI UVM regression

The JSON runner reported 4,676 tests and 0 failures in both invocations. The
UVM run reported 367 passed, 0 failed, 0 skipped. After job 1733, the focused
fixture was expanded to enumerate all 65,280 8-bit X/Z patterns; job 1760
compiled and ran that final fixture against both installs with identical output.
Full logs, timing records, environment, binary hashes, and the batch script are in
[`job-1733/`](job-1733/).

The expanded focused run is documented separately in [`../exhaustive-edge/README.md`](../exhaustive-edge/README.md).
