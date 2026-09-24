# VVP event kernel on Metal: disposable probe

Host: Apple M5, 10 GPU cores, Metal 4. No Icarus or Caliptra source was changed.

Build/run:

```sh
clang++ -O3 -std=c++17 -fobjc-arc -framework Foundation -framework Metal probe.mm -o probe
./probe
```

`probe.mm` models one 32-bit four-state AND per event. Its `a` bits encode
known ones; `b` bits encode unknowns. The independent batch has distinct
state slots and is safe to reorder. The chain has one shared state slot and
must preserve event order. The feedback case waits for the GPU after each
event, as a host scheduler would before inspecting new event work. GPU timings
include command submission and synchronization; shader compilation and buffer
allocation are outside timing. Warm-up dispatches precede timing. Each output
is checked against the CPU reference. `runs.txt` has seven full runs;
`medians.json` has their medians (milliseconds). An earlier trial was
discarded because the dependent-chain launch included idle GPU threads;
these runs launch one thread for that chain.

| Case | CPU | Metal | Result |
| --- | ---: | ---: | --- |
| 4,096 independent | 0.0032 | 0.1937 | match |
| 65,536 independent | 0.0496 | 0.1750 | match |
| 1,048,576 independent | 0.8363 | 0.8447 | match |
| 1,024 dependent | 0.0029 | 0.3865 | match |
| 65,536 dependent | 0.1916 | 11.8456 | match |
| 256 dependent with host feedback | not measured | 64.6853 | match |

The probe does not run VVP bytecode, callbacks, force/release, or Caliptra.
It establishes a lower-bound behavior for GPU submission on this host and
the loss of parallelism for dependent event chains. In VVP,
`vvp/schedule.cc:83-90` has polymorphic `event_s::run_run`; lines 127-140
have the ordered region queues; lines 1677-1948 drain one event at a time,
and its execution may enqueue work in the current slot. Host work includes
VPI callbacks (`vvp/vpi_callback.cc:1201-1240`), force/release callbacks
(`:1320-1381`), DPI coroutines (`vvp/vthread.cc:2039-2095`), and interpreter
thread execution (`vvp/vthread.cc:10530`). A full GPU replacement would need
equivalent host callback timing, four-state and force state, event ordering,
delta-cycle feedback, and stratified regions. This experiment does not
justify such a rewrite. A GPU vector batch might be revisited after an
actual VVP profile finds large independent vector bursts.
