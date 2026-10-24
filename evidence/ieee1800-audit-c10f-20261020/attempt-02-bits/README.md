# §20.6.2 `$bits` isolation probe

Ran Slurm job 3536 on DAN-DESKTOP with Icarus 13.0-devel (`cc25756d1`), 1 CPU, 1 GiB RAM, and `-B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl` to pin helper tools. Each compile had a 30-second timeout. The full Slurm transcript, compile stdout/stderr, source, and exact invocation are preserved here.

Hashes recorded in the job log:

- `iverilog`: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`
- `vvp`: `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`
- `ivl`: `218796e8e4fe0587816e8e8e4fa43b2088807368c9f776f4797fc431a55fcd3d`
- `ivlpp`: `07d3adc5c29c525db009829290dc418b04425a08ee17ea5305ab08b19889c8f2`
- probe: `b96bbd53b7f5a8723a575da0426583140c5c2414972b8afdeb2cce6703d4d7b5`

Both `-g2017` and `-g2023` rejected the combined probe at line 8 (`$bits(P)`) and line 12 (`$bits(real)`) with `Invalid data type for $bits()`. No runtime result was produced, so the other controls in this combined source remain unobserved. The `$bits(P)` error is already reported by open issue [#788](https://github.com/dsellerbrock/iverilog-uvm/issues/788), which also records a wrong size for an unpacked-structure variable; [#652](https://github.com/dsellerbrock/iverilog-uvm/issues/652) covers dynamic queues. Under IEEE 1800-2017 §6.24.3, `real` is not a bit-stream type, so rejection of `$bits(real)` is not a gap. Targeted open/closed searches are saved as `dedupe-*.json`.

The remote run directory was removed after copying evidence; `du -sb` recorded 7,573 bytes freed.
