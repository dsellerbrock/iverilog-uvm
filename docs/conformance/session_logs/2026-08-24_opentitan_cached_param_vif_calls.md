# OpenTitan cached parameterized-class virtual-interface calls

OpenTitan and Caliptra remained unmodified and read-only. This increment fixes
an Icarus elaboration-order defect exposed by the OpenTitan DMA UVM target.

## Defect and fix

Two derived classes can request the same parameterized base-class
specialization. A specialization-cache miss already elaborated the class
signature immediately and queued its method bodies until after root-module
bodies. The cache-hit path instead elaborated the cached body immediately.
That early body pass ran before concrete interface instances and their method
argument rows were visible.

For DMA, six valid calls in `dv_base_vseq` (`apply_reset()` twice and
`drive_rst_pin(...)` four times) were lowered before both reachable
`clk_rst_if` instances existed. Target generation consequently printed twelve
`has no argument row` diagnostics and emitted empty call bodies.

The cache-hit path now keeps signature elaboration immediate but queues body
elaboration through the same post-root worklist as a cache miss. Queueing is
unconditional once the cached scope is ready, so a full-body request is not
lost while recursive signature elaboration unwinds.

The permanent `sv_param_class_cached_vif_default` runtime regression uses two
derived classes sharing one specialization. It checks scalar and associative
array virtual-interface receivers, omitted declaration-scoped defaults,
explicit actual arguments, receiver rebinding, and selected-instance dispatch.
Slang 11.0.448 accepts the same test under both IEEE 1800-2017 and 1800-2023.

## Unmodified OpenTitan witness

The frozen FuseSoC DMA source closure was replayed from its generated work
directory with the patched ARM64 install:

```sh
resource-runner iverilog -g2012 -stb -uvm \
  -DUVM -DUVM_NO_DEPRECATED \
  -DUVM_REG_ADDR_WIDTH=32 -DUVM_REG_DATA_WIDTH=32 \
  -DUVM_REG_BYTENABLE_WIDTH=4 -DSIMULATION -DDUT_HIER=tb.dut \
  -o dma.vvp -c matrix-iverilog.scr
```

The compile completed in 3.02 seconds with exit zero, no target-generator
error lines, and no missing-argument-row diagnostics. Running the resulting
unmodified DMA image constructs `dma_base_test` and reaches its next Icarus
runtime frontier at time zero: an alert-agent driver dispatches to
`dv_base_driver`'s base `drive()` implementation and raises `UVM_FATAL` saying
the task must be implemented by base classes. That virtual-override dispatch
failure is separate follow-up work; this change does not claim a passing DMA
simulation.

## Validation

- Parameterized-class focus: 20/20 legacy and 13/13 JSON/VVP.
- Defaults focus: 97/97 legacy and 96/96 JSON/VVP.
- Complete legacy compiler suite: 1,804/1,804 in 59.01 seconds.
- Complete JSON/VVP suite: 872/872 in 15.08 seconds.
- Real-DPI UVM suite: 338/338, zero failed or skipped, in 537.60 seconds.
- External sv-tests: 1,021/1,027 in 83.12 seconds, with the same six frozen
  failures and unchanged result-class distribution.
- `make check`, all 111 negative tests, and three legacy queue-slice bytecode
  checks passed.

## Invocation gotchas

- Use the native Python 3.13 environment at
  `evidence/arm64-tooling/opentitan-python313`; it owns FuseSoC 2.4.5 and the
  matching HJSON dependencies. Do not invoke that FuseSoC script through a
  different Python installation.
- A generated `matrix-iverilog.scr` contains paths relative to its FuseSoC work
  directory. Replaying it from the repository root fails in preprocessing even
  though the source closure itself is valid.
- The active `resource-runner` retains a 45-second CPU limit per compiler or
  simulator process but has no RSS, address-space, data, file-size, compiler
  image-size, or output-size ceiling.
- Before this fix, Icarus could return exit zero even while `vvp.tgt` printed
  missing argument-row errors. Treat those target diagnostics as hard errors;
  process status alone was not a valid compile-success signal.
- VVP can likewise return zero after a UVM fatal because UVM calls `$finish`.
  Runtime classification must inspect the UVM report summary and test banner.
