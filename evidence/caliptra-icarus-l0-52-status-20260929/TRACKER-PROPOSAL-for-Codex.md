# Proposed tracker update for Codex to integrate

Claude did not edit AGENTS.md or any shared tracker. Please fold this into `.ai/ACTIVE_WORK.yaml` / `.ai/CAMPAIGN.yaml` in the campaign checkout as you see fit.

```yaml
caliptra_l0_exact52_status_20260929:
  label: "nonstandard compatibility (-gcommercial-unsafe)"
  evidence: "iverilog-uvm-caliptra-l0-20260924/evidence/caliptra-icarus-l0-52-status-20260929/README.md (+ status.json)"
  profile_a: "diagnostic_reset_checker_source_ephemeral_jtag_port_overlay; ivl 3fb64d55, vvp 2401049a, vvp.tgt a49e5b4e, iverilog bd83f841"
  profile_a_result: "22/52 qualified; 14 timeouts (0 fail markers, 0 bad diagnostics); 3 FAIL (smoke_test_hmac, pv_hash_zeroize, smoke_test_pcr_zeroize); 2 KILLED low-memory; 6 UNFINISHED; 5 NOT RUN. No complete 52-case result."
  hmac_root_cause: "smoke_test_hmac ERR_HMAC_KEY_NOT_STABLE follows IEEE 16.12 current-value disable iff; genuine failure, not patched (caliptra-l0-hmac-key-stable-probe-20260927)."
  err_hwif_in: "Closed earlier: the five ERR_HWIF_IN failures and the dccm_ecc_unc.we X were an Icarus partial packed-index padding bug, fixed in PR #361; absent from all current logs."
  timeouts: "Cap-limited, not hung: throughput about 350 cycles/min, dominated by Adams Bridge masked-A2B; sha256_wntz (155,834 cycles) and sha3 (97,900 cycles) pass under the 16-hour cap."
  other_profiles_selected_passes: "TRNG PASS (profile A overlays, ivl 3805179c/vvp 4a643ed1); pv_hash_zeroize PASS (sha512 per-word observer profile); smoke_test_pcr_zeroize PASS (ecc pcr key boundary profile). Not counted in profile A."
  pristine: "smoke_test_veer 0/1 qualified (pass marker reached, 29,891 bad diagnostics)."
  next: "Rerun 27 cases (13 without verdict + 14 timeouts) at 16 h, <=2 jobs, physical-memory guard, one pinned compiler image; not started (user instruction: no Caliptra regression)."
```
