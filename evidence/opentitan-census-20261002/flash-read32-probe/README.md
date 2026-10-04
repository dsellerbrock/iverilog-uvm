# Flash backing-memory `read32` probe

This is an unadopted diagnostic candidate. It overrides the Flash memory
backdoor's `read32` to read a containing backing-memory word once when its
four requested bytes fall in that word. The candidate was applied only to a
disposable source overlay; pinned OpenTitan sources and the repository's
release overlay were not changed.

## Evidence

- Baseline `flash_mem_bkdr_util.sv` SHA-256:
  `6578e80e394c74f0b6c438ac5125eefdaaeaf60a3cd03318a5f69368929209eb`.
- Candidate overlay file SHA-256:
  `0cf44484f15add6a3779deb4921bd869c99c29165ce394f05c048128498e02e7`.
- The candidate compiled in the selected OpenTitan Flash image with
  `-gcommercial-unsafe`; this was an isolated compile, not a full census.
- The selected runtime was capped at 180 seconds and 4 GiB. It ended with
  `returncode=124`, `timed_out=true`, `memory_limit_hit=false`, and a
  recorded peak of 966,100,048 bytes. The simulator reached 29,626.5 ns.
- Shutdown reported one `UVM_ERROR`, `noOutstandingReqsAtEndOfSim_A`, and no
  checked PASS marker. This is not a passing Flash result.
- The attempt does not establish semantic equivalence or a runtime improvement.
  Keep this patch as an experiment until both are demonstrated.

The run log and generated VVP are intentionally not included; the bounded
result above records its verdict and resource cap. The most recent coherent
49-row result remains the historical census11 artifact.
