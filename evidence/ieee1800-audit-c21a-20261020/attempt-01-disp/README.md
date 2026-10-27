# §21.2.1, §21.3.6, and §21.3.7 display/file-I/O probe

Slurm job 3551 ran `p21_disp_io.sv` under both editions with the pinned compiler `cc25756d187314742d347267c2a513b3e640a7fb`, 1 CPU, 1 GiB, and a 10-minute limit. Each compile and simulation had a 30-second timeout. Both editions compiled and ran with exit code 0 and produced identical output; each wrote `abc\n` to its scratch `p21_t.txt`. Exact source and raw output are in [remote-3551](remote-3551/). Slurm accounting is disabled, so exact runtime and peak RSS are unavailable.

Observed stdout for both `-g2017` and `-g2023`:

```text
255
ff
10x1
17
ab
x y

FL 4 [abc
]
FE0 0 []
FO 0
FE1 1 1
```

This matches the expected default radix and width, empty-argument space, no-argument `$display` newline, fd-specific flush visibility, and clear/zero `$ferror` result after successful read. The failed-open case observes `$fopen` returning 0 and `$ferror` returning a nonzero code with a nonempty message; the standard does not explicitly specify behavior for querying `$ferror` on that zero descriptor, so this result is recorded without treating it as a conformance assertion.

Open/closed issue searches for `$displayh`, `$write`, `$fflush`, `$ferror`, `21.2.1`, and `21.3.7` are saved as `dedupe-*.json`. The broad `21.2.1` and `$write` queries found existing display-format issues (#797–#802 and unrelated source-code references); none cover the tested default radix/width, empty argument, flush visibility, or ferror behavior. `$fflush`'s only hit, #853, is unrelated to file I/O; `$ferror` and `21.3.7` had no hits.
