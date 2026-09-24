# Caliptra time-zero reset diagnostic (Icarus only)

The first VEER checker error in the unsafe `smoke_test_veer` replay is the ungated deferred immediate assertion `assert #0 (~fifo_done[i] | fifo_valid[i])` at pinned `el2_dma_ctrl.sv:505`. The non-UVM BFM drives `cptra_pwrgood = 1'b0` in a time-zero `initial` block (`caliptra_top_tb_soc_bfm.sv:210`). The boot FSM's `always_ff @(posedge clk or negedge cptra_pwrgood)` generates the VEER reset, which then resets the FIFO flops. If the time-zero drive precedes event-control registration, the chain stays X until a clock edge and the checker reports a real unknown-state failure. This is a startup ordering diagnostic, not evidence of an SVA evaluator defect.

`prepare_overlay.py` requires the exact pinned BFM SHA256 `e0c60be6ad48681458ca38093a494ae263304997e658c5eefa006881da10ae06` and diagnostic filelist SHA256 `577861eb1c4c9a26ada2379f55e3215d097e1cc317804a0f3155c3786ed381f2`. It writes **only under `/tmp`**: a copied BFM with one changed line, `#0 cptra_pwrgood = 1'b0;`, and a copied filelist with only that BFM entry redirected. The pinned checkouts and every assertion/check remain untouched. Generate the disposable files with:

```sh
python3 evidence/caliptra-l0-timezero-reset-overlay-20260923/prepare_overlay.py /tmp/caliptra-reset-overlay
```

IEEE 1800-2017 and 1800-2023 §§4.4.2.2 and 4.7 permit Active-region processes to execute in either order; §9.4.2 defines X-to-0 as a negedge. The BFM's time-zero blocking assignment and the boot FSM's reset event control therefore have no guaranteed ordering. If the assignment executes before the FSM is waiting, that edge cannot wake it. Icarus emits ordinary threads for both `initial` and `always_ff` (`tgt-vvp/vvp_process.c:7821-7859`, `vvp/compile.cc:3190-3207`), with no standards-required priority. Forcing a preferred startup order in Icarus would choose one permitted outcome, not correct an IEEE defect in the unchanged testbench.

The reducers model the two-stage reset and FIFO flops. `reset_chain_reordered.sv` moves the unchanged reset `always_ff` declaration ahead of the unchanged time-zero `initial` block; it changes no assignment or timing control. `reset_chain_delayed.sv` models the disposable BFM overlay. From the campaign checkout, replay all cases in both editions with:

```sh
for mode in 2017 2023; do
  for kind in original reordered delayed; do
    local-install/bin/iverilog -g${mode} -gassertions -o /tmp/reset-${mode}-${kind}.vvp evidence/caliptra-l0-timezero-reset-overlay-20260923/reset_chain_${kind}.sv
    local-install/bin/vvp /tmp/reset-${mode}-${kind}.vvp
  done
done
```

| Icarus edition | Original process order | Reordered declarations | `#0` delayed drive |
| --- | --- | --- | --- |
| 2017 | One time-zero FIFO `ERROR`; reset/FIFO X at time 1 | Zero `ERROR`; reset/FIFO 0 at time 1 | Zero `ERROR`; reset/FIFO 0 at time 1 |
| 2023 | Same | Same | Same |

All reducers exit zero, including the one that prints `ERROR`; runtime qualification must check diagnostics, not exit status alone. The declaration-order pair establishes the standards-permitted race, while the overlay is **diagnostic nonstandard compatibility evidence**. The full Caliptra top has not been replayed with it, and the independent missing ECC/DOE/SHA/ML-DSA/ML-KEM vector generators in that replay remain a setup blocker. There is no L0 pass claim.
