# Flash runtime read-path profile

This checkpoint preserves bounded diagnostics from the selected
`flash_ctrl_smoke_vseq` replay. It is not a passing Flash result and does not
establish a complete root cause for the runtime timeout.

## Findings

- An instrumented `flash_mem_bkdr_util::read32` override recorded 131,000 reads
  for each of the two Flash banks by 18.541 us of simulation time while the
  partition model was populated. The erase scoreboard event at 18.945 us was
  followed by another 130,000 reported reads for bank 1 by 18.967 us.
- The 600-second bounded replay ended at the wall-time cap (`returncode=124`),
  below the 4 GiB memory limit, with a reported peak footprint of 995,476,584
  bytes. Its last progress marker was 260,000 bank-1 reads at 18.967 us. It
  emitted no checked PASS marker; this replay remains unqualified.
- A separate fixed-delay sample captured ten seconds of the replay after about
  85 seconds. In the 820 main-thread samples, the call graph includes
  `uvm_hdl_read` in 183 samples; 170 of those proceed through
  `vpi_handle_by_name` and recursive `find_scope` calls. This points to repeated
  hierarchical VPI name resolution as a substantial cost in this sampled
  interval. It does not prove that name resolution alone causes the timeout.
- The sampling wrapper ended after 95.7 seconds with return code 0, but the
  captured log stopped at 18.967 us and contained no pass marker. Do not count
  that wrapper result as a Flash PASS.
- A separate 180-second Z3-traced replay completed all eight traced solve
  checks, including the 46- and 228-distribution checks, then hit its wall-time
  cap without a PASS marker. The solver was therefore not left inside one of
  those eight checks in that run; later simulation work remains unprofiled.

## Preserved artifacts

- `flash-readpath.sample.txt`: raw macOS `sample` call-graph capture.
- `flash-readpath-fixed-sample.log`: corresponding instrumented replay output.
- `matrix-runtime-count-600s.log`: read-count markers and UVM progress from the
  600-second capped replay.
- `matrix-runtime-z3-trace-180s.log`: the complete captured solver trace and
  replay output from the 180-second capped run.
- The source-level VPI `find_scope` cache and its focused benchmark follow-up
  are recorded in `../flash-vpi-scope-cache-20261003/README.md`.

The temporary VVP executables and OpenTitan build tree are not included. The
instrumented read32 implementation remains an experiment; pinned OpenTitan
sources and the release overlay were not modified.
