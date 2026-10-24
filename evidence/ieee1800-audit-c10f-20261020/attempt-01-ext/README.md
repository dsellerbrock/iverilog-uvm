# §10.7–§10.8 assignment sizing and assignment-like contexts

Ran Slurm job 3535 on DAN-DESKTOP with the pinned Icarus 13.0-devel toolchain (`cc25756d1`), 1 CPU, 1 GiB RAM, and a 30-second timeout for each compile and simulation. The exact commands are in `run.sbatch`; the full scheduler transcript and per-case stdout/stderr are under `slurm-3535.out` and `results-3535/`.

Tool hashes:

- `iverilog`: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`
- `vvp`: `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`

The first log reported `ivl` and `ivlpp` from the A5 profile install path. Their SHA-256 hashes matched the pinned audit toolchain copies exactly: `ivl` `218796e8e4fe0587816e8e8e4fa43b2088807368c9f776f4797fc431a55fcd3d`; `ivlpp` `07d3adc5c29c525db009829290dc418b04425a08ee17ea5305ab08b19889c8f2`. The follow-up §20.6.2 run pins the helper directory with `-B` and records these hashes again.

Source hashes:

- `p10_07_08.sv`: `9429a976938657d3980eaeef29e684a259e4dac9a1ff06e6928f70945acd7599`
- `p10_08_cast_ctx.sv`: `b0ce62f3a09545f6067919d4bbb60c2160db18f99721f28d37d224f31dd582af`
- `p10_08_cast_ctx_k0.sv`: `c763b165ba897e7145d531b1b8ddb8f9b183f1222c1f570baf2be55a60caad1d`

## Results

`p10_07_08.sv` compiled and ran successfully in both `-g2017` and `-g2023`. Each printed:

```text
T1 5
T2 0a
T3 fe
T4 0e
T5 0f
T6 ff 66
C1 5 6
C2 7
C3 3 4
```

The typed-pattern control `p10_08_cast_ctx_k0.sv` compiled and ran in both editions, printing `K0 3 4`.

`p10_08_cast_ctx.sv` compiled and ran in both editions. Both printed `K0 3 4`, `K1 5 6`, and `K2 7 8`; both printed `K3 -1` where the lead expected `$bits(P'('{1, 2}))` to print `64`. Thus Icarus permissively accepts the cast operand in 2017, and the `$bits` observation needs lead classification before attributing it to §10.8.

Open-and-closed GitHub searches for `sign extension assignment`, `truncation`, `assignment-like context`, `pattern argument`, `10.7`, `10.8`, `cast assignment pattern`, and `assignment-like context cast` are saved as `dedupe-*.json`. No issue title directly covers §10.7/§10.8; #415 is a closed nested assignment-pattern return issue and does not describe this behavior. The broad `cast assignment pattern` search result #27 is unrelated.

Remote run directory was removed after copying the evidence; `du -sb` recorded 25,673 bytes freed.
