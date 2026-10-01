# Caliptra L0: exact-52 status from existing evidence (2026-09-29)

This page is **nonstandard compatibility**: every run below uses `-gcommercial-unsafe`. It was compiled from results already on disk; no new simulation was started. Per-case status is in `status.json`.

**Case list:** the exact 52 names come from the released `L0_regression.yml`, as selected by `evidence/caliptra-icarus-l0-parallel-runner-20260924/run.py --plan`.

**Pass rule:** a case passes only if the result shows completed firmware execution, the intended pass marker, zero fail markers, zero assertion/error diagnostics and no timeout.

**Sources:** pinned caliptra-rtl `v2.1.2` (`49370266`) and Adams Bridge (`b77e3d89`), clean before and after every recorded case.

**Strict mode:** strict-mode mixed-driver rejection is kept as a separate conformance guard, not waived here.

## Profile A: sweep diagnostic profile

Profile name: `diagnostic_reset_checker_source_ephemeral_jtag_port_overlay`.

**Overlays:** the bundled reset BFM overlay (`c5b901d3…`), the pure-checker patch (`b3cdf87a…`, producing `6e67d679…`) and the ephemeral-JTAG top overlay (`df8d51cc…`). All are hash-checked and applied to disposable copies.

**Compiler** (SHA-256 recorded in every case summary):

| file | hash |
| --- | --- |
| ivl | `3fb64d5501f8928cbe02d5b9f6deabf4fd39956bd60ca4113931a1e822669a74` |
| vvp | `2401049af54b7b2c8599efef4b66c7eff65f462fe3158a9134f6567c86ee0627` |
| vvp.tgt | `a49e5b4edfcfacd3994fa9028a2873036c4ffbd04c1a5a695acbcf43c626c847` |
| iverilog | `bd83f84182f87a99565372e3eb11a0f9f96bb28e4ae655cac38a85ad3d38efbb` |

**Runs combined:** for each case the best recorded result is taken, in the order PASS > FAIL > KILLED > TIMEOUT > UNFINISHED.
- the original sweep `caliptra-icarus-l0-main-52-20260926` (3 jobs, 4-hour cap);
- the resume sweep `caliptra-icarus-l0-main-52-resume-20260927`;
- the serial 16-hour reruns in `caliptra-icarus-l0-long-cap-20260927`.

| status | count |
| --- | --- |
| qualified PASS | **22** |
| TIMEOUT (4-hour cap) | 14 |
| FAIL (assertion/error diagnostic) | 3 |
| KILLED (SIGKILL, low memory) | 2 |
| UNFINISHED (sweep stopped mid-case) | 6 |
| NOT RUN | 5 |

**PASS:** smoke_test_veer, smoke_test_mbox, smoke_test_sha512, smoke_test_sha512_restore, smoke_test_sha256, smoke_test_sha256_wntz, smoke_test_sha256_wntz_rand, smoke_test_sha3, smoke_test_sha3_interrupt, smoke_test_sha3_regs, smoke_test_cshake, smoke_test_sha_accel, memCpy_ROM_to_dccm, memCpy_dccm_to_iccm, hello_world_iccm, smoke_test_kv, smoke_test_hw_config, smoke_test_strap, smoke_test_fw_kv_backtoback_hmac, smoke_test_ahb_mux, smoke_test_doe_rand, smoke_test_zeroize_crypto.
- smoke_test_sha256_wntz (155,834 cycles) and smoke_test_sha3 (97,900 cycles) passed only under the 16-hour cap. Their 4-hour runs were timeouts.

**FAIL:**
- **smoke_test_hmac:** `ERR_HMAC_KEY_NOT_STABLE`. Root cause: IEEE 16.12 current-value `disable iff`. It is a genuine failure and not patched. See `../caliptra-l0-hmac-key-stable-probe-20260927/`.
- **pv_hash_zeroize** and **smoke_test_pcr_zeroize:** bad diagnostic, exit 1.

**KILLED:** smoke_test_mlkem_locked_api, smoke_test_mldsa_zeroize.

**TIMEOUT:** smoke_test_mbox_byte_read, iccm_lock, c_intr_handler, smoke_test_aes_gcm, smoke_test_aes_kv_rand, smoke_test_mldsa_edge, smoke_test_sram_ecc, smoke_test_trng, smoke_test_kv_uds_reset, smoke_test_kv_securitystate, smoke_test_kv_hmac_flow, smoke_test_kv_doe, smoke_test_kv_mldsa, smoke_test_hmac_errortrigger.
- Every timeout has 0 fail markers and 0 bad diagnostics.
- Profiled throughput is about 350 cycles/min, dominated by Adams Bridge masked-A2B blocks. See `../caliptra-icarus-l0-long-cap-20260927/README.md`.
- smoke_test_mbox_byte_read's 16-hour rerun left no result.

**UNFINISHED:** smoke_test_doe_scan, smoke_test_kv_rules_ocp_lock, smoke_test_hek_flow, smoke_test_datavault_basic, smoke_test_wdt, smoke_test_iccm_reset.

**NOT RUN:** smoke_test_mlkem, smoke_test_mlkem_kv, smoke_test_mlkem_shared_key, smoke_test_kv_lock_use_mid_read, smoke_test_mlkem_kv_endian.

**Profile A result: 22 / 52 qualified. There is no complete 52-case result:** 13 cases have no verdict (6 unfinished, 2 killed, 5 not run).

## Other copied-source diagnostic profiles

These are single selected passes. They are reported separately and **not** counted in Profile A.

| case | profile | compiler | result |
| --- | --- | --- | --- |
| smoke_test_trng | Profile A overlays, 16-hour cap | ivl `3805179c…`, vvp `4a643ed1…` (post-speedup image) | PASS, 138,353 cycles (`../caliptra-trng-guarded-selected-20260929/`) |
| pv_hash_zeroize | `…_axi_read_resp_user_sha512_perword_observer_…` | ivl `3805179c…`, vvp `4a643ed1…` | PASS, 61,838 cycles (`../caliptra-pv-hash-zeroize-perword-selected-20260929/`) |
| smoke_test_pcr_zeroize | `…_ecc_pcr_key_boundary_…` | ivl `3fb64d55…`, vvp `2401049a…` | PASS, 71,791 cycles (`../caliptra-ecc-pcr-zeroize-guard-single-20260928/`) |

## Pristine unsafe profile (no copied-source overlays)

The only pristine run on record is smoke_test_veer in `../caliptra-icarus-l0-pristine-veer-20260926/`.
- Firmware completed with its pass marker.
- 29,891 bad diagnostics, so **0 / 1 qualified**.

## To complete a 52-case result

Run the 13 cases without a verdict and the 14 timeouts with a 16-hour cap. Use at most 2 jobs, under a physical-memory guard. Two cases were already killed for low memory, and each simulation uses 0.6–1.5 GB. Use one pinned compiler image throughout; the current installed image (`3805179c…`) differs from Profile A's.
