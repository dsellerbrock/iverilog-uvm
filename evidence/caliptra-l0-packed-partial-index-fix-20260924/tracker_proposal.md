# Proposed tracker update for Codex (Caliptra L0 lane)

Codex owns `.ai/ACTIVE_WORK.yaml`, `.ai/CAMPAIGN.yaml`, and
`docs/conformance/*`. This session changed none of them. Please integrate the
following, adjusting wording to the tracker's style.

## Replace `caliptra_l0_hwif_in_failure`

```yaml
caliptra_l0_hwif_in_failure:
  state: ROOT_CAUSED_PRIVATE_FIX_VALIDATED_NOT_INSTALLED
  root_cause: >-
    netmisc.cc collapse_packed_member_indices() padded a partial packed index
    chain with literal index 0 instead of each trailing dimension's declared
    LSB. Caliptra el2_mem_if.dccm_addr_bank is logic [N-1:0][17:4] and is
    written per bank from el2_lsu_dccm_mem through a modport, so every DCCM
    bank address was shifted 4 bits and the bank-3 address was X. Core stores
    to bank 3 were dropped. The first DCCM load after the CRT .data copy read
    an X word, rvecc_decode produced double_ecc_error=X, and the unchanged
    ERR_HWIF_IN assertion fired. Not source; not a scheduling race.
  scope_of_defect: >-
    Silent wrong addressing for m[i] where m has 2+ packed dims and a nonzero
    inner LSB, on interface members through a modport, class properties, and
    packed-struct members, for both reads and writes. Plain module variables
    are unaffected.
  fix: PR <link> (branch agent/caliptra-iface-packed-elem-lval-20260924).
  evidence: evidence/caliptra-l0-packed-partial-index-fix-20260924/
  standards: IEEE 1800-2017/2023 7.4.5 (multidimensional packed arrays).
```

## Amend `caliptra_live_sweep_checkpoint`

- The smoke_test_veer copied-source PASS recorded on the installed tool was
  hollow. Its only DCCM load (`hw_data`) read a wrong bank index and returned
  0, so the test printed nothing before the pass write (633 retired). On the
  private fixed compiler, the same profile prints "Hello World from VeeR EL2 !!"
  and passes with 1033 retired instructions, one pass marker, zero fail
  markers, and zero bad diagnostics.
- All five ERR_HWIF_IN failures share this root cause: each stops at its first
  DCCM access after the `.data` copy loop.
- Do not restart the 52-case sweep on the installed ivl
  6ec92c4825dc51e3810d1cb22405071f033015626d39cf3db92c319aeb9d3b10; it
  reproduces the defect. Restarting needs an installation decision for the
  fixed compiler (the installed tool was not changed by this session).

## Results to record (labels kept separate)

- Pristine unsafe lane: unchanged, 0/1; no new pristine runs this session.
- Strict conformance guard (private fixed ivl): full-top compile exits 46 with
  a log byte-identical to evidence/caliptra-icarus-l0-strict-p1-20260924.
- Copied-source diagnostic profile, private fixed compiler (outside the
  installed-tool 52 numerator): smoke_test_veer PASS (qualified, see above);
  smoke_test_mbox PASS (23813 retired, zero bad diagnostics; see README).
- Private gates: see README "Gates".

## Representative long case: done

smoke_test_mbox passed on the private fixed compiler (same diagnostic profile,
--timeout 14400). Next decision for the coordinator: whether to install the
fixed compiler before restarting the 52-case sweep. Do not restart it on the
installed ivl 6ec92c48, which reproduces ERR_HWIF_IN.
