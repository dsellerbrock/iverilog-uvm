# Caliptra bundled AXI BFM RUSER allocation

The pinned Caliptra v2.1.2 `src/axi/rtl/axi_if.sv` allocates `data` and
`resp` in `axi_read`, then writes `resp_user[beat]` without allocating
`resp_user`. Its source SHA-256 is
`e03bd7a7654eb9c31bd532861b94d59c876810aa9798f9f67f7df2a5a3f5495c`.
The active Icarus L0 diagnostic logs print `cannot write to an undefined
darray<vector[32]>` during the SoC BFM's flow-status read. That BFM checks
the separately allocated read data and does not consume the returned RUSER
on this path; the warning is a real lost AXI sideband value, but this trace
does not establish an incorrect flow-status value.

The [one-line patch](../../docs/conformance/release_overlays/caliptra/axi_read_resp_user_alloc.patch)
allocates `resp_user` to `len+1` on a disposable copy of that file. The
[focused test](axi_ruser_read.sv) drives a two-beat read and checks both data
beats, both RUSER values, both responses, and all array lengths. On the
unchanged installed compiler, pinned source compiles in strict and explicit
unsafe 2017/2023 modes, then fails all four runtimes with two undefined-array
warnings and no pass marker. The patched copy compiles and passes all four
runtimes with one pass marker and zero undefined-array warnings. Tool, patch,
source, and post-patch hashes are in [result.json](result.json).

To repeat, copy only `src/axi/rtl/axi_if.sv` under a disposable root, verify
its pinned hash, and apply the patch there with `patch -p1 -d <copy-root> -i
<patch>`. Compile `axi_pkg.sv`, the copied `axi_if.sv`, and `axi_ruser_read.sv`
with `local-install/bin/iverilog -g2017` and `-g2023`, with and without
`-gcommercial-unsafe`; run each image with `local-install/bin/vvp -n`.

This patch is not in the active exact-52 runner. Its live tool/runner
fingerprints remain unchanged. The current `smoke_test_veer` 1/52 result is a
separate copied-source diagnostic under its recorded gate, with this warning;
it is not pristine, IEEE, or warning-clean L0 qualification. A future full
runner profile must select the patch explicitly and replay the case checks
before making a warning-clean claim.
