# Disposable whole-event-kernel Metal model

No repository, pinned-source, shared-build, installed-tool, or active L0-run
file was changed. This is a synthetic model, not VVP or a Caliptra replay.

```sh
cd evidence/caliptra-l0-gpu-kernel-probe-20260924/whole-event-model
clang++ -O3 -std=c++17 -fobjc-arc -framework Foundation -framework Metal model.mm -o model
./model kernel.metal > results_trace1.txt
./model kernel.metal > results_trace2.txt
./model kernel.metal > results_trace3.txt
```

The model gives each isolated event island a two-slot delayed-update wheel,
ordered active events, a nonblocking assignment barrier, four-state 32-bit
vectors (0/1/X/Z), two dependent AND gates, fanout to an OR gate, and a
per-slot output checksum. The CPU and GPU versions use the same generated
stimulus; **every per-slot output** matched byte-for-byte in each warm-up
validation, and final values and accumulated checksums matched in all timed
runs. Each program run warms up once and then takes five trials per shape.
Times below are medians of the three per-run medians. Metal end-to-end time
includes the shared-memory stimulus copy, dispatch, wait, and output copy;
shader compilation, stimulus generation, and buffer allocation are excluded.
CPU runs a single serial scheduler model, consistent with current VVP's
single-event-at-a-time execution.

| Independent islands x slots | CPU ms | Metal end-to-end ms | CPU / Metal |
| --- | ---: | ---: | ---: |
| 1 x 4096 | 0.0587 | 7.4095 | 0.01 |
| 64 x 1024 | 0.8101 | 2.1643 | 0.37 |
| 128 x 256 | 0.4025 | 0.6933 | 0.58 |
| 256 x 256 | 0.8077 | 0.8120 | 0.99 |
| 512 x 256 | 1.6097 | 0.8540 | 1.88 |
| 1024 x 256 | 3.6972 | 0.9608 | 3.85 |
| 4096 x 256 | 13.3780 | 1.5037 | 8.90 |
| 16384 x 256 | 47.5628 | 5.3318 | 8.92 |

This model's crossover is roughly 256-512 **mutually independent** small
islands of 256 time slots; 256 is near parity across the three runs. The single
dependent island is about 126x slower on Metal. VVP's real scheduler uses
intrusive time-step and region lists and polymorphic events
(`vvp/schedule.cc:83-140,885-1040,1770-1948`), executes host bytecode
(`vvp/vthread.cc:10530`), and invokes VPI callbacks on value changes
(`vvp/vpi_callback.cc:1201-1240`) and DPI coroutines
(`vvp/vthread.cc:1971-2055`). Their device representation and exact callback
barriers are absent here. Existing separate feedback probe under
`evidence/caliptra-l0-gpu-kernel-probe-20260924/` measured about 64.7 ms for
only 256 host-visible dependent updates.

**Recommendation:** no full VVP GPU backend from this evidence. The model
shows an accelerator opportunity only for proven independent, homogeneous
event islands. Profile actual VVP event locality and callback frequency
before considering a narrow batch path. No Caliptra speedup is established.
