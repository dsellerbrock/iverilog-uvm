# §21.7 event reducer results

Host: macOS localrun. Toolchain: compiler `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; VVP `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.

| Edition | Probe | Exit | Wall | Peak RSS | Result |
|---|---|---:|---:|---:|---|
| 2017 | `r21v_event_checkpoint.sv` | 0 | 0.05 s | 6,438,912 B | `$var event` is present; `1!` appears in initial `$dumpvars` at #0 before trigger, at trigger #5, under `$dumpon` at #15, and `$dumpall` at #20 |
| 2023 | `r21v_event_checkpoint.sv` | 0 | 0.06 s | 6,438,912 B | Same output |
| 2017 | `r21v_event_declared.sv` | 0 | 0.05 s | 6,586,368 B | Untriggered `ev` has no `$var event` declaration; `a` alone is declared |
| 2023 | `r21v_event_declared.sv` | 0 | 0.08 s | 6,569,984 B | Same output |

The event-marker observation matches the lead's first candidate; the missing declaration matches its second. The lead must finish standard classification and open/closed issue dedupe before either is filed. This file records probe outcomes only.
