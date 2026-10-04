# Flash 60-minute fallback replay (user-directed)

After four comparable 1,200-second Flash optimization runs showed no significant speedup, the user directed us to skip iteration 5 and proceed to the 60-minute run. This replay uses the restored `-O2` VVP runtime, the same prebuilt Flash image, DPI library, test, arguments, default seed, host, and 10 GB RSS cap. The full 49-target corpus will run only after a clean checked Flash PASS with zero UVM errors, fatals, and semantic/runtime debt.

Run result: in progress. The wrapper writes one-second RSS samples and 30-second progress records to `progress.jsonl`, the simulator log to `flash.log`, and the final verdict and hashes to `result.json`. Iteration 5 was skipped by explicit user direction. The full corpus remains gated on a clean checked PASS and zero semantic/runtime debt.
