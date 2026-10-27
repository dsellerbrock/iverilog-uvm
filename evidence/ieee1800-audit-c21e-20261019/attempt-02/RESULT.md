# §21.7 reducer results

Host: macOS localrun. Toolchain: compiler `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; VVP `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.

| Edition | Reducer | Exit | Wall | Peak RSS | Result |
|---|---|---:|---:|---:|---|
| 2017 | `r21v_off_window.sv` | 0 | 0.11 s | 6,602,752 B | `bx !` at `$dumpoff`; no change while off; `b0 !` at `$dumpon` |
| 2023 | `r21v_off_window.sv` | 0 | 0.15 s | 6,586,368 B | Same VCD behavior |
| 2017 | `r21v_event_never.sv` | 0 | 0.06 s | 6,635,520 B | Only `a` is declared; `1!` is its transition, not an event |
| 2023 | `r21v_event_never.sv` | 0 | 0.09 s | 6,569,984 B | Same VCD behavior |

The proposed event reducer does not reproduce the original event observation: `p21_07a_vcd.sv` triggers `ev` at #15, and its VCD emits the event marker at #15000 and again under `$dumpon` at #30000. The second marker is the remaining candidate for lead classification. These results do not establish a conformance gap on their own.
