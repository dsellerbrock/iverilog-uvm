# OpenTitan Ibex I-cache ordered distribution — 2026-09-29

The package-provider patch lets the official `ibex_icache_smoke` compile cleanly. Its inherited constraints then failed at time zero because the joint solver applied ordered-component range requirements to an independent fixed-clock distribution. The paired 2017/2023 reducer is red on the previous installed VVP and green after the narrow `vvp_z3.cc` change. Adjacent ordered and unsatisfiable controls still fail closed, while the independent clipped-range control samples its legal values.

The selected smoke now passes `cfg.randomize()` and starts `ibex_icache_base_test`, but reaches the 1,800-second runtime cap without a DV pass banner. It uses the official `ibex_icache_base_vseq`, which requests 800–1,000 transactions. Compile has zero hard errors and zero semantic notices; the runtime peak physical footprint is 865,502,192 bytes. **Ibex DV remains RUNTIME_TIMEOUT.** This result does not establish that a longer timeout would pass.

`pre-fix-red.json`, `post-fix-green.json`, and `no-order-green.json` preserve focused reducer results. `result.json` and `runtime.log.gz` preserve the selected target, commands, hashes, and runtime transcript. The installed image for this replay has `ivl` SHA-256 `64fee51caec391de5e5667a97273cbac67b29553e4f2fa87a1e13f61b88a3316` and `vvp` SHA-256 `5b9ed7a8ed8006a998b55c0bc42d035aa99ddeb9c1b3495fd0b4651cf23600c3`. Caliptra was not run.

The integrated image also includes the separate I2C queue-last compiler fix. Its final gates are archived under `gates/`: JSON 4,131 run/0 failed using four shards; legacy 6,882 passed/0 failed (two not implemented, three expected failures); real-DPI UVM 362/362; VPI 140/140; negative 154/154; and `make check` passed.
