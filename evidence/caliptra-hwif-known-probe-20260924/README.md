# Caliptra `hwif_in` diagnostic probe mechanic

The completed mailbox pilot fails pinned `soc_ifc_reg.sv`'s unchanged
`ERR_HWIF_IN` assertion at 551.935 us, but its log does not identify which
of the 2,422 packed bits is unknown. This isolated edge-race reducer checks
how to print the value that the assertion sampled before attempting another
multi-hour L0 replay. It is **not** a Caliptra L0 result.

Using installed `ivl` SHA-256 `6ec92c4825dc51e3810d1cb22405071f033015626d39cf3db92c319aeb9d3b10`
and `vvp` SHA-256 `e9b7a64a8643973c9bc6597ca604285bbd718cf733e45181f6155390d9fdc8c6`:

```sh
local-install/bin/iverilog -g2017 -gassertions -o /tmp/caliptra-hwif-probe-check-20260924.vvp evidence/caliptra-hwif-known-probe-20260924/sampled_argument_probe.sv
local-install/bin/vvp -n /tmp/caliptra-hwif-probe-check-20260924.vvp
```

The deliberate fatal exits 1. Its companion property receives the sampled
four-state argument `1x`, while the original assertion's failure action sees
the NBA-updated live value `11`. A separate `$sampled(hwif_in)` call in an
assertion action warned that it returns a live approximation and did not
preserve the four-state sample. The L0 probe should therefore add only an
always-true companion property whose function prints the sampled argument
when unknown. Leave the pinned assertion predicate, reset disable, and fatal
action intact on a hash-guarded disposable source copy.

The separate mailbox replay uses [soc_ifc_reg_sampled_probe.patch](soc_ifc_reg_sampled_probe.patch)
on a disposable copy only. [compile_command.json](compile_command.json) records
the source, filelist, tool, patch, and output hashes. Its full-top compile
exited zero, and the 28-line compile log is byte-identical to the completed
mailbox case's compile log. The original `ERR_HWIF_IN` property remains in
place. The diagnostic VVP is running under `/tmp/caliptra-hwif-probe-20260924/`;
it is outside the 52-case numerator, and no sampled field or runtime verdict
is claimed until that process finishes.

The committed patch uses zero context lines to keep its own whitespace clean.
It reproduces the exact running source copy; the manifest retains the hash of
the originally applied patch as `applied_patch_sha256`.
