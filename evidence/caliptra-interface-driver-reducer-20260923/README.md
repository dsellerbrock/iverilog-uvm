# Caliptra interface-driver reducer (2026-09-23)

Commands use `local-install/bin/iverilog -g2017|2023 -s <top> -o <out> <source>`.

- `legal_forwarding.sv`: continuous assignment to an interface variable consumed through an input modport; compiles in both editions.
- `overlap.sv`: continuous and procedural assignment to the same variable; rejected in both editions.
- `interface_forwarding.sv`: same forwarding plus a task declared in the interface that procedurally assigns the field; rejected in both editions, even though the task is not called.

This isolates the *reported mechanism*: interface-member continuous forwarding itself is accepted. A task declaration containing a procedural assignment to the same variable is counted as an overlapping driver. Caliptra's `axi_if` declares `rst_mgr` and other tasks that procedurally assign these `logic` members, while `caliptra_top_tb_axi_complex.sv` continuously assigns 23 members in each of its two local interface instances. The 46 profile errors match those 46 destinations.

Standards boundary: IEEE 1800-2017 §10.3.2 states variables can only be driven by one continuous assignment or one primitive/module output and makes any procedural assignment to a variable driven continuously an error; §6.5 is referenced for nets and variables. The corresponding 2023 §§6.5 and 10.3.2 appear to retain this rule. Consequently the reduced source with the task assignment is not presently established as a legal RED; the first legal forwarding control passes, and genuine overlap control fails as expected. No implementation source was changed. The follow-up below found no task-reachability exception.


## Slang and task reachability follow-up

Paired Slang 9.1.0 `--std 1800-2017` and `--std 1800-2023` results are recorded beside each source as `*_slang_<edition>.{stdout,stderr}`; matching Icarus logs use `*_icarus_<edition>.*`. Both compilers agree: plain interface forwarding passes; the interface task body with no call fails; the same interface task when called fails; direct continuous/procedural overlap fails; and module-scoped task bodies fail whether unreferenced or called. The diagnostic is not specific to interface-member forwarding or to called processes.

In Icarus, behavioral l-values register in `NetNet::lref_objs_` when `NetAssign_` is constructed (`netlist.h`/`netlist.cc`); `NetNet::test_part_procedurally_driven()` checks that list without task-call reachability. Continuous assignment elaboration consults this predicate in `elab_net.cc`; interface-variable assignments are deferred, then checked against `test_part_driven()` in `elaborate.cc`. Slang independently rejects both uncalled-task variants with `[-Wmixed-var-assigns]`. The current paired evidence supports the standard rule in IEEE 1800-2017/2023 §10.3.2 (procedural assignment to continuously driven variable is an error); no reachability-based exception is demonstrated.

For the actual top, the member-writer task definitions are in the pinned `caliptra-rtl/src/axi/rtl/axi_if.sv`; `rst_mgr` is called on `m_axi_bfm_if` in `caliptra_top_tb_soc_bfm.sv`, while the two locally forwarded `axi_sram_if` and `axi_fifo_if` instances are not task receivers in `caliptra_top_tb_axi_complex.sv`. The declarations still contain task bodies assigning the fields. This does not change the standards result: no Icarus change is justified by the paired reducer.

The unmodified release has no alternate flag/filelist profile that removes the
conflict and keeps active L0 BFM calls. `SYNTHESIS` and `XCELIUM` exclude the
task declarations but leave `m_axi_bfm_if.rst_mgr`, read, and write calls
unresolved; `VERILATOR` retains the tasks and selects a different simulation
path. Meeting both unmodified-source and strict IEEE driver requirements
needs a release-side source correction that separates the task-bearing BFM
interface from the continuously forwarded internal interfaces, or otherwise
gives each member one legal driver.

The local QD-BFM at `/Users/danielellerbrock/projects/quick-and-dirty-eda/qd-bfm`
is not an alternate released L0 profile. Its `qd_axi4_single_master.sv` is a
scalar-pin, single-beat manager without AXI USER/LOCK or bursts. The pinned
filelist does not include it, while `caliptra_top_tb_soc_bfm.sv` uses multi-beat
mailbox transfers and nonzero USER values. Replacing that external BFM would
still leave the 46 errors on the separate internal DMA `axi_sram_if` and
`axi_fifo_if` instances. No QD source or pinned Caliptra source was changed.
