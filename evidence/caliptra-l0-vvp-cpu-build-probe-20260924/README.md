# Isolated VVP CPU build comparison

An isolated VVP built from campaign commit `0135675da` with Apple clang 21,
`-O3 -mcpu=apple-m5`, and no LTO passed VVP's bundled `hello.vvp` smoke. It was
never installed. Its SHA-256 was
`f0c3e3ae975081f8c00148c388528255396506b1e689f221b6bec53eaa41ea33`;
the installed `-O2` VVP was
`e9b7a64a8643973c9bc6597ca604285bbd718cf733e45181f6155390d9fdc8c6`.
No VVP source changed between that commit and this evidence.

Both binaries ran separate copies of the same `smoke_test_mbox` firmware inputs
against compiled top SHA-256
`cd388a641e375edd773d0c7b5068783eb47944b0ec74ed53b78f6c082a7db81c`.
Each 180-second prefix loaded the same JTAG DPI bundle, used `-n`,
`+CLP_REGRESSION`, and `+CLP_BUS_LOGS`, and recorded zero error markers. The
installed-first and candidate-first orders each yielded **369 retired
instructions and 440 byte-identical trace lines for both builds**. The raw
per-run commands, binary hashes, times, and counts are in
[`installed-first.json`](installed-first.json) and
[`candidate-first.json`](candidate-first.json). The current build therefore
has no measured throughput disadvantage on this prefix; no optimization was
integrated. These intentionally timed-out prefixes are performance probes, not
L0 results. The separate long single-case pilot still owns the completed
runtime verdict.

A first `-O3 -flto=thin` isolated build was rejected earlier: even bundled
`hello.vvp` exited 139 before output, and its binary lacked the
`vpi_register_systf` export present in the installed binary. No LTO binary was
used for Caliptra qualification. The missing export is consistent with link-time
internalization of dynamically used VPI entry points; this was not pursued in
the active campaign.
