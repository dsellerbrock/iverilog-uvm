# CSRNG packed net-array metadata crash triage

The pinned CSRNG overlay smoke image aborts during **VVP bytecode parsing**,
before time advances or UVM starts. LLDB's
[backtrace](csrng-lldb.stdout.log.gz) is
`compile_packed_dims` → `resolv_submit` →
`packed_dims_resolv_t::resolve` (`vvp/words.cc:68`) →
`__vpiArray::get_word_size` (`vvp/array.cc:483`), which asserts because the
first array word is not yet a `__vpiSignal`. This is independent of the smoke
seed, plusargs, or transaction traffic.

The [paired RED](concat_driver_candidate.sv) is a singleton unpacked **net**
array with two packed dimensions and a concatenation driver. Both `-g2017`
and `-g2023` compile (exit 0), then VVP aborts (exit -6) with the exact
`get_word_size` assertion. Its emitted VVP order is:

```text
.array "words", 0 0;
.net <array-word>, ..., L_<forward-driver>;
.packed_dims <array-word>, "1:0,3:0";
.packed_dims <array>, "1:0,3:0";  // abort here
L_<forward-driver> .concat ...;
```

`compile_netw` queues the word's unresolved source; the parent array's
`packed_dims_resolv_t` immediately calls `get_word_size()` while `nets[0]`
is still null. The exact 70 MB CSRNG image has the same order for
`csrng_block_encrypt.key_init[0]` (packed `[7:0][31:0]`, unpacked
`[NumShares]` with `NumShares=1`): VVP `.packed_dims` line 1,805,178
precedes its `.concat` driver at line 1,805,262. The
[diagnostic bisect](bisect.json) shows this is the **first** of 28 array
metadata entries that can cause the CSRNG abort. Moving only the RED's
driver definitions before the array in a scratch VVP image makes it print
`PASS` ([order diagnostic](ir-order-diagnostic.json)); no SystemVerilog or
compiler source was changed.

[results.json](results.json) records exact paired commands, installed tool
hashes, stdout/stderr, and exits. A direct-driven packed net array and a
packed net-array port both pass. A variable array with the same two packed
dimensions passes, as does a concatenation-driven net array with only one
packed dimension (which emits no `.packed_dims`). The negative procedural
assignment to a net-array word is rejected at compile time in both editions.

The narrow implementation boundary is `vvp/words.cc`: defer parent-array
packed-dimension validation until its first net word is attached, then
validate the word width and report a hard error if the word never resolves or
is nonintegral. `vvp/compile.cc` already retries unresolved resolvers at
cleanup; `vvp/array.cc` contains the unsafe accessor but need not be changed
if the metadata resolver guards it. This is a runtime linker-order defect,
not the prior OpenTitan pwrmgr seed-3 checker failure: the documented seed-3
pwrmgr overlay run reaches `TEST PASSED CHECKS` with zero UVM errors/fatals,
whereas CSRNG aborts before its first UVM report. No implementation is
included here.
