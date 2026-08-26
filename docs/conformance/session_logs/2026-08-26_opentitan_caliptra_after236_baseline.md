# OpenTitan and Caliptra baseline after PR 236 (2026-08-26)

## Scope and compatibility target

This baseline was collected from Icarus commit
`c2072ad7b21980f29ead885e2d0ed3fc8c1f74b2`, exactly matching
`origin/main` after PR 236. OpenTitan, Caliptra, and Adams Bridge were not
modified. The compatibility target is IEEE 1800 behavior used by VCS, Questa,
and Xcelium. Slang is an independent parser/elaborator comparison only;
Verilator is not the language, UVM, DPI, or VPI oracle.

No commercial simulator executable is installed on this host, so these are
commercial-style source-compatibility baselines rather than direct commercial
simulator differential runs. OpenTitan's runtime inventory deliberately uses
the 77 targets whose metadata selects VCS; Verilator-only targets are excluded
from that runtime lane.

## OpenTitan

The unmodified OpenTitan revision was
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`. The actual FuseSoC 2.4.5 and
Edalize 0.6.3 flow completed 530 jobs in 325.42 seconds with no timeout or CPU
guard termination.

| Lane | Jobs | PASS | Dependency only | Upstream invalid | DEBT | FAIL | Runtime fail | Setup fail |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| RTL | 264 | 93 | 153 | 18 | 0 | 0 | 0 | 0 |
| SVA | 128 | 95 | 4 | 27 | 0 | 2 | 0 | 0 |
| UVM compile | 61 | 0 | 0 | 0 | 0 | 58 | 0 | 3 |
| Runtime | 77 | 0 | 0 | 0 | 2 | 68 | 4 | 3 |
| **Total** | **530** | **188** | **157** | **45** | **2** | **128** | **4** | **6** |

The 128 `FAIL` rows are not 128 independent compiler defects. The UVM compile
rows recur in the runtime lane. Deduplicating those rows leaves 70
compiler-blocked cores: 2 SVA, 58 UVM, and 10 directed. Their first hard
diagnostic divides into 35 parser frontiers, 18 runtime-valued coverage-bin
frontiers, 8 missing `prim_clock_gating` provider cases, 3 unresolved clocking
declaration signal paths, and 6 one-off elaboration/internal diagnostics. The
35 parser rows are a work queue, not a claim that they share one root cause.

The first common compiler frontier is a legal constructor-dependent
covergroup range used by the TL agent. Icarus diagnoses that the runtime-valued
range cannot be represented and drops the bin. The first UVM parser frontier
is parameterized-class inheritance in `ac_range_check_env_cov`. The first
compiled runtime semantic failure is `prim_esc_sim`, which reports four
assertion failures.

The other runtime failures are `prim_flop_2sync_sim` (queue underflow and
value mismatch), `prim_present_sim` (unloaded required DPI symbols followed by
crypto mismatches), and `prim_prince_sim` (VVP concat port-width invariant).
The six setup-failure rows are three fault-injection cores duplicated between
UVM and runtime lanes; register generation succeeds before their pinned source
graphs reference missing `fi/strobe.sv`.

Clean `PASS` remains 188 relative to the preceding full matrix. Three labels
became louder because the runtime coverage-bin drop is now a hard diagnostic:
`adc_ctrl_sva` changed from `DEBT` to `FAIL`, and the UVM/runtime `tl_agent_sim`
rows changed from `DEBT`/`RUNTIME_FAIL` to `FAIL`. This exposes existing lost
coverage rather than regressing a previously correct implementation.

The real UART register-generation flow also ran through OpenTitan's
`util/regtool.py`. It returned zero in 0.33 seconds, and the generated
`uart_reg_pkg.sv` and `uart_reg_top.sv` are byte-identical to the checked-in
RTL.

## Caliptra

The unmodified Caliptra revision was
`bd31614182fb56e55578f48086a10ded650434fd`; Adams Bridge was
`e59eba955eac2a1adcb059f250641ede78e304be`. The frozen 105-manifest matrix
made 420 compiler invocations in 89.00 seconds.

| Lane | Passed |
|---|---:|
| Icarus, assertions enabled | 53/105 |
| Icarus, assertions disabled diagnostic lane | 53/105 |
| Icarus `-S` | 53/105 |
| Slang IEEE 1800-2017 | 54/105 |

Classification is 52 clean `PASS`, 1 semantic `DEBT`, 51
`SHARED_SOURCE_OR_CONFIG`, 1 `SOURCE_ORDER_DEBT`, 0 demonstrated Icarus
language gaps, and 0 timeouts. Both `caliptra_top` and
`caliptra_top_ss_mode` pass all three Icarus static lanes and Slang. A separate
assertion-enabled VVP generation of the unmodified DUT-only top completed with
zero diagnostics in 5.37 seconds, peaking at 727,105,536 bytes RSS.

Thirteen synthesis rows improved from the earlier 40/105 ARM64 baseline, with
no reverse flip: `ahb_lite_bus`, `sha512_ctrl`, `sha256_ctrl`, `sha3_ctrl`,
`doe_ctrl`, `hmac_ctrl`, `soc_ifc_top`, `ecc_top`, `keyvault`,
`entropy_combiner`, `abr_top`, `caliptra_top`, and
`caliptra_top_ss_mode`.

The sole raw Slang lead, `csrng_raw_wrap`, imports a package before its
declaration in the checked-in filelist. It is source-order portability debt,
not a demonstrated Icarus IEEE gap. Both tools reject the 51 shared cases;
they reduce to 11 checked-in source/filelist causes such as missing assertion
include paths, packages, primitive providers, or declared tops. Full
application runtime remains outside this local baseline because the checked-in
verification inventory references unavailable UVMF, Questa MVC, Avery, and
ARM AXI checker inputs.

## Native ARM64 invocation notes

- Use Homebrew Bison 3.8.x for configure/build. Apple's `/usr/bin/bison` is
  version 2.3 and rejects this grammar.
- Use the logical Python 3.13 virtual-environment path for OpenTitan. Resolving
  its symlink bypasses `pyvenv.cfg`; ambient Python 3.14 is outside the pinned
  toolchain.
- Invoke `regtool.py` through that interpreter, and pair FuseSoC with the
  package imported by the same environment.
- The shared runner applies a 45-second per-process CPU guard and no RSS
  ceiling.
- Caliptra's matrix driver already wraps each compiler. Do not outer-wrap the
  driver with the same hard CPU limit: inherited limits prevent its child
  setup from installing its own guard.
- Keep Caliptra's `+timescale+1ns/1ps` command file and absolute nested
  filelist paths; nested `-f` paths resolve relative to their containing file.

## Evidence

The untracked workspace evidence is under
`evidence/opentitan-caliptra-after236-arm64-20260826/`.

- OpenTitan JSON SHA-256:
  `e09c2dae2bfee5ac8b6ece5cac1c2ae0b9967f7f000f2336eb30c521390658a3`
- Caliptra JSON SHA-256:
  `821d9022e3325aca643941bdf4df461f2375369a66a3f1e55b1f865811863c55`

Both external corpora and the Icarus worktree were clean after the runs.
