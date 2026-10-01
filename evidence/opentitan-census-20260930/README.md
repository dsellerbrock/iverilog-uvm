# OpenTitan 49-target census, 2026-09-30

Nonstandard compatibility (`-gcommercial-unsafe`). Pinned corpus `a78922f1` plus the exact-hash overlays already
applied to the shared source copy. Frozen baseline: `../opentitan-49-post-fixes-20260929` (23 PASS / 49).

**Result: 30 PASS, 6 DEBT, 5 FAIL, 6 RUNTIME_FAIL, 2 RUNTIME_TIMEOUT** (was 23 / 3 / 4 / 9 / 2 / 7 memory-limit / 1 matrix error).

Runner: `--lane runtime --commercial-unsafe --native-pkg-config openssl --native-pkg-config libelf --jobs 3
--runtime-timeout 1800 --runtime-memory-mib 4096`, Python 3.13, `PYTHONHASHSEED=2`. Image: ivl `0d50ec5d`,
vvp.tgt `e4382792`, vvp `5a96cb0e` (see `result.json` for the full fingerprint). Every case compiled fresh; the
frozen run's compiler engine (`64fee51c`) is older, so rows are not a like-for-like speed A/B.

## What changed the result

* Returned function-call threads leaked (about 6 GB for 900k trivial calls), so seven cores hit the 4 GiB limit
  within seconds. lc_ctrl, xbar_main, xbar_peri, rom_ctrl and alert_handler now PASS; edn stays under 500 MB.
* `break`/`continue` inside a labeled loop body of a task, function or class method never left the loop. The
  entropy_src scoreboard stalled on it; entropy_src and csrng now reach a checked pass banner.
* Object-handle, real and string `ref` actuals now work for callees that wait on them (UVM `m_get_q`).
* `uvm_hdl_read` accepts a trailing part select; `$bitstoreal` accepts a wider argument (UVM `uvm_field_real`).
* Joint sampling no longer lets a hard-fixed variable merge independent factors (usbdev cfg).
* Constraint fixes found by diagnosing DEBT: dynamic-array packed-member constraints, function arguments read
  through a non-rand object handle, foreach iterators in `local::arr[i]`, queue concatenation of vector part
  selects, and vif event null-validity through the checked packed index.

## Per-core status

| core | frozen | now | seconds |
| --- | --- | --- | --- |
| aes_sim | PASS | PASS | 29 |
| aon_timer_sim | PASS | PASS | 7 |
| clkmgr_sim | PASS | PASS | 9 |
| csrng_sim | RUNTIME_FAIL | PASS | 115 |
| gpio_sim | PASS | PASS | 24 |
| keymgr_sim | DEBT | PASS | 68 |
| kmac_sim | PASS | PASS | 358 |
| lc_ctrl_sim | RUNTIME_MEMORY_LIMIT | PASS | 84 |
| pattgen_sim | PASS | PASS | 32 |
| prim_alert_sim | PASS | PASS | 1 |
| prim_esc_sim | PASS | PASS | 1 |
| prim_flop_2sync_sim | PASS | PASS | 1 |
| prim_lfsr_sim | PASS | PASS | 9 |
| prim_present_sim | PASS | PASS | 3 |
| prim_prince_sim | PASS | PASS | 2 |
| pwm_sim | PASS | PASS | 61 |
| rom_ctrl_sim | RUNTIME_MEMORY_LIMIT | PASS | 422 |
| rstmgr_cnsty_chk_sim | PASS | PASS | 28 |
| rstmgr_sim | PASS | PASS | 37 |
| rv_dm_sim | PASS | PASS | 185 |
| rv_timer_sim | PASS | PASS | 5 |
| spid_jedec_sim | RUNTIME_FAIL | PASS | 1 |
| spid_readcmd_sim | PASS | PASS | 1 |
| spid_status_sim | PASS | PASS | 1 |
| sram_ctrl_sim | PASS | PASS | 398 |
| tl_agent_sim | PASS | PASS | 184 |
| top_earlgrey_xbar_main_sim | RUNTIME_MEMORY_LIMIT | PASS | 207 |
| top_earlgrey_xbar_peri_sim | RUNTIME_MEMORY_LIMIT | PASS | 58 |
| uart_sim | PASS | PASS | 722 |
| top_earlgrey_alert_handler_sim | RUNTIME_MEMORY_LIMIT | PASS | 955 |
| entropy_src_sim | RUNTIME_FAIL | DEBT | 40 |
| otp_ctrl_sim | RUNTIME_MEMORY_LIMIT | DEBT | 135 |
| spi_device_sim | DEBT | DEBT | 196 |
| spi_host_sim | RUNTIME_TIMEOUT | DEBT | 783 |
| spid_passthrough_sim | RUNTIME_FAIL | DEBT | 6 |
| trial1_sim | DEBT | DEBT | 1 |
| chip_sim | FAIL | FAIL | 0 |
| flash_ctrl_sim | FAIL | FAIL | 0 |
| i2c_sim | FAIL | FAIL | 0 |
| spi_tpm_sim | FAIL | FAIL | 0 |
| sysrst_ctrl_sim | PASS | FAIL | 0 |
| adc_ctrl_sim | RUNTIME_FAIL | RUNTIME_FAIL | 2 |
| hmac_sim | RUNTIME_FAIL | RUNTIME_FAIL | 9 |
| otbn_sim | RUNTIME_FAIL | RUNTIME_FAIL | 4 |
| pwrmgr_sim | MATRIX_ERROR | RUNTIME_FAIL | 5 |
| spid_upload_sim | RUNTIME_FAIL | RUNTIME_FAIL | 6 |
| usbdev_sim | RUNTIME_FAIL | RUNTIME_FAIL | 13 |
| edn_sim | RUNTIME_MEMORY_LIMIT | RUNTIME_TIMEOUT | 1800 |
| ibex_icache_sim | RUNTIME_TIMEOUT | RUNTIME_TIMEOUT | 1800 |

## Remaining non-PASS, and why

* **hmac, pwrmgr:** pristine source fails; their exact-hash overlays (`hmac_status_live_counters.patch`,
  `pwrmgr_clock_edge_count.patch`) pass in selected replays but are not applied to this shared copy.
* **otbn:** needs `+otbn_elf_dir`; **spi_tpm:** upstream-invalid overrides of localparams; **spid_upload:**
  testbench has no checker or pass banner.
* **entropy_src, otp_ctrl, spi_device, spi_host, spid_passthrough, trial1 (DEBT):** recorded warnings only
  (covergroup bins on a 1-bit type from `function unsigned f` is correct per slang; the `-gcommercial-unsafe`
  covergroup purity notice; packaging `cSource` notices). The spi rows included the unbound `foreach` iterator
  that is now fixed; they need a rerun to clear.
* **sysrst_ctrl:** the census compile failed on a vif event `sorry` (regression from an earlier commit); fixed
  afterwards and a selected replay PASSES in 44 s.
* **i2c:** three covergroup features (ignore/illegal transition bins, a constructor `with` filter) and
  `.sum()` over a rand dynamic array in `std::randomize() with`.
* **chip, flash_ctrl:** other compile blockers (see `docs/conformance/BLOCKERS.md`).
* **adc_ctrl:** needs rand 2-D dynamic arrays of packed structs in the solver (three solve stages).
* **usbdev:** randomization now succeeds; a deliberately bad-PID packet is not flagged by the DUT
  (`rx_pid_err` never set), cause not isolated.
* **edn, ibex_icache:** run to the 1800 s cap, memory flat; slow, not hung.

A virtual-interface `event` member (`@(vif.printed_log_event)`) is not supported and is silently skipped, and
reading through a null virtual interface returns 0; both are recorded as follow-ups.

## Census 2 (final image, after commit 2b7ad622c)

Same command as census 1, 49 cores, 3 jobs. Result: **32 PASS**, 6 RUNTIME_FAIL, 4 FAIL, 4 DEBT, 2 RUNTIME_TIMEOUT, 1 RUNTIME_MEMORY_LIMIT
(frozen baseline: 23 PASS; census 1: 30 PASS). Files: `result-census2.json`, `result-census2.md`.

- No core that passed in the frozen baseline stopped passing. `sysrst_ctrl` (a census 1 FAIL) passes again after the vif validity change.
- New PASS vs census 1: `spi_host` (the caller-array iterator and packed-select fixes).
- `spi_device` moved from DEBT to RUNTIME_MEMORY_LIMIT: it now gets past compile/elaboration and then hits the 4 GiB cap. Not yet diagnosed; check for another reclaim path before assuming a DUT problem.
- `pwrmgr` is not an overlay-applied run, so its RUNTIME_FAIL is expected here.

### spi_device probe (bounded, 8 min)

The run is alive, not stuck: simulation time advances (about 43 us after 90 s, `IVL_PC_PROGRESS`), no UVM output at UVM_LOW, and RSS grows slowly (about 300 MB at 0 s, 490 MB at 5 min, 620 MB at 8 min). The census run reached the 4 GiB cap at 21 min, so growth accelerates later. Most active scopes are `tb.dut.tlul_assert_device.gen_device_cov` and the register assertions, i.e. throughput of assertion/coverage processes, same family as edn/ibex_icache. Next step is a `heap`/`malloc_history` sample around minute 15, not another full run.

## Census 3 (after commit 70ae3be50)

Same command as census 1 and 2, 49 cores, 3 jobs. Result: **33 PASS**, 5 DEBT, 5 RUNTIME_FAIL, 3 FAIL,
2 RUNTIME_TIMEOUT, 1 RUNTIME_MEMORY_LIMIT. The five DEBT cores (chip_sim, entropy_src, otp_ctrl, spid_passthrough,
trial1) all reach the checked pass banner; DEBT only records unresolved warnings. Files: `result-census3.json`,
`result-census3.md`.

- No core that passed in the frozen baseline stopped passing.
- Versus census 2: `pwrmgr` RUNTIME_FAIL -> PASS (no overlay applied), `chip_sim` FAIL -> DEBT. chip_sim is the whole
  top_earlgrey chip: its xbar smoke passes (918 items) once the runner applies the test's `en_run_modes` (`+xbar_mode=1`).
- chip_sim's remaining debt: four `@(cfg.chip_vif...)` waits on clocking-block events, a `%p` of an unpacked struct, and
  `ref` actuals that are array elements (copy-in/out instead of aliasing).
- Still FAIL: flash_ctrl (fixed arrays of containers as one aggregate: `ref` actual and whole-array assignment),
  i2c (covergroup `with` filter at construction; ignore/illegal transition bins), spi_tpm (the testbench overrides
  localparams and a parameter the RTL does not have: an upstream defect at this pin).
- Still RUNTIME_FAIL: adc_ctrl (rand 2-D dynamic array), hmac (needs its overlay), otbn (needs an ELF directory),
  spid_upload, usbdev (`rx_pid_err`).
- Slow: edn and ibex_icache time out at 1800 s; spi_device reaches the 4 GiB cap.
