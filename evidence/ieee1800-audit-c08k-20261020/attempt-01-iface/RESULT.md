# §8.26 interface classes (IEEE 1800-2017 and 2023)

Slurm job 3492 used the pinned Icarus 13.0-devel toolchain from source `cc25756d187314742d347267c2a513b3e640a7fb`, with one CPU, 1 GiB, and a 30-second process-group timeout per command. Both language editions compiled and ran the positive probe in about 0.01 s and 12 MiB RSS.

The §8.26 standard example passed in both editions:

```text
FIFO 1 2
STACK 2 1
INH 7
```

This exercises parameterized interface classes, generic implementation by `Fifo` and `Stack`, calls through interface-typed handles, and the inherited implementation of `PutImp`/`GetImp` through `class C2 extends Fifo#(int,4)`.

Three negative controls also failed to compile in both editions with rule-specific diagnostics:

| Probe | Observed |
|---|---|
| `n08_26_missing_implementation.sv` | Rejected: non-virtual `MissingPut` does not implement `put` |
| `n08_26_constraint_in_interface.sv` | Rejected: constraint is not allowed in an interface class |
| `n08_26_nonpure_method.sv` | Rejected: method in interface class must be pure virtual |

The nested-interface probe `n08_26_nested_interface.sv` compiled successfully in both editions (empty compile logs, rc 0). The standard changed between editions: IEEE 1800-2017 §8.26 p.194 says an interface class shall not be nested within another class, so `-g2017` acceptance is a gap. IEEE 1800-2023 §8.26 p.206 only prohibits nesting inside another interface class, so this same `-g2023` acceptance is conforming. The audit lead filed [#845](https://github.com/dsellerbrock/iverilog-uvm/issues/845) as a 2017-only issue; its title/body were corrected to reflect the edition change.

The initial job runner expected this case to fail in both editions, following the lead's first interpretation. That expectation made the batch script report a failed expectation for `-g2023`; the result itself is conforming, and the job artifacts preserve the original run unchanged.

Open-and-closed GitHub dedupe searches are recorded in `dedupe-open-closed.txt` for `interface class`, `implements`, `8.26`, `pure virtual interface class`, and nested-interface wording. Returned issues #434, #5, #27, #30, #533, and #841 were reviewed and are about class/interface handle lifetime, virtual-interface members, runtime support, method dispatch, parameterized class parsing, or external constraints; none covers nesting an interface class in another class. No issue has been filed by the probe runner.

The same job reran the §18.5.13 error-order check with flushed markers and merged output. In both editions exactly 50 null-path diagnostics fall between `BEGIN E1C2` and `BEGIN E1C3`; E1C1 and E1C3 emitted none. The separately preserved original log has 100 diagnostics due to buffering. The remaining 50 are not yet independently attributed to E2C2.

The authoritative text is IEEE 1800-2017 §8.26, pp. 194–195, and IEEE 1800-2023 §8.26, p. 206; the positive sample is the standard's `PutImp`/`GetImp`/`Fifo`/`Stack` example. The next probe will check the other §8.26 subclauses and the 2023 nested-interface-class restriction.
