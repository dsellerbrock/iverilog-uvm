# Flash associative-array microbenchmark

This isolated probe models the Flash scoreboard's 32-bit associative key and
value shape. It inserts 524,288 words into a local model, copies the aggregate
into a persistent model, and checks every copied value.

Recorded on the current VVP build: **PASS in 0.539 seconds**. The run printed
`INSERTED keys=524288`, `COPIED keys=524288`, and
`FLASH ASSOC BENCH PASS keys=524288`.

This makes a simple insert/copy/lookup loop of this size an unlikely sole cause
of the multi-minute Flash runtime. It does not measure the full OpenTitan class
callback path, UVM HDL reads, DUT behavior, or the concurrent simulation
scheduler, so it does not identify the timeout's root cause. No full census was
run for this probe. The generated `.vvp` binary is omitted.
