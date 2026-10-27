# IEEE 1800 §§20.8–20.9 math and bit-vector probe

The combined probe `p20_08a_math_bits.sv` compiles successfully in both `-g2017` and `-g2023` modes on macOS ARM64 using the local T2 Icarus build. Each compile and simulation used `~/codex-supervisor/localrun 10`, sequentially. Tool and source hashes, full logs, exit codes, wall time, and peak RSS are in `attempt-01-math-bits/`.

Both VVP runs abort with exit code 134 before printing `FAIL` or `RESULT`:

`internal error: vpi_get_value(<format=5>) not implemented for __vpiVThrVec4Stack.`

`Assertion failed: (0), function vpi_get_value, file vpi_vthr_vector.cc, line 589.`

The audit lead then isolated 30 single expressions in `attempt-02-isolated/`. All 30 compile and run with the expected value in both editions, including `$countbits` with variable x/z controls, `$onehot` on a variable, `$isunknown` on a variable, all tested `$clog2` cases, and the isolated math functions. The VPI abort therefore remains specific to an interaction or call context in the combined probe; no §20.8/§20.9 issue has been classified or filed yet.

## Fixture whitespace normalization

The 30 `m/*.sv` fixture sources were normalized after the original probe in `attempt-02-isolated`; that historical record contains no Slurm job number because it was a local Mac run. Only trailing spaces and tabs were removed, so semantics are unchanged. On 2026-10-21, all 30 sources were recompiled and rerun in both editions under `localrun 120` with the same pinned Icarus/VVP hashes (60/60 case outputs match the prior records). Per-case output is in `attempt-02-isolated/whitespace-recheck-20261021.log`; localrun resource output is `attempt-02-isolated/whitespace-recheck-localrun.log`.

Post-normalization SHA-256 (trailing spaces and tabs removed):

| Original SHA-256 | Post-normalization SHA-256 | Fixture |
|---|---|---|
| `27963c2fae0fe02dc0faec3e66c19ea7b7480b2fee8bde97376385fce4e65dbe` | `33b59220e41daa8899c56eee2bbd80aea319977e818a21783613bc7608246cc3` | `tests/1800_audit/c20/m/m_acosh.sv` |
| `7d3ed8d34f416707501986bc43ff1edd5436f2ee3f5132230a2457941364e1f1` | `e1c41c05ec7aadd12c3cfee9fa60f13319e6d79d0d1220e5119673eb2d6750d4` | `tests/1800_audit/c20/m/m_atan2.sv` |
| `69a3e616b8cfb90229e5f4d5ab03045b76e9675c9759ab8276467d343c895bbc` | `3ec369d50592418f93919b174c2bd548869ad62e189c04f40b784dfb9f73cf71` | `tests/1800_audit/c20/m/m_bitsof.sv` |
| `7b07b0c4b93c2a00c178fa51a93c539a61d4ba6b4f1c162b8a3a5a8ab5091735` | `ea0c76148194b288c68819005614200bdb62e912b0d34a31481f2ace3a56a288` | `tests/1800_audit/c20/m/m_cb1.sv` |
| `c0039128e28c37584c9e55c1ac8ea0ff52b2761c3ad3a65c7e744d655aab076d` | `aced4f71973d78c1523e6f2662cef1a9d425a651ffee7cb60b856ae6b98e48aa` | `tests/1800_audit/c20/m/m_cb2.sv` |
| `a27ea5d1fc4cba6d2b9b95dcb984fbcee44bac479a6b5c8de57e6f3b5ea6ce7f` | `cd2fe86053cd96514fbc98e3720942d64a218ca9c19976d195a75c33e5a55e0d` | `tests/1800_audit/c20/m/m_cb3.sv` |
| `36733b9ca554d37206d533eaef68eb511767089ea3e25f780531db6f44682677` | `88413f14fcef0a834b510ca8a0a2f3605b61ffb11f72f3f055b7a0246021ae0e` | `tests/1800_audit/c20/m/m_cb4.sv` |
| `cc9a1955c7fb7fe9849037e63f4adbd027f30e15bcd69942c643de5109b6a0de` | `79c720bc3c6abc8cabbfd1c53ff9df12086834783ea583cb6e13a3ecd4a1de15` | `tests/1800_audit/c20/m/m_cbvar.sv` |
| `3c863da70c2303761289758dcc2e53569a58c869be90d13d42c7e2aef0426877` | `4c458bc2459d78fe1d5126cda48f6f05ccc72fe263b9c0e74bd1c68ac995de27` | `tests/1800_audit/c20/m/m_ceilneg.sv` |
| `453ce0a368e66dba90dbec2bc6d591545c467f1c9d349d3c1ca0ebcceacc178d` | `27b25555be95fe5ad3e274b42ee7fbd2856aa78bccafe6c3b66bfd3a6b2443d4` | `tests/1800_audit/c20/m/m_clog0.sv` |
| `4fa3d1052b418535da4e8f6f5cf690432231631e7becaa41b9800d520d451046` | `43cb138e7c0aa74263a3ab3c8242c9292da1c367864f27c22ea68cadddbb37e4` | `tests/1800_audit/c20/m/m_clog1.sv` |
| `baf44f520cb7efb308314c191d4fd3f73ce626106961cb8b656ae1fda51131f2` | `cb9c1c119661f3fda2646eb7accd66325d33b9526cd629a91f7acc1b38926aef` | `tests/1800_audit/c20/m/m_clog1025.sv` |
| `0373b62b0e519d4cf1b74a6177d4630a3a2e8268446863fc976871aa72d135fa` | `a2ebe5fbc52ea0e003e4356c251fd57fb8bb003a28e3ab2bfebb35c81735acd2` | `tests/1800_audit/c20/m/m_clog3.sv` |
| `a184eb3114f9822b58a19e1959aa1325091ce63368b622154906cc28944826bc` | `ec3c28ed3d37a3a44b71f390919957c8f13ec3df019cdbc137b96f279dcb032a` | `tests/1800_audit/c20/m/m_clogbig.sv` |
| `37c2403ccf4c73a1b6135eb59ec6190065d6219fbb4208f95cee3a2966b75467` | `b7ec1b258ee7709230f6defc11d39ffa0606a37f5367e88cb2218a13654b2178` | `tests/1800_audit/c20/m/m_clogwide.sv` |
| `e1d862c869987b3c9f7dca374e517da890360831ba97c6d147d13272af185ed5` | `9b61cc272c00ccccd3d5c717a57a5b818c6126655caaae87b1669bb3480483da` | `tests/1800_audit/c20/m/m_co1.sv` |
| `df2d51bae61efc877358531ceef25cfe161c6a7c3461a8d37e5dca53cc16dba0` | `bed2acdd6b857daf07ac93f3480167b543b4f2a6baa87bea24f66528b56358c2` | `tests/1800_audit/c20/m/m_co2.sv` |
| `89ed21235e6504d439562f1ff1384046d9d5da054a2e9562e715218bebaf386c` | `556103e1db2a5ace99521463c52132f694b2c813f73d68e995327c1764b5f9b9` | `tests/1800_audit/c20/m/m_floorneg.sv` |
| `e32bf8f0a5da3015aefaae92da30bd1d4dafe2eefe495bb8608c9482f087cf52` | `ba2604ca4535e83dec21af167d52041a10a49aff6bfd78d52009cd00c49c0477` | `tests/1800_audit/c20/m/m_hypot.sv` |
| `5c1860d01e23e99be72075321610873d7bbf84cebbf71ca8d250ecf915506222` | `ace2370387fbcb2c81755bd3f3bb6329be21c0755ebc40d2c83984f025549242` | `tests/1800_audit/c20/m/m_isu1.sv` |
| `5b9026c8527c84f0077019bdbdb99f31a55afb078a2460c26fab65d34380a625` | `f1348421a1cbbd4d8ea40f3bd2801c29bebf2302947de255f187f400b5c7f76b` | `tests/1800_audit/c20/m/m_isu2.sv` |
| `6bb6b0869e0debe005509b55876e954ce0161d0352c4edf1f5225c71f38d5000` | `da921a058076d05dd974694597526fecf5c6802f81a4aa63ae1edf11e161b84f` | `tests/1800_audit/c20/m/m_oh0a.sv` |
| `b436651cbc667a2a012453bafa625d958ccdc2bc069dc0863323ee460365fe2c` | `0b8e857fc5efbe75352508d49d3d7f1d02f870eaa813630cc5f836f95005ed33` | `tests/1800_audit/c20/m/m_oh0b.sv` |
| `1710bae3e4d0c82dc5527d89f11d540e30f8e2496c0036482df3c83df1d28399` | `78f625a2205430e4bb687e37d8692be7437fe91b20c5adf0c78768805b9fccdc` | `tests/1800_audit/c20/m/m_oh1.sv` |
| `0841cd57328e04a4a9bbe743153efe82621f73461525c63817989a14c255fc46` | `f94fa5116dcdade5f12d03a96637a240f3364f0606614948076963ea25a5c4f3` | `tests/1800_audit/c20/m/m_oh2.sv` |
| `633cedae54224e26bf135a846ba8b2a958e1d21baa3b5c6905e65a6445f1eaf6` | `23deee93e0dd7f58eb6cb982911588530d92c71c685b921b3ab7ccf1b078ab78` | `tests/1800_audit/c20/m/m_ohvar.sv` |
| `3d7e2c3e39683aa166622bfb08cef733e320deaf6596cb65706fb698adfcf232` | `2e6a373a58eea297da03f08227c40326e8b2c1847d8479c5a8d3c1f10ae6fab9` | `tests/1800_audit/c20/m/m_onehotx.sv` |
| `e579a48f0993a7dd99e9b3369f4e1225122e8047234c56e432829bf8b949f5e8` | `39cae7d0f8c523d913f25b1c292618e3233ef7a3c5567e3ea9c1a4e62de6e813` | `tests/1800_audit/c20/m/m_pow.sv` |
| `164f46fa60396cd9ce5f783e6a58a4bb6037eca944b99a8919b5e38fa4a83f4b` | `b9581c97b05ad983d313e2210e9461fb078fc92170733f0b9b68c5af1cfda372` | `tests/1800_audit/c20/m/m_sqrt.sv` |
| `bfa7fded4d0016c3e2fcfd28ee8a509a46523a770b4626992c33c4b8c7745659` | `5a18a69b53efc6706320aa6d142e7e7db5c6b6ac579b69e049827875abd2a34d` | `tests/1800_audit/c20/m/m_tanh.sv` |
